import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../data/models/achievements.dart';
import '../features/achievements/application/achievements_controller.dart';
import '../features/achievements/presentation/achievement_texts.dart';
import '../features/cart/application/checkpoint_controller.dart';
import '../features/gallery/application/gallery_controller.dart';
import '../features/reminders/application/reminders.dart';
import '../features/settings/application/settings_controller.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';

class TidyPicsApp extends ConsumerStatefulWidget {
  const TidyPicsApp({super.key});

  @override
  ConsumerState<TidyPicsApp> createState() => _TidyPicsAppState();
}

class _TidyPicsAppState extends ConsumerState<TidyPicsApp> {
  // Au retour dans l'app : la permission a pu changer dans les réglages, et
  // des photos ont pu être prises ou supprimées ailleurs.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () async {
      unawaited(ref.read(settingsProvider.notifier).recordUsage());
      await ref.read(galleryAccessProvider.notifier).refresh();
      unawaited(ref.read(gallerySyncProvider.notifier).scan());
    },
    onHide: () {
      // Option Android 12+ : le panier part à la corbeille quand on quitte.
      unawaited(ref.read(checkpointActionsProvider).trashOnLeave());
      // Les rappels partent de cette visite.
      final context = _messenger.currentContext;
      if (context != null) {
        final l10n = AppLocalizations.of(context);
        unawaited(
          ref
              .read(settingsProvider.notifier)
              .markVisit()
              .then((_) => ref.read(reminderActionsProvider).replan(l10n)),
        );
      }
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // Démarre l'écoute.
    // L'indexation de la galerie démarre dès que l'accès est connu.
    // L'heure des rappels s'adapte aux ouvertures de l'app.
    // Pas pendant la construction du premier écran.
    unawaited(
      Future.microtask(ref.read(settingsProvider.notifier).recordUsage),
    );
    ref
      ..read(gallerySyncProvider)
      // Les empreintes visuelles (doublons) se calculent après chaque scan.
      ..read(visualHashProvider);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Pour annoncer un succès quel que soit l'écran ouvert.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  void _announce(List<Achievement> unlocked) {
    final messenger = _messenger.currentState;
    final context = _messenger.currentContext;
    if (unlocked.isEmpty || messenger == null || context == null) return;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    messenger.showSnackBar(
      SnackBar(
        persist: false,
        content: Row(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              color: theme.colorScheme.onInverseSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                unlocked.length == 1
                    ? l10n.achievementUnlocked(
                        l10n.achievementTitle(unlocked.single),
                      )
                    : l10n.achievementsUnlockedMany(unlocked.length),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: l10n.achievementSee,
          onPressed: () =>
              ref.read(routerProvider).push(AppRoutes.achievements),
        ),
      ),
    );
    ref.read(achievementWatcherProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(achievementWatcherProvider, (_, next) => _announce(next));
    return MaterialApp.router(
      scaffoldMessengerKey: _messenger,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(settingsProvider.select((s) => s.themeMode)),
      // Le français est la langue de référence et la langue par défaut.
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
