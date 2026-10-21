/// Rappels façon jeu (V2) : quand les envoyer et quoi dire. Logique pure,
/// sans plugin : facile à tester.
library;

/// Fréquence choisie par l'utilisateur.
enum ReminderMode { off, weekly, daily }

/// Moment de la journée choisi à l'onboarding, en heure locale.
/// L'heure précise s'adapte à celle où l'on ouvre le plus l'app dans ce
/// moment de la journée ([preferredHour]) ; [hour] sert tant qu'on ne sait
/// pas.
enum ReminderSlot {
  morning(8, 6, 11),
  afternoon(13, 12, 17),
  evening(19, 18, 22);

  const ReminderSlot(this.hour, this.first, this.last);

  /// Heure par défaut.
  final int hour;

  /// Heures (incluses) qui font partie de ce moment.
  final int first;
  final int last;

  /// L'heure la plus fréquente d'ouverture de l'app dans ce moment de la
  /// journée ([usage] : nombre d'ouvertures pour chaque heure, de 0 à 23).
  /// Au moins 3 ouvertures dans ce moment, sinon l'heure par défaut.
  int preferredHour(List<int> usage) {
    if (usage.length != 24) return hour;
    var total = 0;
    var best = hour;
    for (var h = first; h <= last; h++) {
      total += usage[h];
      final better = usage[h] > usage[best];
      // À égalité, la plus proche de l'heure par défaut.
      final tieCloser =
          usage[h] == usage[best] && (h - hour).abs() < (best - hour).abs();
      if (better || tieCloser) best = h;
    }
    return total >= 3 ? best : hour;
  }
}

/// Ce qu'on sait de la galerie et du joueur au moment de planifier.
class ReminderState {
  const ReminderState({
    required this.total,
    required this.sorted,
    this.streak = 0,
    this.sortedToday = false,
    this.newThisWeek = 0,
    this.nextStepTarget,
  });

  /// Photos et vidéos de la galerie, triées (décidées ou au panier).
  final int total;
  final int sorted;

  /// Jours de tri d'affilée jusqu'à aujourd'hui (ou hier).
  final int streak;
  final bool sortedToday;

  /// Photos prises ces 7 derniers jours.
  final int newThisWeek;

  /// Prochain palier « photos triées » (succès), s'il en reste un.
  final int? nextStepTarget;

  int get toSort => (total - sorted).clamp(0, total);

  /// Part triée, de 0 à 100.
  int get percent => total == 0 ? 100 : (sorted * 100 / total).floor();
}

/// Ce qui déclenche le message.
enum ReminderKind {
  /// Série en cours : ne pas la casser.
  streak,

  /// Série qui vient de s'arrêter : en relancer une.
  streakLost,

  /// Galerie rangée à X % : viser le palier suivant.
  progress,

  /// Plus que N photos pour le prochain succès.
  achievement,

  /// Défi du jour.
  challenge,

  /// Après plusieurs jours sans venir.
  comeBack,

  /// Presque tout est trié, mais beaucoup de photos cette semaine.
  bigWeek,
}

/// Une notification à programmer.
class PlannedReminder {
  const PlannedReminder({
    required this.at,
    required this.kind,
    required this.state,
    required this.daysAway,
  });

  final DateTime at;
  final ReminderKind kind;
  final ReminderState state;

  /// Jours depuis la dernière visite (1 = le lendemain).
  final int daysAway;

  /// Série encore en jeu ce jour-là (on n'est pas revenu entre-temps).
  int get streakAtThatDay => daysAway <= 1 ? state.streak : 0;
}

abstract final class ReminderRules {
  /// « Beaucoup de photos cette semaine » : un retour de vacances.
  static const bigWeekPhotos = 30;

  /// « Presque tout trié ».
  static const almostDonePercent = 90;

  /// Défi du jour, en photos.
  static const challengePhotos = 20;

  /// Quotidien : tous les jours tant qu'on revient, puis on espace.
  static const dailyDays = [1, 2, 3, 5, 7, 14];

  /// Hebdomadaire.
  static const weeklyDays = [7, 14, 28];
}

/// Les prochaines notifications, après [lastVisit], à l'heure de [slot].
///
/// - Rien si le rappel est coupé ou s'il n'y a rien à dire.
/// - Galerie triée à 90 % ou plus : seulement si l'on a pris au moins
///   30 photos cette semaine, une fois au plus.
/// - Sinon, un message différent à chaque fois : série, avancée, succès,
///   défi, puis « reviens » quand on ne vient plus.
List<PlannedReminder> planReminders({
  required ReminderMode mode,
  required ReminderSlot slot,
  required DateTime now,
  required DateTime lastVisit,
  required ReminderState state,
  List<int> usage = const [],
}) {
  final hour = slot.preferredHour(usage);
  if (mode == ReminderMode.off || state.total == 0) return const [];
  final days = mode == ReminderMode.daily
      ? ReminderRules.dailyDays
      : ReminderRules.weeklyDays;
  final visitDay = DateTime(lastVisit.year, lastVisit.month, lastVisit.day);
  final almostDone = state.percent >= ReminderRules.almostDonePercent;

  final planned = <PlannedReminder>[];
  for (final day in days) {
    final at = DateTime(
      visitDay.year,
      visitDay.month,
      visitDay.day + day,
      hour,
    );
    if (!at.isAfter(now)) continue;
    if (almostDone) {
      // Un seul rappel « grosse semaine », le plus tôt possible.
      if (state.newThisWeek >= ReminderRules.bigWeekPhotos &&
          state.toSort > 0) {
        planned.add(
          PlannedReminder(
            at: at,
            kind: ReminderKind.bigWeek,
            state: state,
            daysAway: day,
          ),
        );
      }
      break;
    }
    if (state.toSort == 0) break;
    planned.add(
      PlannedReminder(
        at: at,
        kind: _kindFor(day, planned.length, state),
        state: state,
        daysAway: day,
      ),
    );
  }
  return planned;
}

/// Le lendemain : la série d'abord. Ensuite, on varie. Après une semaine,
/// on invite à revenir.
ReminderKind _kindFor(int day, int index, ReminderState state) {
  if (day >= 7) return ReminderKind.comeBack;
  if (day == 1 && state.streak >= 2) return ReminderKind.streak;
  if (day == 2 && state.streak >= 2) return ReminderKind.streakLost;
  const rotation = [
    ReminderKind.progress,
    ReminderKind.challenge,
    ReminderKind.achievement,
  ];
  for (var i = 0; i < rotation.length; i++) {
    final kind = rotation[(index + i) % rotation.length];
    if (kind == ReminderKind.achievement && state.nextStepTarget == null) {
      continue;
    }
    return kind;
  }
  return ReminderKind.challenge;
}
