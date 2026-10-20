import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/gallery_photo.dart';

/// Niveau d'accès à la galerie accordé par l'utilisateur.
enum GalleryAccess {
  /// Pas encore demandé.
  notDetermined,

  /// Toutes les photos.
  full,

  /// Seulement les photos choisies (iOS, Android 14+).
  limited,

  /// Refusé : l'app ne peut rien faire.
  denied,
}

/// Stockage du téléphone, pour la barre du menu.
class DeviceStorage {
  const DeviceStorage({
    required this.total,
    required this.free,
    this.photos,
    this.videos,
  });

  final int total;
  final int free;

  /// Place prise par les photos et les vidéos, si le système la donne
  /// (Android).
  final int? photos;
  final int? videos;

  int get used => total - free;
}

/// Accès à la galerie du téléphone. Seule implémentation réelle :
/// [PhotoManagerGallerySource]. Les tests en utilisent une fausse.
abstract interface class GallerySource {
  Future<GalleryAccess> currentAccess();
  Future<GalleryAccess> requestAccess();
  Future<void> openAppSettings();

  /// Permet d'ajouter des photos à la sélection en accès limité.
  Future<void> extendLimitedAccess();

  /// Toutes les photos de la galerie, sans les vidéos.
  Future<List<GalleryPhoto>> fetchAll();

  /// Taille du fichier en octets (0 si inconnue).
  Future<int> fileSize(String id);

  Future<Uint8List?> thumbnail(String id, {int size = 200});

  /// Fichier d'une photo ou d'une vidéo : lecture sur la carte, partage
  /// (`null` si illisible).
  Future<File?> mediaFile(String id);

  /// Android : la galerie du système sait ouvrir une photo précise.
  bool get canOpenInGallery;

  /// Ouvre la photo dans la galerie du système. `false` si impossible.
  Future<bool> openInGallery(String id);

  /// Met ou retire le favori système. Renvoie `false` en cas d'échec.
  Future<bool> setFavorite(String id, {required bool favorite});

  /// Envoie les photos à la corbeille système, en un minimum de popups.
  /// Renvoie les identifiants réellement envoyés (vide si refusé).
  /// [onProgress] reçoit le nombre de photos déjà envoyées.
  Future<List<String>> moveToTrash(
    List<GalleryPhoto> photos, {
    ValueChanged<int>? onProgress,
  });

  /// Android seulement : sort les photos de la corbeille.
  Future<List<String>> restoreFromTrash(List<GalleryPhoto> photos);

  /// Android seulement : la corbeille système est lisible et restaurable.
  bool get hasRestorableTrash;

  /// Android : parmi ces photos envoyées à la corbeille, celles qui y sont
  /// encore (elles ont pu être restaurées ou effacées ailleurs).
  Future<Set<String>> stillInTrash(List<String> ids);

  /// Android : efface définitivement ces photos de la corbeille (une popup,
  /// aucune avec « Gestion des médias »). Renvoie les identifiants effacés.
  Future<List<String>> deleteForever(List<String> ids);

  /// Capacité et espace libre du téléphone (`null` si inconnus).
  Future<DeviceStorage?> deviceStorage();

  /// Android 12+ : la permission « Gestion des médias » existe.
  Future<bool> supportsManageMedia();
  Future<bool> canManageMedia();
  Future<void> requestManageMedia();

  /// Émet quand la galerie change (photo ajoutée ou supprimée ailleurs).
  Stream<void> get changes;
}

/// Implémentation basée sur `photo_manager`.
class PhotoManagerGallerySource implements GallerySource {
  static const _permission = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  static const _device = MethodChannel('tidypics/device');

  /// `PHAssetMediaSubtype.photoScreenshot`.
  static const _iosScreenshot = 1 << 2;

  /// Lots d'envoi à la corbeille (Android). Mesuré sur émulateur : un lot de
  /// 3 000 photos passe sans erreur, en une seule popup.
  /// - Sans « Gestion des médias », chaque lot est une popup : le moins de
  ///   lots possible.
  /// - Avec, pas de popup : des lots plus petits font avancer la barre.
  static const trashBatchPerPopup = 3000;
  static const trashBatchSilent = 250;

  final _changes = StreamController<void>.broadcast(
    onListen: _startNotify,
    onCancel: _stopNotify,
  );

  static void _startNotify() => unawaited(PhotoManager.startChangeNotify());
  static void _stopNotify() => unawaited(PhotoManager.stopChangeNotify());

  bool _callbackAdded = false;

  void _onChange(MethodCall _) => _changes.add(null);

  @override
  Stream<void> get changes {
    if (!_callbackAdded) {
      PhotoManager.addChangeCallback(_onChange);
      _callbackAdded = true;
    }
    return _changes.stream;
  }

  GalleryAccess _map(PermissionState state) => switch (state) {
    PermissionState.authorized => GalleryAccess.full,
    PermissionState.limited => GalleryAccess.limited,
    PermissionState.notDetermined => GalleryAccess.notDetermined,
    PermissionState.denied ||
    PermissionState.restricted => GalleryAccess.denied,
  };

  @override
  Future<GalleryAccess> currentAccess() async =>
      _map(await PhotoManager.getPermissionState(requestOption: _permission));

  @override
  Future<GalleryAccess> requestAccess() async => _map(
    await PhotoManager.requestPermissionExtend(requestOption: _permission),
  );

  @override
  Future<void> openAppSettings() => PhotoManager.openSetting();

  @override
  Future<void> extendLimitedAccess() =>
      PhotoManager.presentLimited(type: RequestType.common);

  @override
  Future<List<GalleryPhoto>> fetchAll() async {
    final filter = FilterOptionGroup(
      imageOption: const FilterOption(needTitle: true),
      videoOption: const FilterOption(
        needTitle: true,
        // Par défaut, photo_manager ignore les vidéos de plus d'un jour. Pas
        // plus de 7 jours : la durée part en millisecondes sur 32 bits.
        durationConstraint: DurationConstraint(max: Duration(days: 7)),
      ),
      orders: [const OrderOption(type: OrderOptionType.createDate)],
    );
    final count = await PhotoManager.getAssetCount(
      filterOption: filter,
      type: RequestType.common,
    );
    const page = 500;
    final photos = <GalleryPhoto>[];
    for (var start = 0; start < count; start += page) {
      final assets = await PhotoManager.getAssetListRange(
        start: start,
        end: start + page,
        filterOption: filter,
        type: RequestType.common,
      );
      photos.addAll(assets.map(_toPhoto));
    }
    if (!Platform.isAndroid) return photos;
    // Android : toutes les tailles en une requête, pour mettre les grosses
    // vidéos en tête et chiffrer le panier sans attendre.
    try {
      final sizes = await _device.invokeMapMethod<String, int>('sizes');
      if (sizes == null) return photos;
      return [
        for (final p in photos)
          sizes[p.id] == null ? p : p.copyWith(sizeBytes: sizes[p.id]),
      ];
    } on PlatformException catch (error) {
      debugPrint('Tailles illisibles : $error');
      return photos;
    }
  }

  GalleryPhoto _toPhoto(AssetEntity asset) => GalleryPhoto(
    id: asset.id,
    takenAt: asset.createDateTime,
    title: asset.title,
    width: asset.orientatedWidth,
    height: asset.orientatedHeight,
    isFavorite: asset.isFavorite,
    duration: asset.type == AssetType.video ? asset.videoDuration : null,
    // iOS ne range pas en dossiers : une capture d'écran (sous-type
    // signalé par Photos) reçoit le dossier « Screenshots ».
    folder:
        asset.relativePath ??
        (Platform.isIOS && asset.subtype & _iosScreenshot != 0
            ? 'Screenshots'
            : null),
  );

  AssetEntity _entity(GalleryPhoto photo) => AssetEntity(
    id: photo.id,
    typeInt: (photo.isVideo ? AssetType.video : AssetType.image).index,
    duration: photo.duration?.inSeconds ?? 0,
    width: photo.width,
    height: photo.height,
    title: photo.title,
    isFavorite: photo.isFavorite,
  );

  @override
  Future<int> fileSize(String id) async {
    try {
      return await _entity(GalleryPhoto(id: id, takenAt: DateTime(1970)))
          .fileSize;
    } on PlatformException {
      return 0;
    }
  }

  @override
  Future<Uint8List?> thumbnail(String id, {int size = 200}) async {
    final entity = await AssetEntity.fromId(id);
    return entity?.thumbnailDataWithSize(
      ThumbnailSize.square(size),
      quality: 80,
    );
  }

  @override
  Future<File?> mediaFile(String id) async {
    try {
      final entity = await AssetEntity.fromId(id);
      return await entity?.file;
    } on Object catch (error) {
      debugPrint('Vidéo illisible $id : $error');
      return null;
    }
  }

  @override
  bool get canOpenInGallery => Platform.isAndroid;

  @override
  Future<bool> openInGallery(String id) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _device.invokeMethod<bool>('openInGallery', {'id': id}) ??
          false;
    } on PlatformException catch (error) {
      debugPrint('Ouverture dans la galerie impossible : $error');
      return false;
    }
  }

  @override
  Future<bool> setFavorite(String id, {required bool favorite}) async {
    final entity = await AssetEntity.fromId(id);
    if (entity == null) return false;
    try {
      if (Platform.isAndroid) {
        await PhotoManager.editor.android.favoriteAsset(
          entity: entity,
          favorite: favorite,
        );
      } else {
        await PhotoManager.editor.darwin.favoriteAsset(
          entity: entity,
          favorite: favorite,
        );
      }
      return true;
    } on Object catch (error) {
      debugPrint('Favori impossible pour $id : $error');
      return false;
    }
  }

  @override
  Future<List<String>> moveToTrash(
    List<GalleryPhoto> photos, {
    ValueChanged<int>? onProgress,
  }) async {
    if (photos.isEmpty) return const [];
    if (!Platform.isAndroid) {
      // iOS : un seul lot, une seule popup. Les photos vont dans
      // « Récemment supprimés ».
      return PhotoManager.editor.deleteWithIds(
        photos.map((p) => p.id).toList(),
      );
    }
    final size = await canManageMedia() ? trashBatchSilent : trashBatchPerPopup;
    final trashed = <String>[];
    for (var i = 0; i < photos.length; i += size) {
      final batch = photos.skip(i).take(size).map(_entity).toList();
      final done = await PhotoManager.editor.android.moveToTrash(batch);
      // Lot refusé : on s'arrête là, le reste du panier est conservé.
      if (done.isEmpty) break;
      trashed.addAll(done);
      onProgress?.call(trashed.length);
    }
    return trashed;
  }

  @override
  Future<List<String>> restoreFromTrash(List<GalleryPhoto> photos) {
    if (!Platform.isAndroid || photos.isEmpty) return Future.value(const []);
    return PhotoManager.editor.android.restoreFromTrash(
      photos.map(_entity).toList(),
    );
  }

  @override
  bool get hasRestorableTrash => Platform.isAndroid;

  @override
  Future<Set<String>> stillInTrash(List<String> ids) async {
    if (!Platform.isAndroid || ids.isEmpty) return const {};
    final found = await _device.invokeListMethod<String>('trashedIds', {
      'ids': ids,
    });
    return {...?found};
  }

  @override
  Future<List<String>> deleteForever(List<String> ids) async {
    if (!Platform.isAndroid || ids.isEmpty) return const [];
    final done = await _device.invokeListMethod<String>('deleteForever', {
      'ids': ids,
    });
    return done ?? const [];
  }

  @override
  Future<DeviceStorage?> deviceStorage() async {
    try {
      final values = await _device.invokeMapMethod<String, Object?>('storage');
      final total = (values?['total'] as num?)?.toInt() ?? 0;
      if (total <= 0) return null;
      return DeviceStorage(
        total: total,
        free: (values?['free'] as num?)?.toInt() ?? 0,
        photos: (values?['photos'] as num?)?.toInt(),
        videos: (values?['videos'] as num?)?.toInt(),
      );
    } on Object catch (error) {
      debugPrint('Stockage illisible : $error');
      return null;
    }
  }

  @override
  Future<bool> supportsManageMedia() async {
    if (!Platform.isAndroid) return false;
    final sdk = await _device.invokeMethod<int>('sdkInt') ?? 0;
    return sdk >= 31;
  }

  @override
  Future<bool> canManageMedia() => PhotoManager.canManageMedia();

  @override
  Future<void> requestManageMedia() => PhotoManager.requestManageMedia();
}
