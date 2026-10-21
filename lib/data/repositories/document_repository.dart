import 'dart:io';

import 'package:drift/drift.dart';

import '../models/document_file.dart';
import '../sources/document_source.dart';
import '../sources/local_db.dart';

/// Un document dans la corbeille de TidyPics.
class DocumentTrashEntry {
  const DocumentTrashEntry(this.row);

  final DocumentTrashRow row;

  /// Comme la corbeille du système : 30 jours.
  static const keep = Duration(days: 30);

  /// Comme pour les photos : arrondi au jour supérieur (30 juste après).
  int daysLeft(DateTime now) {
    final left = row.trashedAt.add(keep).difference(now);
    return left.isNegative ? 0 : (left.inHours / 24).ceil();
  }

  DocumentFile get file => DocumentFile(
    uri: row.uri,
    name: row.name,
    mime: row.mime,
    sizeBytes: row.sizeBytes,
    folder: row.folder,
    tree: row.tree,
  );
}

/// Documents gardés, corbeille des documents et espace libéré (V2, F16).
class DocumentRepository {
  DocumentRepository(this._db, this._source);

  final LocalDb _db;
  final DocumentSource _source;

  Future<Set<String>> keptUris() async {
    final rows = await _db.select(_db.documentDecisions).get();
    return {for (final r in rows) r.uri};
  }

  Future<void> keep(String uri, {DateTime? at}) => _db
      .into(_db.documentDecisions)
      .insertOnConflictUpdate(
        DocumentDecisionsCompanion.insert(
          uri: uri,
          decidedAt: at ?? DateTime.now(),
        ),
      );

  Future<void> unkeep(String uri) =>
      (_db.delete(_db.documentDecisions)..where((t) => t.uri.equals(uri))).go();

  /// Met de côté dans la corbeille de l'app. Renvoie ceux qui y sont allés.
  Future<List<DocumentFile>> trash(
    List<DocumentFile> files, {
    DateTime? at,
  }) async {
    if (files.isEmpty) return const [];
    final moved = {
      for (final m in await _source.moveToAppTrash([
        for (final f in files) f.uri,
      ]))
        m.uri: m.path,
    };
    final now = at ?? DateTime.now();
    final done = [
      for (final f in files)
        if (moved.containsKey(f.uri)) f,
    ];
    await _db.batch((batch) {
      for (final f in done) {
        batch.insert(
          _db.documentTrash,
          DocumentTrashCompanion.insert(
            uri: f.uri,
            name: f.name,
            mime: Value(f.mime),
            sizeBytes: Value(f.sizeBytes),
            path: moved[f.uri]!,
            tree: Value(f.tree),
            folder: Value(f.folder),
            trashedAt: now,
          ),
        );
      }
    });
    await _recordFreed(done.fold(0, (s, f) => s + f.sizeBytes), now);
    return done;
  }

  Stream<List<DocumentTrashEntry>> watchTrash() =>
      (_db.select(_db.documentTrash)
            ..orderBy([(t) => OrderingTerm.desc(t.trashedAt)]))
          .watch()
          .map((rows) => [for (final r in rows) DocumentTrashEntry(r)]);

  /// Remet le document à sa place. Vrai si c'est fait.
  Future<bool> restore(DocumentTrashEntry entry) async {
    final row = entry.row;
    final uri = await _source.restore(
      path: row.path,
      name: row.name,
      mime: row.mime,
      tree: row.tree,
      folder: row.folder,
    );
    if (uri == null) return false;
    await (_db.delete(
      _db.documentTrash,
    )..where((t) => t.id.equals(row.id))).go();
    // Il n'est plus « libéré ».
    await _db
        .into(_db.statsEvents)
        .insert(
          StatsEventsCompanion.insert(
            type: StatsEventType.restored,
            bytes: row.sizeBytes,
            photoCount: 0,
            at: DateTime.now(),
          ),
        );
    return true;
  }

  /// Efface pour de bon (« Vider maintenant », ou au bout de 30 jours).
  Future<void> emptyNow(List<DocumentTrashEntry> entries) async {
    for (final entry in entries) {
      try {
        await File(entry.row.path).delete();
      } on FileSystemException {
        // Déjà effacé.
      }
    }
    await (_db.delete(
      _db.documentTrash,
    )..where((t) => t.id.isIn([for (final e in entries) e.row.id]))).go();
  }

  /// Au démarrage : efface ce qui a plus de 30 jours.
  Future<void> purgeExpired({DateTime? now}) async {
    final limit = (now ?? DateTime.now()).subtract(DocumentTrashEntry.keep);
    final rows = await (_db.select(
      _db.documentTrash,
    )..where((t) => t.trashedAt.isSmallerThanValue(limit))).get();
    if (rows.isEmpty) return;
    await emptyNow([for (final r in rows) DocumentTrashEntry(r)]);
  }

  /// L'espace libéré compte dans les stats et les succès (sans compter de
  /// photos).
  Future<void> _recordFreed(int bytes, DateTime at) {
    if (bytes <= 0) return Future.value();
    return _db
        .into(_db.statsEvents)
        .insert(
          StatsEventsCompanion.insert(
            type: StatsEventType.trashed,
            bytes: bytes,
            photoCount: 0,
            at: at,
          ),
        );
  }
}
