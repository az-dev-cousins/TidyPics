import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/gallery_photo.dart';
import '../../l10n/app_localizations.dart';

/// Fabrique les images des photos. Remplacée par de fausses images dans les
/// tests.
class PhotoImages {
  const PhotoImages();

  /// Miniature carrée pour les grilles.
  ImageProvider thumbnail(GalleryPhoto photo, {int size = 240}) =>
      AssetEntityImageProvider(
        _entity(photo),
        isOriginal: false,
        thumbnailSize: ThumbnailSize.square(size),
      );

  /// Image assez grande pour la carte de swipe, sans charger l'original.
  ImageProvider large(GalleryPhoto photo, {int maxSide = 1600}) {
    final w = photo.width > 0 ? photo.width : maxSide;
    final h = photo.height > 0 ? photo.height : maxSide;
    final scale = math.min(1, maxSide / math.max(w, h));
    return AssetEntityImageProvider(
      _entity(photo),
      isOriginal: false,
      thumbnailSize: ThumbnailSize((w * scale).round(), (h * scale).round()),
    );
  }

  AssetEntity _entity(GalleryPhoto photo) => AssetEntity(
    id: photo.id,
    typeInt: (photo.isVideo ? AssetType.video : AssetType.image).index,
    duration: photo.duration?.inSeconds ?? 0,
    width: photo.width,
    height: photo.height,
  );
}

final photoImagesProvider = Provider<PhotoImages>((ref) => const PhotoImages());

/// Miniature arrondie d'une photo, avec un repli si elle est illisible.
class PhotoThumbnail extends ConsumerWidget {
  const PhotoThumbnail({super.key, required this.photo, this.size = 240});

  final GalleryPhoto photo;
  final int size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(photoImagesProvider);
    final image = Image(
      image: images.thumbnail(photo, size: size),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, _, _) => const PhotoPlaceholder(),
      frameBuilder: (context, child, frame, sync) =>
          frame == null && !sync ? const PhotoPlaceholder() : child,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusThumbnail),
      child: photo.duration == null
          ? image
          : Stack(
              fit: StackFit.expand,
              children: [
                image,
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: VideoMark(duration: photo.duration!),
                ),
              ],
            ),
    );
  }
}

/// Petite marque « ▶ 0:42 » posée sur la miniature d'une vidéo.
class VideoMark extends StatelessWidget {
  const VideoMark({super.key, required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 1, 7, 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              size: 14,
              color: theme.colorScheme.onSurface,
            ),
            Text(l10n.videoLength(duration), style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// Fond neutre affiché pendant le chargement ou si la photo est illisible.
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key, this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tidy = TidyColors.of(context);
    return ColoredBox(
      color: tidy.line.withValues(alpha: 0.5),
      child: icon == null
          ? const SizedBox.expand()
          : Center(child: Icon(icon, color: tidy.inkMuted, size: 40)),
    );
  }
}
