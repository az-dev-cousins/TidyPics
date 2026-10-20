import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../data/repositories/settings_repository.dart';

/// Réglages courants. Chaque changement est enregistré tout de suite.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsRepositoryProvider).read();

  Future<void> _save(AppSettings settings) async {
    state = settings;
    await ref.read(settingsRepositoryProvider).write(settings);
  }

  Future<void> completeOnboarding() =>
      _save(state.copyWith(onboardingDone: true));

  Future<void> setSortOrder(SortOrder order) =>
      _save(state.copyWith(sortOrder: order));

  Future<void> setCheckpointThreshold(int value) =>
      _save(state.copyWith(checkpointThreshold: value));

  Future<void> markManageMediaAsked() =>
      _save(state.copyWith(manageMediaAsked: true));

  Future<void> setThemeMode(ThemeMode mode) =>
      _save(state.copyWith(themeMode: mode));
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
