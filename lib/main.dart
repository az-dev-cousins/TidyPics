import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/providers.dart';
import 'data/repositories/settings_repository.dart';
import 'features/reminders/application/reminder_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Les réglages sont lus avant le premier écran : ils décident de la route
  // de départ (onboarding ou accueil) et du thème.
  final settings = await SettingsRepository.open();
  // Android : mise à jour quotidienne du texte des rappels.
  unawaited(ReminderBackground.start());
  runApp(
    ProviderScope(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
      child: const TidyPicsApp(),
    ),
  );
}
