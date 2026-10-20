import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/models/gallery_photo.dart';
import 'package:tidypics/data/models/photo_groups.dart';
import 'package:tidypics/data/providers.dart';
import 'package:tidypics/data/repositories/library_repository.dart';
import 'package:tidypics/data/sources/local_db.dart';
import 'package:tidypics/features/swipe/application/swipe_session.dart';

import '../../helpers/fake_gallery_source.dart';
import '../../helpers/test_container.dart';

void main() {
  late FakeGallerySource gallery;
  late ProviderContainer container;
  var provider = swipeSessionProvider(const SwipeScope.all());

  Future<void> start({
    int photos = 5,
    Map<String, Object> settings = const {},
    List<GalleryPhoto>? custom,
    SwipeScope scope = const SwipeScope.all(),
  }) async {
    provider = swipeSessionProvider(scope);
    gallery = FakeGallerySource(photos: custom ?? samplePhotos(photos));
    container = await testContainer(
      db: memoryDb(),
      gallery: gallery,
      settings: {
        'onboarding_done': true,
        'sort_order': 'oldestFirst',
        ...settings,
      },
    );
    await container.read(libraryRepositoryProvider).sync(gallery.photos);
    // Garde la session en vie pendant le test (autoDispose).
    container.listen(provider, (_, _) {});
    await container.read(provider.future);
  }

  SwipeSession session() => container.read(provider.notifier);
  SwipeState state() => container.read(provider).requireValue;
  LibraryRepository library() => container.read(libraryRepositoryProvider);

  test('garder, favori et panier avancent dans la file', () async {
    await start();
    expect(state().current?.id, 'p0');

    await session().decide(SwipeChoice.keep);
    await session().decide(SwipeChoice.favorite);
    await session().decide(SwipeChoice.trash);

    expect(state().current?.id, 'p3');
    expect(state().sortedCount, 3);
    expect(state().cartCount, 1);
    expect(gallery.favorites, {'p1': true});

    final summary = await library().watchSummary().first;
    expect(summary.sorted, 2);
    expect(summary.cartCount, 1);
    // La taille est lue avant d'entrer dans le panier.
    expect(summary.cartBytes, 1000);
  });

  test(
    'chaque décision est enregistrée : une nouvelle session reprend',
    () async {
      await start();
      await session().decide(SwipeChoice.keep);
      await session().decide(SwipeChoice.trash);

      container.invalidate(swipeSessionProvider);
      await container.read(provider.future);

      expect(state().queue.map((i) => i.id), ['p2', 'p3', 'p4']);
      expect(state().cartCount, 1);
    },
  );

  test('annuler remet la photo en tête et défait la décision', () async {
    await start();
    await session().decide(SwipeChoice.favorite);
    await session().decide(SwipeChoice.trash);

    await session().undo();
    expect(state().current?.id, 'p1');
    expect(state().cartCount, 0);
    expect((await library().watchSummary().first).cartCount, 0);

    await session().undo();
    expect(state().current?.id, 'p0');
    expect(state().sortedCount, 0);
    // Le favori système est retiré.
    expect(gallery.favorites, {'p0': false});
    expect(state().canUndo, isFalse);
  });

  test('on peut annuler les 10 dernières décisions, pas plus', () async {
    await start(photos: 12);
    for (var i = 0; i < 12; i++) {
      await session().decide(SwipeChoice.keep);
    }
    for (var i = 0; i < 12; i++) {
      await session().undo();
    }
    expect(state().current?.id, 'p2');
    expect(state().sortedCount, 2);
  });

  test('passer envoie la photo en fin de file, sans décision', () async {
    await start(photos: 3);
    session().skip();
    expect(state().queue.map((i) => i.id), ['p1', 'p2', 'p0']);
    expect(state().sortedCount, 0);
    expect(state().canUndo, isFalse);
  });

  test('le récap est proposé toutes les N photos triées', () async {
    await start(photos: 12, settings: {'checkpoint_threshold': 3});
    await session().decide(SwipeChoice.trash);
    await session().decide(SwipeChoice.keep);
    expect(state().checkpointDue, isFalse);
    await session().decide(SwipeChoice.keep);
    expect(state().checkpointDue, isTrue);
    expect(state().checkpointProgress, 1);

    session().postponeCheckpoint();
    expect(state().checkpointDue, isFalse);
    expect(state().nextCheckpointAt, 6);
  });

  test('pas de récap si le panier est vide au seuil', () async {
    await start(photos: 8, settings: {'checkpoint_threshold': 3});
    for (var i = 0; i < 3; i++) {
      await session().decide(SwipeChoice.keep);
    }
    expect(state().checkpointDue, isFalse);
    expect(state().nextCheckpointAt, 6);

    await session().decide(SwipeChoice.keep);
    await session().decide(SwipeChoice.keep);
    await session().decide(SwipeChoice.trash);
    expect(state().checkpointDue, isTrue);
  });

  test('après la suppression, le récap repart de zéro', () async {
    await start(photos: 6, settings: {'checkpoint_threshold': 2});
    await session().decide(SwipeChoice.trash);
    await session().decide(SwipeChoice.trash);
    expect(state().checkpointDue, isTrue);

    final cart = await library().cart();
    await container
        .read(trashRepositoryProvider)
        .trash(cart.map((e) => e.photo).toList());
    await session().refreshCart();

    expect(state().cartCount, 0);
    expect(state().checkpointDue, isFalse);
    expect(state().nextCheckpointAt, 4);
    // Les photos parties à la corbeille ne peuvent plus être annulées.
    expect(state().canUndo, isFalse);
  });

  test('une photo rendue au tri au récap ne peut plus être annulée', () async {
    await start(photos: 4);
    await session().decide(SwipeChoice.keep);
    await session().decide(SwipeChoice.trash);

    await library().releaseFromCart(['p1']);
    await session().refreshCart();

    expect(state().cartCount, 0);
    expect(state().history.map((r) => r.item.id), ['p0']);
  });

  test('galerie entièrement triée : la session est terminée', () async {
    await start(photos: 1);
    await session().decide(SwipeChoice.keep);
    expect(state().isDone, isTrue);
  });

  group('groupes', () {
    final t0 = DateTime(2025, 6, 1, 12);
    GalleryPhoto at(String id, int seconds, {String? title}) => GalleryPhoto(
      id: id,
      takenAt: t0.add(Duration(seconds: seconds)),
      title: title ?? '$id.jpg',
    );

    test('une rafale arrive comme un seul élément', () async {
      await start(
        custom: [at('a', 0), at('b', 1), at('c', 2), at('d', 600)],
        settings: {'sort_order': 'oldestFirst'},
      );
      expect(state().current?.kind, PhotoItemKind.burst);
      expect(state().queue, hasLength(2));

      await session().decide(SwipeChoice.trash);
      expect(state().cartCount, 3);
      expect(state().sortedCount, 3);

      await session().undo();
      expect(state().cartCount, 0);
      expect((await library().watchSummary().first).cartCount, 0);
    });

    test('rafale triée photo par photo : gardées et panier', () async {
      await start(custom: [at('a', 0), at('b', 1), at('c', 2)]);
      await session().resolveGroup({'b'});

      final summary = await library().watchSummary().first;
      expect(summary.sorted, 1);
      expect(summary.cartCount, 2);
      expect(state().history.single.trashed.map((p) => p.id), ['a', 'c']);
    });

    test('regroupement désactivé : photo par photo', () async {
      await start(
        custom: [at('a', 0), at('b', 1)],
        settings: {'group_bursts': false},
      );
      expect(state().queue, hasLength(2));
    });

    test('paire JPG + RAW : les deux fichiers deviennent favoris', () async {
      await start(
        custom: [
          at('j', 0, title: 'DSC_1.JPG'),
          at('r', 0, title: 'DSC_1.DNG'),
        ],
      );
      expect(state().current?.kind, PhotoItemKind.rawPair);
      await session().decide(SwipeChoice.favorite);
      expect(gallery.favorites, {'j': true, 'r': true});
    });
  });

  test('un mois propose toutes ses photos, même gardées', () async {
    final photos = [
      GalleryPhoto(id: 'a', takenAt: DateTime(2025, 3, 2)),
      GalleryPhoto(id: 'b', takenAt: DateTime(2025, 3, 20)),
      GalleryPhoto(id: 'c', takenAt: DateTime(2025, 4, 1)),
    ];
    await start(custom: photos, scope: const SwipeScope.month(2025, 3));
    expect(state().queue.map((i) => i.id), ['a', 'b']);

    // Déjà gardée puis mise au panier : elle ne compte qu'une fois.
    await library().decide(photos[0], Decision.kept);
    await session().decide(SwipeChoice.trash);
    final summary = await library().watchSummary().first;
    expect(summary.sorted, 0);
    expect(summary.cartCount, 1);
  });
}
