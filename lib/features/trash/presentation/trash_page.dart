import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/trash_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';
import '../../gallery/application/gallery_controller.dart';

/// « En cours de suppression » (F4) : ce que TidyPics a envoyé à la
/// corbeille, avec les jours restants. Restauration possible sur Android.
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    TrashEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final count = await ref.read(trashRepositoryProvider).restore([entry]);
    if (count == 0) return;
    // La photo est de retour dans la galerie : on la réindexe.
    unawaited(ref.read(gallerySyncProvider.notifier).scan());
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.trashRestored(l10n.photoCount(count)))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final entries = ref.watch(trashLogProvider).value;
    final canRestore = ref.watch(gallerySourceProvider).hasRestorableTrash;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trashTitle)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: entries == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      Text(
                        Platform.isIOS
                            ? l10n.trashIosNote
                            : l10n.trashAndroidNote,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tidy.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Text(
                            l10n.trashEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: tidy.inkMuted,
                            ),
                          ),
                        ),
                      for (final entry in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              SizedBox.square(
                                dimension: 64,
                                child: _Thumbnail(entry: entry),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.trashDaysLeft(entry.daysLeft(now)),
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    Text(
                                      '${l10n.shortDate(entry.photo.takenAt)}'
                                      ' · '
                                      '${l10n.fileSize(entry.photo.sizeBytes ?? 0)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: tidy.inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                              if (canRestore)
                                TextButton(
                                  onPressed: () =>
                                      _restore(context, ref, entry),
                                  child: Text(l10n.trashRestore),
                                ),
                            ],
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.entry});

  final TrashEntry entry;

  @override
  Widget build(BuildContext context) {
    final bytes = entry.thumbnail;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusThumbnail),
      child: bytes == null
          ? const PhotoPlaceholder(icon: Icons.image_outlined)
          : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}
