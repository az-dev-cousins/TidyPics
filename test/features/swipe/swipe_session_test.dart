import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/providers.dart';
import 'package:tidypics/data/repositories/library_repository.dart';
import 'package:tidypics/features/swipe/application/swipe_session.dart';

import '../../helpers/fake_gallery_source.dart';
import '../../helpers/test_container.dart';

void main() {
  late FakeGallerySource gallery;
  late ProviderContainer container;

  Future<void> start({
    int photos = 5,
    Map<String, Object> settings = const {},
  }) async {
    gallery = FakeGallerySource(photos: samplePhotos(photos));
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
    container.listen(swipeSessionProvider, (_, _) {});
    await container.read(swipeSessionProvider.future);
  }

  SwipeSession session() => container.read(swipeSessionProvider.notifier);
  SwipeState state() => container.read(swipeSessionProvider).requireValue;
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
      await container.read(swipeSessionProvider.future);

      expect(state().queue.map((p) => p.id), ['p2', 'p3', 'p4']);
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
    expect(state().queue.map((p) => p.id), ['p1', 'p2', 'p0']);
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
    expect(state().history.map((r) => r.photo.id), ['p0']);
  });

  test('galerie entièrement triée : la session est terminée', () async {
    await start(photos: 1);
    await session().decide(SwipeChoice.keep);
    expect(state().isDone, isTrue);
  });
}
