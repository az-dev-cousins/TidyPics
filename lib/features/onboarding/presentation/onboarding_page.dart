import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/tidy_wordmark.dart';
import '../../gallery/application/gallery_controller.dart';
import '../../settings/application/settings_controller.dart';

/// Onboarding en 3 écrans (F9) : le swipe, la vie privée, la permission.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pages = PageController();
  int _index = 0;
  bool _requesting = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index < 2) {
      await _pages.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() => _requesting = true);
    // La redirection du routeur prend le relais : accueil si l'accès est
    // accordé, écran d'explication sinon.
    await ref.read(galleryAccessProvider.notifier).request();
    await ref.read(settingsProvider.notifier).completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tidy = TidyColors.of(context);
    final steps = [
      (
        Icons.swipe_rounded,
        l10n.onboardingSwipeTitle,
        l10n.onboardingSwipeBody,
      ),
      (
        Icons.verified_user_outlined,
        l10n.onboardingPrivacyTitle,
        l10n.onboardingPrivacyBody,
      ),
      (
        Icons.photo_library_outlined,
        l10n.onboardingAccessTitle,
        l10n.onboardingAccessBody,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: TidyWordmark(fontSize: 28),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      onPageChanged: (i) => setState(() => _index = i),
                      children: [
                        for (final (icon, title, body) in steps)
                          _Step(icon: icon, title: title, body: body),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? Theme.of(context).colorScheme.primary
                                : tidy.line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _requesting ? null : _next,
                    child: Text(
                      _index < 2
                          ? l10n.actionNext
                          : l10n.onboardingAccessButton,
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

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.body});

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
        DecoratedBox(
          decoration: BoxDecoration(color: tidy.mint, shape: BoxShape.circle),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Icon(icon, size: 40, color: tidy.onMint),
          ),
        ),
        const SizedBox(height: 28),
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          body,
          style: theme.textTheme.bodyLarge?.copyWith(color: tidy.inkMuted),
        ),
      ],
    );
  }
}
