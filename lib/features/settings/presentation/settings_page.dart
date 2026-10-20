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

/// Paramètres (F8).
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

  SettingsController get _controller => ref.read(settingsProvider.notifier);

  Future<void> _resetKept() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      title: l10n.settingsResetKept,
      body: l10n.settingsResetKeptBody,
      action: l10n.settingsResetKeptConfirm,
    );
    if (!ok) return;
    await ref.read(libraryRepositoryProvider).resetKept();
    messenger.showSnackBar(SnackBar(content: Text(l10n.settingsResetKeptDone)));
  }

  Future<void> _setDeleteDirectly(bool value) async {
    final l10n = AppLocalizations.of(context);
    if (value) {
      final ok = await _confirm(
        title: l10n.settingsDeleteDirectlyWarningTitle,
        body: l10n.settingsDeleteDirectlyWarningBody,
        action: l10n.settingsDeleteDirectlyEnable,
        danger: true,
      );
      if (!ok) return;
    }
    await _controller.setDeleteDirectly(value);
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool danger = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final tidy = TidyColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: tidy.delete)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final settings = ref.watch(settingsProvider);
    final manageMedia = ref.watch(manageMediaStatusProvider).value;
    final android = manageMedia?.supported ?? false;
    final granted = manageMedia?.granted ?? false;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(color: tidy.inkMuted),
      ),
    );
    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                section(l10n.settingsSectionSorting),
                RadioGroup<SortOrder>(
                  groupValue: settings.sortOrder,
                  onChanged: (v) {
                    if (v != null) unawaited(_controller.setSortOrder(v));
                  },
                  child: Card(
                    child: Column(
                      children: [
                        for (final (value, text) in [
                          (SortOrder.random, l10n.settingsSortRandom),
                          (SortOrder.oldestFirst, l10n.settingsSortOldest),
                          (SortOrder.newestFirst, l10n.settingsSortNewest),
                        ])
                          RadioListTile<SortOrder>(
                            value: value,
                            title: Text(text),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                label(l10n.settingsThreshold),
                SegmentedButton<int>(
                  segments: [
                    for (final n in AppSettings.thresholds)
                      ButtonSegment(value: n, label: Text('$n')),
                  ],
                  selected: {settings.checkpointThreshold},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      unawaited(_controller.setCheckpointThreshold(s.first)),
                ),

                section(l10n.settingsSectionBursts),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: settings.groupBursts,
                        title: Text(l10n.settingsGroupBursts),
                        subtitle: Text(l10n.settingsGroupBurstsBody),
                        onChanged: (v) =>
                            unawaited(_controller.setGroupBursts(v)),
                      ),
                      if (settings.groupBursts)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.settingsBurstGap(settings.burstGapSeconds),
                              ),
                              Slider(
                                value: settings.burstGapSeconds.toDouble(),
                                min: AppSettings.minBurstGap.toDouble(),
                                max: AppSettings.maxBurstGap.toDouble(),
                                divisions:
                                    AppSettings.maxBurstGap -
                                    AppSettings.minBurstGap,
                                label: '${settings.burstGapSeconds} s',
                                onChanged: (v) => unawaited(
                                  _controller.setBurstGap(v.round()),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                if (android) ...[
                  section(l10n.settingsSectionDeletion),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            granted
                                ? Icons.check_circle_rounded
                                : Icons.bolt_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(l10n.settingsManageMedia),
                          subtitle: Text(
                            granted
                                ? l10n.settingsManageMediaOn
                                : l10n.settingsManageMediaOff,
                          ),
                          onTap: () => ref
                              .read(gallerySourceProvider)
                              .requestManageMedia(),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: settings.autoTrashOnLeave && granted,
                          title: Text(l10n.settingsAutoTrash),
                          subtitle: Text(
                            granted
                                ? l10n.settingsAutoTrashBody
                                : l10n.settingsAutoTrashNeedsManageMedia,
                          ),
                          onChanged: granted
                              ? (v) => unawaited(
                                  _controller.setAutoTrashOnLeave(v),
                                )
                              : null,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: settings.deleteDirectly,
                          title: Text(l10n.settingsDeleteDirectly),
                          subtitle: Text(l10n.settingsDeleteDirectlyBody),
                          onChanged: (v) => unawaited(_setDeleteDirectly(v)),
                        ),
                      ],
                    ),
                  ),
                ],

                section(l10n.settingsSectionDisplay),
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
                      unawaited(_controller.setThemeMode(s.first)),
                ),
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
