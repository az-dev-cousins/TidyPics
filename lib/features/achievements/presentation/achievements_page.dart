import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/achievements.dart';
import '../../../l10n/app_localizations.dart';
import '../application/achievements_controller.dart';
import 'achievement_texts.dart';

/// Succès (V2) : paliers et premières fois, avec l'avancée de chacun.
class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final all = ref.watch(achievementsProvider);
    final dates = ref.watch(unlockedAchievementsProvider).value ?? const {};
    final days = ref.watch(activityDaysProvider).value ?? const [];
    final done = all?.where((a) => a.unlocked).length ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.achievementsTitle)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: all == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: tidy.hero,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.emoji_events_outlined,
                                color: tidy.onHero,
                                size: 40,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.achievementsCount(done, all.length),
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(color: tidy.onHero),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.achievementsStreak(
                                        currentStreak(days, DateTime.now()),
                                      ),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: tidy.onHero.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      for (final category in AchievementCategory.values) ...[
                        const SizedBox(height: 20),
                        Text(
                          l10n.achievementCategory(category).toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tidy.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              for (final (i, a)
                                  in all
                                      .where((a) => a.category == category)
                                      .indexed) ...[
                                if (i > 0) const Divider(height: 1),
                                _AchievementRow(
                                  achievement: a,
                                  unlockedAt: dates[a.id],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.achievement, this.unlockedAt});

  final Achievement achievement;
  final DateTime? unlockedAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final a = achievement;
    final progress = l10n.achievementProgress(a);
    final date = unlockedAt;

    return Semantics(
      label: [
        l10n.achievementTitle(a),
        l10n.achievementDetail(a),
        if (a.unlocked && date != null)
          l10n.achievementUnlockedOn(
            DateFormat.yMMMd(l10n.localeName).format(date),
          )
        else
          ?progress,
      ].join(' · '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: a.unlocked ? tidy.mint : tidy.line.withValues(alpha: .5),
              ),
              child: Icon(
                achievementIcon(a),
                color: a.unlocked ? tidy.onMint : tidy.inkMuted,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.achievementTitle(a),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: a.unlocked ? null : tidy.inkMuted,
                    ),
                  ),
                  Text(
                    a.unlocked && date != null
                        ? l10n.achievementUnlockedOn(
                            DateFormat.yMMMd(l10n.localeName).format(date),
                          )
                        : l10n.achievementDetail(a),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tidy.inkMuted,
                    ),
                  ),
                  if (!a.unlocked && progress != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: a.progress,
                              minHeight: 5,
                              backgroundColor: tidy.line,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(progress, style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (a.unlocked) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, color: tidy.keep, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
