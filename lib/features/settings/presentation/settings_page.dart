import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settings_controller.dart';

/// « Gestion des médias » : existe-t-elle (Android 12+) et est-elle accordée ?
final manageMediaStatusProvider =
    FutureProvider.autoDispose<({bool supported, bool granted})>((ref) async {
      final gallery = ref.watch(gallerySourceProvider);
      final supported = await gallery.supportsManageMedia();
      return (
        supported: supported,
        granted: supported && await gallery.canManageMedia(),
      );
    });

/// Paramètres (F8), version de la première livraison.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Au retour des réglages du téléphone, on relit « Gestion des médias ».
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => ref.invalidate(manageMediaStatusProvider),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // Démarre l'écoute.
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _resetKept() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsResetKept),
        content: Text(l10n.settingsResetKeptBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsResetKeptConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(libraryRepositoryProvider).resetKept();
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsResetKeptDone)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final manageMedia = ref.watch(manageMediaStatusProvider).value;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(color: tidy.inkMuted),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                section(l10n.settingsSortOrder),
                RadioGroup<SortOrder>(
                  groupValue: settings.sortOrder,
                  onChanged: (v) {
                    if (v != null) unawaited(controller.setSortOrder(v));
                  },
                  child: Card(
                    child: Column(
                      children: [
                        for (final (value, label) in [
                          (SortOrder.random, l10n.settingsSortRandom),
                          (SortOrder.oldestFirst, l10n.settingsSortOldest),
                          (SortOrder.newestFirst, l10n.settingsSortNewest),
                        ])
                          RadioListTile<SortOrder>(
                            value: value,
                            title: Text(label),
                          ),
                      ],
                    ),
                  ),
                ),
                section(l10n.settingsThreshold),
                SegmentedButton<int>(
                  segments: [
                    for (final n in AppSettings.thresholds)
                      ButtonSegment(value: n, label: Text('$n')),
                  ],
                  selected: {settings.checkpointThreshold},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      unawaited(controller.setCheckpointThreshold(s.first)),
                ),
                section(l10n.settingsTheme),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(l10n.settingsThemeSystem),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(l10n.settingsThemeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(l10n.settingsThemeDark),
                    ),
                  ],
                  selected: {settings.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      unawaited(controller.setThemeMode(s.first)),
                ),
                if (manageMedia?.supported ?? false) ...[
                  section('Android'),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        manageMedia!.granted
                            ? Icons.check_circle_rounded
                            : Icons.bolt_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(l10n.settingsManageMedia),
                      subtitle: Text(
                        manageMedia.granted
                            ? l10n.settingsManageMediaOn
                            : l10n.settingsManageMediaOff,
                      ),
                      onTap: () =>
                          ref.read(gallerySourceProvider).requestManageMedia(),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.replay_rounded),
                    title: Text(l10n.settingsResetKept),
                    subtitle: Text(l10n.settingsResetKeptBody),
                    onTap: _resetKept,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
