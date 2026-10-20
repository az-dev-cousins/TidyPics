import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/repositories/library_repository.dart';
import 'package:tidypics/data/sources/local_db.dart';

void main() {
  test('v1 → v2 : les photos déjà indexées gardent leurs données', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    // Base telle que la créait la v1 (sans les colonnes des vidéos).
    final db = LocalDb(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute(
              'CREATE TABLE photos (id TEXT NOT NULL PRIMARY KEY, '
              'taken_at INTEGER NOT NULL, title TEXT, '
              'width INTEGER NOT NULL DEFAULT 0, '
              'height INTEGER NOT NULL DEFAULT 0, size_bytes INTEGER, '
              'is_favorite INTEGER NOT NULL DEFAULT 0)',
            )
            ..execute(
              'CREATE TABLE trash_log (asset_id TEXT NOT NULL PRIMARY KEY, '
              'title TEXT, taken_at INTEGER, '
              'width INTEGER NOT NULL DEFAULT 0, '
              'height INTEGER NOT NULL DEFAULT 0, '
              'size_bytes INTEGER NOT NULL DEFAULT 0, '
              'trashed_at INTEGER NOT NULL, thumbnail BLOB)',
            )
            ..execute(
              'CREATE TABLE photo_decisions (asset_id TEXT NOT NULL PRIMARY '
              'KEY, decision INTEGER NOT NULL, decided_at INTEGER NOT NULL, '
              'was_favorite INTEGER NOT NULL DEFAULT 0)',
            )
            ..execute(
              'CREATE TABLE cart_items (asset_id TEXT NOT NULL PRIMARY KEY, '
              'size_bytes INTEGER NOT NULL DEFAULT 0, '
              'added_at INTEGER NOT NULL)',
            )
            ..execute(
              'CREATE TABLE stats_events (id INTEGER NOT NULL PRIMARY KEY '
              'AUTOINCREMENT, type INTEGER NOT NULL, bytes INTEGER NOT NULL, '
              'photo_count INTEGER NOT NULL, at INTEGER NOT NULL)',
            )
            ..execute(
              'INSERT INTO photos (id, taken_at, title, size_bytes) '
              "VALUES ('p1', 1700000000, 'IMG_1.JPG', 4000)",
            )
            ..execute('PRAGMA user_version = 1');
        },
      ),
    );
    addTearDown(db.close);

    final photos = await LibraryRepository(db)
        .unsortedPhotos(SortOrder.oldestFirst);
    expect(photos.single.id, 'p1');
    expect(photos.single.sizeBytes, 4000);
    expect(photos.single.isVideo, isFalse);
  });
}
