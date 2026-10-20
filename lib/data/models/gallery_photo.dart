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

  GalleryPhoto copyWith({int? sizeBytes, bool? isFavorite}) => GalleryPhoto(
    id: id,
    takenAt: takenAt,
    title: title,
    width: width,
    height: height,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    isFavorite: isFavorite ?? this.isFavorite,
    duration: duration,
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
      other.duration == duration;

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
  );
}
