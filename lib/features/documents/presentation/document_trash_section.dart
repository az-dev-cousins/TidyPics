import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/document_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../application/document_session.dart';

/// Les documents dans la corbeille de TidyPics, dans « En cours de
/// suppression » : remettre en place ou effacer tout de suite.
class DocumentTrashSection extends ConsumerWidget {
  const DocumentTrashSection({super.key});

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    DocumentTrashEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(documentRepositoryProvider).restore(entry);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.documentsRestored(entry.row.name)
              : l10n.documentsRestoreFailed,
        ),
      ),
    );
  }

  Future<void> _empty(
    BuildContext context,
    WidgetRef ref,
    List<DocumentTrashEntry> entries,
  ) async {
    final l10n = AppLocalizations.of(context);
    final tidy = TidyColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trashEmptyConfirmTitle),
        content: Text(
          l10n.trashEmptyConfirmBody(l10n.documentsFiles(entries.length)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: tidy.delete),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.trashEmptyConfirm),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(documentRepositoryProvider).emptyNow(entries);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final entries = ref.watch(documentTrashProvider).value ?? const [];
    if (entries.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final bytes = entries.fold(0, (s, e) => s + e.row.sizeBytes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          l10n.documentsTrashTitle.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: tidy.inkMuted),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.documentsTrashNote(l10n.fileSize(bytes)),
          style: theme.textTheme.bodySmall?.copyWith(color: tidy.inkMuted),
        ),
        const SizedBox(height: 8),
        for (final entry in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.description_outlined, color: tidy.inkMuted),
            title: Text(
              entry.row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${l10n.trashDaysLeft(entry.daysLeft(now))} · '
              '${l10n.fileSize(entry.row.sizeBytes)}',
            ),
            trailing: TextButton(
              onPressed: () => unawaited(_restore(context, ref, entry)),
              child: Text(l10n.trashRestore),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(side: BorderSide(color: tidy.delete)),
          onPressed: () => unawaited(_empty(context, ref, entries)),
          icon: Icon(Icons.delete_forever_outlined, color: tidy.delete),
          label: Text(l10n.documentsTrashEmpty(l10n.fileSize(bytes))),
        ),
      ],
    );
  }
}
