import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Empreinte d'une photo : formes grossières, détails, couleurs, et deux
/// mesures de qualité (netteté, luminosité) pour les photos ratées.
typedef VisualPrint = ({
  int hash,
  Uint8List detail,
  int color,
  int sharpness,
  int brightness,
});

/// Empreinte visuelle d'une photo, calculée sur le téléphone.
///
/// - [VisualPrint.hash] : dHash 64 bits. L'image est réduite à 9 × 8 pixels
///   en niveaux de gris ; chaque bit dit si un pixel est plus clair que son
///   voisin de droite. Sert à trouver vite les candidates.
/// - [VisualPrint.detail] : le même calcul en 17 × 16 (256 bits), pour
///   confirmer : deux captures d'une même app se ressemblent en 9 × 8, pas
///   en 16 × 16.
/// - [VisualPrint.color] : couleur moyenne des quatre quarts (4 bits par
///   canal). Les formes seules ne suffisent pas : deux paysages ciel +
///   colline ont les mêmes.
///
/// Une copie recompressée ou réduite (WhatsApp) garde des empreintes très
/// proches ; une autre photo, non.
abstract final class VisualHash {
  /// Au plus autant de bits différents sur 64 : candidates au doublon.
  static const duplicateDistance = 4;

  /// Au plus autant de bits différents sur 256 : la même photo.
  static const detailDistance = 20;

  /// Au plus autant de bits différents sur 64 entre deux photos d'une
  /// rafale (même scène, prises à la suite).
  static const burstDistance = 16;

  /// Écart de couleur toléré, par canal et par quart (sur 16 niveaux).
  static const colorTolerance = 1;

  /// Illisible : rien à comparer, on ne réessaie pas.
  static final VisualPrint unreadable = (
    hash: 0,
    detail: Uint8List(0),
    color: 0,
    sharpness: -1,
    brightness: -1,
  );

  /// Empreinte d'une image encodée (JPEG, PNG…), `null` si illisible.
  static VisualPrint? of(Uint8List encoded) {
    final decoded = img.decodeImage(encoded);
    if (decoded == null) return null;
    final coarse = _dHashBits(decoded, 8);
    var hash = 0;
    for (final bit in coarse) {
      hash = (hash << 1) | bit;
    }
    final fine = _dHashBits(decoded, 16);
    final detail = Uint8List(32);
    for (final (i, bit) in fine.indexed) {
      if (bit == 1) detail[i >> 3] |= 1 << (7 - (i & 7));
    }
    final quarters = img.copyResize(
      decoded,
      width: 2,
      height: 2,
      interpolation: img.Interpolation.average,
    );
    var color = 0;
    for (final pixel in quarters) {
      for (final channel in [pixel.r, pixel.g, pixel.b]) {
        color = (color << 4) | (channel.toInt() >> 4);
      }
    }
    final (:sharpness, :brightness) = quality(decoded);
    return (
      hash: hash,
      detail: detail,
      color: color,
      sharpness: sharpness,
      brightness: brightness,
    );
  }

  /// Netteté : variance du laplacien sur l'image en niveaux de gris (une
  /// photo floue a peu de contours nets, donc une variance faible).
  /// Luminosité : moyenne de 0 (noir) à 255 (blanc).
  static ({int sharpness, int brightness}) quality(img.Image image) {
    final gray = img.grayscale(
      image.width >= image.height
          ? img.copyResize(image, width: 160)
          : img.copyResize(image, height: 160),
    );
    final w = gray.width;
    final h = gray.height;
    double lum(int x, int y) => gray.getPixel(x, y).luminance.toDouble();
    var sum = 0.0;
    var sumSq = 0.0;
    var brightness = 0.0;
    var n = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        brightness += lum(x, y);
        if (x == 0 || y == 0 || x == w - 1 || y == h - 1) continue;
        final l =
            lum(x - 1, y) +
            lum(x + 1, y) +
            lum(x, y - 1) +
            lum(x, y + 1) -
            4 * lum(x, y);
        sum += l;
        sumSq += l * l;
        n++;
      }
    }
    final mean = n == 0 ? 0 : sum / n;
    final variance = n == 0 ? 0 : sumSq / n - mean * mean;
    return (
      sharpness: variance.round(),
      brightness: (brightness / (w * h)).round(),
    );
  }

  /// dHash de côté [size] : (size + 1) × size pixels, size² bits.
  static List<int> _dHashBits(img.Image image, int size) {
    final small = img.grayscale(
      img.copyResize(
        image,
        width: size + 1,
        height: size,
        interpolation: img.Interpolation.average,
      ),
    );
    return [
      for (var y = 0; y < size; y++)
        for (var x = 0; x < size; x++)
          small.getPixel(x, y).luminance > small.getPixel(x + 1, y).luminance
              ? 1
              : 0,
    ];
  }

  /// Nombre de bits différents entre deux empreintes 64 bits (0 à 64).
  static int distance(int a, int b) => bitCount(a ^ b);

  /// Nombre de bits différents entre deux empreintes détaillées.
  static int detailDistanceOf(Uint8List a, Uint8List b) {
    if (a.length != b.length) return 1 << 30;
    var count = 0;
    for (var i = 0; i < a.length; i++) {
      count += bitCount(a[i] ^ b[i]);
    }
    return count;
  }

  static int bitCount(int value) {
    var v = value;
    var count = 0;
    while (v != 0) {
      v &= v - 1;
      count++;
    }
    return count;
  }

  /// Couleurs des quatre quarts assez proches pour la même photo.
  static bool sameColors(int a, int b) {
    for (var i = 0; i < 12; i++) {
      final da = (a >> (i * 4)) & 0xF;
      final db = (b >> (i * 4)) & 0xF;
      if ((da - db).abs() > colorTolerance) return false;
    }
    return true;
  }

  /// Une image presque unie (photo noire, capture blanche) a une empreinte
  /// pauvre : toutes se ressembleraient. On ne s'y fie pas.
  static bool isInformative(int? hash) {
    if (hash == null) return false;
    final bits = bitCount(hash);
    return bits >= 6 && bits <= 58;
  }
}
