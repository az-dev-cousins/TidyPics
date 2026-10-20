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

  /// Met ou retire le favori système. Renvoie `false` en cas d'échec.
  Future<bool> setFavorite(String id, {required bool favorite});

  /// Envoie les photos à la corbeille système, en un minimum de popups.
  /// Renvoie les identifiants réellement envoyés (vide si refusé).
  Future<List<String>> moveToTrash(List<GalleryPhoto> photos);

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
      type: RequestType.image,
      mediaLocation: false,
    ),
  );

  static const _device = MethodChannel('tidypics/device');

  /// Taille maximum d'un lot de suppression. Au-delà, Android peut échouer
  /// (limite de taille des échanges entre processus). À affiner au lot 0bis.
  static const trashBatchSize = 500;

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
      PhotoManager.presentLimited(type: RequestType.image);

  @override
  Future<List<GalleryPhoto>> fetchAll() async {
    final filter = FilterOptionGroup(
      imageOption: const FilterOption(needTitle: true),
      orders: [const OrderOption(type: OrderOptionType.createDate)],
    );
    final count = await PhotoManager.getAssetCount(
      filterOption: filter,
      type: RequestType.image,
    );
    const page = 500;
    final photos = <GalleryPhoto>[];
    for (var start = 0; start < count; start += page) {
      final assets = await PhotoManager.getAssetListRange(
        start: start,
        end: start + page,
        filterOption: filter,
        type: RequestType.image,
      );
      photos.addAll(assets.map(_toPhoto));
    }
    return photos;
  }

  GalleryPhoto _toPhoto(AssetEntity asset) => GalleryPhoto(
    id: asset.id,
    takenAt: asset.createDateTime,
    title: asset.title,
    width: asset.orientatedWidth,
    height: asset.orientatedHeight,
    isFavorite: asset.isFavorite,
  );

  AssetEntity _entity(GalleryPhoto photo) => AssetEntity(
    id: photo.id,
    typeInt: AssetType.image.index,
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
  Future<List<String>> moveToTrash(List<GalleryPhoto> photos) async {
    if (photos.isEmpty) return const [];
    if (!Platform.isAndroid) {
      // iOS : un seul lot, une seule popup. Les photos vont dans
      // « Récemment supprimés ».
      return PhotoManager.editor.deleteWithIds(
        photos.map((p) => p.id).toList(),
      );
    }
    final trashed = <String>[];
    for (var i = 0; i < photos.length; i += trashBatchSize) {
      final batch = photos.skip(i).take(trashBatchSize).map(_entity).toList();
      final done = await PhotoManager.editor.android.moveToTrash(batch);
      // Lot refusé : on s'arrête là, le reste du panier est conservé.
      if (done.isEmpty) break;
      trashed.addAll(done);
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
