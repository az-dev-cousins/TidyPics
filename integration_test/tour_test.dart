// Visite guidée de l'app sur un vrai simulateur / émulateur, pour vérifier
// les écrans à l'œil (les captures sont prises à côté, avec simctl ou adb).
//
//   flutter test integration_test/tour_test.dart -d <simulateur>
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tidypics/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pause(WidgetTester tester, [int seconds = 3]) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) return;
    await tester.tap(finder.first);
    await pause(tester, 2);
  }

  testWidgets('visite', (tester) async {
    unawaited(app.main());
    await pause(tester, 4);
    await tapText(tester, 'Passer');
    await tapText(tester, 'Suivant');
    await tapText(tester, 'Pas de rappel');
    await tapText(tester, 'Suivant');
    await tapText(tester, "Autoriser l'accès");
    await pause(tester, 6);
    // Le tri : garder, supprimer, supprimer.
    for (final tip in ['Garder', 'Supprimer', 'Supprimer']) {
      final f = find.byTooltip(tip);
      if (f.evaluate().isNotEmpty) await tester.tap(f.first);
      await pause(tester, 2);
    }
    // Le menu.
    await tester.tap(find.byTooltip('Menu'));
    await pause(tester, 4);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await pause(tester, 4);
    // Le récap, puis la suppression (popup d'iOS).
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
    await pause(tester, 2);
    await tapText(tester, 'Panier');
    await pause(tester, 3);
    final delete = find.textContaining('Supprimer 2');
    if (delete.evaluate().isNotEmpty) await tester.tap(delete.first);
    await pause(tester, 8);
  });
}
