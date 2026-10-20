import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/providers.dart';
import 'data/repositories/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Les réglages sont lus avant le premier écran : ils décident de la route
  // de départ (onboarding ou accueil) et du thème.
  final settings = await SettingsRepository.open();
  runApp(
    ProviderScope(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
      child: const TidyPicsApp(),
    ),
  );
}
