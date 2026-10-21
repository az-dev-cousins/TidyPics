import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../data/models/achievements.dart';
import '../../../data/models/reminder_plan.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/sources/gallery_source.dart';
import '../../../l10n/app_localizations.dart';
import '../../achievements/presentation/achievement_texts.dart';
import '../../settings/application/settings_controller.dart';

/// Une notification prête : quand, titre, texte.
typedef ScheduledText = ({DateTime at, String title, String body});

/// Rappels (V2) : notifications locales programmées par le téléphone.
/// Rien ne passe par un serveur.
abstract interface class ReminderScheduler {
  /// Demande la permission de notifier (Android 13+, iOS). Vrai si accordée.
  Future<bool> requestPermission();

  /// Remplace les rappels prévus par ceux-ci.
  Future<void> scheduleAll(List<ScheduledText> reminders);

  Future<void> cancelAll();
}

class LocalReminderScheduler implements ReminderScheduler {
  /// Identifiants réservés aux rappels.
  static const _firstId = 100;
  static const _maxCount = 20;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // La permission n'est demandée qu'en activant les rappels.
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
  Future<void> scheduleAll(List<ScheduledText> reminders) async {
    await _init();
    await _cancelOurs();
    for (final (i, r) in reminders.take(_maxCount).indexed) {
      try {
        await _plugin.zonedSchedule(
          id: _firstId + i,
          // L'instant exact suffit : pas besoin de connaître le fuseau.
          scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
          title: r.title,
          body: r.body,
          // Pas d'heure exacte : aucune permission d'alarme à demander.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'sort_reminders',
              'Rappels de tri',
              importance: Importance.defaultImportance,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      } on Object catch (error) {
        debugPrint('Rappel impossible à programmer : $error');
      }
    }
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _cancelOurs();
  }

  Future<void> _cancelOurs() async {
    for (var i = 0; i < _maxCount; i++) {
      await _plugin.cancel(id: _firstId + i);
    }
    // Ancien rappel hebdomadaire (avant les rappels façon jeu).
    await _plugin.cancel(id: 1);
  }
}

/// Remplacé par un faux dans les tests.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => LocalReminderScheduler(),
);

/// Où en est l'utilisateur : lu dans la base et la galerie. Sert au premier
/// plan comme en tâche de fond (sans Riverpod).
Future<ReminderState> readReminderState({
  required LibraryRepository library,
  required ProgressRepository progress,
  required GallerySource gallery,
  DateTime? now,
}) async {
  final today = now ?? DateTime.now();
  final summary = await library.watchSummary().first;
  final days = await progress.watchActivityDays().first;
  final sortedTotal = await progress.watchSortedTotal().first;
  var newThisWeek = 0;
  try {
    newThisWeek = await gallery.countPhotosSince(
      today.subtract(const Duration(days: 7)),
    );
  } on Object catch (error) {
    debugPrint('Photos de la semaine illisibles : $error');
  }
  final todayKey = today.year * 10000 + today.month * 100 + today.day;
  return ReminderState(
    total: summary.total,
    sorted: summary.sorted + summary.cartCount,
    streak: currentStreak(days, today),
    sortedToday: days.contains(todayKey),
    newThisWeek: newThisWeek,
    nextStepTarget: sortedSteps.where((s) => s > sortedTotal).firstOrNull,
  );
}

/// Les notifications à programmer, avec leur texte.
List<ScheduledText> reminderTexts(
  AppLocalizations l10n,
  List<PlannedReminder> planned,
) => [
  for (final r in planned)
    switch (_texts(l10n, r)) {
      (final title, final body) => (at: r.at, title: title, body: body),
    },
];

(String, String) _texts(AppLocalizations l10n, PlannedReminder r) {
  final s = r.state;
  return switch (r.kind) {
    ReminderKind.streak => (
      l10n.notifStreakTitle(s.streak),
      l10n.notifStreakBody,
    ),
    ReminderKind.streakLost => (
      l10n.notifStreakLostTitle,
      l10n.notifStreakLostBody(s.streak),
    ),
    ReminderKind.progress => (
      l10n.notifProgressTitle(s.percent),
      l10n.notifProgressBody(
        // Prochaine dizaine (ou 100 %).
        ((s.percent ~/ 10) + 1).clamp(1, 10) * 10,
        s.toSort,
      ),
    ),
    ReminderKind.achievement => (
      l10n.notifAchievementTitle,
      l10n.notifAchievementBody(
        (s.nextStepTarget ?? 0) - s.sorted,
        l10n.achievementTitle(
          Achievement(
            id: 'sorted_${s.nextStepTarget}',
            category: AchievementCategory.sorted,
            target: s.nextStepTarget ?? 0,
            current: s.sorted,
          ),
        ),
      ),
    ),
    ReminderKind.challenge => (
      l10n.notifChallengeTitle,
      l10n.notifChallengeBody(ReminderRules.challengePhotos),
    ),
    ReminderKind.comeBack => (
      l10n.notifComeBackTitle,
      l10n.notifComeBackBody(s.toSort),
    ),
    ReminderKind.bigWeek => (
      l10n.notifBigWeekTitle,
      l10n.notifBigWeekBody(s.newThisWeek),
    ),
  };
}

/// Planifie et programme les rappels. Commun au premier plan et à la tâche
/// de fond.
Future<void> replanReminders({
  required AppSettings settings,
  required ReminderScheduler scheduler,
  required AppLocalizations l10n,
  required ReminderState state,
  DateTime? now,
}) async {
  if (settings.reminderMode == ReminderMode.off) {
    await scheduler.cancelAll();
    return;
  }
  final at = now ?? DateTime.now();
  final planned = planReminders(
    mode: settings.reminderMode,
    slot: settings.reminderSlot,
    now: at,
    lastVisit: settings.lastVisit ?? at,
    state: state,
    usage: settings.usageHours,
  );
  await scheduler.scheduleAll(reminderTexts(l10n, planned));
}

/// « Matin », « Après-midi », « Soir ».
String slotName(AppLocalizations l10n, ReminderSlot slot) => switch (slot) {
  ReminderSlot.morning => l10n.slotMorning,
  ReminderSlot.afternoon => l10n.slotAfternoon,
  ReminderSlot.evening => l10n.slotEvening,
};

/// Activer, couper et reprogrammer les rappels depuis l'app.
class ReminderActions {
  ReminderActions(this._ref);

  final Ref _ref;

  /// Reprogramme à partir de maintenant (en quittant l'app, ou après un
  /// changement de réglage).
  Future<void> replan(AppLocalizations l10n) async {
    final settings = _ref.read(settingsProvider);
    final scheduler = _ref.read(reminderSchedulerProvider);
    if (settings.reminderMode == ReminderMode.off) {
      await scheduler.cancelAll();
      return;
    }
    final state = await readReminderState(
      library: _ref.read(libraryRepositoryProvider),
      progress: _ref.read(progressRepositoryProvider),
      gallery: _ref.read(gallerySourceProvider),
    );
    await replanReminders(
      settings: _ref.read(settingsProvider),
      scheduler: scheduler,
      l10n: l10n,
      state: state,
    );
  }

  /// Choisit la fréquence et le moment. Faux si la permission est refusée
  /// (les rappels restent alors coupés).
  Future<bool> configure(
    AppLocalizations l10n, {
    required ReminderMode mode,
    ReminderSlot? slot,
  }) async {
    final settings = _ref.read(settingsProvider.notifier);
    if (mode != ReminderMode.off &&
        !await _ref.read(reminderSchedulerProvider).requestPermission()) {
      await settings.setReminder(ReminderMode.off, slot: slot);
      return false;
    }
    await settings.setReminder(mode, slot: slot);
    await replan(l10n);
    return true;
  }
}

final reminderActionsProvider = Provider<ReminderActions>(ReminderActions.new);
