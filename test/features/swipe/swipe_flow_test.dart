import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_gallery_source.dart';

void main() {
  /// Met les [count] premières photos au panier, puis « Je m'arrête là ».
  Future<void> trashAndStop(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tester.tap(find.byTooltip('Supprimer'));
      await settle(tester);
    }
    await tester.tap(find.text("Je m'arrête là"));
    await settle(tester);
  }

  testWidgets("l'app s'ouvre directement sur le tri", (tester) async {
    await pumpApp(tester, gallery: FakeGallerySource(photos: samplePhotos(3)));

    expect(find.text('0 triée'), findsOneWidget);
    expect(find.byTooltip('Garder'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets("trier, s'arrêter, supprimer : le parcours complet", (
    tester,
  ) async {
    final gallery = FakeGallerySource(photos: samplePhotos(4));
    await pumpApp(tester, gallery: gallery);

    await tester.tap(find.byTooltip('Garder'));
    await settle(tester);
    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    expect(find.text('3 triées'), findsOneWidget);
    expect(find.text('2 · 2 Ko'), findsOneWidget);

    await tester.tap(find.text("Je m'arrête là"));
    await settle(tester);
    expect(find.text('Récap avant de supprimer'), findsOneWidget);
    expect(find.text('2 photos · 2 Ko à libérer'), findsOneWidget);

    await tester.tap(find.text('Supprimer 2 photos (2 Ko)'));
    await settle(tester);

    expect(gallery.trashed, hasLength(2));
    expect(find.text('2 photos à la corbeille · 2 Ko libérés'), findsOneWidget);
    // Session terminée : le menu s'ouvre, avec le gros chiffre.
    expect(find.text('ESPACE LIBÉRÉ'), findsOneWidget);
    expect(find.text('2 Ko'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('une photo décochée reste visible et revient au tri', (
    tester,
  ) async {
    final gallery = FakeGallerySource(photos: samplePhotos(4));
    await pumpApp(tester, gallery: gallery);
    await trashAndStop(tester, 2);

    final tiles = find.bySemanticsLabel(RegExp('sera supprimée'));
    expect(tiles, findsNWidgets(2));
    await tester.tap(tiles.first);
    await settle(tester);
    expect(find.text('1 photo · 1 Ko à libérer'), findsOneWidget);
    expect(find.text('Plus tard'), findsWidgets);

    // On change d'avis : elle redevient cochée.
    await tester.tap(find.bySemanticsLabel(RegExp('ne sera pas supprimée')));
    await settle(tester);
    expect(find.text('2 photos · 2 Ko à libérer'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('sera supprimée')).first);
    await settle(tester);
    await tester.tap(find.text('Supprimer 1 photo (1 Ko)'));
    await settle(tester);

    expect(gallery.trashed, hasLength(1));
    // L'autre n'est ni supprimée ni gardée : elle reviendra dans le tri.
    expect(find.text('0 % triées'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('le récap s\'ouvre tout seul au seuil de photos triées', (
    tester,
  ) async {
    await pumpApp(
      tester,
      gallery: FakeGallerySource(photos: samplePhotos(6)),
      settings: const {'onboarding_done': true, 'checkpoint_threshold': 2},
    );

    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    expect(find.text('Récap dans 1 photo'), findsNothing);
    expect(find.text('Récap à la prochaine photo'), findsOneWidget);
    await tester.tap(find.byTooltip('Garder'));
    await settle(tester);

    expect(find.text('Récap avant de supprimer'), findsOneWidget);
    await tester.tap(find.text('Continuer le tri'));
    await settle(tester);
    expect(find.text('2 triées'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('popup refusée : le panier est conservé', (tester) async {
    final gallery = FakeGallerySource(photos: samplePhotos(2))
      ..refuseTrash = true;
    await pumpApp(tester, gallery: gallery);
    await trashAndStop(tester, 1);

    await tester.tap(find.text('Supprimer 1 photo (1 Ko)'));
    await settle(tester);

    expect(
      find.text("Rien n'a été supprimé. Les photos restent dans le panier."),
      findsOneWidget,
    );
    expect(find.text('Récap avant de supprimer'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('Android 12+ : « Gestion des médias » proposée une fois', (
    tester,
  ) async {
    final gallery = FakeGallerySource(photos: samplePhotos(2))
      ..manageMediaSupported = true;
    await pumpApp(tester, gallery: gallery);
    await trashAndStop(tester, 1);

    await tester.tap(find.text('Supprimer 1 photo (1 Ko)'));
    await settle(tester);

    expect(find.text('Supprimer sans confirmation'), findsOneWidget);
    await tester.tap(find.text('Pas maintenant'));
    await settle(tester);
    expect(gallery.trashed, hasLength(1));
    expect(gallery.manageMediaRequests, 0);

    await closeApp(tester);
  });
}
