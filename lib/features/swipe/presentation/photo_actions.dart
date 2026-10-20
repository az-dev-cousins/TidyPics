import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/gallery_photo.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';

/// Appui long ou « ⋯ » sur une carte : partager la photo (menu de partage du
/// système : Google Photos, Drive, WhatsApp…) ou l'ouvrir dans la galerie.
/// Rien n'est envoyé par TidyPics : c'est l'app choisie qui s'en charge.
Future<void> showPhotoActions(
  BuildContext context,
  WidgetRef ref,
  GalleryPhoto photo,
) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final tidy = TidyColors.of(context);
  final gallery = ref.read(gallerySourceProvider);
  final messenger = ScaffoldMessenger.of(context);
  final size = photo.sizeBytes ?? 0;
  final details = [
    l10n.shortDate(photo.takenAt),
    if (photo.width > 0) '${photo.width} × ${photo.height}',
    if (size > 0) l10n.fileSize(size),
    ?photo.folderName,
  ].join(' · ');

  Future<void> share() async {
    final file = await gallery.mediaFile(photo.id);
    if (file == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoShareFailed)));
      return;
    }
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  Future<void> open() async {
    if (!await gallery.openInGallery(photo.id)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoOpenFailed)));
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo.title ?? l10n.photoUntitled,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tidy.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(l10n.photoShare),
            subtitle: Text(l10n.photoShareHint),
            onTap: () {
              Navigator.of(context).pop();
              share();
            },
          ),
          if (gallery.canOpenInGallery)
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.photoOpenInGallery),
              onTap: () {
                Navigator.of(context).pop();
                open();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
