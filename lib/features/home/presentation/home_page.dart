import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/providers.dart';
import '../../../data/sources/gallery_source.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/tidy_wordmark.dart';
import '../../cart/presentation/checkpoint_page.dart';
import '../../gallery/application/gallery_controller.dart';

/// Menu (F9) : gros chiffre, progression, retour au tri et accès rapides.
/// Ouvert depuis le tri, l'écran principal.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// Retour au tri, l'écran principal (toujours sous le menu).
  void _backToSorting() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.swipe);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final summary = ref.watch(librarySummaryProvider).value;
    final freed = ref.watch(freedStatsProvider).value;
    final sync = ref.watch(gallerySyncProvider);
    final access = ref.watch(galleryAccessProvider).value;
    final trash = ref.watch(trashLogProvider).value ?? const [];

    final total = summary?.total ?? 0;
    final unsorted = summary?.unsorted ?? 0;
    final scanning = sync == SyncStatus.idle || sync == SyncStatus.scanning;

    final String status;
    if (sync == SyncStatus.failed) {
      status = l10n.homeScanFailed;
    } else if (total == 0 && scanning) {
      status = l10n.homeScanning;
    } else if (total == 0) {
      status = l10n.homeNoPhotos;
    } else {
      status = l10n.homeProgress(total - unsorted, total);
    }

    return Scaffold(
      appBar: AppBar(
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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                const SizedBox(height: 24),
                Text(
                  freed == null || freed.bytes <= 0
                      ? l10n.homeFreedNone
                      : l10n.homeFreed(l10n.fileSize(freed.bytes)),
                  style: theme.textTheme.displaySmall,
                ),
                if (freed != null && freed.photos > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.homeFreedSubtitle(freed.photos),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: tidy.inkMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Text(status, style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: total == 0 && scanning
                        ? null
                        : summary?.progress ?? 0,
                    backgroundColor: tidy.line,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: unsorted > 0 ? _backToSorting : null,
                  icon: Icon(
                    unsorted > 0 || total == 0
                        ? Icons.swipe_rounded
                        : Icons.check_rounded,
                  ),
                  label: Text(
                    unsorted > 0 || total == 0
                        ? l10n.homeSort
                        : l10n.homeAllSorted,
                  ),
                ),
                const SizedBox(height: 28),
                _Tile(
                  icon: Icons.delete_outline_rounded,
                  title: l10n.homeCart,
                  subtitle: (summary?.cartCount ?? 0) == 0
                      ? l10n.homeCartEmpty
                      : l10n.homeCartDetail(
                          l10n.photoCount(summary!.cartCount),
                          l10n.fileSize(summary.cartBytes),
                        ),
                  badge: summary?.cartCount ?? 0,
                  onTap: () =>
                      context.push(AppRoutes.checkpoint(CheckpointOrigin.home)),
                ),
                const SizedBox(height: 12),
                _Tile(
                  icon: Icons.restore_from_trash_outlined,
                  title: l10n.homeTrash,
                  subtitle: trash.isEmpty
                      ? l10n.homeTrashEmpty
                      : l10n.photoCount(trash.length),
                  onTap: () => context.push(AppRoutes.trash),
                ),
                const SizedBox(height: 32),
                Row(
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
                        l10n.homePrivacyBody,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tidy.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    this.badge = 0,
  });

  final IconData icon;
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          backgroundColor: tidy.delete,
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle, style: TextStyle(color: tidy.inkMuted)),
        trailing: Icon(Icons.chevron_right_rounded, color: tidy.inkMuted),
        onTap: onTap,
      ),
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
