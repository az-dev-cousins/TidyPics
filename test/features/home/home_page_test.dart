import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/app/app.dart';

void main() {
  testWidgets('l\'accueil affiche le slogan et la promesse vie privée', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const ProviderScope(child: TidyPicsApp()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('TidyPics'), findsOneWidget);
    expect(find.text('Trie. Respire. Libère de la place.'), findsOneWidget);
    expect(find.text('Tes photos restent chez toi'), findsOneWidget);
  });

  testWidgets('une langue non gérée retombe sur le français', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const ProviderScope(child: TidyPicsApp()));
    await tester.pumpAndSettle();

    expect(find.text('Trie. Respire. Libère de la place.'), findsOneWidget);
  });

  testWidgets('l\'accueil est traduit en anglais', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const ProviderScope(child: TidyPicsApp()));
    await tester.pumpAndSettle();

    expect(find.text('Sort. Breathe. Free up space.'), findsOneWidget);
  });
}
