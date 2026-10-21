import 'dart:typed_data';

import 'package:tidypics/data/models/document_file.dart';
import 'package:tidypics/data/sources/document_source.dart';

/// Faux documents en mémoire.
class FakeDocumentSource implements DocumentSource {
  FakeDocumentSource({
    this.picked = const [],
    Map<String, List<DocumentFile>>? folderFiles,
    this.canDelete = true,
  }) : folderFiles = folderFiles ?? {};

  /// Ce que renvoie le sélecteur.
  List<DocumentFile> picked;

  /// Dossiers accessibles et leurs fichiers.
  final Map<String, List<DocumentFile>> folderFiles;
  final granted = <DocumentFolder>[];

  /// Faux : les fichiers sont protégés, rien ne peut être supprimé.
  bool canDelete;

  final trashed = <String>[];
  final restored = <String>[];
  final opened = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<List<DocumentFile>> pickFiles() async => picked;

  @override
  Future<DocumentFolder?> pickFolder() async {
    if (folderFiles.isEmpty) return null;
    final uri = folderFiles.keys.first;
    final folder = (uri: uri, name: 'Documents');
    granted.add(folder);
    return folder;
  }

  @override
  Future<List<DocumentFolder>> folders() async => [...granted];

  @override
  Future<void> forgetFolder(String uri) async =>
      granted.removeWhere((f) => f.uri == uri);

  @override
  Future<List<DocumentFile>> listFolder(String uri) async => [
    ...?folderFiles[uri],
  ];

  @override
  Future<PdfPreview?> pdfPreview(String uri, {int width = 600}) async => null;

  @override
  Future<Uint8List?> readBytes(String uri, {int max = 8 << 20}) async => null;

  @override
  Future<bool> open(DocumentFile file) async {
    opened.add(file.uri);
    return true;
  }

  @override
  Future<List<({String uri, String path})>> moveToAppTrash(
    List<String> uris,
  ) async {
    if (!canDelete) return const [];
    trashed.addAll(uris);
    _remove(uris);
    return [for (final u in uris) (uri: u, path: '/fake/trash/${u.hashCode}')];
  }

  @override
  Future<String?> restore({
    required String path,
    required String name,
    String? mime,
    String? tree,
    String? folder,
  }) async {
    restored.add(name);
    return 'content://restored/$name';
  }

  void _remove(List<String> uris) {
    for (final files in folderFiles.values) {
      files.removeWhere((f) => uris.contains(f.uri));
    }
  }
}
