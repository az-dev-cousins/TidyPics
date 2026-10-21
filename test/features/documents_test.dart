import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/models/document_file.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_document_source.dart';
import '../helpers/fake_gallery_source.dart';

void main() {
  DocumentFile doc(String name, int megabytes) => DocumentFile(
    uri: 'content://docs/$name',
    name: name,
    sizeBytes: megabytes * 1000 * 1000,
    modified: DateTime(2025, 1, 10),
    folder: '',
  );

  Future<void> openDocuments(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Menu'));
    await settle(tester);
    final tile = find.text('Documents');
    for (var i = 0; i < 6; i++) {
      final y = tester.getCenter(tile).dy;
      if (y > 80 && y < 880) break;
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.tap(tile);
    await settle(tester);
  }

  testWidgets('mes documents : le dossier, les plus gros d\'abord, corbeille', (
    tester,
  ) async {
    final documents = FakeDocumentSource(
      folderFiles: {
        'tree:Documents': [doc('petit.pdf', 1), doc('gros.pdf', 40)],
      },
    );
    await pumpApp(
      tester,
      gallery: FakeGallerySource(photos: samplePhotos(1)),
      documents: documents,
    );
    await openDocuments(tester);

    await tester.tap(find.text('Choisir le dossier Documents'));
    await settle(tester);
    await tester.tap(find.text('Trier mes documents'));
    await settle(tester);

    // Le plus gros en premier.
    expect(find.text('gros.pdf'), findsOneWidget);
    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    expect(find.text('petit.pdf'), findsOneWidget);
    await tester.tap(find.byTooltip('Garder'));
    await settle(tester);

    expect(find.text('Tous les documents sont triés !'), findsOneWidget);
    await tester.tap(find.text('Envoyer à la corbeille (40 Mo)'));
    await settle(tester);
    expect(documents.trashed, ['content://docs/gros.pdf']);

    // Une autre fois : le document gardé n'est plus proposé.
    await tester.tap(find.text('Trier mes documents'));
    await settle(tester);
    expect(
      find.text('Rien à trier ici : tout est déjà gardé.'),
      findsOneWidget,
    );

    // Dans « En cours de suppression » : 30 jours pour changer d'avis.
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    final trash = find.text('Corbeille');
    for (var i = 0; i < 6; i++) {
      final y = tester.getCenter(trash).dy;
      if (y > 80 && y < 880) break;
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.tap(trash);
    await settle(tester);
    expect(find.text('gros.pdf'), findsOneWidget);
    await tester.tap(find.text('Restaurer').last);
    await settle(tester);
    expect(documents.restored, ['gros.pdf']);
    expect(find.text('gros.pdf'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('fichiers protégés : on prévient, rien n\'est perdu', (
    tester,
  ) async {
    final documents = FakeDocumentSource(
      picked: [doc('vieux.apk', 80)],
      canDelete: false,
    );
    await pumpApp(
      tester,
      gallery: FakeGallerySource(photos: samplePhotos(1)),
      documents: documents,
    );
    await openDocuments(tester);

    await tester.tap(find.text('Choisir des fichiers'));
    await settle(tester);
    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    await tester.tap(find.text('Envoyer à la corbeille (80 Mo)'));
    await settle(tester);

    expect(find.textContaining("n'ont pas pu être supprimés"), findsOneWidget);
    expect(documents.trashed, isEmpty);

    await closeApp(tester);
  });
}
