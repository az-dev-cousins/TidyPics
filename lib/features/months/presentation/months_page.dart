import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';
import '../../gallery/application/gallery_controller.dart';

/// Tri ciblé par année et par mois (F2) : les années en haut, une carte par
/// mois avec sa photo et sa barre de complétion.
class MonthsPage extends ConsumerStatefulWidget {
  const MonthsPage({super.key});

  @override
  ConsumerState<MonthsPage> createState() => _MonthsPageState();
}

class _MonthsPageState extends ConsumerState<MonthsPage> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final months = ref.watch(monthsProvider).value;

    // Années dans l'ordre des mois (du plus récent au plus ancien).
    final years = {for (final m in months ?? const <MonthSummary>[]) m.year}
        .toList();
    final year = _year != null && years.contains(_year)
        ? _year!
        : years.firstOrNull;
    final shown = [
      for (final m in months ?? const <MonthSummary>[])
        if (m.year == year) m,
    ];
    final total = shown.fold(0, (s, m) => s + m.total);
    final sorted = shown.fold(0, (s, m) => s + m.sorted);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.monthsTitle)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: months == null
                ? const Center(child: CircularProgressIndicator())
                : months.isEmpty
                ? Center(
                    child: Text(
                      l10n.homeNoPhotos,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: tidy.inkMuted,
                      ),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 56,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                            scrollDirection: Axis.horizontal,
                            itemCount: years.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) => ChoiceChip(
                              label: Text('${years[i]}'),
                              selected: years[i] == year,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _year = years[i]),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$year',
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  textAlign: TextAlign.end,
                                  l10n.monthsYearSummary(
                                    total,
                                    total == 0
                                        ? 0
                                        : (sorted * 100 / total).round(),
                                  ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: tidy.inkMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.82,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _MonthTile(month: shown[i]),
                            childCount: shown.length,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            l10n.monthsHint,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tidy.inkMuted,
                            ),
                          ),
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

class _MonthTile extends ConsumerWidget {
  const _MonthTile({required this.month});

  final MonthSummary month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final scheme = theme.colorScheme;
    final images = ref.watch(photoImagesProvider);
    final cover = month.cover;
    final percent = (month.progress * 100).round();
    final name = l10n.monthShort(DateTime(month.year, month.month));

    return Semantics(
      button: true,
      label:
          '$name ${month.year} · ${l10n.photoCount(month.total)} · $percent %',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.month(month.year, month.month)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover != null)
                      Image(
                        image: images.thumbnail(cover, size: 360),
                        fit: BoxFit.cover,
                        errorBuilder: (context, _, _) =>
                            const PhotoPlaceholder(),
                      )
                    else
                      const PhotoPlaceholder(),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: month.isDone
                              ? scheme.primary
                              : scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (month.isDone) ...[
                                Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: scheme.onPrimary,
                                ),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                month.isDone
                                    ? l10n.monthsDone
                                    : l10n.percent(percent),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: month.isDone
                                      ? scheme.onPrimary
                                      : scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleSmall),
                    Text(
                      l10n.photoCount(month.total),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tidy.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: month.progress,
                        minHeight: 6,
                        backgroundColor: tidy.line,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
