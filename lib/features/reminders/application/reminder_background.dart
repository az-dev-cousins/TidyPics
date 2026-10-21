import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../../data/models/reminder_plan.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/sources/gallery_source.dart';
import '../../../data/sources/local_db.dart';
import '../../../l10n/app_localizations.dart';
import 'reminders.dart';

/// Android : une fois par jour, le système réveille l'app quelques secondes
/// pour mettre à jour le texte des prochains rappels (« t'as pris 85 photos
/// cette semaine… »). Rien ne passe par le réseau.
abstract final class ReminderBackground {
  static const _task = 'tidypics.reminders.refresh';

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().initialize(reminderCallbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _task,
        _task,
        frequency: const Duration(hours: 12),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } on Object catch (error) {
      debugPrint('Tâche de fond des rappels impossible : $error');
    }
  }
}

@pragma('vm:entry-point')
void reminderCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final settings = (await SettingsRepository.open()).read();
    if (settings.reminderMode == ReminderMode.off) return true;
    final db = LocalDb();
    try {
      final state = await readReminderState(
        library: LibraryRepository(db),
        progress: ProgressRepository(db),
        gallery: PhotoManagerGallerySource(),
      );
      await replanReminders(
        settings: settings,
        scheduler: LocalReminderScheduler(),
        l10n: lookupAppLocalizations(_locale()),
        state: state,
      );
    } on Object catch (error) {
      debugPrint('Mise à jour des rappels impossible : $error');
    } finally {
      await db.close();
    }
    return true;
  });
}

/// La langue du téléphone si l'app la connaît, sinon le français.
Locale _locale() {
  final code = PlatformDispatcher.instance.locale.languageCode;
  return AppLocalizations.supportedLocales.any((l) => l.languageCode == code)
      ? Locale(code)
      : const Locale('fr');
}
