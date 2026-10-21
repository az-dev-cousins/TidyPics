import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tidypics/data/models/failed_photos.dart';
import 'package:tidypics/data/models/gallery_photo.dart';
import 'package:tidypics/data/models/visual_hash.dart';

import '../helpers/test_images.dart';

void main() {
  GalleryPhoto photo(String id, {int sharpness = 500, int brightness = 120}) =>
      GalleryPhoto(
        id: id,
        takenAt: DateTime(2025),
        sharpness: sharpness,
        brightness: brightness,
      );

  test('netteté : une image floutée est bien moins nette', () {
    final sharp = VisualHash.quality(scene(3));
    final blurred = VisualHash.quality(img.gaussianBlur(scene(3), radius: 8));
    expect(blurred.sharpness, lessThan(sharp.sharpness ~/ 3));
  });

  test('luminosité : noir et blanc', () {
    final black = img.Image(width: 50, height: 50)
      ..clear(img.ColorRgb8(5, 5, 5));
    final white = img.Image(width: 50, height: 50)
      ..clear(img.ColorRgb8(250, 250, 250));
    expect(VisualHash.quality(black).brightness, lessThan(10));
    expect(VisualHash.quality(white).brightness, greaterThan(245));
  });

  test('sombres, claires et floues, les pires d\'abord', () {
    final photos = [
      for (var i = 0; i < 40; i++) photo('ok$i', sharpness: 400 + i * 10),
      photo('poche', brightness: 8),
      photo('cramée', brightness: 250),
      photo('floue', sharpness: 15),
    ];
    final failed = FailedPhotos.find(photos);
    expect(failed.map((f) => f.$1.id), ['poche', 'cramée', 'floue']);
    expect(failed.map((f) => f.$2), [
      FailReason.dark,
      FailReason.bright,
      FailReason.blurry,
    ]);
  });

  test('galerie trop petite : on ne juge pas la netteté', () {
    final failed = FailedPhotos.find([photo('a', sharpness: 1), photo('b')]);
    expect(failed, isEmpty);
  });
}
