import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/achievements.dart';
import '../../../data/providers.dart';
import '../../gallery/application/gallery_controller.dart';

final _sortedTotalProvider = StreamProvider<int>(
  (ref) => ref.watch(progressRepositoryProvider).watchSortedTotal(),
);

final activityDaysProvider = StreamProvider<List<int>>(
  (ref) => ref.watch(progressRepositoryProvider).watchActivityDays(),
);

final _milestonesProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(progressRepositoryProvider).watchMilestones(),
);

/// Succès débloqués et leur date.
final unlockedAchievementsProvider = StreamProvider<Map<String, DateTime>>(
  (ref) => ref.watch(progressRepositoryProvider).watchUnlocked(),
);

/// Tous les succès, ou `null` tant que les données ne sont pas lues.
final achievementsProvider = Provider<List<Achievement>?>((ref) {
  final freed = ref.watch(freedStatsProvider).value;
  final sorted = ref.watch(_sortedTotalProvider).value;
  final days = ref.watch(activityDaysProvider).value;
  final milestones = ref.watch(_milestonesProvider).value;
  final months = ref.watch(monthsProvider).value;
  final summary = ref.watch(librarySummaryProvider).value;
  final unlocked = ref.watch(unlockedAchievementsProvider).value;
  if (freed == null ||
      sorted == null ||
      days == null ||
      milestones == null ||
      months == null ||
      summary == null ||
      unlocked == null) {
    return null;
  }
  return computeAchievements(
    AchievementInputs(
      freedBytes: freed.bytes,
      sortedPhotos: sorted,
      activityDays: days,
      milestones: milestones,
      monthsFullySorted: months
          .where((m) => m.total > 0 && m.sorted >= m.total)
          .length,
      gallerySorted:
          summary.total > 0 &&
          summary.sorted + summary.cartCount >= summary.total,
      unlocked: unlocked.keys.toSet(),
    ),
  );
});

/// Note les succès qui viennent d'être gagnés et les annonce : l'état est
/// la liste des derniers débloqués (vide sinon).
///
/// À la première ouverture après la mise à jour, ceux déjà mérités sont
/// inscrits sans annonce, pour ne pas en afficher dix d'un coup.
class AchievementWatcher extends Notifier<List<Achievement>> {
  static const _readyKey = '_achievements_ready';

  @override
  List<Achievement> build() {
    ref.listen(achievementsProvider, (_, next) {
      if (next != null) unawaited(_check(next));
    }, fireImmediately: true);
    return const [];
  }

  bool _busy = false;

  /// Déjà inscrits ou annoncés, le temps que le journal suive.
  final _handled = <String>{};

  /// Vrai une fois la première vérification faite (annonces permises).
  bool? _announcing;

  /// Un changement est arrivé pendant une vérification : on refait.
  bool _again = false;

  Future<void> _check(List<Achievement> all) async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      final progress = ref.read(progressRepositoryProvider);
      final ready = _announcing ??= (await progress.watchMilestones().first)
          .contains(_readyKey);
      final fresh = [
        for (final a in all)
          if (a.unlocked && !a.unlockedBefore && _handled.add(a.id)) a,
      ];
      if (fresh.isNotEmpty) await progress.unlock(fresh.map((a) => a.id));
      if (!ready) {
        await progress.recordMilestone(_readyKey);
        _announcing = true;
        return;
      }
      if (fresh.isNotEmpty && ref.mounted) state = fresh;
    } finally {
      _busy = false;
    }
    if (_again && ref.mounted) {
      _again = false;
      final latest = ref.read(achievementsProvider);
      if (latest != null) await _check(latest);
    }
  }

  /// Après l'annonce.
  void clear() => state = const [];
}

final achievementWatcherProvider =
    NotifierProvider<AchievementWatcher, List<Achievement>>(
      AchievementWatcher.new,
    );
