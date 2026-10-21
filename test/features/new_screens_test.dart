import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tidypics/data/models/gallery_photo.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_gallery_source.dart';
import '../helpers/fake_reminders.dart';
import '../helpers/test_images.dart';

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menu'));
  await settle(tester);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  // La grille du menu ne défile pas elle-même : on fait défiler la page
  // jusqu'à voir l'élément.
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (var i = 0; i < 10; i++) {
    // Pas encore construit (liste longue) : on descend.
    if (finder.evaluate().isEmpty) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      continue;
    }
    final y = tester.getCenter(finder).dy;
    if (y > 80 && y < screen.height - 80) break;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
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
    // Première fois : l'explication.
    expect(find.text('Choisir les meilleures'), findsWidgets);
    await tester.tap(find.text("C'est parti"));
    await settle(tester);

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

  testWidgets('rafale : la flèche ramène au tri, la carte supprime tout', (
    tester,
  ) async {
    final gallery = FakeGallerySource(
      photos: [photo('a', 0), photo('b', 1), photo('c', 2)],
    );
    await pumpApp(
      tester,
      gallery: gallery,
      settings: const {'onboarding_done': true, 'burst_intro_seen': true},
    );
    await tester.tap(find.text('Choisir les meilleures'));
    await settle(tester);
    await tester.tap(find.byTooltip('Retour au tri'));
    await settle(tester);

    // Glisser la carte de la rafale : toute la rafale au panier.
    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    expect(find.text('3 · 3 Ko'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('tablette en paysage : session et panier à droite', (
    tester,
  ) async {
    await pumpApp(
      tester,
      gallery: FakeGallerySource(photos: samplePhotos(3)),
      // 1280 × 800 points.
      size: const Size(3200, 2000),
    );
    expect(find.text('CETTE SESSION'), findsOneWidget);
    expect(find.text('Les photos glissées à gauche arrivent ici.'), findsOne);

    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    expect(find.text('1 · 1 Ko'), findsOneWidget);
    expect(find.text('Voir le récap'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('vidéo : en tête, sans le son, pause et son au bouton', (
    tester,
  ) async {
    final gallery = FakeGallerySource(
      photos: [
        photo('a', 0),
        GalleryPhoto(
          id: 'v',
          takenAt: t0.add(const Duration(days: 1)),
          title: 'VID_1.mp4',
          sizeBytes: 300 * 1000 * 1000,
          duration: const Duration(seconds: 42),
        ),
      ],
    );
    await pumpApp(tester, gallery: gallery);
    expect(find.text('Vidéo · 0:42'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.tap(find.byTooltip('Activer le son'));
    await settle(tester);
    expect(find.byTooltip('Couper le son'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await settle(tester);
    expect(find.byTooltip('Lecture'), findsOneWidget);

    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    expect(find.text('1 · 300 Mo'), findsOneWidget);

    // Le récap compte photos et vidéos à part.
    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    await tester.tap(find.text('2 · 300 Mo'));
    await settle(tester);
    expect(find.text('Supprimer 1 photo et 1 vidéo (300 Mo)'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('doublons : la copie WhatsApp part, l\'original reste', (
    tester,
  ) async {
    const whatsapp =
        'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/';
    final gallery = FakeGallerySource(
      photos: [
        GalleryPhoto(
          id: 'orig',
          takenAt: t0,
          title: 'PXL_1.jpg',
          folder: 'DCIM/Camera/',
          width: 4000,
          height: 3000,
          sizeBytes: 3000000,
        ),
        GalleryPhoto(
          id: 'copie',
          takenAt: t0.add(const Duration(hours: 2)),
          title: 'IMG-WA0001.jpg',
          folder: whatsapp,
          width: 1600,
          height: 1200,
          sizeBytes: 200000,
        ),
        GalleryPhoto(
          id: 'autre',
          takenAt: t0.add(const Duration(days: 1)),
          folder: 'DCIM/Camera/',
          sizeBytes: 3000000,
        ),
      ],
      images: {
        'orig': jpg(scene(1)),
        'copie': jpg(img.copyResize(scene(1), width: 160), quality: 40),
        'autre': jpg(scene(4)),
      },
    );
    await pumpApp(tester, gallery: gallery);
    await openMenu(tester);
    expect(find.text('1 groupe · 200 Ko'), findsOneWidget);

    await tapVisible(tester, find.text('Doublons'));
    expect(find.text('WhatsApp Images'), findsOneWidget);

    // En grand : la copie, avec le choix garder / supprimer.
    await tester.tap(find.text('WhatsApp Images'));
    await settle(tester);
    expect(find.text('Version 2 sur 2'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await settle(tester);

    await tester.tap(find.text('Supprimer 1 photo (200 Ko)'));
    await settle(tester);
    expect(gallery.trashed, ['copie']);

    await closeApp(tester);
  });

  testWidgets('succès : annoncé quand on le gagne, listé dans le menu', (
    tester,
  ) async {
    await pumpApp(
      tester,
      gallery: FakeGallerySource(
        photos: [photo('a', 0), photo('b', 1), photo('c', 2), photo('d', 600)],
      ),
      settings: const {'onboarding_done': true, 'sort_order': 'oldestFirst'},
    );
    // Trier la rafale d'un geste : première rafale triée.
    await tester.tap(find.byTooltip('Garder'));
    // Plusieurs allers-retours avec la base avant l'annonce.
    await settle(tester);
    await settle(tester);
    expect(find.text('Succès débloqué : Œil de lynx'), findsOneWidget);
    // L'annonce se retire toute seule.
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);

    await openMenu(tester);
    expect(find.text('1 sur 16'), findsOneWidget);
    await tapVisible(tester, find.text('Succès'));
    expect(find.text('Rythme de croisière'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Œil de lynx'), 300);
    expect(find.text('Œil de lynx'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('« ⋯ » sur une carte : partager ou ouvrir dans la galerie', (
    tester,
  ) async {
    final gallery = FakeGallerySource(
      photos: [
        GalleryPhoto(
          id: 'a',
          takenAt: t0,
          title: 'PXL_1.jpg',
          folder: 'DCIM/Camera/',
        ),
      ],
    );
    await pumpApp(tester, gallery: gallery);
    expect(find.text('Camera'), findsOneWidget);

    await tester.tap(find.byTooltip("Plus d'options"));
    await settle(tester);
    expect(find.text('PXL_1.jpg'), findsOneWidget);
    expect(find.text('Partager…'), findsOneWidget);
    await tester.tap(find.text('Ouvrir dans la galerie'));
    await settle(tester);
    expect(gallery.openedInGallery, ['a']);

    await closeApp(tester);
  });

  testWidgets('captures d\'écran : un tri à part, seulement les captures', (
    tester,
  ) async {
    final gallery = FakeGallerySource(
      photos: [
        photo('photo', 0),
        GalleryPhoto(
          id: 'cap1',
          takenAt: t0.add(const Duration(hours: 1)),
          title: 'Screenshot_20250310-130000.png',
          folder: 'Pictures/Screenshots/',
        ),
        GalleryPhoto(
          id: 'cap2',
          takenAt: t0.add(const Duration(hours: 2)),
          title: 'Screenshot_20250310-140000.png',
          folder: 'Pictures/Screenshots/',
        ),
      ],
    );
    await pumpApp(tester, gallery: gallery);
    await openMenu(tester);
    expect(find.text('2 à trier'), findsOneWidget);
    await tapVisible(tester, find.text("Captures d'écran"));

    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    await tester.tap(find.byTooltip('Garder'));
    await settle(tester);
    expect(find.text('Toutes les captures sont triées !'), findsOneWidget);
    // La capture supprimée attend au panier, comme dans le tri normal.
    expect(find.text('1 · 1 Ko'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('rappels : chaque jour à l\'heure choisie, façon jeu', (
    tester,
  ) async {
    final reminders = FakeReminderScheduler();
    await pumpApp(
      tester,
      gallery: FakeGallerySource(photos: [photo('a', 0), photo('b', 900)]),
      reminders: reminders,
    );
    await openMenu(tester);
    await tester.tap(find.byTooltip('Réglages'));
    await settle(tester);
    await tapVisible(tester, find.text('Jour'));
    await tapVisible(tester, find.textContaining('Matin'));

    expect(reminders.scheduled, isNotEmpty);
    expect(reminders.scheduled.first.at.hour, 8);
    expect(reminders.scheduled.first.title, 'Galerie rangée à 0 %');

    // Refusé : les rappels restent coupés et l'app explique pourquoi.
    await tapVisible(tester, find.text('Aucun'));
    expect(reminders.scheduled, isEmpty);
    reminders.permission = false;
    await tapVisible(tester, find.text('Semaine'));
    expect(find.textContaining('Notifications refusées'), findsOneWidget);
    expect(reminders.scheduled, isEmpty);

    await closeApp(tester);
  });

  testWidgets('doublons au swipe : seulement les copies', (tester) async {
    final gallery = FakeGallerySource(
      photos: [
        GalleryPhoto(
          id: 'orig',
          takenAt: t0,
          folder: 'DCIM/Camera/',
          width: 4000,
          height: 3000,
          sizeBytes: 3000000,
        ),
        GalleryPhoto(
          id: 'copie',
          takenAt: t0.add(const Duration(hours: 2)),
          folder: 'Pictures/',
          width: 1600,
          height: 1200,
          sizeBytes: 200000,
        ),
      ],
      images: {
        'orig': jpg(scene(1)),
        'copie': jpg(img.copyResize(scene(1), width: 160), quality: 40),
      },
    );
    await pumpApp(tester, gallery: gallery);
    await openMenu(tester);
    await tapVisible(tester, find.text('Doublons'));
    await tester.tap(find.text('Trier au swipe'));
    await settle(tester);

    expect(find.text("Copie · l'original est gardé"), findsOneWidget);
    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    expect(find.text('Toutes les copies sont triées !'), findsOneWidget);

    await closeApp(tester);
  });
}
