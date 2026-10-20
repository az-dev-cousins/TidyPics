import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/sources/gallery_source.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_gallery_source.dart';

void main() {
  testWidgets('premier lancement : 3 écrans puis la permission', (
    tester,
  ) async {
    final gallery = FakeGallerySource(
      photos: samplePhotos(2),
      access: GalleryAccess.notDetermined,
    )..accessAfterRequest = GalleryAccess.full;
    await pumpApp(tester, gallery: gallery, settings: const {});

    expect(find.text("Trie d'un geste"), findsOneWidget);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Tes photos restent sur ton téléphone'), findsOneWidget);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Autoriser l'accès"));
    await settle(tester);

    expect(find.text('0 triées sur 2'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('permission refusée pendant l\'onboarding', (tester) async {
    final gallery = FakeGallerySource(access: GalleryAccess.notDetermined)
      ..accessAfterRequest = GalleryAccess.denied;
    await pumpApp(tester, gallery: gallery, settings: const {});

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text("Autoriser l'accès"));
    await settle(tester);

    expect(find.text('TidyPics ne voit pas tes photos'), findsOneWidget);

    await closeApp(tester);
  });
}
