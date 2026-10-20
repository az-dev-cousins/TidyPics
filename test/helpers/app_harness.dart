import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/app/app.dart';
import 'package:tidypics/data/models/gallery_photo.dart';
import 'package:tidypics/data/sources/local_db.dart';
import 'package:tidypics/shared/widgets/photo_image.dart';

import 'fake_gallery_source.dart';
import 'test_container.dart';

/// PNG transparent de 1 × 1 pixel.
final _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Fausses images : aucune lecture de la galerie pendant les tests.
class FakePhotoImages extends PhotoImages {
  const FakePhotoImages();

  @override
  ImageProvider thumbnail(GalleryPhoto photo, {int size = 240}) =>
      MemoryImage(_pixel);

  @override
  ImageProvider large(GalleryPhoto photo, {int maxSide = 1600}) =>
      MemoryImage(_pixel);
}

/// Lance l'app complète avec une fausse galerie et une base en mémoire.
Future<void> pumpApp(
  WidgetTester tester, {
  required FakeGallerySource gallery,
  LocalDb? db,
  Map<String, Object> settings = const {'onboarding_done': true},
  Locale locale = const Locale('fr'),
  Size size = const Size(1080, 2400),
}) async {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  final database = db ?? memoryDb();
  final overrides = await testOverrides(
    db: database,
    gallery: gallery,
    settings: settings,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        photoImagesProvider.overrideWithValue(const FakePhotoImages()),
      ],
      child: const TidyPicsApp(),
    ),
  );
  await settle(tester);
  _openDb = database;
}

LocalDb? _openDb;

/// À appeler à la fin de chaque test d'écran : démonte l'app, laisse Drift
/// fermer ses flux (minuteurs à zéro), puis ferme la base.
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
  final db = _openDb;
  _openDb = null;
  if (db != null) await tester.runAsync(db.close);
  await tester.pump(Duration.zero);
}

/// Laisse les requêtes Drift (vrais futures) et les animations se terminer.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}
