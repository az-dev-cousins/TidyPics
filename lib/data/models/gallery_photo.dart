import 'dart:typed_data';

/// Une photo ou une vidéo de la galerie du téléphone, telle que vue par l'app.
class GalleryPhoto {
  const GalleryPhoto({
    required this.id,
    required this.takenAt,
    this.title,
    this.width = 0,
    this.height = 0,
    this.sizeBytes,
    this.isFavorite = false,
    this.duration,
    this.folder,
    this.visualHash,
    this.visualColor,
    this.visualDetail,
  });

  /// Identifiant système (MediaStore sur Android, PHAsset sur iOS).
  final String id;
  final DateTime takenAt;

  /// Nom du fichier, s'il est connu (ex. `IMG_1234.JPG`).
  final String? title;
  final int width;
  final int height;

  /// Taille du fichier en octets, `null` tant qu'elle n'a pas été lue.
  final int? sizeBytes;
  final bool isFavorite;

  /// Durée d'une vidéo ; `null` pour une photo.
  final Duration? duration;

  bool get isVideo => duration != null;

  /// Dossier du fichier sur le téléphone (Android), ex. `DCIM/Camera/`.
  /// `null` sur iOS, où les photos ne sont pas rangées en dossiers.
  final String? folder;

  /// Nom du dossier tel que la galerie l'affiche : « Camera »,
  /// « WhatsApp Images »…
  String? get folderName {
    final path = folder;
    if (path == null) return null;
    final parts = path.split('/').where((p) => p.isNotEmpty);
    return parts.isEmpty ? null : parts.last;
  }

  /// Capture d'écran : rangée dans un dossier « Screenshots » (Android, et
  /// iOS où la galerie le signale), ou nommée « Screenshot_… ».
  bool get isScreenshot {
    final folderLower = folder?.toLowerCase() ?? '';
    final name = title?.toLowerCase() ?? '';
    return folderLower.contains('screenshot') || name.startsWith('screenshot');
  }

  /// Empreinte visuelle (dHash 64 bits) : deux photos qui se ressemblent ont
  /// des empreintes proches. `null` tant qu'elle n'est pas calculée.
  final int? visualHash;

  /// Couleur moyenne des quatre quarts de l'image (voir `VisualHash`).
  final int? visualColor;

  /// Empreinte détaillée (256 bits), pour confirmer un doublon. Calculée,
  /// donc hors de l'égalité.
  final Uint8List? visualDetail;

  /// Au-delà, une vidéo passe en tête du tri : c'est là qu'on libère le plus.
  static const bigVideoBytes = 100 * 1000 * 1000;

  /// Taille inconnue (iOS avant lecture) : on se fie à la durée.
  static const bigVideoDuration = Duration(minutes: 1);

  bool get isBigVideo {
    final d = duration;
    if (d == null) return false;
    final size = sizeBytes;
    return size != null && size > 0
        ? size >= bigVideoBytes
        : d >= bigVideoDuration;
  }

  static const _rawExtensions = {
    'dng',
    'cr2',
    'cr3',
    'nef',
    'arw',
    'raf',
    'orf',
    'rw2',
    'pef',
    'srw',
  };

  /// Vrai si le fichier est un RAW (d'après son extension).
  bool get isRaw {
    final name = title;
    if (name == null) return false;
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    return _rawExtensions.contains(name.substring(dot + 1).toLowerCase());
  }

  GalleryPhoto copyWith({
    int? sizeBytes,
    bool? isFavorite,
    int? visualHash,
    int? visualColor,
    Uint8List? visualDetail,
  }) => GalleryPhoto(
    id: id,
    takenAt: takenAt,
    title: title,
    width: width,
    height: height,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    isFavorite: isFavorite ?? this.isFavorite,
    duration: duration,
    folder: folder,
    visualHash: visualHash ?? this.visualHash,
    visualColor: visualColor ?? this.visualColor,
    visualDetail: visualDetail ?? this.visualDetail,
  );

  @override
  bool operator ==(Object other) =>
      other is GalleryPhoto &&
      other.id == id &&
      other.takenAt == takenAt &&
      other.title == title &&
      other.width == width &&
      other.height == height &&
      other.sizeBytes == sizeBytes &&
      other.isFavorite == isFavorite &&
      other.duration == duration &&
      other.folder == folder &&
      other.visualHash == visualHash &&
      other.visualColor == visualColor;

  @override
  int get hashCode => Object.hash(
    id,
    takenAt,
    title,
    width,
    height,
    sizeBytes,
    isFavorite,
    duration,
    folder,
    visualHash,
    visualColor,
  );
}
