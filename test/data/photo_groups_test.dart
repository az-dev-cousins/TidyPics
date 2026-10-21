import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/models/gallery_photo.dart';
import 'package:tidypics/data/models/photo_groups.dart';

GalleryPhoto photo(String id, String title, DateTime at) =>
    GalleryPhoto(id: id, takenAt: at, title: title);

void main() {
  final t0 = DateTime(2025, 10, 12, 18);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  group('paires JPG + RAW', () {
    test('même nom et même date', () {
      final pairs = findRawPairs([
        photo('1', 'DSC_0187.JPG', at(0)),
        photo('2', 'DSC_0187.DNG', at(1)),
        photo('3', 'DSC_0188.JPG', at(60)),
      ]);
      expect(pairs, hasLength(1));
      expect(pairs.single.kind, PhotoItemKind.rawPair);
      expect(pairs.single.photos.map((p) => p.id), ['1', '2']);
    });

    test('même nom mais prises à des moments différents : pas une paire', () {
      final pairs = findRawPairs([
        photo('1', 'IMG_0001.jpg', at(0)),
        photo('2', 'IMG_0001.cr2', at(3600)),
      ]);
      expect(pairs, isEmpty);
    });

    test('noms des Pixel : suffixes RAW-01.COVER et RAW-02.ORIGINAL', () {
      final items = groupPhotos([
        photo('j', 'PXL_20251012_101010123.RAW-01.COVER.jpg', at(0)),
        photo('r', 'PXL_20251012_101010123.RAW-02.ORIGINAL.dng', at(0)),
      ]);
      // Une paire, pas une rafale.
      expect(items.single.kind, PhotoItemKind.rawPair);
      expect(items.single.photos.map((p) => p.id), ['j', 'r']);
    });

    test('HEIC + RAW, casse ignorée', () {
      final pairs = findRawPairs([
        photo('1', 'img_42.heic', at(0)),
        photo('2', 'IMG_42.ARW', at(0)),
      ]);
      expect(pairs, hasLength(1));
    });
  });

  group('rafales', () {
    test('photos à moins de 3 s : une rafale', () {
      final items = groupPhotos([
        photo('a', 'A.jpg', at(0)),
        photo('b', 'B.jpg', at(1)),
        photo('c', 'C.jpg', at(3)),
        photo('d', 'D.jpg', at(60)),
      ]);
      expect(items.map((i) => i.kind), [
        PhotoItemKind.burst,
        PhotoItemKind.single,
      ]);
      expect(items.first.photos.map((p) => p.id), ['a', 'b', 'c']);
    });

    test('une vidéo reste seule, sans couper la rafale', () {
      final items = groupPhotos([
        photo('a', 'A.jpg', at(0)),
        GalleryPhoto(
          id: 'v',
          takenAt: at(1),
          title: 'V.mp4',
          duration: const Duration(seconds: 4),
        ),
        photo('b', 'B.jpg', at(2)),
      ]);
      expect(items, hasLength(2));
      expect(
        items.firstWhere((i) => i.cover.isVideo).kind,
        PhotoItemKind.single,
      );
      expect(
        items
            .firstWhere((i) => i.kind == PhotoItemKind.burst)
            .photos
            .map((p) => p.id),
        ['a', 'b'],
      );
    });

    test('photos WhatsApp reçues à la même heure : pas une rafale', () {
      GalleryPhoto wa(String id, int s) => GalleryPhoto(
        id: id,
        takenAt: at(s),
        title: 'IMG-WA$id.jpg',
        folder: 'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/',
      );
      final items = groupPhotos([wa('1', 0), wa('2', 0), wa('3', 1)]);
      expect(items.map((i) => i.kind), everyElement(PhotoItemKind.single));
    });

    test('captures d\'écran prises à la suite : pas une rafale', () {
      final items = groupPhotos([
        photo('a', 'Screenshot_1.png', at(0)),
        photo('b', 'Screenshot_2.png', at(1)),
      ]);
      expect(items.map((i) => i.kind), everyElement(PhotoItemKind.single));
    });

    test('même heure mais dossiers différents : pas une rafale', () {
      final items = groupPhotos([
        GalleryPhoto(id: 'a', takenAt: at(0), folder: 'DCIM/Camera/'),
        GalleryPhoto(id: 'b', takenAt: at(1), folder: 'Pictures/Edits/'),
      ]);
      expect(items.map((i) => i.kind), everyElement(PhotoItemKind.single));
    });

    test('empreintes très différentes : pas une rafale', () {
      // 0x0F0F… et 0xF0F0… : 64 bits d'écart, chacune assez « riche ».
      final items = groupPhotos([
        GalleryPhoto(id: 'a', takenAt: at(0), visualHash: 0x0F0F0F0F0F0F0F0F),
        GalleryPhoto(id: 'b', takenAt: at(1), visualHash: 0x70F0F0F0F0F0F0F0),
        GalleryPhoto(id: 'c', takenAt: at(2), visualHash: 0x70F0F0F0F0F0F0F1),
      ]);
      expect(items.map((i) => i.kind), [
        PhotoItemKind.single,
        PhotoItemKind.burst,
      ]);
    });

    test('photos semblables à 20 s d\'écart : une rafale (test)', () {
      GalleryPhoto shot(String id, int s, int hash, int color) => GalleryPhoto(
        id: id,
        takenAt: at(s),
        folder: 'DCIM/Camera/',
        visualHash: hash,
        visualColor: color,
      );
      const view = 0x0F0F0F0F0F0F0F0F;
      const other = 0x70F0F0F0F0F0F0F0;
      final photos = [
        shot('a', 0, view, 0x123456789ABC),
        shot('b', 20, view ^ 0x3, 0x123456789ABC),
        shot('c', 45, view ^ 0x5, 0x123456789ABC),
        // Autre sujet, 20 s plus tard : pas dans la rafale.
        shot('d', 65, other, 0x123456789ABC),
      ];
      final items = groupPhotos(photos, similarGap: const Duration(minutes: 2));
      expect(items.first.photos.map((p) => p.id), ['a', 'b', 'c']);
      expect(items.last.photos.single.id, 'd');
      // Réglage coupé : chacune seule.
      expect(groupPhotos(photos), hasLength(4));
    });

    test("l'écart est réglable", () {
      final photos = [photo('a', 'A.jpg', at(0)), photo('b', 'B.jpg', at(5))];
      expect(groupPhotos(photos), hasLength(2));
      expect(groupPhotos(photos, burstGap: const Duration(seconds: 10)), [
        isA<PhotoItem>().having((i) => i.kind, 'kind', PhotoItemKind.burst),
      ]);
    });

    test('regroupement désactivé : que des photos seules', () {
      final items = groupPhotos([
        photo('a', 'A.jpg', at(0)),
        photo('b', 'B.jpg', at(1)),
      ], bursts: false);
      expect(items.map((i) => i.kind), everyElement(PhotoItemKind.single));
    });

    test('au-delà de $maxBurstSize photos, ce n\'est plus une rafale', () {
      final copied = [
        for (var i = 0; i <= maxBurstSize; i++) photo('c$i', 'C$i.jpg', at(0)),
      ];
      expect(groupPhotos(copied), hasLength(maxBurstSize + 1));
      expect(
        groupPhotos(copied.take(maxBurstSize).toList()).single.kind,
        PhotoItemKind.burst,
      );
    });

    test('une paire JPG + RAW ne forme pas une rafale', () {
      final items = groupPhotos([
        photo('j', 'DSC_1.JPG', at(0)),
        photo('r', 'DSC_1.DNG', at(0)),
        photo('x', 'IMG_9.jpg', at(1)),
      ]);
      expect(items.map((i) => i.kind), [
        PhotoItemKind.rawPair,
        PhotoItemKind.single,
      ]);
    });

    test('le résultat est trié par date et chaque photo apparaît une fois', () {
      final photos = [
        photo('3', 'C.jpg', at(100)),
        photo('1', 'A.jpg', at(0)),
        photo('2', 'B.jpg', at(1)),
      ];
      final items = groupPhotos(photos);
      expect(items.first.takenAt, at(0));
      expect(items.expand((i) => i.photos).map((p) => p.id).toSet(), {
        '1',
        '2',
        '3',
      });
    });
  });

  test('taille et identifiant d\'un groupe', () {
    final item = PhotoItem.burst([
      GalleryPhoto(id: 'a', takenAt: at(0), sizeBytes: 100),
      GalleryPhoto(id: 'b', takenAt: at(1), sizeBytes: 250),
    ]);
    expect(item.sizeBytes, 350);
    expect(item.id, 'a+b');
  });
}
