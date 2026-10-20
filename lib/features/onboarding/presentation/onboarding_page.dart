import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/tidy_wordmark.dart';
import '../../gallery/application/gallery_controller.dart';
import '../../settings/application/settings_controller.dart';
import 'swipe_tutorial.dart';

/// Onboarding en 3 écrans (F9) : le tutoriel du swipe, la vie privée, la
/// permission. On avance avec le bouton (pas de glissement de page : le
/// geste sert aux cartes du tutoriel).
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _pageCount = 3;
  static const _gutter = 24.0;

  final _pages = PageController();
  int _index = 0;
  bool _requesting = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _goTo(int index) async {
    setState(() => _index = index);
    await _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _next() async {
    if (_index < _pageCount - 1) {
      await _goTo(_index + 1);
      return;
    }
    setState(() => _requesting = true);
    // La redirection du routeur prend le relais : le tri si l'accès est
    // accordé, l'écran d'explication sinon.
    await ref.read(galleryAccessProvider.notifier).request();
    await ref.read(settingsProvider.notifier).completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tidy = TidyColors.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              // Pas de marge sur les côtés ici : les pages vont jusqu'au bord
              // de l'écran, pour que l'ombre et le geste des cartes ne soient
              // pas coupés. Chaque élément ajoute sa propre marge.
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: _gutter),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TidyWordmark(fontSize: 28),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final page in _pageContents(l10n, theme))
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _gutter,
                            ),
                            child: page,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pageCount; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? theme.colorScheme.primary
                                : tidy.line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _gutter),
                    child: FilledButton(
                      onPressed: _requesting ? null : _next,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(switch (_index) {
                          0 => l10n.onboardingSkipTutorial,
                          1 => l10n.actionNext,
                          _ => l10n.onboardingAccessButton,
                        }, key: ValueKey(_index)),
                      ),
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

  List<Widget> _pageContents(AppLocalizations l10n, ThemeData theme) => [
    _Entrance(
      active: _index == 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.onboardingSwipeTitle,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SwipeTutorial(
              onDone: () {
                if (_index == 0) unawaited(_goTo(1));
              },
            ),
          ),
        ],
      ),
    ),
    _Step(
      active: _index == 1,
      icon: Icons.verified_user_outlined,
      title: l10n.onboardingPrivacyTitle,
      body: l10n.onboardingPrivacyBody,
    ),
    _Step(
      active: _index == 2,
      icon: Icons.photo_library_outlined,
      title: l10n.onboardingAccessTitle,
      body: l10n.onboardingAccessBody,
    ),
  ];
}

/// Fait entrer le contenu en fondu et en glissant, quand la page s'affiche.
class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.active,
    required this.child,
    this.delay = Duration.zero,
  });

  final bool active;
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Rejoue l'animation à chaque fois que la page devient active.
      key: ValueKey(active),
      tween: Tween(begin: active ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 520) + delay,
      curve: Interval(
        delay.inMilliseconds / (520 + delay.inMilliseconds),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 24),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.active,
    required this.icon,
    required this.title,
    required this.body,
  });

  final bool active;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // L'icône arrive avec un léger rebond.
        TweenAnimationBuilder<double>(
          key: ValueKey(active),
          tween: Tween(begin: active ? 0.4 : 1, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (context, t, child) => Transform.scale(
            scale: t,
            alignment: Alignment.center,
            child: child,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: tidy.mint, shape: BoxShape.circle),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, size: 40, color: tidy.onMint),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _Entrance(
          active: active,
          delay: const Duration(milliseconds: 80),
          child: Text(title, style: theme.textTheme.headlineMedium),
        ),
        const SizedBox(height: 12),
        _Entrance(
          active: active,
          delay: const Duration(milliseconds: 160),
          child: Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(color: tidy.inkMuted),
          ),
        ),
      ],
    );
  }
}
