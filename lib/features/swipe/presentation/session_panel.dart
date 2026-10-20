import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';
import '../../gallery/application/gallery_controller.dart';
import '../application/swipe_session.dart';

/// Tablette en paysage (F1) : le panneau à droite de la carte, avec la
/// session en cours et le panier.
class SessionPanel extends ConsumerWidget {
  const SessionPanel({
    super.key,
    required this.state,
    required this.onOpenCart,
  });

  final SwipeState state;
  final VoidCallback onOpenCart;

  /// Taille à partir de laquelle le panneau s'affiche, en paysage. Un
  /// téléphone couché est trop bas : il garde la mise en page normale.
  static const minWidth = 840.0;
  static const minHeight = 480.0;
  static const width = 340.0;

  /// Miniatures du panier affichées au plus.
  static const _preview = 9;

  static bool fits(BoxConstraints constraints) =>
      constraints.maxWidth >= minWidth &&
      constraints.maxHeight >= minHeight &&
      constraints.maxWidth > constraints.maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final cart = ref.watch(cartProvider).value ?? const [];
    final bytes = cart.fold(0, (sum, e) => sum + e.sizeBytes);
    final left = state.nextCheckpointAt - state.sortedCount;
    // Panier trop grand : la dernière case annonce le reste.
    final overflow = cart.length > _preview;
    final shown = cart.take(overflow ? _preview - 1 : _preview).toList();
    final more = cart.length - shown.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(
          l10n.panelSession.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: tidy.inkMuted),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.swipeSorted(state.sortedCount),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: state.checkpointProgress,
            minHeight: 5,
            backgroundColor: tidy.line,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          state.cartCount > 0
              ? l10n.swipeCheckpointIn(left < 1 ? 1 : left)
              : l10n.panelCartHint,
          style: theme.textTheme.labelSmall?.copyWith(color: tidy.inkMuted),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Icon(Icons.delete_outline_rounded, size: 20, color: tidy.delete),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.homeCart, style: theme.textTheme.titleMedium),
            ),
            Text(
              cart.isEmpty
                  ? l10n.homeCartEmpty
                  : '${cart.length} · ${l10n.fileSize(bytes)}',
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shown.isNotEmpty) ...[
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final entry in shown)
                PhotoThumbnail(
                  key: ValueKey(entry.photo.id),
                  photo: entry.photo,
                  size: 160,
                ),
              if (overflow)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    border: Border.all(color: tidy.line),
                    borderRadius: BorderRadius.circular(
                      AppTheme.radiusThumbnail,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      l10n.panelMore(more),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onOpenCart,
            child: Text(l10n.panelOpenRecap),
          ),
        ],
      ],
    );
  }
}
