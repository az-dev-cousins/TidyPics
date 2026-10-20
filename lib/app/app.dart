import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/cart/application/checkpoint_controller.dart';
import '../features/gallery/application/gallery_controller.dart';
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
      await ref.read(galleryAccessProvider.notifier).refresh();
      unawaited(ref.read(gallerySyncProvider.notifier).scan());
    },
    // Option Android 12+ : le panier part à la corbeille quand on quitte.
    onHide: () => unawaited(ref.read(checkpointActionsProvider).trashOnLeave()),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // Démarre l'écoute.
    // L'indexation de la galerie démarre dès que l'accès est connu.
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
