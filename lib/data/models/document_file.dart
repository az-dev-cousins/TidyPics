import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Un fichier qui n'est ni une photo ni une vidéo : PDF, Word, archive…
/// (V2, F16). Identifié par son adresse dans le sélecteur du système.
class DocumentFile {
  const DocumentFile({
    required this.uri,
    required this.name,
    this.mime,
    this.sizeBytes = 0,
    this.modified,
    this.folder,
    this.tree,
  });

  factory DocumentFile.fromMap(Map<Object?, Object?> map, {String? tree}) =>
      DocumentFile(
        uri: map['uri']! as String,
        name: (map['name'] as String?) ?? '',
        mime: map['mime'] as String?,
        sizeBytes: (map['size'] as num?)?.toInt() ?? 0,
        modified: switch ((map['modified'] as num?)?.toInt()) {
          final int ms when ms > 0 => DateTime.fromMillisecondsSinceEpoch(ms),
          _ => null,
        },
        folder: map['folder'] as String?,
        tree: tree,
      );

  final String uri;
  final String name;
  final String? mime;
  final int sizeBytes;
  final DateTime? modified;

  /// Sous-dossier dans le dossier donné (« Factures/2024/ »), s'il y a lieu.
  final String? folder;

  /// Le dossier donné (« Mes documents ») qui le contient : sert à le
  /// remettre à sa place. `null` pour un fichier choisi dans le sélecteur.
  final String? tree;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  DocumentKind get kind => DocumentKind.of(extension, mime);

  @override
  bool operator ==(Object other) => other is DocumentFile && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;
}

/// Famille de fichier : sert à l'icône et à l'aperçu.
enum DocumentKind {
  pdf,
  word,
  sheet,
  slides,
  text,
  archive,
  apk,
  image,
  audio,
  video,
  other;

  static DocumentKind of(String extension, String? mime) {
    switch (extension) {
      case 'pdf':
        return pdf;
      case 'doc' || 'docx' || 'odt' || 'rtf' || 'pages':
        return word;
      case 'xls' || 'xlsx' || 'ods' || 'csv' || 'numbers':
        return sheet;
      case 'ppt' || 'pptx' || 'odp' || 'key':
        return slides;
      case 'txt' || 'md' || 'json' || 'xml' || 'html' || 'log':
        return text;
      case 'zip' || 'rar' || '7z' || 'tar' || 'gz':
        return archive;
      case 'apk' || 'xapk' || 'apks':
        return apk;
    }
    final type = mime ?? '';
    if (type.startsWith('image/')) return image;
    if (type.startsWith('audio/')) return audio;
    if (type.startsWith('video/')) return video;
    if (type.startsWith('text/')) return text;
    if (type == 'application/pdf') return pdf;
    return other;
  }
}

/// Aperçu en texte des premières lignes d'un fichier Office ou texte, tiré
/// du fichier lui-même : un .docx est une archive zip de XML.
abstract final class DocumentText {
  /// Au plus autant de caractères.
  static const maxLength = 600;

  static String? extract(DocumentFile file, Uint8List bytes) {
    try {
      final text = switch (file.extension) {
        'docx' => _fromZip(bytes, ['word/document.xml'], 'w:t', 'w:p'),
        'pptx' => _fromZip(bytes, _slides(bytes), 'a:t', 'a:p'),
        'xlsx' => _fromZip(bytes, ['xl/sharedStrings.xml'], 't', 'si'),
        'odt' ||
        'odp' ||
        'ods' => _fromZip(bytes, ['content.xml'], null, 'text:p'),
        _ when file.kind == DocumentKind.text => utf8.decode(
          bytes.length > 8000 ? bytes.sublist(0, 8000) : bytes,
          allowMalformed: true,
        ),
        _ => null,
      };
      if (text == null) return null;
      final clean = text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
      if (clean.isEmpty) return null;
      return clean.length > maxLength
          ? '${clean.substring(0, maxLength)}…'
          : clean;
    } on Object {
      return null;
    }
  }

  static List<String> _slides(Uint8List bytes) {
    final names =
        ZipDecoder()
            .decodeBytes(bytes)
            .files
            .map((f) => f.name)
            .where((n) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(n))
            .toList()
          ..sort((a, b) => _number(a).compareTo(_number(b)));
    return names.take(3).toList();
  }

  static int _number(String name) =>
      int.tryParse(RegExp(r'(\d+)\.xml$').firstMatch(name)?.group(1) ?? '') ??
      0;

  /// Le texte des balises [textTag] (toutes si `null`), un paragraphe
  /// ([paragraphTag]) par ligne.
  static String? _fromZip(
    Uint8List bytes,
    List<String> entries,
    String? textTag,
    String paragraphTag,
  ) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final buffer = StringBuffer();
    for (final entry in entries) {
      final file = archive.findFile(entry);
      if (file == null) continue;
      final xml = utf8.decode(file.content, allowMalformed: true);
      for (final paragraph in RegExp(
        '<$paragraphTag[ >][\\s\\S]*?</$paragraphTag>',
      ).allMatches(xml)) {
        final inner = paragraph.group(0)!;
        final pieces = textTag == null
            ? [inner.replaceAll(RegExp('<[^>]+>'), '')]
            : [
                for (final m in RegExp(
                  '<$textTag(?: [^>]*)?>([^<]*)</$textTag>',
                ).allMatches(inner))
                  m.group(1)!,
              ];
        final line = _unescape(pieces.join());
        if (line.trim().isNotEmpty) buffer.writeln(line.trim());
        if (buffer.length > maxLength) return buffer.toString();
      }
    }
    return buffer.isEmpty ? null : buffer.toString();
  }

  static String _unescape(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
