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
  });

  final bool onboardingDone;
  final SortOrder sortOrder;

  /// Nombre de photos triées entre deux récaps (s'il y a des photos au
  /// panier).
  final int checkpointThreshold;

  /// « Gestion des médias » déjà proposée une fois (Android 12+).
  final bool manageMediaAsked;
  final ThemeMode themeMode;

  static const thresholds = [10, 25, 50, 100];

  AppSettings copyWith({
    bool? onboardingDone,
    SortOrder? sortOrder,
    int? checkpointThreshold,
    bool? manageMediaAsked,
    ThemeMode? themeMode,
  }) => AppSettings(
    onboardingDone: onboardingDone ?? this.onboardingDone,
    sortOrder: sortOrder ?? this.sortOrder,
    checkpointThreshold: checkpointThreshold ?? this.checkpointThreshold,
    manageMediaAsked: manageMediaAsked ?? this.manageMediaAsked,
    themeMode: themeMode ?? this.themeMode,
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

  static const keys = {
    _onboardingDone,
    _sortOrder,
    _threshold,
    _manageMediaAsked,
    _themeMode,
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

    return AppSettings(
      onboardingDone: _prefs.getBool(_onboardingDone) ?? false,
      sortOrder: byName(SortOrder.values, _sortOrder, SortOrder.random),
      checkpointThreshold: _prefs.getInt(_threshold) ?? 25,
      manageMediaAsked: _prefs.getBool(_manageMediaAsked) ?? false,
      themeMode: byName(ThemeMode.values, _themeMode, ThemeMode.system),
    );
  }

  Future<void> write(AppSettings settings) async {
    await _prefs.setBool(_onboardingDone, settings.onboardingDone);
    await _prefs.setString(_sortOrder, settings.sortOrder.name);
    await _prefs.setInt(_threshold, settings.checkpointThreshold);
    await _prefs.setBool(_manageMediaAsked, settings.manageMediaAsked);
    await _prefs.setString(_themeMode, settings.themeMode.name);
  }
}
