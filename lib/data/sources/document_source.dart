import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/document_file.dart';

/// Un dossier dont l'utilisateur a donné l'accès (« Documents »).
typedef DocumentFolder = ({String uri, String name});

/// Première page d'un PDF.
typedef PdfPreview = ({Uint8List png, int pages});

/// Accès aux documents (V2, F16), par le sélecteur du système : aucune
/// permission spéciale, accepté par le Play Store. Android seulement.
abstract interface class DocumentSource {
  bool get isSupported;

  /// Le sélecteur de fichiers, plusieurs à la fois. Vide si annulé.
  Future<List<DocumentFile>> pickFiles();

  /// Donner l'accès à un dossier (Documents proposé d'abord). `null` si
  /// annulé.
  Future<DocumentFolder?> pickFolder();

  Future<List<DocumentFolder>> folders();

  Future<void> forgetFolder(String uri);

  /// Tous les fichiers du dossier, sous-dossiers compris.
  Future<List<DocumentFile>> listFolder(String uri);

  Future<PdfPreview?> pdfPreview(String uri, {int width = 600});

  /// Le début du fichier (aperçu du texte), au plus [max] octets.
  Future<Uint8List?> readBytes(String uri, {int max = 8 << 20});

  /// Ouvre le fichier dans l'app qui sait le lire.
  Future<bool> open(DocumentFile file);

  /// Corbeille de TidyPics : le fichier est copié dans le stockage de l'app
  /// puis effacé de son dossier (la corbeille du système n'accepte que les
  /// photos, vidéos et sons). Renvoie ceux mis de côté et leur copie.
  Future<List<({String uri, String path})>> moveToAppTrash(List<String> uris);

  /// Remet un document mis de côté : dans son dossier d'origine si [tree]
  /// est connu, sinon dans Téléchargements. Renvoie sa nouvelle adresse.
  Future<String?> restore({
    required String path,
    required String name,
    String? mime,
    String? tree,
    String? folder,
  });
}

class PlatformDocumentSource implements DocumentSource {
  static const _channel = MethodChannel('tidypics/documents');

  @override
  bool get isSupported => Platform.isAndroid;

  List<DocumentFile> _files(List<Object?>? raw, {String? tree}) => [
    for (final item in raw ?? const [])
      DocumentFile.fromMap(item! as Map<Object?, Object?>, tree: tree),
  ];

  DocumentFolder _folder(Map<Object?, Object?> map) =>
      (uri: map['uri']! as String, name: (map['name'] as String?) ?? '');

  @override
  Future<List<DocumentFile>> pickFiles() async =>
      _files(await _channel.invokeListMethod<Object?>('pickFiles'));

  @override
  Future<DocumentFolder?> pickFolder() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('pickFolder');
    return map == null ? null : _folder(map);
  }

  @override
  Future<List<DocumentFolder>> folders() async => [
    for (final item
        in await _channel.invokeListMethod<Object?>('folders') ?? const [])
      _folder(item! as Map<Object?, Object?>),
  ];

  @override
  Future<void> forgetFolder(String uri) =>
      _channel.invokeMethod('forgetFolder', {'uri': uri});

  @override
  Future<List<DocumentFile>> listFolder(String uri) async => _files(
    await _channel.invokeListMethod<Object?>('listFolder', {'uri': uri}),
    tree: uri,
  );

  @override
  Future<PdfPreview?> pdfPreview(String uri, {int width = 600}) async {
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>(
        'pdfPreview',
        {'uri': uri, 'width': width},
      );
      if (map == null) return null;
      return (png: map['png']! as Uint8List, pages: map['pages']! as int);
    } on PlatformException catch (error) {
      debugPrint('Aperçu PDF impossible : $error');
      return null;
    }
  }

  @override
  Future<Uint8List?> readBytes(String uri, {int max = 8 << 20}) async {
    try {
      return await _channel.invokeMethod<Uint8List>('readBytes', {
        'uri': uri,
        'max': max,
      });
    } on PlatformException catch (error) {
      debugPrint('Lecture impossible : $error');
      return null;
    }
  }

  @override
  Future<bool> open(DocumentFile file) async =>
      await _channel.invokeMethod<bool>('open', {
        'uri': file.uri,
        'mime': file.mime,
      }) ??
      false;

  @override
  Future<List<({String uri, String path})>> moveToAppTrash(
    List<String> uris,
  ) async {
    try {
      final raw =
          await _channel.invokeListMethod<Object?>('moveToAppTrash', {
            'uris': uris,
          }) ??
          const [];
      return [
        for (final item in raw.cast<Map<Object?, Object?>>())
          (uri: item['uri']! as String, path: item['path']! as String),
      ];
    } on PlatformException catch (error) {
      debugPrint('Mise de côté impossible : $error');
      return const [];
    }
  }

  @override
  Future<String?> restore({
    required String path,
    required String name,
    String? mime,
    String? tree,
    String? folder,
  }) async {
    try {
      return await _channel.invokeMethod<String>('restore', {
        'path': path,
        'name': name,
        'mime': mime,
        'tree': tree,
        'folder': folder,
      });
    } on PlatformException catch (error) {
      debugPrint('Restauration impossible : $error');
      return null;
    }
  }
}
