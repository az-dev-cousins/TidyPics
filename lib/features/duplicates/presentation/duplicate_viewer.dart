import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/duplicates.dart';
import '../../../data/models/gallery_photo.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';

/// Les versions d'un doublon en grand, l'une après l'autre (glisser pour
/// passer de l'une à l'autre, pincer pour zoomer), avec le choix
/// garder / supprimer.
Future<void> showDuplicateViewer(
  BuildContext context, {
  required DuplicateGroup group,
  required int initialIndex,
  required bool Function(GalleryPhoto photo) kept,
  required ValueChanged<GalleryPhoto> onToggle,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (context) => _DuplicateViewer(
      group: group,
      initialIndex: initialIndex,
      kept: kept,
      onToggle: onToggle,
    ),
  ),
);

class _DuplicateViewer extends ConsumerStatefulWidget {
  const _DuplicateViewer({
    required this.group,
    required this.initialIndex,
    required this.kept,
    required this.onToggle,
  });

  final DuplicateGroup group;
  final int initialIndex;
  final bool Function(GalleryPhoto photo) kept;
  final ValueChanged<GalleryPhoto> onToggle;

  @override
  ConsumerState<_DuplicateViewer> createState() => _DuplicateViewerState();
}

class _DuplicateViewerState extends ConsumerState<_DuplicateViewer> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final images = ref.watch(photoImagesProvider);
    final photos = widget.group.photos;
    final photo = photos[_index];
    final kept = widget.kept(photo);
    final size = photo.sizeBytes ?? 0;
    final details = [
      if (photo.width > 0) '${photo.width} × ${photo.height}',
      if (size > 0) l10n.fileSize(size),
      ?photo.folderName,
    ].join(' · ');

    return Scaffold(
      backgroundColor: tidy.photoBackdrop,
      appBar: AppBar(
        backgroundColor: tidy.photoBackdrop,
        title: Text(
          l10n.duplicatesViewerTitle(_index + 1, photos.length),
          style: theme.textTheme.titleMedium,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Image(
                    image: images.large(photos[i], maxSide: 2400),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (context, _, _) => const PhotoPlaceholder(
                      icon: Icons.broken_image_outlined,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (photo == widget.group.best)
                    Text(
                      l10n.duplicatesBestVersion,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tidy.keep,
                      ),
                    ),
                  Text(photo.title ?? '', style: theme.textTheme.titleSmall),
                  Text(
                    details,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tidy.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(l10n.duplicatesKept),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.close_rounded),
                        label: Text(l10n.duplicatesDeleted),
                      ),
                    ],
                    selected: {kept},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) {
                      if (s.first != kept) {
                        widget.onToggle(photo);
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
