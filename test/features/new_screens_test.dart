import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/models/gallery_photo.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_gallery_source.dart';

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menu'));
  await settle(tester);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  final t0 = DateTime(2025, 3, 10, 12);
  GalleryPhoto photo(
    String id,
    int seconds, {
    String? title,
    int size = 1000,
  }) => GalleryPhoto(
    id: id,
    takenAt: t0.add(Duration(seconds: seconds)),
    title: title ?? '$id.jpg',
    sizeBytes: size,
  );

  testWidgets('par mois : les années, puis le tri d\'un mois', (tester) async {
    final gallery = FakeGallerySource(
      photos: [
        photo('a', 0),
        photo('b', 3600),
        GalleryPhoto(id: 'old', takenAt: DateTime(2023, 7, 1)),
      ],
    );
    await pumpApp(tester, gallery: gallery);
    await openMenu(tester);
    await tapVisible(tester, find.text('Par mois'));

    expect(find.text('Trier par mois'), findsOneWidget);
    expect(find.text('2025'), findsWidgets);
    expect(find.text('2023'), findsOneWidget);
    expect(find.text('Mars'), findsOneWidget);

    await tester.tap(find.text('2023'));
    await settle(tester);
    expect(find.text('Juillet'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('Juillet 2023')));
    await settle(tester);
    expect(find.text('Juillet 2023'), findsOneWidget);
    expect(find.byTooltip('Garder'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('stats : le total, les barres et les chiffres clés', (
    tester,
  ) async {
    await pumpApp(tester, gallery: FakeGallerySource(photos: samplePhotos(2)));
    await openMenu(tester);
    await tester.tap(find.text('ESPACE LIBÉRÉ'));
    await settle(tester);

    expect(find.text('Statistiques'), findsOneWidget);
    expect(find.text('Espace libéré par semaine'), findsOneWidget);
    await tester.tap(find.text('Par mois'));
    await settle(tester);
    expect(find.text('Espace libéré par mois'), findsOneWidget);
    await tapVisible(tester, find.text('Photos supprimées'));
    expect(find.text('Photos triées'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('JPG + RAW : garder les JPG envoie les RAW à la corbeille', (
    tester,
  ) async {
    final gallery = FakeGallerySource(
      photos: [
        photo('j1', 0, title: 'DSC_1.JPG'),
        photo('r1', 0, title: 'DSC_1.DNG', size: 25000000),
        photo('j2', 900, title: 'DSC_2.JPG'),
        photo('r2', 900, title: 'DSC_2.DNG', size: 25000000),
      ],
      // Tailles lues par l'app à l'ouverture de l'écran.
      sizes: {'r1': 25000000, 'r2': 25000000},
    );
    await pumpApp(
      tester,
      gallery: gallery,
      settings: const {'onboarding_done': true, 'raw_intro_seen': true},
    );
    await openMenu(tester);
    await tapVisible(tester, find.text('Trier les RAW'));
    // Le détail des paires s'ouvre depuis le tri des RAW.
    await tester.tap(find.byTooltip('Détail des paires JPG + RAW'));
    await settle(tester);

    expect(find.text('50 Mo à libérer'), findsOneWidget);
    // Une paire passe à « Les deux » : seul l'autre RAW partira.
    await tester.tap(find.bySemanticsLabel(RegExp('DSC_1')));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('DSC_1')));
    await settle(tester);
    expect(find.text('25 Mo à libérer'), findsOneWidget);

    await tester.tap(find.text('Supprimer 1 fichier (25 Mo)'));
    await settle(tester);
    expect(gallery.trashed, ['r2']);

    await closeApp(tester);
  });

  testWidgets('rafale : choisir les meilleures, puis valider', (tester) async {
    final gallery = FakeGallerySource(
      photos: [photo('a', 0), photo('b', 1), photo('c', 2)],
    );
    await pumpApp(tester, gallery: gallery);
    expect(find.text('Rafale · 3 photos'), findsOneWidget);

    await tester.tap(find.text('Choisir les meilleures'));
    await settle(tester);
    expect(
      find.text('Glisse à droite pour garder, à gauche pour mettre au panier.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Garder'));
    await settle(tester);
    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);

    expect(find.text('Rafale triée'), findsOneWidget);
    expect(find.text('1 gardée · 2 au panier'), findsOneWidget);
    await tester.tap(find.text('Valider'));
    await settle(tester);

    // De retour au tri : 3 photos triées, 2 au panier.
    expect(find.text('3 triées'), findsOneWidget);
    expect(find.text('2 · 2 Ko'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('tri des RAW : explication, puis un swipe par RAW', (
    tester,
  ) async {
    final gallery = FakeGallerySource(
      photos: [
        photo('j1', 0, title: 'DSC_1.JPG'),
        photo('r1', 0, title: 'DSC_1.DNG'),
        photo('j2', 900, title: 'DSC_2.JPG'),
        photo('r2', 900, title: 'DSC_2.DNG'),
      ],
    );
    await pumpApp(tester, gallery: gallery);
    await openMenu(tester);
    expect(find.text('2 RAW à trier'), findsOneWidget);
    await tapVisible(tester, find.text('Trier les RAW'));

    // Première fois : l'explication du mode.
    expect(find.text("C'est parti"), findsOneWidget);
    await tester.tap(find.text("C'est parti"));
    await settle(tester);
    expect(find.text('2 restants'), findsOneWidget);

    await tester.tap(find.byTooltip('Supprimer le RAW'));
    await settle(tester);
    await tester.tap(find.byTooltip('Garder le RAW'));
    await settle(tester);

    expect(find.text('Tous les RAW sont triés'), findsOneWidget);
    expect(find.text('1 RAW au panier · 1 Ko'), findsOneWidget);
    // Rien n'est supprimé avant le récap, et les JPG restent à trier.
    expect(gallery.trashed, isEmpty);

    await closeApp(tester);
  });
}
