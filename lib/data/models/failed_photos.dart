import 'gallery_photo.dart';

/// Pourquoi une photo semble ratée (test).
enum FailReason { dark, bright, blurry }

/// Photos ratées (test, V2) : très sombres (photo de poche), très claires,
/// ou parmi les plus floues de la galerie. Rien d'automatique : elles sont
/// juste proposées en premier dans leur propre tri.
abstract final class FailedPhotos {
  /// Moyenne de luminosité (0 à 255) en dessous de laquelle c'est trop
  /// sombre, au-dessus de laquelle c'est trop clair.
  static const darkBelow = 28;
  static const brightAbove = 238;

  /// Floue : parmi les 8 % les moins nettes de la galerie, et sous un
  /// plafond (une galerie très nette n'a pas de photo floue pour autant).
  static const blurryShare = 0.08;
  static const blurryCap = 120;

  /// Il faut assez de photos mesurées pour juger la netteté.
  static const minMeasured = 30;

  static FailReason? reasonFor(GalleryPhoto photo, int blurryBelow) {
    final b = photo.brightness;
    final s = photo.sharpness;
    if (b == null || s == null || b < 0 || s < 0) return null;
    if (b < darkBelow) return FailReason.dark;
    if (b > brightAbove) return FailReason.bright;
    if (s < blurryBelow) return FailReason.blurry;
    return null;
  }

  /// Seuil de netteté de la galerie : sous lui, une photo est floue.
  static int blurryThreshold(List<GalleryPhoto> photos) {
    final values = [
      for (final p in photos)
        if ((p.sharpness ?? -1) >= 0 && !p.isVideo && !p.isScreenshot)
          p.sharpness!,
    ]..sort();
    if (values.length < minMeasured) return 0;
    final index = (values.length * blurryShare).floor();
    final percentile = values[index.clamp(0, values.length - 1)];
    return percentile < blurryCap ? percentile : blurryCap;
  }

  /// Les photos ratées, les pires d'abord (sombres et claires, puis les
  /// plus floues).
  static List<(GalleryPhoto, FailReason)> find(List<GalleryPhoto> photos) {
    final threshold = blurryThreshold(photos);
    final failed = [
      for (final p in photos)
        if (!p.isVideo && !p.isScreenshot)
          if (reasonFor(p, threshold) case final reason?) (p, reason),
    ];
    // De 0 (le pire) à 1 pour la lumière, puis de 1 à 2 pour le flou.
    double severity((GalleryPhoto, FailReason) f) => switch (f.$2) {
      FailReason.dark => f.$1.brightness! / darkBelow,
      FailReason.bright => (255 - f.$1.brightness!) / (255 - brightAbove),
      FailReason.blurry => 1 + f.$1.sharpness! / (threshold + 1),
    };
    return failed..sort((a, b) => severity(a).compareTo(severity(b)));
  }
}
