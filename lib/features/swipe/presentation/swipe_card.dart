import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/gallery_photo.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';
import '../application/swipe_session.dart';

/// Cadre commun des cartes : image en haut, légende en bas, tampon pendant
/// le geste.
class SwipeCardFrame extends StatelessWidget {
  const SwipeCardFrame({
    super.key,
    required this.image,
    required this.caption,
    this.trailing = const [],
    this.stamp,
    this.strength = 0,
  });

  final Widget image;
  final String caption;
  final List<Widget> trailing;
  final SwipeChoice? stamp;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSwipeCard),
        border: Border.all(color: tidy.line),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSwipeCard),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    child: image,
                  ),
                  if (stamp != null && strength > 0)
                    SwipeStamp(choice: stamp!, strength: strength),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      caption,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tidy.inkMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  ...trailing,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'une photo de la galerie.
class PhotoSwipeCard extends ConsumerWidget {
  const PhotoSwipeCard({
    super.key,
    required this.photo,
    this.stamp,
    this.strength = 0,
  });

  final GalleryPhoto photo;
  final SwipeChoice? stamp;
  final double strength;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tidy = TidyColors.of(context);
    final images = ref.watch(photoImagesProvider);
    final size = photo.sizeBytes;
    final caption = [
      l10n.shortDate(photo.takenAt),
      if (size != null && size > 0) l10n.fileSize(size).toUpperCase(),
    ].join(' · ');

    return SwipeCardFrame(
      caption: caption,
      stamp: stamp,
      strength: strength,
      trailing: [
        if (photo.isRaw) _Badge(text: l10n.swipeRaw),
        if (photo.isFavorite) ...[
          const SizedBox(width: 8),
          Icon(Icons.star_rounded, color: tidy.favorite, size: 20),
        ],
      ],
      // La photo entière, sans recadrage : on juge mieux.
      image: Image(
        image: images.large(photo),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        semanticLabel: caption,
        errorBuilder: (context, _, _) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, color: tidy.inkMuted),
            const SizedBox(height: 8),
            Text(l10n.swipeImageError, style: TextStyle(color: tidy.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tidy = TidyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tidy.mint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: tidy.onMint),
        ),
      ),
    );
  }
}

/// Tampon « Supprimer / Garder / Favori » qui apparaît pendant le geste.
class SwipeStamp extends StatelessWidget {
  const SwipeStamp({super.key, required this.choice, required this.strength});

  final SwipeChoice choice;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final (icon, text, color, alignment) = switch (choice) {
      SwipeChoice.trash => (
        Icons.close_rounded,
        l10n.swipeTrash,
        tidy.delete,
        Alignment.topRight,
      ),
      SwipeChoice.keep => (
        Icons.check_rounded,
        l10n.swipeKeep,
        tidy.keep,
        Alignment.topLeft,
      ),
      SwipeChoice.favorite => (
        Icons.star_rounded,
        l10n.swipeFavorite,
        theme.colorScheme.onSurface,
        Alignment.bottomCenter,
      ),
    };
    final iconColor = choice == SwipeChoice.favorite ? tidy.favorite : color;

    return Opacity(
      opacity: strength,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    text.toUpperCase(),
                    // Texte neutre : pas de texte tomate en petite taille.
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
