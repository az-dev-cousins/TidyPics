import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Une « photo » : dégradé et disque, placés selon [seed].
img.Image scene(int seed, {int width = 320, int height = 240}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final v = ((x * (seed + 1) + y * (7 - seed % 5)) % 256);
      image.setPixelRgb(x, y, v, (v + seed * 40) % 256, 255 - v);
    }
  }
  img.fillCircle(
    image,
    x: (width * (0.2 + 0.15 * (seed % 5))).round(),
    y: height ~/ 2,
    radius: height ~/ 4,
    color: img.ColorRgb8(250, 230, 120),
  );
  return image;
}

Uint8List jpg(img.Image image, {int quality = 90}) =>
    img.encodeJpg(image, quality: quality);
