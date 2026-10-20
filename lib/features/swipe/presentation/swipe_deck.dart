import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/gallery_photo.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';
import '../application/swipe_session.dart';

/// La pile de cartes : la photo courante, que l'on fait glisser, et la
/// suivante juste derrière (déjà chargée, donc jamais d'écran blanc).
class SwipeDeck extends ConsumerStatefulWidget {
  const SwipeDeck({
    super.key,
    required this.current,
    required this.next,
    required this.onSwiped,
  });

  final GalleryPhoto current;
  final GalleryPhoto? next;

  /// Appelé une fois la carte partie de l'écran.
  final ValueChanged<SwipeChoice> onSwiped;

  @override
  ConsumerState<SwipeDeck> createState() => SwipeDeckState();
}

class SwipeDeckState extends ConsumerState<SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onTick);

  Offset _offset = Offset.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  Size _size = Size.zero;

  /// La carte s'envole : les gestes sont ignorés jusqu'à la suivante.
  SwipeChoice? _flying;

  /// La prochaine carte arrivera de ce côté (après une annulation).
  SwipeChoice? _returning;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheNext();
  }

  /// Préchargement : la photo d'après est décodée avant d'être visible.
  void _precacheNext() {
    final next = widget.next;
    if (next == null) return;
    final images = ref.read(photoImagesProvider);
    unawaited(precacheImage(images.large(next), context, onError: (_, _) {}));
  }

  @override
  void didUpdateWidget(SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.next?.id != widget.next?.id) _precacheNext();
    if (oldWidget.current.id == widget.current.id) return;
    _controller.stop();
    _flying = null;
    final from = _returning;
    _returning = null;
    if (from == null) {
      _offset = Offset.zero;
    } else {
      // Annulation : la carte revient de là où elle était partie.
      _animate(from: _target(from), to: Offset.zero);
    }
  }

  void _onTick() {
    final t = _controller.value;
    setState(() => _offset = Offset.lerp(_from, _to, t)!);
    if (_flying != null && t >= 1) {
      final choice = _flying!;
      _controller.stop();
      widget.onSwiped(choice);
    }
  }

  void _animate({
    required Offset from,
    required Offset to,
    double velocity = 0,
  }) {
    _from = from;
    _to = to;
    _offset = from;
    // Ressort souple, sans rebond excessif (direction artistique).
    const spring = SpringDescription(mass: 1, stiffness: 320, damping: 30);
    _controller.animateWith(SpringSimulation(spring, 0, 1, velocity));
  }

  Offset _target(SwipeChoice choice) {
    final w = _size.width == 0 ? 400.0 : _size.width;
    final h = _size.height == 0 ? 800.0 : _size.height;
    return switch (choice) {
      SwipeChoice.trash => Offset(-w * 1.5, _offset.dy),
      SwipeChoice.keep => Offset(w * 1.5, _offset.dy),
      SwipeChoice.favorite => Offset(_offset.dx, -h * 1.4),
    };
  }

  /// Lance la carte, comme un geste (boutons et clavier).
  void swipe(SwipeChoice choice) {
    if (_flying != null) return;
    _fly(choice);
  }

  /// Prévient que la prochaine carte affichée revient d'une annulation.
  void prepareReturn(SwipeChoice choice) => _returning = choice;

  void _fly(SwipeChoice choice) {
    _flying = choice;
    unawaited(HapticFeedback.selectionClick());
    final target = _target(choice);
    _from = _offset;
    _to = target;
    // Pas de ressort pour l'envol : une courbe rapide suffit.
    _controller.value = 0;
    unawaited(
      _controller.animateTo(
        1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  SwipeChoice? _choiceFor(Offset offset, Offset velocity) {
    final w = _size.width;
    final h = _size.height;
    if (offset.dy < -h * 0.18 && offset.dy.abs() > offset.dx.abs() ||
        velocity.dy < -900 && velocity.dy.abs() > velocity.dx.abs()) {
      return SwipeChoice.favorite;
    }
    if (offset.dx > w * 0.28 || velocity.dx > 900) return SwipeChoice.keep;
    if (offset.dx < -w * 0.28 || velocity.dx < -900) return SwipeChoice.trash;
    return null;
  }

  /// Direction en cours et intensité (0 à 1), pour les tampons.
  (SwipeChoice?, double) get _hint {
    if (_size == Size.zero) return (null, 0);
    final dx = _offset.dx / (_size.width * 0.28);
    final dy = -_offset.dy / (_size.height * 0.18);
    if (dy > dx.abs() && dy > 0) {
      return (SwipeChoice.favorite, dy.clamp(0, 1).toDouble());
    }
    if (dx > 0) return (SwipeChoice.keep, dx.clamp(0, 1).toDouble());
    if (dx < 0) return (SwipeChoice.trash, (-dx).clamp(0, 1).toDouble());
    return (null, 0);
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.next;
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        final (hint, strength) = _hint;
        final progress = math
            .min(1, _offset.distance / (_size.width * 0.5))
            .toDouble();
        final angle = (_offset.dx / _size.width) * 0.25;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (next != null)
              Transform.scale(
                scale: 0.94 + 0.06 * progress,
                child: _PhotoCard(
                  key: ValueKey('next-${next.id}'),
                  photo: next,
                ),
              ),
            GestureDetector(
              onPanStart: (_) {
                if (_flying == null) _controller.stop();
              },
              onPanUpdate: (details) {
                if (_flying != null) return;
                setState(() => _offset += details.delta);
              },
              onPanEnd: (details) {
                if (_flying != null) return;
                final velocity = details.velocity.pixelsPerSecond;
                final choice = _choiceFor(_offset, velocity);
                if (choice == null) {
                  _animate(
                    from: _offset,
                    to: Offset.zero,
                    velocity: velocity.distance / 1000,
                  );
                } else {
                  _fly(choice);
                }
              },
              child: Transform.translate(
                offset: _offset,
                child: Transform.rotate(
                  angle: angle,
                  child: _PhotoCard(
                    key: ValueKey(widget.current.id),
                    photo: widget.current,
                    stamp: hint,
                    stampStrength: strength,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PhotoCard extends ConsumerWidget {
  const _PhotoCard({
    super.key,
    required this.photo,
    this.stamp,
    this.stampStrength = 0,
  });

  final GalleryPhoto photo;
  final SwipeChoice? stamp;
  final double stampStrength;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final images = ref.watch(photoImagesProvider);
    final size = photo.sizeBytes;
    final label = [
      l10n.shortDate(photo.takenAt),
      if (size != null && size > 0) l10n.fileSize(size).toUpperCase(),
    ].join(' · ');

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
                  // La photo entière, sans recadrage : on juge mieux.
                  ColoredBox(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    child: Image(
                      image: images.large(photo),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      semanticLabel: label,
                      errorBuilder: (context, _, _) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: tidy.inkMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.swipeImageError,
                            style: TextStyle(color: tidy.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (stamp != null && stampStrength > 0)
                    _Stamp(choice: stamp!, strength: stampStrength),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tidy.inkMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  if (photo.isRaw) _Badge(text: l10n.swipeRaw),
                  if (photo.isFavorite) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.star_rounded, color: tidy.favorite, size: 20),
                  ],
                ],
              ),
            ),
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
class _Stamp extends StatelessWidget {
  const _Stamp({required this.choice, required this.strength});

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
