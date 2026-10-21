import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/document_file.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../application/document_session.dart';

/// Documents (V2, F16) : deux façons de trier, sans permission spéciale.
/// - « Mes documents » : un dossier donné une fois (Documents d'abord),
///   relu à chaque fois.
/// - « Trier des fichiers » : le sélecteur du système, n'importe où.
class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  bool _working = false;

  Future<void> _run(Future<List<DocumentFile>?> Function() load) async {
    if (_working) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    try {
      final files = await load();
      if (files == null || !mounted) return;
      final session = ref.read(documentSessionProvider.notifier);
      await session.start(files);
      if (!mounted) return;
      if (ref.read(documentSessionProvider).queue.isEmpty) {
        if (files.isNotEmpty) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.documentsNothing)));
        }
        return;
      }
      await context.push(AppRoutes.documentsSort);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<List<DocumentFile>?> _folderFiles() async {
    final source = ref.read(documentSourceProvider);
    final folders = await source.folders();
    return [
      for (final folder in folders) ...await source.listFolder(folder.uri),
    ];
  }

  Future<void> _addFolder() async {
    await ref.read(documentSourceProvider).pickFolder();
    ref.invalidate(documentFoldersProvider);
  }

  Future<void> _forget(String uri) async {
    await ref.read(documentSourceProvider).forgetFolder(uri);
    ref.invalidate(documentFoldersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final folders = ref.watch(documentFoldersProvider).value ?? const [];

    Widget section({
      required IconData icon,
      required String title,
      required String body,
      required List<Widget> children,
    }) => Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(color: tidy.inkMuted),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentsTitle)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Text(
                  l10n.documentsIntro,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: tidy.inkMuted,
                  ),
                ),
                const SizedBox(height: 16),
                section(
                  icon: Icons.folder_open_outlined,
                  title: l10n.documentsFolderTitle,
                  body: l10n.documentsFolderBody,
                  children: [
                    for (final folder in folders)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(folder.name),
                        trailing: IconButton(
                          tooltip: l10n.documentsFolderForget,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => unawaited(_forget(folder.uri)),
                        ),
                      ),
                    if (folders.isEmpty)
                      FilledButton.icon(
                        onPressed: _working ? null : _addFolder,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: Text(l10n.documentsFolderGrant),
                      )
                    else ...[
                      FilledButton.icon(
                        onPressed: _working ? null : () => _run(_folderFiles),
                        icon: const Icon(Icons.swipe_outlined),
                        label: Text(l10n.documentsFolderSort),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _working ? null : _addFolder,
                        child: Text(l10n.documentsFolderAdd),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                section(
                  icon: Icons.file_open_outlined,
                  title: l10n.documentsPickTitle,
                  body: l10n.documentsPickBody,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _working
                          ? null
                          : () => _run(
                              ref.read(documentSourceProvider).pickFiles,
                            ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.documentsPickButton),
                    ),
                  ],
                ),
                if (_working) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
