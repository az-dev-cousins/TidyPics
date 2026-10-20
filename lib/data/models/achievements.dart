/// Succès (V2, lot 13) : des paliers et des premières fois, calculés à partir
/// de ce que l'app sait déjà. Rien n'est envoyé nulle part.
enum AchievementCategory { freed, sorted, streak, firsts }

/// Premières fois enregistrées au moment où elles arrivent.
abstract final class Milestone {
  static const burstSorted = 'burst_sorted';
  static const duplicateDeleted = 'duplicate_deleted';
  static const rawSorted = 'raw_sorted';
}

/// Un succès : son identifiant stable, sa catégorie, son objectif et où on
/// en est.
class Achievement {
  const Achievement({
    required this.id,
    required this.category,
    required this.target,
    required this.current,
    this.unlockedBefore = false,
  });

  final String id;
  final AchievementCategory category;

  /// Objectif (octets, photos, jours) ; 1 pour une première fois.
  final int target;
  final int current;

  /// Déjà gagné plus tôt (un compteur a pu baisser depuis).
  final bool unlockedBefore;

  bool get unlocked => unlockedBefore || current >= target;

  double get progress =>
      unlocked ? 1 : (current / target).clamp(0, 1).toDouble();
}

/// Ce qu'il faut savoir pour calculer les succès.
class AchievementInputs {
  const AchievementInputs({
    this.freedBytes = 0,
    this.sortedPhotos = 0,
    this.activityDays = const [],
    this.milestones = const {},
    this.monthsFullySorted = 0,
    this.gallerySorted = false,
    this.unlocked = const {},
    this.today,
  });

  final int freedBytes;
  final int sortedPhotos;

  /// Jours de tri, au format AAAAMMJJ.
  final List<int> activityDays;
  final Set<String> milestones;
  final int monthsFullySorted;
  final bool gallerySorted;

  /// Identifiants déjà débloqués (journal).
  final Set<String> unlocked;
  final DateTime? today;
}

const _mb = 1000 * 1000;
const _gb = 1000 * _mb;

/// Paliers d'espace libéré, en octets.
const freedSteps = [100 * _mb, _gb, 5 * _gb, 20 * _gb];

/// Paliers de photos triées.
const sortedSteps = [100, 1000, 5000, 10000];

/// Séries de jours de tri d'affilée.
const streakSteps = [3, 7, 30];

/// Tous les succès, dans l'ordre d'affichage.
List<Achievement> computeAchievements(AchievementInputs inputs) {
  final best = bestStreak(inputs.activityDays);
  Achievement make(
    String id,
    AchievementCategory category,
    int target,
    int current,
  ) => Achievement(
    id: id,
    category: category,
    target: target,
    current: current,
    unlockedBefore: inputs.unlocked.contains(id),
  );

  int first(bool done) => done ? 1 : 0;
  return [
    for (final step in freedSteps)
      make('freed_$step', AchievementCategory.freed, step, inputs.freedBytes),
    for (final step in sortedSteps)
      make(
        'sorted_$step',
        AchievementCategory.sorted,
        step,
        inputs.sortedPhotos,
      ),
    for (final step in streakSteps)
      make('streak_$step', AchievementCategory.streak, step, best),
    make(
      'first_${Milestone.burstSorted}',
      AchievementCategory.firsts,
      1,
      first(inputs.milestones.contains(Milestone.burstSorted)),
    ),
    make(
      'first_${Milestone.duplicateDeleted}',
      AchievementCategory.firsts,
      1,
      first(inputs.milestones.contains(Milestone.duplicateDeleted)),
    ),
    make(
      'first_${Milestone.rawSorted}',
      AchievementCategory.firsts,
      1,
      first(inputs.milestones.contains(Milestone.rawSorted)),
    ),
    make(
      'first_month_done',
      AchievementCategory.firsts,
      1,
      first(inputs.monthsFullySorted > 0),
    ),
    make(
      'first_gallery_done',
      AchievementCategory.firsts,
      1,
      first(inputs.gallerySorted),
    ),
  ];
}

/// Plus longue série de jours consécutifs (jours au format AAAAMMJJ).
int bestStreak(List<int> days) {
  if (days.isEmpty) return 0;
  final dates = {
    for (final d in days) DateTime.utc(d ~/ 10000, d ~/ 100 % 100, d % 100),
  }.toList()..sort();
  var best = 1;
  var run = 1;
  for (var i = 1; i < dates.length; i++) {
    final gap = dates[i].difference(dates[i - 1]).inDays;
    run = gap == 1 ? run + 1 : 1;
    if (run > best) best = run;
  }
  return best;
}

/// Série en cours : jours d'affilée jusqu'à aujourd'hui (ou hier, si on n'a
/// pas encore trié aujourd'hui).
int currentStreak(List<int> days, DateTime today) {
  final set = days.toSet();
  int key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
  var day = DateTime(today.year, today.month, today.day);
  if (!set.contains(key(day))) {
    day = day.subtract(const Duration(days: 1));
  }
  var count = 0;
  while (set.contains(key(day))) {
    count++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return count;
}
