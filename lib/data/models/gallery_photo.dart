/// Une photo de la galerie du téléphone, telle que vue par l'app.
class GalleryPhoto {
  const GalleryPhoto({
    required this.id,
    required this.takenAt,
    this.title,
    this.width = 0,
    this.height = 0,
    this.sizeBytes,
    this.isFavorite = false,
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
      other.isFavorite == isFavorite;

  @override
  int get hashCode =>
      Object.hash(id, takenAt, title, width, height, sizeBytes, isFavorite);
}
