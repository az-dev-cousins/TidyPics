import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/sources/gallery_source.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_gallery_source.dart';

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menu'));
  await settle(tester);
}

void main() {
  testWidgets('le menu montre la galerie indexée', (tester) async {
    await pumpApp(tester, gallery: FakeGallerySource(photos: samplePhotos(3)));
    await openMenu(tester);

    expect(find.bySemanticsLabel('TidyPics'), findsOneWidget);
    expect(find.text('ESPACE LIBÉRÉ'), findsOneWidget);
    expect(find.text('0 % triées'), findsOneWidget);
    // Barre de stockage : photos, autre, libre.
    expect(find.text('Stockage du téléphone'), findsOneWidget);
    expect(find.text('Photos · 30 Go'), findsOneWidget);
    expect(find.text('Libre · 40 Go'), findsOneWidget);

    // « Reprendre le tri » ramène à l'écran principal.
    await tester.tap(find.byTooltip('Reprendre le tri'));
    await settle(tester);
    expect(find.byTooltip('Garder'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('une langue non gérée retombe sur le français', (tester) async {
    await pumpApp(
      tester,
      gallery: FakeGallerySource(photos: samplePhotos(1)),
      locale: const Locale('de'),
    );
    expect(find.text("Je m'arrête là"), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('le menu est traduit en anglais', (tester) async {
    await pumpApp(
      tester,
      gallery: FakeGallerySource(photos: samplePhotos(2)),
      locale: const Locale('en'),
    );
    expect(find.text("I'll stop here"), findsOneWidget);
    await openMenu(tester);
    expect(find.text('0% sorted'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets("accès refusé : écran d'explication", (tester) async {
    await pumpApp(
      tester,
      gallery: FakeGallerySource(access: GalleryAccess.denied),
    );
    expect(find.text('TidyPics ne voit pas tes photos'), findsOneWidget);
    expect(find.text('Ouvrir les réglages'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('accès limité : bandeau pour en autoriser plus', (tester) async {
    await pumpApp(
      tester,
      gallery: FakeGallerySource(
        photos: samplePhotos(1),
        access: GalleryAccess.limited,
      ),
    );
    await openMenu(tester);
    expect(find.text('Choisir plus de photos'), findsOneWidget);

    await closeApp(tester);
  });
}
