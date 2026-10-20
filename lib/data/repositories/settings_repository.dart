import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    this.weeklyReminder = false,
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

  /// Rappel hebdomadaire par notification locale (désactivé par défaut).
  final bool weeklyReminder;

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
    bool? weeklyReminder,
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
    weeklyReminder: weeklyReminder ?? this.weeklyReminder,
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
      weeklyReminder: _prefs.getBool(_weeklyReminder) ?? false,
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
    await _prefs.setBool(_weeklyReminder, settings.weeklyReminder);
  }
}
