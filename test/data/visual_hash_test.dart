import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tidypics/data/models/visual_hash.dart';

import '../helpers/test_images.dart';

void main() {
  test('la même photo, recompressée et réduite : empreintes proches', () {
    final original = VisualHash.of(jpg(scene(1)))!.hash;
    // Ce que fait WhatsApp : plus petite et plus compressée.
    final copyPrint = VisualHash.of(
      jpg(img.copyResize(scene(1), width: 160), quality: 40),
    )!;
    final copy = copyPrint.hash;
    expect(
      VisualHash.sameColors(
        VisualHash.of(jpg(scene(1)))!.color,
        copyPrint.color,
      ),
      isTrue,
    );
    expect(
      VisualHash.distance(original, copy),
      lessThanOrEqualTo(VisualHash.duplicateDistance),
    );
  });

  test('deux photos différentes : empreintes éloignées', () {
    final a = VisualHash.of(jpg(scene(1)))!.hash;
    final b = VisualHash.of(jpg(scene(4)))!.hash;
    expect(VisualHash.distance(a, b), greaterThan(VisualHash.burstDistance));
  });

  test('une image unie n\'est pas fiable', () {
    final plain = img.Image(width: 50, height: 50)
      ..clear(img.ColorRgb8(10, 10, 10));
    expect(VisualHash.isInformative(VisualHash.of(jpg(plain))!.hash), isFalse);
    expect(
      VisualHash.isInformative(VisualHash.of(jpg(scene(2)))!.hash),
      isTrue,
    );
  });

  test('distance : nombre de bits différents', () {
    expect(VisualHash.distance(0, 0), 0);
    expect(VisualHash.distance(0, 7), 3);
    expect(VisualHash.distance(0, -1), 64);
  });

  test('même composition, autres couleurs : couleurs différentes', () {
    // Comme les photos de test : ciel, soleil, colline, d'une autre teinte.
    final blue = img.Image(width: 200, height: 150)
      ..clear(img.ColorRgb8(90, 140, 220));
    final green = img.Image(width: 200, height: 150)
      ..clear(img.ColorRgb8(90, 200, 100));
    expect(
      VisualHash.sameColors(
        VisualHash.of(jpg(blue))!.color,
        VisualHash.of(jpg(green))!.color,
      ),
      isFalse,
    );
  });
}
