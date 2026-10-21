import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/models/duplicates.dart';
import 'package:tidypics/data/models/gallery_photo.dart';

void main() {
  final t0 = DateTime(2025, 6, 1, 12);
  const hash = 0x0F0F0F0F0F0F0F0F;
  const color = 0x123456789ABC;
  final detail = Uint8List.fromList(List.filled(32, 0x5A));

  GalleryPhoto photo(
    String id, {
    int h = hash,
    int minutes = 0,
    String folder = 'DCIM/Camera/',
    int width = 4000,
    int size = 3000000,
    String? title,
    int c = color,
    Uint8List? d,
  }) => GalleryPhoto(
    id: id,
    takenAt: t0.add(Duration(minutes: minutes)),
    title: title ?? '$id.jpg',
    folder: folder,
    width: width,
    height: width * 3 ~/ 4,
    sizeBytes: size,
    visualHash: h,
    visualColor: c,
    visualDetail: d ?? detail,
  );

  test('la copie WhatsApp rejoint l\'original, qui est gardé', () {
    final groups = findDuplicates([
      photo(
        'copie',
        h: hash ^ 0x3,
        minutes: 90,
        width: 1600,
        size: 200000,
        folder: 'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/',
      ),
      photo('original'),
      photo('autre', h: 0x70F0F0F0F0F0F0F0, minutes: 5),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.best.id, 'original');
    expect(groups.single.photos.map((p) => p.id), ['original', 'copie']);
    expect(groups.single.extraBytes, 200000);
  });

  test('deux photos d\'une rafale ne sont pas des doublons', () {
    final groups = findDuplicates([
      photo('a'),
      GalleryPhoto(
        id: 'b',
        takenAt: t0.add(const Duration(seconds: 1)),
        folder: 'DCIM/Camera/',
        visualHash: hash ^ 0x1,
        visualColor: color,
        visualDetail: detail,
      ),
    ]);
    expect(groups, isEmpty);
  });

  test('ni les vidéos, ni les RAW, ni les images unies', () {
    final groups = findDuplicates([
      photo('a', title: 'DSC_1.JPG'),
      photo('raw', title: 'DSC_1.DNG', minutes: 60),
      GalleryPhoto(
        id: 'v',
        takenAt: t0,
        visualHash: hash,
        duration: const Duration(seconds: 3),
      ),
      photo('noir1', h: 0, minutes: 10),
      photo('noir2', h: 0, minutes: 20),
    ]);
    expect(groups, isEmpty);
  });

  test('les groupes qui libèrent le plus passent en premier', () {
    final groups = findDuplicates([
      photo('a1'),
      photo('a2', minutes: 30, size: 100),
      photo('b1', h: 0x70F0F0F0F0F0F0F0),
      photo('b2', h: 0x70F0F0F0F0F0F0F0, minutes: 30, size: 900000),
    ]);
    expect(groups.map((g) => g.best.id), ['b1', 'a1']);
  });

  test('mêmes formes, autres couleurs : pas un doublon', () {
    final groups = findDuplicates([
      photo('bleu'),
      photo('vert', minutes: 60, c: 0xFEDCBA987654),
    ]);
    expect(groups, isEmpty);
  });

  test('pas de proche en proche : chacune ressemble à la meilleure', () {
    // a ~ b et b ~ c, mais a et c ont 6 bits d'écart.
    final groups = findDuplicates([
      photo('a', width: 5000),
      photo('b', h: hash ^ 0x7, minutes: 10),
      photo('c', h: hash ^ 0x3F, minutes: 20),
    ]);
    expect(groups.single.photos.map((p) => p.id), ['a', 'b']);
  });

  test('mêmes grandes formes, détails différents : pas un doublon', () {
    // Deux captures d'une même app : pareilles de loin, pas de près.
    final groups = findDuplicates([
      photo('capture1'),
      photo(
        'capture2',
        minutes: 60,
        d: Uint8List.fromList(List.filled(32, 0xA5)),
      ),
    ]);
    expect(groups, isEmpty);
  });

  test('proportions différentes : pas un doublon', () {
    final groups = findDuplicates([
      photo('paysage'),
      GalleryPhoto(
        id: 'carre',
        takenAt: t0.add(const Duration(hours: 1)),
        width: 1000,
        height: 1000,
        visualHash: hash,
        visualColor: color,
        visualDetail: detail,
      ),
    ]);
    expect(groups, isEmpty);
  });

  test('copie exacte, même date et même dossier : un doublon', () {
    final groups = findDuplicates([photo('a'), photo('copie_a')]);
    expect(groups.single.photos, hasLength(2));
  });

  test('une copie déjà gardée ne revient pas', () {
    final groups = findDuplicates(
      [photo('a'), photo('copie_a', minutes: 60)],
      resolved: {'copie_a'},
    );
    expect(groups, isEmpty);
  });
}
