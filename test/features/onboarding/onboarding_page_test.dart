import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/models/reminder_plan.dart';
import 'package:tidypics/data/sources/gallery_source.dart';
import 'package:tidypics/features/settings/application/settings_controller.dart';
import 'package:tidypics/features/swipe/presentation/swipe_deck.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_gallery_source.dart';
import '../../helpers/fake_reminders.dart';

void main() {
  Future<void> fling(WidgetTester tester, Offset offset) async {
    await tester.fling(find.byType(SwipeDeck), offset, 2000);
    await tester.pumpAndSettle();
  }

  testWidgets('tutoriel : un geste par photo d\'exemple, puis la suite', (
    tester,
  ) async {
    final gallery = FakeGallerySource(
      photos: samplePhotos(2),
      access: GalleryAccess.notDetermined,
    )..accessAfterRequest = GalleryAccess.full;
    await pumpApp(
      tester,
      gallery: gallery,
      settings: const {},
      reminders: FakeReminderScheduler(),
    );

    expect(find.text("Trie d'un geste"), findsOneWidget);
    expect(find.textContaining('Floue ?'), findsOneWidget);

    await fling(tester, const Offset(-500, 0));
    expect(find.textContaining('Jolie !'), findsOneWidget);

    // Mauvais sens : la carte revient, la consigne reste.
    await fling(tester, const Offset(-500, 0));
    expect(find.textContaining('Jolie !'), findsOneWidget);

    await fling(tester, const Offset(500, 0));
    expect(find.textContaining('Ta préférée ?'), findsOneWidget);
    await fling(tester, const Offset(0, -700));
    expect(find.textContaining('Bravo'), findsOneWidget);

    // Passe tout seul à l'écran suivant.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.text('Tes photos restent sur ton téléphone'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    // Le moment des rappels : le matin.
    expect(find.text('Quand aimes-tu trier ?'), findsOneWidget);
    await tester.tap(find.text('Matin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suivant'));
    await settle(tester);
    // Choix enregistré ; les rappels seront programmés en quittant l'app,
    // une fois la galerie lue.
    final settings = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(settingsProvider);
    expect(settings.reminderMode, ReminderMode.daily);
    expect(settings.reminderSlot, ReminderSlot.morning);

    await tester.tap(find.text("Autoriser l'accès"));
    await settle(tester);

    // Directement sur le tri.
    expect(find.text('0 triée'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets("on peut passer le tutoriel ; refus de l'accès", (tester) async {
    final gallery = FakeGallerySource(access: GalleryAccess.notDetermined)
      ..accessAfterRequest = GalleryAccess.denied;
    await pumpApp(tester, gallery: gallery, settings: const {});

    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    // Pas de rappel.
    await tester.tap(find.text('Pas de rappel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suivant'));
    await settle(tester);
    await tester.tap(find.text("Autoriser l'accès"));
    await settle(tester);

    expect(find.text('TidyPics ne voit pas tes photos'), findsOneWidget);

    await closeApp(tester);
  });
}
