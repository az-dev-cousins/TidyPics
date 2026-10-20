import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/sources/gallery_source.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_gallery_source.dart';

void main() {
  testWidgets("l'accueil montre la galerie indexée", (tester) async {
    await pumpApp(tester, gallery: FakeGallerySource(photos: samplePhotos(3)));

    expect(find.bySemanticsLabel('TidyPics'), findsOneWidget);
    expect(find.text('Prêt à faire de la place ?'), findsOneWidget);
    expect(find.text('0 triées sur 3'), findsOneWidget);
    expect(find.text('Trier'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('une langue non gérée retombe sur le français', (tester) async {
    await pumpApp(
      tester,
      gallery: FakeGallerySource(photos: samplePhotos(1)),
      locale: const Locale('de'),
    );
    expect(find.text('Trier'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets("l'accueil est traduit en anglais", (tester) async {
    await pumpApp(
      tester,
      gallery: FakeGallerySource(photos: samplePhotos(2)),
      locale: const Locale('en'),
    );
    expect(find.text('0 of 2 sorted'), findsOneWidget);
    expect(find.text('Sort'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('accès refusé : écran d\'explication', (tester) async {
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
    expect(find.text('Choisir plus de photos'), findsOneWidget);

    await closeApp(tester);
  });
}
