import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/models/document_file.dart';

Uint8List zip(Map<String, String> files) {
  final archive = Archive();
  for (final MapEntry(:key, :value) in files.entries) {
    final bytes = utf8.encode(value);
    archive.addFile(ArchiveFile(key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  DocumentFile file(String name) =>
      DocumentFile(uri: 'content://$name', name: name);

  test('famille selon l\'extension et le type', () {
    expect(file('Facture.PDF').kind, DocumentKind.pdf);
    expect(file('CV.docx').kind, DocumentKind.word);
    expect(file('budget.xlsx').kind, DocumentKind.sheet);
    expect(file('jeu.apk').kind, DocumentKind.apk);
    expect(
      const DocumentFile(uri: 'x', name: 'scan', mime: 'image/jpeg').kind,
      DocumentKind.image,
    );
    expect(file('mystere.bin').kind, DocumentKind.other);
  });

  test('aperçu d\'un Word : le texte des paragraphes', () {
    final bytes = zip({
      'word/document.xml':
          '<w:document><w:body>'
          '<w:p><w:r><w:t>Contrat de location</w:t></w:r></w:p>'
          '<w:p><w:r><w:t xml:space="preserve">Entre M. Dupont </w:t></w:r>'
          '<w:r><w:t>&amp; Mme Martin</w:t></w:r></w:p>'
          '</w:body></w:document>',
    });
    expect(
      DocumentText.extract(file('contrat.docx'), bytes),
      'Contrat de location\nEntre M. Dupont & Mme Martin',
    );
  });

  test('aperçu d\'un PowerPoint : les premières diapositives', () {
    final bytes = zip({
      'ppt/slides/slide2.xml':
          '<p:sld><a:p><a:r><a:t>Deuxième</a:t></a:r></a:p></p:sld>',
      'ppt/slides/slide1.xml':
          '<p:sld><a:p><a:r><a:t>Titre</a:t></a:r></a:p></p:sld>',
    });
    expect(DocumentText.extract(file('cours.pptx'), bytes), 'Titre\nDeuxième');
  });

  test('aperçu d\'un texte, coupé s\'il est long', () {
    final long = 'a' * 2000;
    final text = DocumentText.extract(
      file('notes.txt'),
      Uint8List.fromList(utf8.encode(long)),
    )!;
    expect(text.length, DocumentText.maxLength + 1);
    expect(text.endsWith('…'), isTrue);
  });

  test('fichier abîmé ou sans texte : pas d\'aperçu', () {
    expect(
      DocumentText.extract(file('casse.docx'), Uint8List.fromList([1, 2, 3])),
      isNull,
    );
    expect(DocumentText.extract(file('photo.zip'), zip({'a': 'b'})), isNull);
  });
}
