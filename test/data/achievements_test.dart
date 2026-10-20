import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/models/achievements.dart';

void main() {
  Achievement byId(List<Achievement> all, String id) =>
      all.firstWhere((a) => a.id == id);

  test('paliers : débloqués selon les compteurs', () {
    final all = computeAchievements(
      const AchievementInputs(
        freedBytes: 1500 * 1000 * 1000,
        sortedPhotos: 120,
      ),
    );
    expect(byId(all, 'freed_${100 * 1000 * 1000}').unlocked, isTrue);
    expect(byId(all, 'freed_${1000 * 1000 * 1000}').unlocked, isTrue);
    expect(byId(all, 'freed_${5000 * 1000 * 1000}').unlocked, isFalse);
    expect(byId(all, 'sorted_100').unlocked, isTrue);
    expect(byId(all, 'sorted_1000').progress, closeTo(0.12, 0.001));
  });

  test('un succès gagné le reste, même si le compteur baisse', () {
    final all = computeAchievements(
      const AchievementInputs(unlocked: {'sorted_100'}),
    );
    expect(byId(all, 'sorted_100').unlocked, isTrue);
  });

  test('premières fois', () {
    final all = computeAchievements(
      const AchievementInputs(
        milestones: {Milestone.burstSorted},
        monthsFullySorted: 1,
      ),
    );
    expect(byId(all, 'first_burst_sorted').unlocked, isTrue);
    expect(byId(all, 'first_month_done').unlocked, isTrue);
    expect(byId(all, 'first_duplicate_deleted').unlocked, isFalse);
    expect(byId(all, 'first_gallery_done').unlocked, isFalse);
  });

  test('séries : la plus longue, et celle en cours', () {
    const days = [20261001, 20261002, 20261003, 20261010, 20261019, 20261020];
    expect(bestStreak(days), 3);
    expect(currentStreak(days, DateTime(2026, 10, 20, 18)), 2);
    // Pas encore trié aujourd'hui : la série d'hier compte encore.
    expect(currentStreak(days, DateTime(2026, 10, 21)), 2);
    expect(currentStreak(days, DateTime(2026, 10, 23)), 0);
    // Changement de mois.
    expect(bestStreak([20260930, 20261001]), 2);
  });
}
