import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/trash_repository.dart';
import '../../../data/sources/gallery_source.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/charts.dart';
import '../../../shared/widgets/tidy_wordmark.dart';
import '../../cart/presentation/checkpoint_page.dart';
import '../../gallery/application/gallery_controller.dart';

/// Menu (F9), ouvert depuis le tri : l'espace libéré et sa courbe, le
/// stockage du téléphone, puis les accès rapides.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(librarySummaryProvider).value;
    final access = ref.watch(galleryAccessProvider).value;
    final trash = ref.watch(trashLogProvider).value ?? const [];
    final months = ref.watch(monthsProvider).value ?? const [];
    final pairs = ref.watch(rawPairsProvider).value ?? const [];

    void backToSorting() =>
        context.canPop() ? context.pop() : context.go(AppRoutes.swipe);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.homeSort,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: backToSorting,
        ),
        title: const TidyWordmark(fontSize: 26),
        actions: [
          IconButton(
            tooltip: l10n.homeSettings,
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            // Sur tablette, le contenu reste lisible au centre.
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                if (access == GalleryAccess.limited) ...[
                  _LimitedBanner(
                    onPressed: () => ref
                        .read(gallerySourceProvider)
                        .extendLimitedAccess()
                        .then(
                          (_) => ref.read(gallerySyncProvider.notifier).scan(),
                        ),
                  ),
                  const SizedBox(height: 16),
                ],
                const _FreedHero(),
                const SizedBox(height: 12),
                const _StorageCard(),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _Tile(
                      icon: Icons.delete_outline_rounded,
                      iconColor: TidyColors.of(context).delete,
                      title: l10n.homeCart,
                      subtitle: (summary?.cartCount ?? 0) == 0
                          ? l10n.homeCartEmpty
                          : l10n.fileSize(summary!.cartBytes),
                      badge: summary?.cartCount ?? 0,
                      onTap: () => context.push(
                        AppRoutes.checkpoint(CheckpointOrigin.home),
                      ),
                    ),
                    _Tile(
                      icon: Icons.calendar_month_outlined,
                      title: l10n.menuMonths,
                      subtitle: l10n.menuMonthsDetail(months.length),
                      onTap: () => context.push(AppRoutes.months),
                    ),
                    _Tile(
                      icon: Icons.filter_none_rounded,
                      title: l10n.swipeRawPairBadge,
                      subtitle: pairs.isEmpty
                          ? l10n.menuRawNone
                          : l10n.menuRawDetail(pairs.length),
                      onTap: () => context.push(AppRoutes.rawPairs),
                    ),
                    _Tile(
                      icon: Icons.restore_from_trash_outlined,
                      title: l10n.menuTrash,
                      subtitle: trash.isEmpty
                          ? l10n.homeTrashEmpty
                          : l10n.photoCount(trash.length),
                      onTap: () => context.push(AppRoutes.trash),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: backToSorting,
                  icon: const Icon(Icons.swipe_rounded),
                  label: Text(l10n.homeSort),
                ),
                const SizedBox(height: 20),
                _PrivacyNote(text: l10n.homePrivacyBody),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// En tête : l'espace libéré, sa courbe sur 8 semaines et deux chiffres.
/// Un tap ouvre les statistiques.
class _FreedHero extends ConsumerWidget {
  const _FreedHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final freed = ref.watch(freedStatsProvider).value ?? FreedStats.zero;
    final weeks = ref.watch(freedHistoryProvider(StatsPeriod.week)).value;
    final summary = ref.watch(librarySummaryProvider).value;
    final percent = ((summary?.progress ?? 0) * 100).round();

    // Cumul sur la fenêtre, à partir de ce qui était déjà libéré avant.
    final inWindow = weeks?.fold(0, (s, w) => s + w.bytes) ?? 0;
    var running = freed.bytes - inWindow;
    final cumulative = [
      for (final w in weeks ?? const <FreedBucket>[]) running += w.bytes,
    ];

    final onHero = scheme.onPrimary;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.stats),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.menuFreedLabel.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: onHero.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: onHero.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.fileSize(freed.bytes),
                style: theme.textTheme.displaySmall?.copyWith(color: onHero),
              ),
              const SizedBox(height: 12),
              if (cumulative.length > 1)
                FreedCurve(
                  values: cumulative,
                  semanticLabel: l10n.menuCurveLabel,
                  line: onHero,
                  fill: onHero.withValues(alpha: 0.14),
                  height: 72,
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroChip(text: l10n.menuSortedChip(percent), color: onHero),
                  _HeroChip(
                    text: l10n.menuDeletedChip(freed.photos),
                    color: onHero,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      ),
    );
  }
}

/// Stockage du téléphone, avec la part des photos.
class _StorageCard extends ConsumerWidget {
  const _StorageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final storage = ref.watch(deviceStorageProvider).value;
    if (storage == null) return const SizedBox.shrink();
    final photos = storage.photos;
    final segments = [
      if (photos != null) ...[
        StorageSegment(
          label: l10n.storagePhotos,
          bytes: photos,
          color: theme.colorScheme.primary,
        ),
        StorageSegment(
          label: l10n.storageOther,
          bytes: (storage.used - photos).clamp(0, storage.total),
          color: tidy.chartNeutral,
        ),
      ] else
        StorageSegment(
          label: l10n.storageUsed,
          bytes: storage.used,
          color: tidy.chartNeutral,
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    l10n.storageTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.storageFreeOf(
                    l10n.fileSize(storage.free),
                    l10n.fileSize(storage.total),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tidy.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            StorageBar(
              total: storage.total,
              segments: segments,
              freeLabel: l10n.storageFree,
              format: l10n.fileSize,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.badge = 0,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor ?? theme.colorScheme.primary),
                  const Spacer(),
                  if (badge > 0)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: tidy.delete,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Text(
                          '$badge',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onError,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tidy.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: tidy.inkMuted),
          ),
        ),
      ],
    );
  }
}

class _LimitedBanner extends StatelessWidget {
  const _LimitedBanner({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tidy = TidyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tidy.mint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.homeLimitedTitle, style: TextStyle(color: tidy.onMint)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onPressed,
                child: Text(l10n.homeLimitedAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
