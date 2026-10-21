import 'gallery_photo.dart';
import 'visual_hash.dart';

/// Ce qu'on propose au tri : une photo seule, une rafale ou une paire
/// JPG + RAW. Un groupe est toujours tiré comme un seul élément (F2).
enum PhotoItemKind { single, burst, rawPair }

class PhotoItem {
  PhotoItem.single(GalleryPhoto photo)
    : kind = PhotoItemKind.single,
      photos = [photo];

  PhotoItem.burst(List<GalleryPhoto> photos)
    : assert(photos.length > 1, 'Une rafale a au moins deux photos'),
      kind = PhotoItemKind.burst,
      photos = List.unmodifiable(photos);

  /// [jpg] d'abord, puis [raw].
  PhotoItem.rawPair({required GalleryPhoto jpg, required GalleryPhoto raw})
    : kind = PhotoItemKind.rawPair,
      photos = List.unmodifiable([jpg, raw]);

  final PhotoItemKind kind;
  final List<GalleryPhoto> photos;

  /// Photo affichée sur la carte.
  GalleryPhoto get cover => photos.first;
  String get id => photos.map((p) => p.id).join('+');
  DateTime get takenAt => cover.takenAt;

  int get sizeBytes => photos.fold(0, (sum, p) => sum + (p.sizeBytes ?? 0));
}

const _jpgLike = {'jpg', 'jpeg', 'heic', 'heif'};

/// Extension en minuscules, ou `null` sans nom de fichier.
String? _extension(GalleryPhoto photo) {
  final name = photo.title;
  if (name == null) return null;
  final dot = name.lastIndexOf('.');
  return dot < 0 ? null : name.substring(dot + 1).toLowerCase();
}

/// Nom commun aux deux fichiers d'une paire : ce qui précède le premier
/// point. Les Pixel ajoutent des suffixes (`PXL_….RAW-01.COVER.jpg` et
/// `PXL_….RAW-02.ORIGINAL.dng`), les autres appareils non (`DSC_1.JPG`).
String? _baseName(GalleryPhoto photo) {
  final name = photo.title;
  if (name == null) return null;
  final dot = name.indexOf('.');
  return (dot < 0 ? name : name.substring(0, dot)).toLowerCase();
}

/// Paires JPG + RAW (F6) : même nom de fichier hors extension, prises à
/// moins de [tolerance] l'une de l'autre.
List<PhotoItem> findRawPairs(
  List<GalleryPhoto> photos, {
  Duration tolerance = const Duration(seconds: 2),
}) {
  final jpgsByName = <String, List<GalleryPhoto>>{};
  for (final photo in photos) {
    final name = _baseName(photo);
    if (name != null && _jpgLike.contains(_extension(photo))) {
      (jpgsByName[name] ??= []).add(photo);
    }
  }
  final pairs = <PhotoItem>[];
  final used = <String>{};
  for (final raw in photos.where((p) => p.isRaw)) {
    final candidates = jpgsByName[_baseName(raw)] ?? const [];
    for (final jpg in candidates) {
      if (used.contains(jpg.id)) continue;
      if (jpg.takenAt.difference(raw.takenAt).abs() <= tolerance) {
        pairs.add(PhotoItem.rawPair(jpg: jpg, raw: raw));
        used.add(jpg.id);
        break;
      }
    }
  }
  return pairs;
}

/// Dossiers de photos reçues ou enregistrées d'un coup : plusieurs photos
/// différentes y ont la même heure, ce ne sont pas des rafales.
const _receivedFolders = [
  'whatsapp',
  'telegram',
  'signal',
  'messenger',
  'snapchat',
  'instagram',
  'facebook',
  'discord',
  'bluetooth',
  'download',
  'screenshot',
];

/// Vrai pour un dossier de photos reçues (WhatsApp, Telegram,
/// téléchargements, captures d'écran…).
bool isReceivedFolder(String? folder) {
  if (folder == null) return false;
  final lower = folder.toLowerCase();
  return _receivedFolders.any(lower.contains);
}

/// Deux photos de suite font partie d'une rafale : prises à moins de
/// [gap] et, si leurs empreintes sont connues, presque identiques.
///
/// [similarGap] (test) : au-delà de [gap] et jusqu'à [similarGap], deux
/// photos qui se ressemblent (formes et couleurs) font aussi partie de la
/// rafale : la même vue prise toutes les 20 secondes.
bool _sameBurst(
  GalleryPhoto previous,
  GalleryPhoto photo,
  Duration gap,
  Duration? similarGap,
) {
  final elapsed = photo.takenAt.difference(previous.takenAt);
  final a = previous.visualHash;
  final b = photo.visualHash;
  final known = VisualHash.isInformative(a) && VisualHash.isInformative(b);
  if (elapsed <= gap) {
    return !known || VisualHash.distance(a!, b!) <= VisualHash.burstDistance;
  }
  if (similarGap == null || elapsed > similarGap || !known) return false;
  final colorsA = previous.visualColor;
  final colorsB = photo.visualColor;
  return VisualHash.distance(a!, b!) <= VisualHash.burstDistance &&
      colorsA != null &&
      colorsB != null &&
      VisualHash.sameColors(colorsA, colorsB);
}

/// Écart maximum entre deux photos semblables d'une même rafale (test).
const similarBurstGap = Duration(minutes: 2);

/// Au-delà, ce n'est pas une rafale : ce sont des fichiers sans date de prise
/// de vue, copiés d'un coup (sauvegarde restaurée, téléchargements). Ils se
/// trient un par un.
const maxBurstSize = 50;

/// Découpe la galerie en éléments à trier (F5, F6).
///
/// 1. Les paires JPG + RAW sont repérées d'abord : ce n'est pas une rafale.
/// 2. Parmi les autres photos, triées par date, celles prises à moins de
///    [burstGap] de la précédente forment une rafale, jusqu'à [maxBurstSize].
///    Il faut aussi le même dossier, pas un dossier de photos reçues
///    (WhatsApp…), et des empreintes proches quand elles sont connues.
///
/// Le résultat est trié par date.
List<PhotoItem> groupPhotos(
  List<GalleryPhoto> photos, {
  Duration burstGap = const Duration(seconds: 3),
  bool bursts = true,
  Duration? similarGap,
}) {
  final pairs = findRawPairs(photos);
  final paired = {for (final pair in pairs) ...pair.photos.map((p) => p.id)};
  final singles = photos.where((p) => !paired.contains(p.id)).toList()
    ..sort((a, b) => a.takenAt.compareTo(b.takenAt));

  final items = <PhotoItem>[...pairs];
  var run = <GalleryPhoto>[];
  void flush() {
    if (run.length > 1 && run.length <= maxBurstSize) {
      items.add(PhotoItem.burst(run));
    } else {
      items.addAll(run.map(PhotoItem.single));
    }
    run = [];
  }

  // Une rafale reste dans un seul dossier : on les parcourt un par un.
  final byFolder = <String?, List<GalleryPhoto>>{};
  for (final photo in singles) {
    // Une vidéo, une capture d'écran ou une photo reçue (WhatsApp,
    // téléchargement…) se trie toujours seule.
    if (photo.isVideo ||
        photo.isScreenshot ||
        !bursts ||
        isReceivedFolder(photo.folder)) {
      items.add(PhotoItem.single(photo));
    } else {
      (byFolder[photo.folder] ??= []).add(photo);
    }
  }
  for (final photos in byFolder.values) {
    for (final photo in photos) {
      final previous = run.lastOrNull;
      if (previous == null ||
          !_sameBurst(previous, photo, burstGap, similarGap)) {
        flush();
      }
      run.add(photo);
    }
    flush();
  }

  items.sort((a, b) => a.takenAt.compareTo(b.takenAt));
  return items;
}
