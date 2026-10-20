import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/application/settings_controller.dart';

/// Rappels (V2, lot 13) : une notification locale par semaine, facultative.
/// Rien ne passe par un serveur : c'est le téléphone qui la programme.
abstract interface class ReminderScheduler {
  /// Demande la permission de notifier (Android 13+, iOS). Vrai si accordée.
  Future<bool> requestPermission();

  /// Programme le rappel une semaine après maintenant, puis chaque semaine.
  /// Le remplace s'il existe déjà.
  Future<void> scheduleWeekly({required String title, required String body});

  Future<void> cancel();
}

class LocalReminderScheduler implements ReminderScheduler {
  static const _id = 1;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // La permission n'est demandée qu'en activant le rappel.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true) ??
        false;
  }

  @override
  Future<void> scheduleWeekly({
    required String title,
    required String body,
  }) async {
    await _init();
    await _plugin.cancel(id: _id);
    try {
      await _plugin.periodicallyShow(
        id: _id,
        repeatInterval: RepeatInterval.weekly,
        title: title,
        body: body,
        // Pas d'heure exacte : aucune permission d'alarme à demander.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'weekly_reminder',
            'Rappel de tri',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } on Object catch (error) {
      debugPrint('Rappel impossible à programmer : $error');
    }
  }

  @override
  Future<void> cancel() async {
    await _init();
    await _plugin.cancel(id: _id);
  }
}

/// Remplacé par un faux dans les tests.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => LocalReminderScheduler(),
);

/// Activer, couper et reprogrammer le rappel.
class ReminderActions {
  ReminderActions(this._ref);

  final Ref _ref;

  ReminderScheduler get _scheduler => _ref.read(reminderSchedulerProvider);

  /// Reprogramme le rappel avec le nombre de photos à trier du moment : il
  /// tombera une semaine après la dernière visite. Rien à trier : pas de
  /// rappel.
  Future<void> reschedule(AppLocalizations l10n) async {
    if (!_ref.read(settingsProvider).weeklyReminder) return;
    final scheduler = _scheduler;
    final summary = await _ref
        .read(libraryRepositoryProvider)
        .watchSummary()
        .first;
    final toSort = summary.total - summary.sorted - summary.cartCount;
    if (toSort <= 0) {
      await scheduler.cancel();
      return;
    }
    await scheduler.scheduleWeekly(
      title: l10n.reminderTitle,
      body: l10n.reminderBody(toSort),
    );
  }

  /// Active ou coupe le rappel. Faux si la permission est refusée.
  Future<bool> setEnabled(
    AppLocalizations l10n, {
    required bool enabled,
  }) async {
    final scheduler = _scheduler;
    final settings = _ref.read(settingsProvider.notifier);
    if (!enabled) {
      await settings.setWeeklyReminder(false);
      await scheduler.cancel();
      return true;
    }
    if (!await scheduler.requestPermission()) return false;
    await settings.setWeeklyReminder(true);
    await reschedule(l10n);
    return true;
  }
}

final reminderActionsProvider = Provider<ReminderActions>(ReminderActions.new);
