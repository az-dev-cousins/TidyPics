import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder_plan.dart';
import 'library_repository.dart';

/// Réglages de l'app (F8), stockés avec `shared_preferences`.
@immutable
class AppSettings {
  const AppSettings({
    this.onboardingDone = false,
    this.sortOrder = SortOrder.random,
    this.checkpointThreshold = 25,
    this.manageMediaAsked = false,
    this.themeMode = ThemeMode.system,
    this.groupBursts = true,
    this.burstGapSeconds = 3,
    this.autoTrashOnLeave = false,
    this.deleteDirectly = false,
    this.rawIntroSeen = false,
    this.burstIntroSeen = false,
    this.reminderMode = ReminderMode.off,
    this.reminderSlot = ReminderSlot.evening,
    this.lastVisit,
    this.usageHours = const [],
    this.similarBursts = true,
  });

  final bool onboardingDone;
  final SortOrder sortOrder;

  /// Nombre de photos triées entre deux récaps (s'il y a des photos au
  /// panier).
  final int checkpointThreshold;

  /// « Gestion des médias » déjà proposée une fois (Android 12+).
  final bool manageMediaAsked;
  final ThemeMode themeMode;

  /// Rafales (F5) : regroupement et écart maximum entre deux photos.
  final bool groupBursts;
  final int burstGapSeconds;

  /// Android 12+ avec « Gestion des médias » : le panier part à la corbeille
  /// quand on quitte l'app (F3).
  final bool autoTrashOnLeave;

  /// Android, option avancée : effacer pour de bon au récap, sans corbeille.
  final bool deleteDirectly;

  /// Explication du tri des RAW déjà vue.
  final bool rawIntroSeen;

  /// Explication du tri d'une rafale déjà vue.
  final bool burstIntroSeen;

  /// Rappels par notification locale (coupés par défaut), à l'heure du
  /// créneau choisi à l'onboarding.
  final ReminderMode reminderMode;
  final ReminderSlot reminderSlot;

  /// Dernière ouverture de l'app : les rappels partent de là.
  final DateTime? lastVisit;

  /// Ouvertures de l'app par heure (24 nombres) : l'heure des rappels
  /// s'adapte à l'habitude.
  final List<int> usageHours;

  /// Test : des photos semblables jusqu'à 2 min d'écart forment aussi une
  /// rafale.
  final bool similarBursts;

  static const thresholds = [10, 25, 50, 100];
  static const minBurstGap = 1;
  static const maxBurstGap = 10;

  AppSettings copyWith({
    bool? onboardingDone,
    SortOrder? sortOrder,
    int? checkpointThreshold,
    bool? manageMediaAsked,
    ThemeMode? themeMode,
    bool? groupBursts,
    int? burstGapSeconds,
    bool? autoTrashOnLeave,
    bool? deleteDirectly,
    bool? rawIntroSeen,
    bool? burstIntroSeen,
    ReminderMode? reminderMode,
    ReminderSlot? reminderSlot,
    DateTime? lastVisit,
    List<int>? usageHours,
    bool? similarBursts,
  }) => AppSettings(
    onboardingDone: onboardingDone ?? this.onboardingDone,
    sortOrder: sortOrder ?? this.sortOrder,
    checkpointThreshold: checkpointThreshold ?? this.checkpointThreshold,
    manageMediaAsked: manageMediaAsked ?? this.manageMediaAsked,
    themeMode: themeMode ?? this.themeMode,
    groupBursts: groupBursts ?? this.groupBursts,
    burstGapSeconds: burstGapSeconds ?? this.burstGapSeconds,
    autoTrashOnLeave: autoTrashOnLeave ?? this.autoTrashOnLeave,
    deleteDirectly: deleteDirectly ?? this.deleteDirectly,
    rawIntroSeen: rawIntroSeen ?? this.rawIntroSeen,
    burstIntroSeen: burstIntroSeen ?? this.burstIntroSeen,
    reminderMode: reminderMode ?? this.reminderMode,
    reminderSlot: reminderSlot ?? this.reminderSlot,
    lastVisit: lastVisit ?? this.lastVisit,
    usageHours: usageHours ?? this.usageHours,
    similarBursts: similarBursts ?? this.similarBursts,
  );
}

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static const _onboardingDone = 'onboarding_done';
  static const _sortOrder = 'sort_order';
  static const _threshold = 'checkpoint_threshold';
  static const _manageMediaAsked = 'manage_media_asked';
  static const _themeMode = 'theme_mode';
  static const _groupBursts = 'group_bursts';
  static const _burstGap = 'burst_gap_seconds';
  static const _autoTrashOnLeave = 'auto_trash_on_leave';
  static const _deleteDirectly = 'delete_directly';
  static const _rawIntroSeen = 'raw_intro_seen';
  static const _burstIntroSeen = 'burst_intro_seen';
  static const _reminderMode = 'reminder_mode';
  static const _reminderSlot = 'reminder_slot';
  static const _lastVisit = 'last_visit';
  static const _usageHours = 'usage_hours';
  static const _similarBursts = 'similar_bursts';

  /// Ancienne clé (rappel hebdomadaire seul), lue une fois pour migrer.
  static const _weeklyReminder = 'weekly_reminder';

  static const keys = {
    _onboardingDone,
    _sortOrder,
    _threshold,
    _manageMediaAsked,
    _themeMode,
    _groupBursts,
    _burstGap,
    _autoTrashOnLeave,
    _deleteDirectly,
    _rawIntroSeen,
    _burstIntroSeen,
    _reminderMode,
    _reminderSlot,
    _lastVisit,
    _usageHours,
    _similarBursts,
    _weeklyReminder,
  };

  static Future<SettingsRepository> open() async => SettingsRepository(
    await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(allowList: keys),
    ),
  );

  AppSettings read() {
    T byName<T extends Enum>(List<T> values, String key, T fallback) {
      final name = _prefs.getString(key);
      return values.where((v) => v.name == name).firstOrNull ?? fallback;
    }

    const defaults = AppSettings();
    return AppSettings(
      onboardingDone: _prefs.getBool(_onboardingDone) ?? false,
      sortOrder: byName(SortOrder.values, _sortOrder, defaults.sortOrder),
      checkpointThreshold:
          _prefs.getInt(_threshold) ?? defaults.checkpointThreshold,
      manageMediaAsked: _prefs.getBool(_manageMediaAsked) ?? false,
      themeMode: byName(ThemeMode.values, _themeMode, defaults.themeMode),
      groupBursts: _prefs.getBool(_groupBursts) ?? defaults.groupBursts,
      burstGapSeconds: (_prefs.getInt(_burstGap) ?? defaults.burstGapSeconds)
          .clamp(AppSettings.minBurstGap, AppSettings.maxBurstGap),
      autoTrashOnLeave: _prefs.getBool(_autoTrashOnLeave) ?? false,
      deleteDirectly: _prefs.getBool(_deleteDirectly) ?? false,
      rawIntroSeen: _prefs.getBool(_rawIntroSeen) ?? false,
      burstIntroSeen: _prefs.getBool(_burstIntroSeen) ?? false,
      reminderMode: _prefs.containsKey(_reminderMode)
          ? byName(ReminderMode.values, _reminderMode, defaults.reminderMode)
          : (_prefs.getBool(_weeklyReminder) ?? false)
          ? ReminderMode.weekly
          : ReminderMode.off,
      reminderSlot: byName(
        ReminderSlot.values,
        _reminderSlot,
        defaults.reminderSlot,
      ),
      lastVisit: switch (_prefs.getInt(_lastVisit)) {
        final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        null => null,
      },
      similarBursts: _prefs.getBool(_similarBursts) ?? true,
      usageHours: [
        for (final v in _prefs.getStringList(_usageHours) ?? const <String>[])
          int.tryParse(v) ?? 0,
      ],
    );
  }

  Future<void> write(AppSettings settings) async {
    await _prefs.setBool(_onboardingDone, settings.onboardingDone);
    await _prefs.setString(_sortOrder, settings.sortOrder.name);
    await _prefs.setInt(_threshold, settings.checkpointThreshold);
    await _prefs.setBool(_manageMediaAsked, settings.manageMediaAsked);
    await _prefs.setString(_themeMode, settings.themeMode.name);
    await _prefs.setBool(_groupBursts, settings.groupBursts);
    await _prefs.setInt(_burstGap, settings.burstGapSeconds);
    await _prefs.setBool(_autoTrashOnLeave, settings.autoTrashOnLeave);
    await _prefs.setBool(_deleteDirectly, settings.deleteDirectly);
    await _prefs.setBool(_rawIntroSeen, settings.rawIntroSeen);
    await _prefs.setBool(_burstIntroSeen, settings.burstIntroSeen);
    await _prefs.setString(_reminderMode, settings.reminderMode.name);
    await _prefs.setString(_reminderSlot, settings.reminderSlot.name);
    final visit = settings.lastVisit;
    if (visit != null) {
      await _prefs.setInt(_lastVisit, visit.millisecondsSinceEpoch);
    }
    await _prefs.setBool(_similarBursts, settings.similarBursts);
    if (settings.usageHours.isNotEmpty) {
      await _prefs.setStringList(_usageHours, [
        for (final v in settings.usageHours) '$v',
      ]);
    }
  }
}
