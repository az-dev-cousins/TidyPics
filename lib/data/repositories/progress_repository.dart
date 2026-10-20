import 'package:drift/drift.dart';

import '../sources/local_db.dart';

/// Ce qui alimente les succès : jours de tri, premières fois, succès déjà
/// débloqués.
class ProgressRepository {
  ProgressRepository(this._db);

  final LocalDb _db;

  /// Note une première fois (sans effet si elle est déjà notée).
  Future<void> recordMilestone(String key, {DateTime? at}) => _db
      .into(_db.milestones)
      .insert(
        MilestonesCompanion.insert(key: key, at: at ?? DateTime.now()),
        mode: InsertMode.insertOrIgnore,
      );

  Stream<Set<String>> watchMilestones() => _db
      .select(_db.milestones)
      .watch()
      .map((rows) => {for (final r in rows) r.key});

  /// Jours de tri, au format AAAAMMJJ.
  Stream<List<int>> watchActivityDays() => _db
      .select(_db.activityDays)
      .watch()
      .map((rows) => [for (final r in rows) r.day]);

  /// Photos triées depuis le début : décisions prises et photos au panier.
  Stream<int> watchSortedTotal() => _db
      .customSelect(
        'SELECT (SELECT COUNT(*) FROM photo_decisions) + '
        '(SELECT COUNT(*) FROM cart_items) AS total',
        readsFrom: {_db.photoDecisions, _db.cartItems},
      )
      .watchSingle()
      .map((row) => row.read<int>('total'));

  /// Succès déjà débloqués, avec leur date.
  Stream<Map<String, DateTime>> watchUnlocked() => _db
      .select(_db.achievementLog)
      .watch()
      .map((rows) => {for (final r in rows) r.id: r.unlockedAt});

  /// Vrai si aucun succès n'a encore été inscrit (première ouverture après
  /// la mise à jour).
  Future<bool> hasNoUnlocked() async {
    final count = _db.achievementLog.id.count();
    final query = _db.selectOnly(_db.achievementLog)..addColumns([count]);
    return (await query.map((r) => r.read(count)).getSingle()) == 0;
  }

  Future<void> unlock(Iterable<String> ids, {DateTime? at}) =>
      _db.batch((batch) {
        for (final id in ids) {
          batch.insert(
            _db.achievementLog,
            AchievementLogCompanion.insert(
              id: id,
              unlockedAt: at ?? DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
}
