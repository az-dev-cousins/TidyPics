import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/models/reminder_plan.dart';

void main() {
  final visit = DateTime(2026, 10, 21, 21, 30);
  final now = visit;

  List<PlannedReminder> plan(
    ReminderState state, {
    ReminderMode mode = ReminderMode.daily,
    ReminderSlot slot = ReminderSlot.evening,
  }) => planReminders(
    mode: mode,
    slot: slot,
    now: now,
    lastVisit: visit,
    state: state,
  );

  test('quotidien : tous les jours, puis de plus en plus espacé', () {
    final reminders = plan(const ReminderState(total: 1000, sorted: 100));
    expect(reminders.map((r) => r.at), [
      DateTime(2026, 10, 22, 19),
      DateTime(2026, 10, 23, 19),
      DateTime(2026, 10, 24, 19),
      DateTime(2026, 10, 26, 19),
      DateTime(2026, 10, 28, 19),
      DateTime(2026, 11, 4, 19),
    ]);
  });

  test("à l'heure choisie, et hebdomadaire si demandé", () {
    final reminders = plan(
      const ReminderState(total: 1000, sorted: 100),
      mode: ReminderMode.weekly,
      slot: ReminderSlot.morning,
    );
    expect(reminders.map((r) => r.at), [
      DateTime(2026, 10, 28, 8),
      DateTime(2026, 11, 4, 8),
      DateTime(2026, 11, 18, 8),
    ]);
  });

  test('coupé, ou galerie vide : rien', () {
    expect(
      plan(const ReminderState(total: 1000, sorted: 0), mode: ReminderMode.off),
      isEmpty,
    );
    expect(plan(const ReminderState(total: 0, sorted: 0)), isEmpty);
  });

  test('série en cours : le lendemain la garder, puis la relancer', () {
    final kinds = plan(const ReminderState(total: 1000, sorted: 300, streak: 4))
        .map((r) => r.kind);
    expect(kinds.take(2), [ReminderKind.streak, ReminderKind.streakLost]);
    expect(kinds.last, ReminderKind.comeBack);
  });

  test('sans série : on varie les messages', () {
    final kinds = plan(
      const ReminderState(total: 1000, sorted: 300, nextStepTarget: 1000),
    ).map((r) => r.kind).toList();
    expect(kinds.take(3).toSet(), {
      ReminderKind.progress,
      ReminderKind.challenge,
      ReminderKind.achievement,
    });
  });

  test('presque tout trié : rien, sauf après une grosse semaine', () {
    expect(plan(const ReminderState(total: 1000, sorted: 950)), isEmpty);
    final vacation = plan(
      const ReminderState(total: 1000, sorted: 950, newThisWeek: 85),
    );
    expect(vacation.single.kind, ReminderKind.bigWeek);
    expect(vacation.single.at, DateTime(2026, 10, 22, 19));
  });

  test("le créneau du jour n'est pas encore passé : il compte", () {
    final reminders = planReminders(
      mode: ReminderMode.daily,
      slot: ReminderSlot.evening,
      now: DateTime(2026, 10, 21, 10),
      lastVisit: DateTime(2026, 10, 20, 22),
      state: const ReminderState(total: 100, sorted: 10),
    );
    expect(reminders.first.at, DateTime(2026, 10, 21, 19));
  });

  group("l'heure s'adapte à l'habitude", () {
    List<int> usage(Map<int, int> counts) => [
      for (var h = 0; h < 24; h++) counts[h] ?? 0,
    ];

    test("l'heure la plus fréquente dans ce moment de la journée", () {
      // Ouvre souvent l'app vers 21 h, parfois à 9 h (hors du soir).
      final u = usage({21: 5, 20: 2, 9: 8});
      expect(ReminderSlot.evening.preferredHour(u), 21);
      expect(ReminderSlot.morning.preferredHour(u), 9);
    });

    test("pas assez d'ouvertures : l'heure par défaut", () {
      expect(ReminderSlot.evening.preferredHour(usage({22: 2})), 19);
      expect(ReminderSlot.afternoon.preferredHour(const []), 13);
    });

    test('à égalité, la plus proche de l\'heure par défaut', () {
      expect(ReminderSlot.evening.preferredHour(usage({18: 2, 22: 2})), 18);
    });

    test('les rappels tombent à cette heure', () {
      final reminders = planReminders(
        mode: ReminderMode.daily,
        slot: ReminderSlot.evening,
        now: now,
        lastVisit: visit,
        state: const ReminderState(total: 100, sorted: 10),
        usage: usage({21: 6}),
      );
      expect(reminders.first.at, DateTime(2026, 10, 22, 21));
    });
  });
}
