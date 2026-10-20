import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/trash_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/charts.dart';
import '../../gallery/application/gallery_controller.dart';

/// Statistiques (F7) : le total depuis l'installation, puis le détail par
/// semaine ou par mois (barres et cumul) et quelques chiffres clés.
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  StatsPeriod _period = StatsPeriod.week;

  String _label(AppLocalizations l10n, DateTime start) => switch (_period) {
    StatsPeriod.week => DateFormat.Md(l10n.localeName).format(start),
    StatsPeriod.month => DateFormat.MMM(l10n.localeName).format(start),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final scheme = theme.colorScheme;
    final freed = ref.watch(freedStatsProvider).value ?? FreedStats.zero;
    final buckets = ref.watch(freedHistoryProvider(_period)).value;
    final summary = ref.watch(librarySummaryProvider).value;
    final trash = ref.watch(trashLogProvider).value ?? const [];

    final values = [for (final b in buckets ?? const <FreedBucket>[]) b.bytes];
    final labels = [
      for (final b in buckets ?? const <FreedBucket>[]) _label(l10n, b.start),
    ];
    final inWindow = values.fold(0, (s, v) => s + v);
    var running = freed.bytes - inWindow;
    final cumulative = [for (final v in values) running += v];
    final best = values.isEmpty ? -1 : values.indexOf(values.reduce(math.max));
    final recoverable = trash.fold(0, (s, e) => s + (e.photo.sizeBytes ?? 0));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.statsSinceInstall.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.fileSize(freed.bytes),
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: scheme.onPrimary,
                          ),
                        ),
                        Text(
                          l10n.statsHeroDeleted(freed.photos),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<StatsPeriod>(
                  segments: [
                    ButtonSegment(
                      value: StatsPeriod.week,
                      label: Text(l10n.statsByWeek),
                    ),
                    ButtonSegment(
                      value: StatsPeriod.month,
                      label: Text(l10n.statsByMonth),
                    ),
                  ],
                  selected: {_period},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _period = s.first),
                ),
                const SizedBox(height: 16),
                if (buckets != null) ...[
                  _Section(
                    title: _period == StatsPeriod.week
                        ? l10n.statsFreedPerWeek
                        : l10n.statsFreedPerMonth,
                    child: PeriodBars(
                      key: ValueKey(_period),
                      values: values,
                      labels: labels,
                      format: l10n.fileSize,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: l10n.statsCumulative,
                    child: FreedCurve(
                      values: cumulative,
                      semanticLabel: l10n.statsCumulative,
                      line: scheme.primary,
                      fill: tidy.mint,
                      height: 120,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      _Row(
                        label: l10n.statsPhotosDeleted,
                        value: '${freed.photos}',
                      ),
                      const Divider(height: 1),
                      _Row(
                        label: l10n.statsPhotosSorted,
                        value:
                            '${(summary?.sorted ?? 0) + (summary?.cartCount ?? 0)}',
                      ),
                      if (best >= 0 && values[best] > 0) ...[
                        const Divider(height: 1),
                        _Row(
                          label: _period == StatsPeriod.week
                              ? l10n.statsBestWeek
                              : l10n.statsBestMonth,
                          value:
                              '${l10n.fileSize(values[best])} · ${labels[best]}',
                        ),
                      ],
                      const Divider(height: 1),
                      _Row(
                        label: l10n.statsRecoverable,
                        value: l10n.fileSize(recoverable),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.statsNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tidy.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
