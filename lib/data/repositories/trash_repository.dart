import 'package:drift/drift.dart';

import '../models/gallery_photo.dart';
import '../sources/gallery_source.dart';
import '../sources/local_db.dart';

/// Une photo envoyée à la corbeille système par TidyPics (F4).
class TrashEntry {
  const TrashEntry({
    required this.photo,
    required this.trashedAt,
    this.thumbnail,
  });

  /// Durée avant effacement définitif par le système.
  static const retention = Duration(days: 30);

  final GalleryPhoto photo;
  final DateTime trashedAt;
  final Uint8List? thumbnail;

  int daysLeft(DateTime now) {
    final left = trashedAt.add(retention).difference(now);
    return left.isNegative ? 0 : (left.inHours / 24).ceil();
  }
}

/// Résultat d'un envoi à la corbeille.
class TrashOutcome {
  const TrashOutcome({required this.count, required this.bytes});

  static const none = TrashOutcome(count: 0, bytes: 0);

  final int count;
  final int bytes;
}

/// Statistiques depuis l'installation (F7).
class FreedStats {
  const FreedStats({required this.bytes, required this.photos});

  static const zero = FreedStats(bytes: 0, photos: 0);

  final int bytes;
  final int photos;
}

/// Envoi à la corbeille, journal et statistiques d'espace libéré.
class TrashRepository {
  TrashRepository(this._db, this._gallery);

  final LocalDb _db;
  final GallerySource _gallery;

  /// Envoie les photos à la corbeille système (une popup par lot au plus),
  /// puis met à jour le journal, les stats et le panier.
  ///
  /// Si l'utilisateur refuse, rien ne change et le panier est conservé.
  Future<TrashOutcome> trash(List<GalleryPhoto> photos, {DateTime? at}) async {
    if (photos.isEmpty) return TrashOutcome.none;

    // Les miniatures sont lues avant : une fois à la corbeille, la photo
    // n'est plus accessible.
    final thumbnails = <String, Uint8List?>{};
    for (final photo in photos) {
      thumbnails[photo.id] = await _gallery.thumbnail(photo.id, size: 160);
    }

    final trashedIds = (await _gallery.moveToTrash(photos)).toSet();
    if (trashedIds.isEmpty) return TrashOutcome.none;

    final now = at ?? DateTime.now();
    final trashed = photos.where((p) => trashedIds.contains(p.id)).toList();
    final bytes = trashed.fold<int>(0, (sum, p) => sum + (p.sizeBytes ?? 0));
    final ids = trashed.map((p) => p.id).toList();

    await _db.transaction(() async {
      await _db.batch((batch) {
        for (final photo in trashed) {
          batch.insert(
            _db.trashLog,
            TrashLogCompanion.insert(
              assetId: photo.id,
              title: Value(photo.title),
              takenAt: Value(photo.takenAt),
              width: Value(photo.width),
              height: Value(photo.height),
              sizeBytes: Value(photo.sizeBytes ?? 0),
              trashedAt: now,
              thumbnail: Value(thumbnails[photo.id]),
            ),
            mode: InsertMode.insertOrReplace,
          );
          batch.insert(
            _db.photoDecisions,
            PhotoDecisionsCompanion.insert(
              assetId: photo.id,
              decision: Decision.trashed,
              decidedAt: now,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        batch.insert(
          _db.statsEvents,
          StatsEventsCompanion.insert(
            type: StatsEventType.trashed,
            bytes: bytes,
            photoCount: trashed.length,
            at: now,
          ),
        );
      });
      for (var i = 0; i < ids.length; i += 500) {
        final chunk = ids.skip(i).take(500).toList();
        await (_db.delete(
          _db.cartItems,
        )..where((t) => t.assetId.isIn(chunk))).go();
        await (_db.delete(_db.photos)..where((t) => t.id.isIn(chunk))).go();
      }
    });
    return TrashOutcome(count: trashed.length, bytes: bytes);
  }

  /// Android : sort des photos de la corbeille. Elles comptent comme gardées.
  Future<int> restore(List<TrashEntry> entries, {DateTime? at}) async {
    final photos = entries.map((e) => e.photo).toList();
    final restoredIds = (await _gallery.restoreFromTrash(photos)).toSet();
    if (restoredIds.isEmpty) return 0;
    final restored = photos.where((p) => restoredIds.contains(p.id)).toList();
    final now = at ?? DateTime.now();
    final ids = restored.map((p) => p.id).toList();
    await _db.transaction(() async {
      await (_db.delete(_db.trashLog)..where((t) => t.assetId.isIn(ids))).go();
      await _db.batch((batch) {
        for (final photo in restored) {
          batch.insert(
            _db.photoDecisions,
            PhotoDecisionsCompanion.insert(
              assetId: photo.id,
              decision: Decision.kept,
              decidedAt: now,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        batch.insert(
          _db.statsEvents,
          StatsEventsCompanion.insert(
            type: StatsEventType.restored,
            bytes: restored.fold<int>(0, (s, p) => s + (p.sizeBytes ?? 0)),
            photoCount: restored.length,
            at: now,
          ),
        );
      });
    });
    return restored.length;
  }

  Stream<List<TrashEntry>> watchLog() {
    final query = _db.select(_db.trashLog)
      ..orderBy([(t) => OrderingTerm.desc(t.trashedAt)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          TrashEntry(
            photo: GalleryPhoto(
              id: row.assetId,
              takenAt: row.takenAt ?? row.trashedAt,
              title: row.title,
              width: row.width,
              height: row.height,
              sizeBytes: row.sizeBytes,
            ),
            trashedAt: row.trashedAt,
            thumbnail: row.thumbnail,
          ),
      ],
    );
  }

  /// Oublie les entrées dont le système a déjà effacé la photo (> 30 jours).
  Future<void> purgeExpired({DateTime? now}) {
    final limit = (now ?? DateTime.now()).subtract(TrashEntry.retention);
    return (_db.delete(
      _db.trashLog,
    )..where((t) => t.trashedAt.isSmallerThanValue(limit))).go();
  }

  Stream<FreedStats> watchFreed() {
    return _db
        .customSelect(
          'SELECT '
          'COALESCE(SUM(CASE type WHEN ? THEN bytes ELSE -bytes END), 0) '
          'AS bytes, '
          'COALESCE(SUM(CASE type WHEN ? THEN photo_count ELSE -photo_count '
          'END), 0) AS photos '
          'FROM stats_events',
          variables: [
            Variable.withInt(StatsEventType.trashed.index),
            Variable.withInt(StatsEventType.trashed.index),
          ],
          readsFrom: {_db.statsEvents},
        )
        .watchSingle()
        .map(
          (row) => FreedStats(
            bytes: row.read<int>('bytes'),
            photos: row.read<int>('photos'),
          ),
        );
  }
}
