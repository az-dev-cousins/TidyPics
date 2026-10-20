import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../swipe/application/swipe_session.dart';
import '../../swipe/presentation/swipe_card.dart';
import '../../swipe/presentation/swipe_deck.dart';

/// Tutoriel de l'onboarding : trois photos d'exemple, un geste chacune.
///
/// La carte esquisse le geste attendu tant que l'utilisateur ne l'a pas
/// fait. Un mauvais geste ramène la carte au centre.
class SwipeTutorial extends StatefulWidget {
  const SwipeTutorial({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SwipeTutorial> createState() => _SwipeTutorialState();
}

class _SwipeTutorialState extends State<SwipeTutorial> {
  static const _steps = [
    (SwipeChoice.trash, SampleScene.blurry),
    (SwipeChoice.keep, SampleScene.hike),
    (SwipeChoice.favorite, SampleScene.sunset),
  ];

  final _deck = GlobalKey<SwipeDeckState>();
  int _index = 0;
  int _mistakes = 0;
  Timer? _nudges;

  bool get _done => _index >= _steps.length;

  @override
  void initState() {
    super.initState();
    _scheduleNudges();
  }

  @override
  void dispose() {
    _nudges?.cancel();
    super.dispose();
  }

  void _scheduleNudges({Duration first = const Duration(milliseconds: 900)}) {
    _nudges?.cancel();
    if (_done) return;
    _nudges = Timer(first, () {
      if (!mounted || _done) return;
      unawaited(_deck.currentState?.nudge(_steps[_index].$1));
      _scheduleNudges(first: const Duration(milliseconds: 2600));
    });
  }

  void _onSwiped(SwipeChoice choice) {
    setState(() => _index++);
    if (_done) {
      _nudges?.cancel();
      unawaited(HapticFeedback.mediumImpact());
      Timer(const Duration(milliseconds: 1100), () {
        if (mounted) widget.onDone();
      });
    } else {
      _scheduleNudges();
    }
  }

  void _onRejected(SwipeChoice choice) {
    unawaited(HapticFeedback.heavyImpact());
    setState(() => _mistakes++);
    _scheduleNudges(first: const Duration(milliseconds: 500));
  }

  String _prompt(AppLocalizations l10n) {
    if (_done) return l10n.tutorialDone;
    return switch (_steps[_index].$1) {
      SwipeChoice.trash => l10n.tutorialTrash,
      SwipeChoice.keep => l10n.tutorialKeep,
      SwipeChoice.favorite => l10n.tutorialFavorite,
    };
  }

  String _caption(AppLocalizations l10n, SampleScene scene) => switch (scene) {
    SampleScene.blurry => l10n.tutorialBlurryCaption,
    SampleScene.hike => l10n.tutorialHikeCaption,
    SampleScene.sunset => l10n.tutorialSunsetCaption,
  };

  Widget _card(
    BuildContext context,
    SampleScene scene, {
    SwipeChoice? stamp,
    double strength = 0,
  }) {
    final l10n = AppLocalizations.of(context);
    return SwipeCardFrame(
      image: SampleSceneView(scene: scene),
      caption: _caption(l10n, scene).toUpperCase(),
      stamp: stamp,
      strength: strength,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Petite secousse à chaque mauvais geste.
        TweenAnimationBuilder<double>(
          key: ValueKey(_mistakes),
          tween: Tween(begin: _mistakes == 0 ? 1 : 0, end: 1),
          duration: const Duration(milliseconds: 420),
          builder: (context, t, child) => Transform.translate(
            offset: Offset(math.sin(t * math.pi * 4) * (1 - t) * 10, 0),
            child: child,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              _prompt(l10n),
              key: ValueKey(_index),
              style: theme.textTheme.bodyLarge?.copyWith(color: tidy.inkMuted),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _StepDots(count: _steps.length, done: _index),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            // Place pour l'ombre de la carte, sous elle.
            padding: const EdgeInsets.only(bottom: 36),
            child: Center(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: _done
                    ? const _Bravo()
                    : SwipeDeck(
                        key: _deck,
                        currentKey: _index,
                        nextKey: _index + 1 < _steps.length ? _index + 1 : null,
                        currentCard:
                            (
                              context, {
                              required isCurrent,
                              stamp,
                              strength = 0,
                            }) => _card(
                              context,
                              _steps[_index].$2,
                              stamp: stamp,
                              strength: strength,
                            ),
                        nextCard: _index + 1 < _steps.length
                            ? (context) => _card(context, _steps[_index + 1].$2)
                            : null,
                        accepts: (choice) => choice == _steps[_index].$1,
                        onRejected: _onRejected,
                        onSwiped: _onSwiped,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Trois pastilles : ✕, ✓, ★, cochées au fur et à mesure.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.done});

  final int count;
  final int done;

  @override
  Widget build(BuildContext context) {
    final tidy = TidyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    const icons = [
      Icons.close_rounded,
      Icons.check_rounded,
      Icons.star_rounded,
    ];
    final colors = [tidy.delete, tidy.keep, tidy.favorite];
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? tidy.mint : scheme.surfaceContainer,
              border: Border.all(
                color: i == done ? colors[i] : tidy.line,
                width: i == done ? 2 : 1,
              ),
            ),
            child: Icon(
              i < done ? Icons.done_rounded : icons[i],
              size: 18,
              color: i < done ? tidy.onMint : colors[i],
            ),
          ),
          if (i < count - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _Bravo extends StatelessWidget {
  const _Bravo();

  @override
  Widget build(BuildContext context) {
    final tidy = TidyColors.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(color: tidy.mint, shape: BoxShape.circle),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Icon(
              Icons.celebration_rounded,
              size: 56,
              color: tidy.onMint,
            ),
          ),
        ),
      ),
    );
  }
}

/// Les photos d'exemple du tutoriel, dessinées par l'app.
enum SampleScene { blurry, hike, sunset }

/// Dessine une photo d'exemple (paysage simple, dans l'esprit du logo).
class SampleSceneView extends StatelessWidget {
  const SampleSceneView({super.key, required this.scene});

  final SampleScene scene;

  @override
  Widget build(BuildContext context) {
    final painting = CustomPaint(
      painter: _ScenePainter(scene),
      child: const SizedBox.expand(),
    );
    if (scene != SampleScene.blurry) return painting;
    // Photo ratée : floue et un peu de travers.
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: Transform.scale(
          scale: 1.15,
          child: Transform.rotate(angle: 0.06, child: painting),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene);

  final SampleScene scene;

  // Couleurs des illustrations : c'est le contenu des photos d'exemple, pas
  // l'interface, d'où des valeurs fixes.
  static const _palettes = {
    SampleScene.blurry: [
      Color(0xFFB9C4C9),
      Color(0xFFE8E2D0),
      Color(0xFF7E8F86),
      Color(0xFF5F6F68),
    ],
    SampleScene.hike: [
      Color(0xFF9CD3E8),
      Color(0xFFFFE9A8),
      Color(0xFF6FBF8E),
      Color(0xFF2F7D5B),
    ],
    SampleScene.sunset: [
      Color(0xFFF7A97B),
      Color(0xFFFFE3A3),
      Color(0xFFC0607A),
      Color(0xFF6E3B5C),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final [sky, sun, far, near] = _palettes[scene]!;
    final w = size.width;
    final h = size.height;

    final skyPaint = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
        sky,
        Color.lerp(sky, sun, 0.55)!,
      ]);
    canvas.drawRect(Offset.zero & size, skyPaint);

    final sunCenter = scene == SampleScene.sunset
        ? Offset(w * 0.5, h * 0.58)
        : Offset(w * 0.72, h * 0.24);
    canvas.drawCircle(sunCenter, w * 0.13, Paint()..color = sun);

    final farHill = Path()
      ..moveTo(0, h * 0.62)
      ..quadraticBezierTo(w * 0.3, h * 0.46, w * 0.62, h * 0.6)
      ..quadraticBezierTo(w * 0.85, h * 0.7, w, h * 0.56)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(farHill, Paint()..color = far);

    final nearHill = Path()
      ..moveTo(0, h * 0.8)
      ..quadraticBezierTo(w * 0.45, h * 0.62, w, h * 0.82)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(nearHill, Paint()..color = near);

    if (scene == SampleScene.hike) {
      // Un petit sentier qui serpente.
      final trail = Path()
        ..moveTo(w * 0.42, h)
        ..quadraticBezierTo(w * 0.56, h * 0.88, w * 0.48, h * 0.78)
        ..quadraticBezierTo(w * 0.42, h * 0.72, w * 0.56, h * 0.66);
      canvas.drawPath(
        trail,
        Paint()
          ..color = sun.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.025
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) => oldDelegate.scene != scene;
}
