import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../application/swipe_session.dart';

/// Construit une carte. [stamp] et [strength] indiquent le geste en cours,
/// pour afficher le tampon « Supprimer / Garder / Favori ».
typedef SwipeCardBuilder = Widget Function(
  BuildContext context, {
  required bool isCurrent,
  SwipeChoice? stamp,
  double strength,
});

/// La pile de cartes : la carte courante, que l'on fait glisser, et la
/// suivante juste derrière. Sert au tri et au tutoriel de l'onboarding.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.currentKey,
    required this.nextKey,
    required this.currentCard,
    required this.nextCard,
    required this.onSwiped,
    this.accepts,
    this.onRejected,
  });

  /// Identifie la carte courante : quand il change, la pile repart à zéro.
  final Object currentKey;
  final Object? nextKey;
  final SwipeCardBuilder currentCard;
  final WidgetBuilder? nextCard;

  /// Appelé une fois la carte partie de l'écran.
  final ValueChanged<SwipeChoice> onSwiped;

  /// Filtre les gestes permis (tutoriel). Par défaut, tous.
  final bool Function(SwipeChoice choice)? accepts;

  /// Un geste non permis a été tenté : la carte revient au centre.
  final ValueChanged<SwipeChoice>? onRejected;

  @override
  State<SwipeDeck> createState() => SwipeDeckState();
}

class SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onTick);

  Offset _offset = Offset.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  Size _size = Size.zero;
  bool _dragging = false;

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
  void didUpdateWidget(SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentKey == widget.currentKey) return;
    _controller.stop();
    _flying = null;
    _dragging = false;
    final from = _returning;
    _returning = null;
    if (from == null) {
      _offset = Offset.zero;
    } else {
      // Annulation : la carte revient de là où elle était partie.
      _spring(from: _target(from), to: Offset.zero);
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

  void _spring({
    required Offset from,
    required Offset to,
    double velocity = 0,
  }) {
    _from = from;
    _to = to;
    _offset = from;
    // Ressort souple, sans rebond excessif (direction artistique).
    const spring = SpringDescription(mass: 1, stiffness: 320, damping: 30);
    unawaited(
      _controller.animateWith(SpringSimulation(spring, 0, 1, velocity)),
    );
  }

  Offset _target(SwipeChoice choice, {double share = 1.5}) {
    final w = _size.width == 0 ? 400.0 : _size.width;
    final h = _size.height == 0 ? 800.0 : _size.height;
    return switch (choice) {
      SwipeChoice.trash => Offset(-w * share, _offset.dy),
      SwipeChoice.keep => Offset(w * share, _offset.dy),
      SwipeChoice.favorite => Offset(_offset.dx, -h * share * 0.93),
    };
  }

  bool _accepts(SwipeChoice choice) => widget.accepts?.call(choice) ?? true;

  /// Lance la carte, comme un geste (boutons et clavier).
  void swipe(SwipeChoice choice) {
    if (_flying != null) return;
    if (!_accepts(choice)) {
      widget.onRejected?.call(choice);
      return;
    }
    _fly(choice);
  }

  /// Prévient que la prochaine carte affichée revient d'une annulation.
  void prepareReturn(SwipeChoice choice) => _returning = choice;

  /// Esquisse le geste puis revient : montre quoi faire (tutoriel).
  Future<void> nudge(SwipeChoice choice) async {
    if (_flying != null || _dragging || _offset != Offset.zero) return;
    try {
      _from = Offset.zero;
      _to = _target(choice, share: 0.32);
      _controller.value = 0;
      await _controller
          .animateTo(
            1,
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted || _dragging || _flying != null) return;
      _from = _offset;
      _to = Offset.zero;
      _controller.value = 0;
      await _controller
          .animateTo(
            1,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
          )
          .orCancel;
    } on TickerCanceled {
      // L'utilisateur a pris la carte : on le laisse faire.
    }
  }

  void _fly(SwipeChoice choice) {
    _flying = choice;
    unawaited(HapticFeedback.selectionClick());
    _from = _offset;
    _to = _target(choice);
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
    final nextCard = widget.nextCard;
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
          // La carte et son ombre dépassent pendant le geste : pas de coupe.
          clipBehavior: Clip.none,
          children: [
            if (nextCard != null)
              Transform.scale(
                scale: 0.94 + 0.06 * progress,
                child: KeyedSubtree(
                  key: ValueKey(('next', widget.nextKey)),
                  child: nextCard(context),
                ),
              ),
            GestureDetector(
              onPanStart: (_) {
                if (_flying != null) return;
                _dragging = true;
                _controller.stop();
              },
              onPanUpdate: (details) {
                if (_flying != null) return;
                setState(() => _offset += details.delta);
              },
              onPanEnd: (details) {
                _dragging = false;
                if (_flying != null) return;
                final velocity = details.velocity.pixelsPerSecond;
                final choice = _choiceFor(_offset, velocity);
                if (choice != null && _accepts(choice)) {
                  _fly(choice);
                  return;
                }
                if (choice != null) widget.onRejected?.call(choice);
                _spring(
                  from: _offset,
                  to: Offset.zero,
                  velocity: velocity.distance / 1000,
                );
              },
              child: Transform.translate(
                offset: _offset,
                child: Transform.rotate(
                  angle: angle,
                  child: KeyedSubtree(
                    key: ValueKey(widget.currentKey),
                    child: widget.currentCard(
                      context,
                      isCurrent: true,
                      stamp: hint,
                      strength: strength,
                    ),
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
