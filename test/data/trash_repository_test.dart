import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/models/gallery_photo.dart';
import 'package:tidypics/data/repositories/library_repository.dart';
import 'package:tidypics/data/repositories/trash_repository.dart';
import 'package:tidypics/data/sources/local_db.dart';

import '../helpers/fake_gallery_source.dart';
import '../helpers/test_container.dart';

void main() {
  late LocalDb db;
  late FakeGallerySource gallery;
  late LibraryRepository library;
  late TrashRepository trash;
  late List<GalleryPhoto> photos;

  setUp(() async {
    db = memoryDb();
    photos = [for (final p in samplePhotos(3)) p.copyWith(sizeBytes: 1000)];
    gallery = FakeGallerySource(photos: photos);
    library = LibraryRepository(db);
    trash = TrashRepository(db, gallery);
    await library.sync(photos);
    for (final p in photos) {
      await library.addToCart(p);
    }
  });
  tearDown(() => db.close());

  test('envoie le panier en un seul lot et compte l\'espace libéré', () async {
    final at = DateTime(2026, 10, 1);
    final outcome = await trash.trash(photos, at: at);

    expect(outcome.count, 3);
    expect(outcome.bytes, 3000);
    expect(gallery.trashCalls, 1);

    final summary = await library.watchSummary().first;
    expect(summary.cartCount, 0);
    expect(summary.total, 0);

    final freed = await trash.watchFreed().first;
    expect(freed.bytes, 3000);
    expect(freed.photos, 3);

    final log = await trash.watchLog().first;
    expect(log, hasLength(3));
    expect(log.first.thumbnail, isNotNull);
    expect(log.first.daysLeft(at), 30);
    expect(log.first.daysLeft(at.add(const Duration(days: 29))), 1);
  });

  test('popup refusée : rien ne change, le panier reste', () async {
    gallery.refuseTrash = true;
    final outcome = await trash.trash(photos);

    expect(outcome.count, 0);
    expect((await library.watchSummary().first).cartCount, 3);
    expect(await trash.watchLog().first, isEmpty);
    expect((await trash.watchFreed().first).bytes, 0);
  });

  test('une photo restaurée est décomptée et gardée', () async {
    await trash.trash(photos);
    final log = await trash.watchLog().first;

    final restored = await trash.restore([log.first]);

    expect(restored, 1);
    expect((await trash.watchFreed().first).bytes, 2000);
    expect(await trash.watchLog().first, hasLength(2));
    // De retour dans la galerie, elle n'est pas reproposée.
    await library.sync(gallery.photos);
    expect(await library.unsortedPhotos(SortOrder.random), isEmpty);
  });

  test('oublie les entrées de plus de 30 jours', () async {
    await trash.trash(photos, at: DateTime(2026, 1, 1));
    await trash.purgeExpired(now: DateTime(2026, 2, 15));
    expect(await trash.watchLog().first, isEmpty);
    // Les stats, elles, restent.
    expect((await trash.watchFreed().first).bytes, 3000);
  });

  test(
    '« Vider maintenant » efface pour de bon, sans toucher aux stats',
    () async {
      await trash.trash(photos);
      final log = await trash.watchLog().first;

      expect(await trash.emptyNow(log), 3);
      expect(gallery.systemTrash, isEmpty);
      expect(await trash.watchLog().first, isEmpty);
      expect((await trash.watchFreed().first).bytes, 3000);
    },
  );

  test('vidage refusé : le journal reste', () async {
    await trash.trash(photos);
    gallery.refuseDeleteForever = true;
    expect(await trash.emptyNow(await trash.watchLog().first), 0);
    expect(await trash.watchLog().first, hasLength(3));
  });

  test(
    'le journal suit la corbeille : restaurée ou effacée ailleurs',
    () async {
      await trash.trash(photos);
      // p0 restaurée depuis l'app Galerie, p1 effacée pour de bon.
      gallery.systemTrash.removeAll(['p0', 'p1']);

      await trash.syncWithSystemTrash({'p0', 'p2-other'});

      final log = await trash.watchLog().first;
      expect(log.map((e) => e.photo.id), ['p2']);
      // Seule la restaurée est décomptée.
      expect((await trash.watchFreed().first).bytes, 2000);
    },
  );

  test('historique par semaine, semaines vides comprises', () async {
    final monday = DateTime(2026, 10, 12);
    await trash.trash([photos[0]], at: monday.add(const Duration(hours: 9)));
    await trash.trash([
      photos[1],
      photos[2],
    ], at: monday.subtract(const Duration(days: 6)));

    final weeks = await trash
        .watchHistory(StatsPeriod.week, count: 3, now: DateTime(2026, 10, 15))
        .first;
    expect(weeks.map((w) => w.start), [
      DateTime(2026, 9, 28),
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 12),
    ]);
    expect(weeks.map((w) => w.bytes), [0, 2000, 1000]);
  });

  test('historique par mois', () async {
    await trash.trash(photos, at: DateTime(2026, 9, 20));
    final months = await trash
        .watchHistory(StatsPeriod.month, count: 2, now: DateTime(2026, 10, 3))
        .first;
    expect(months.map((m) => m.start), [DateTime(2026, 9), DateTime(2026, 10)]);
    expect(months.map((m) => m.photos), [3, 0]);
  });

  test(
    'effacement direct : pas de journal, mais compté dans les stats',
    () async {
      final outcome = await trash.trash(photos, permanent: true);
      expect(outcome.count, 3);
      expect(gallery.trashed, isEmpty);
      expect(await trash.watchLog().first, isEmpty);
      expect((await trash.watchFreed().first).bytes, 3000);
      expect((await library.watchSummary().first).cartCount, 0);
    },
  );

  test('une miniature illisible ne bloque pas la suppression', () async {
    gallery.unreadableThumbnails.add('p1');
    final outcome = await trash.trash(photos);
    expect(outcome.count, 3);
    final log = await trash.watchLog().first;
    expect(log.firstWhere((e) => e.photo.id == 'p1').thumbnail, isNull);
  });
}
