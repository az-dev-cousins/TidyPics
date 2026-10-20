import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/models/gallery_photo.dart';
import 'package:tidypics/data/repositories/library_repository.dart';
import 'package:tidypics/data/sources/local_db.dart';

import '../helpers/fake_gallery_source.dart';
import '../helpers/test_container.dart';

void main() {
  late LocalDb db;
  late LibraryRepository library;

  setUp(() {
    db = memoryDb();
    library = LibraryRepository(db);
  });
  tearDown(() => db.close());

  test(
    'le scan ajoute les photos et oublie celles supprimées ailleurs',
    () async {
      final photos = samplePhotos(3);
      await library.sync(photos);
      expect((await library.watchSummary().first).total, 3);

      await library.addToCart(photos[2]);
      await library.sync(photos.take(2).toList());

      final summary = await library.watchSummary().first;
      expect(summary.total, 2);
      // Supprimée depuis l'app Photos : retirée du panier sans bruit.
      expect(summary.cartCount, 0);
    },
  );

  test('un nouveau scan garde la taille déjà lue', () async {
    final photos = samplePhotos(1);
    await library.sync(photos);
    await library.setSize('p0', 4200);
    await library.sync(photos);

    final unsorted = await library.unsortedPhotos(SortOrder.oldestFirst);
    expect(unsorted.single.sizeBytes, 4200);
  });

  test('les photos à trier excluent les décisions et le panier', () async {
    final photos = samplePhotos(4);
    await library.sync(photos);
    await library.decide(photos[0], Decision.kept);
    await library.decide(photos[1], Decision.favorite);
    await library.addToCart(photos[2]);

    final unsorted = await library.unsortedPhotos(SortOrder.random);
    expect(unsorted.map((p) => p.id), ['p3']);

    final summary = await library.watchSummary().first;
    expect(summary.sorted, 2);
    expect(summary.cartCount, 1);
    expect(summary.unsorted, 1);
    expect(summary.progress, 0.75);
  });

  test("l'ordre ancien → récent et récent → ancien", () async {
    await library.sync(samplePhotos(3).reversed.toList());

    final oldest = await library.unsortedPhotos(SortOrder.oldestFirst);
    expect(oldest.map((p) => p.id), ['p0', 'p1', 'p2']);
    final newest = await library.unsortedPhotos(SortOrder.newestFirst);
    expect(newest.map((p) => p.id), ['p2', 'p1', 'p0']);
  });

  test('annuler une décision rend la photo à trier', () async {
    final photo = samplePhotos(1).single;
    await library.sync([photo]);
    await library.decide(photo, Decision.favorite);
    await library.undecide(photo);

    final unsorted = await library.unsortedPhotos(SortOrder.random);
    expect(unsorted.single.isFavorite, isFalse);
  });

  test('une photo décochée au récap revient dans le tri', () async {
    final photo = samplePhotos(1).single;
    await library.sync([photo]);
    await library.addToCart(photo.copyWith(sizeBytes: 500));
    expect((await library.watchSummary().first).cartBytes, 500);

    await library.releaseFromCart([photo.id]);

    final summary = await library.watchSummary().first;
    expect(summary.cartCount, 0);
    // Ni supprimée ni gardée : elle sera reproposée plus tard.
    expect(summary.sorted, 0);
    expect(await library.unsortedPhotos(SortOrder.random), hasLength(1));
  });

  test('remettre à zéro les photos gardées les repropose', () async {
    final photos = samplePhotos(2);
    await library.sync(photos);
    await library.decide(photos[0], Decision.kept);
    await library.decide(photos[1], Decision.favorite);

    await library.resetKept();

    expect(await library.unsortedPhotos(SortOrder.random), hasLength(2));
  });

  test('détecte les fichiers RAW par leur extension', () {
    GalleryPhoto named(String? title) =>
        GalleryPhoto(id: 'x', takenAt: DateTime(2020), title: title);
    expect(named('IMG_1.DNG').isRaw, isTrue);
    expect(named('dsc.nef').isRaw, isTrue);
    expect(named('IMG_1.JPG').isRaw, isFalse);
    expect(named(null).isRaw, isFalse);
  });

  group('par mois', () {
    List<GalleryPhoto> spread() => [
      GalleryPhoto(id: 'a', takenAt: DateTime(2025, 3, 2)),
      GalleryPhoto(id: 'b', takenAt: DateTime(2025, 3, 30, 23)),
      GalleryPhoto(id: 'c', takenAt: DateTime(2025, 4, 1)),
      GalleryPhoto(id: 'd', takenAt: DateTime(2024, 12, 25)),
    ];

    test('chaque mois avec son nombre de photos et sa part triée', () async {
      final photos = spread();
      await library.sync(photos);
      await library.decide(photos[0], Decision.kept);
      await library.addToCart(photos[1]);

      final months = await library.watchMonths().first;
      expect(months.map((m) => '${m.year}-${m.month}:${m.sorted}/${m.total}'), [
        '2025-4:0/1',
        '2025-3:2/2',
        '2024-12:0/1',
      ]);
      expect(months[1].isDone, isTrue);
    });

    test(
      'un mois propose toutes ses photos, même gardées, sauf le panier',
      () async {
        final photos = spread();
        await library.sync(photos);
        await library.decide(photos[0], Decision.kept);

        expect((await library.monthPhotos(2025, 3)).map((p) => p.id), [
          'a',
          'b',
        ]);
        await library.addToCart(photos[1]);
        expect((await library.monthPhotos(2025, 3)).map((p) => p.id), ['a']);
      },
    );
  });

  test('RAW à trier : avec leur JPG, et les orphelins signalés', () async {
    final at = DateTime(2025, 5, 1, 10);
    final jpg1 = GalleryPhoto(id: 'j1', takenAt: at, title: 'DSC_1.JPG');
    final raw1 = GalleryPhoto(id: 'r1', takenAt: at, title: 'DSC_1.DNG');
    final jpg2 = GalleryPhoto(
      id: 'j2',
      takenAt: at.add(const Duration(hours: 1)),
      title: 'DSC_2.JPG',
    );
    final raw2 = GalleryPhoto(
      id: 'r2',
      takenAt: at.add(const Duration(hours: 1)),
      title: 'DSC_2.DNG',
    );
    final solo = GalleryPhoto(
      id: 'r3',
      takenAt: at.add(const Duration(hours: 2)),
      title: 'IMG_3.ARW',
    );
    await library.sync([jpg1, raw1, jpg2, raw2, solo]);
    await library.addToCart(jpg2);

    final files = await library.rawFilesToSort();
    expect(files.map((f) => f.raw.id), ['r1', 'r2', 'r3']);
    expect(files[0].isOrphan, isFalse);
    expect(files[1].jpgInCart, isTrue);
    expect(files[2].jpg, isNull);

    // Un RAW trié ne revient plus.
    await library.decide(raw1, Decision.kept);
    expect((await library.rawFilesToSort()).map((f) => f.raw.id), ['r2', 'r3']);
  });
}
