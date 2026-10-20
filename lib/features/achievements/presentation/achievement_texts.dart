import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/achievements.dart';
import '../../../l10n/app_localizations.dart';

/// Titre, détail, icône et avancée d'un succès, dans la langue de l'app.
extension AchievementTexts on AppLocalizations {
  String achievementTitle(Achievement a) => switch (a.category) {
    AchievementCategory.freed => switch (freedSteps.indexOf(a.target)) {
      0 => achFreedTitle0,
      1 => achFreedTitle1,
      2 => achFreedTitle2,
      _ => achFreedTitle3,
    },
    AchievementCategory.sorted => switch (sortedSteps.indexOf(a.target)) {
      0 => achSortedTitle0,
      1 => achSortedTitle1,
      2 => achSortedTitle2,
      _ => achSortedTitle3,
    },
    AchievementCategory.streak => switch (streakSteps.indexOf(a.target)) {
      0 => achStreakTitle0,
      1 => achStreakTitle1,
      _ => achStreakTitle2,
    },
    AchievementCategory.firsts => switch (a.id) {
      'first_${Milestone.burstSorted}' => achBurstTitle,
      'first_${Milestone.duplicateDeleted}' => achDuplicateTitle,
      'first_${Milestone.rawSorted}' => achRawTitle,
      'first_month_done' => achMonthTitle,
      _ => achGalleryTitle,
    },
  };

  String achievementDetail(Achievement a) => switch (a.category) {
    AchievementCategory.freed => achFreedDetail(fileSize(a.target)),
    AchievementCategory.sorted => achSortedDetail(a.target),
    AchievementCategory.streak => achStreakDetail(a.target),
    AchievementCategory.firsts => switch (a.id) {
      'first_${Milestone.burstSorted}' => achBurstDetail,
      'first_${Milestone.duplicateDeleted}' => achDuplicateDetail,
      'first_${Milestone.rawSorted}' => achRawDetail,
      'first_month_done' => achMonthDetail,
      _ => achGalleryDetail,
    },
  };

  /// « 450 Mo / 1 Go », « 120 / 1 000 », « 2 / 3 jours » ; rien pour une
  /// première fois.
  String? achievementProgress(Achievement a) {
    final number = NumberFormat.decimalPattern(localeName);
    return switch (a.category) {
      AchievementCategory.freed => achProgress(
        fileSize(a.current.clamp(0, a.target)),
        fileSize(a.target),
      ),
      AchievementCategory.sorted => achProgress(
        number.format(a.current.clamp(0, a.target)),
        number.format(a.target),
      ),
      AchievementCategory.streak => achProgress(
        number.format(a.current.clamp(0, a.target)),
        achDays(a.target),
      ),
      AchievementCategory.firsts => null,
    };
  }

  String achievementCategory(AchievementCategory c) => switch (c) {
    AchievementCategory.freed => achievementsFreed,
    AchievementCategory.sorted => achievementsSorted,
    AchievementCategory.streak => achievementsStreaks,
    AchievementCategory.firsts => achievementsFirsts,
  };
}

IconData achievementIcon(Achievement a) => switch (a.category) {
  AchievementCategory.freed => Icons.cleaning_services_outlined,
  AchievementCategory.sorted => Icons.swipe_outlined,
  AchievementCategory.streak => Icons.local_fire_department_outlined,
  AchievementCategory.firsts => switch (a.id) {
    'first_${Milestone.burstSorted}' => Icons.burst_mode_outlined,
    'first_${Milestone.duplicateDeleted}' => Icons.copy_all_rounded,
    'first_${Milestone.rawSorted}' => Icons.filter_none_rounded,
    'first_month_done' => Icons.calendar_month_outlined,
    _ => Icons.verified_outlined,
  },
};
