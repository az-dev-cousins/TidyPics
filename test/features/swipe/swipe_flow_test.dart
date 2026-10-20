import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_gallery_source.dart';

void main() {
  testWidgets('trier, s\'arrêter, supprimer : le parcours complet', (
    tester,
  ) async {
    final gallery = FakeGallerySource(photos: samplePhotos(4));
    await pumpApp(tester, gallery: gallery);

    await tester.tap(find.text('Trier'));
    await settle(tester);

    await tester.tap(find.byTooltip('Garder'));
    await settle(tester);
    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    expect(find.text('3 triées · 2 Ko au panier'), findsOneWidget);

    await tester.tap(find.text("Je m'arrête là"));
    await settle(tester);
    expect(find.text('Avant de supprimer'), findsOneWidget);
    expect(find.text('2 photos · 2 Ko à libérer'), findsOneWidget);

    await tester.tap(find.text('Supprimer 2 photos (2 Ko)'));
    await settle(tester);

    expect(gallery.trashed, hasLength(2));
    expect(find.text('2 photos à la corbeille · 2 Ko libérés'), findsOneWidget);
    // Retour à l'accueil, avec le gros chiffre.
    expect(find.text('2 Ko libérés'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('popup refusée : le panier est conservé', (tester) async {
    final gallery = FakeGallerySource(photos: samplePhotos(2))
      ..refuseTrash = true;
    await pumpApp(tester, gallery: gallery);

    await tester.tap(find.text('Trier'));
    await settle(tester);
    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    await tester.tap(find.text("Je m'arrête là"));
    await settle(tester);
    await tester.tap(find.text('Supprimer 1 photo (1 Ko)'));
    await settle(tester);

    expect(
      find.text("Rien n'a été supprimé. Les photos restent dans le panier."),
      findsOneWidget,
    );
    expect(find.text('Avant de supprimer'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('Android 12+ : « Gestion des médias » proposée une fois', (
    tester,
  ) async {
    final gallery = FakeGallerySource(photos: samplePhotos(2))
      ..manageMediaSupported = true;
    await pumpApp(tester, gallery: gallery);

    await tester.tap(find.text('Trier'));
    await settle(tester);
    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    await tester.tap(find.text("Je m'arrête là"));
    await settle(tester);
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
