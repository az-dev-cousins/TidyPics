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
      SnackBar(
        content: Text(
          l10n.trashRestored(
            entry.photo.isVideo ? l10n.videoCount(1) : l10n.photoCount(1),
          ),
        ),
      ),
    );
  }

  Future<void> _emptyNow(
    BuildContext context,
    WidgetRef ref,
    List<TrashEntry> entries,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tidy = TidyColors.of(context);
    final videos = entries.where((e) => e.photo.isVideo).length;
    final photos = l10n.items(photos: entries.length - videos, videos: videos);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trashEmptyConfirmTitle),
        content: Text(l10n.trashEmptyConfirmBody(photos)),
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
    if (ok != true) return;
    final count = await ref.read(trashRepositoryProvider).emptyNow(entries);
    if (count == 0) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.trashEmptied(
            // Tout est parti d'un coup, sauf refus partiel (rare).
            count == entries.length ? photos : l10n.photoCount(count),
          ),
        ),
      ),
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
      bottomNavigationBar: canRestore && (entries?.isNotEmpty ?? false)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: tidy.delete),
                  ),
                  onPressed: () => _emptyNow(context, ref, entries!),
                  icon: Icon(Icons.delete_forever_outlined, color: tidy.delete),
                  label: Text(l10n.trashEmptyNow),
                ),
              ),
            )
          : null,
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
                                    // Le nom du fichier : utile pour s'y
                                    // retrouver (paires JPG + RAW, rafales).
                                    if (entry.photo.title != null)
                                      Text(
                                        entry.photo.title!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    Text(
                                      '${l10n.trashDaysLeft(entry.daysLeft(now))}'
                                      ' · '
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
    final duration = entry.photo.duration;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusThumbnail),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bytes == null)
            PhotoPlaceholder(
              icon: duration == null
                  ? Icons.image_outlined
                  : Icons.videocam_outlined,
            )
          else
            Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
          if (duration != null)
            Positioned(
              left: 4,
              bottom: 4,
              child: VideoMark(duration: duration),
            ),
        ],
      ),
    );
  }
}
