import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/gallery_photo.dart';
import '../../../data/models/photo_groups.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';
import '../application/swipe_session.dart';

/// Cadre commun des cartes : image en haut, légende en bas, tampon pendant
/// le geste.
class SwipeCardFrame extends StatelessWidget {
  const SwipeCardFrame({
    super.key,
    required this.image,
    required this.caption,
    this.trailing = const [],
    this.stamp,
    this.strength = 0,
  });

  final Widget image;
  final String caption;
  final List<Widget> trailing;
  final SwipeChoice? stamp;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSwipeCard),
        border: Border.all(color: tidy.line),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSwipeCard),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: tidy.photoBackdrop, child: image),
                  if (stamp != null && strength > 0)
                    SwipeStamp(choice: stamp!, strength: strength),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      caption,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tidy.inkMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  ...trailing,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'une photo de la galerie.
class PhotoSwipeCard extends ConsumerWidget {
  const PhotoSwipeCard({
    super.key,
    required this.photo,
    this.stamp,
    this.strength = 0,
    this.play = false,
  });

  final GalleryPhoto photo;
  final SwipeChoice? stamp;
  final double strength;

  /// Vidéo : lecture sur la carte du dessus seulement.
  final bool play;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (photo.isVideo) {
      return VideoSwipeCard(
        video: photo,
        play: play,
        stamp: stamp,
        strength: strength,
      );
    }
    final l10n = AppLocalizations.of(context);
    final tidy = TidyColors.of(context);
    final images = ref.watch(photoImagesProvider);
    final size = photo.sizeBytes;
    final caption = [
      l10n.shortDate(photo.takenAt),
      if (size != null && size > 0) l10n.fileSize(size).toUpperCase(),
    ].join(' · ');

    return SwipeCardFrame(
      caption: caption,
      stamp: stamp,
      strength: strength,
      trailing: [
        if (photo.isRaw) _Badge(text: l10n.swipeRaw),
        if (photo.isFavorite) ...[
          const SizedBox(width: 8),
          Icon(Icons.star_rounded, color: tidy.favorite, size: 20),
        ],
      ],
      // La photo entière, sans recadrage : on juge mieux.
      image: Image(
        image: images.large(photo),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        semanticLabel: caption,
        errorBuilder: (context, _, _) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, color: tidy.inkMuted),
            const SizedBox(height: 8),
            Text(l10n.swipeImageError, style: TextStyle(color: tidy.inkMuted)),
          ],
        ),
      ),
    );
  }
}

/// Carte d'un élément à trier : photo seule, paire JPG + RAW ou rafale.
class ItemSwipeCard extends ConsumerWidget {
  const ItemSwipeCard({
    super.key,
    required this.item,
    this.stamp,
    this.strength = 0,
    this.onPickBest,
    this.play = false,
  });

  final PhotoItem item;
  final SwipeChoice? stamp;
  final double strength;

  /// Vidéo : lecture sur la carte du dessus seulement.
  final bool play;

  /// Rafale : ouvre le tri photo par photo.
  final VoidCallback? onPickBest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.kind == PhotoItemKind.single) {
      return PhotoSwipeCard(
        photo: item.cover,
        stamp: stamp,
        strength: strength,
        play: play,
      );
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final images = ref.watch(photoImagesProvider);
    final size = item.sizeBytes;
    final burst = item.kind == PhotoItemKind.burst;
    final caption = [
      l10n.shortDate(item.takenAt),
      if (size > 0) l10n.fileSize(size).toUpperCase(),
    ].join(' · ');

    final card = SwipeCardFrame(
      caption: caption,
      stamp: stamp,
      strength: strength,
      image: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: images.large(item.cover),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            semanticLabel: caption,
            errorBuilder: (context, _, _) =>
                const PhotoPlaceholder(icon: Icons.broken_image_outlined),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: _Chip(
              icon: burst
                  ? Icons.burst_mode_outlined
                  : Icons.filter_none_rounded,
              text: burst
                  ? l10n.swipeBurstBadge(item.photos.length)
                  : l10n.swipeRawPairBadge,
            ),
          ),
          if (burst)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Strip(photos: item.photos),
                  if (onPickBest != null) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: tidy.mint,
                          foregroundColor: tidy.onMint,
                        ),
                        onPressed: onPickBest,
                        icon: const Icon(Icons.checklist_rounded),
                        label: Text(l10n.swipeBurstPick),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
    if (!burst) return card;

    // Rafale : deux cartes en éventail derrière, pour montrer le groupe.
    Widget layer(double angle) => Transform.rotate(
      angle: angle,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusSwipeCard),
          border: Border.all(color: tidy.line),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.all(8), child: layer(-0.06)),
        Padding(padding: const EdgeInsets.all(8), child: layer(0.045)),
        card,
      ],
    );
  }
}

/// Son des vidéos pour la session : coupé au départ (F1), il reste comme
/// l'utilisateur l'a mis d'une vidéo à l'autre.
class VideoSound extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final videoSoundProvider = NotifierProvider<VideoSound, bool>(VideoSound.new);

/// Carte d'une vidéo : lecture automatique sans le son, en boucle, avec
/// pause et son. La miniature reste dessous tant que la vidéo charge.
class VideoSwipeCard extends ConsumerStatefulWidget {
  const VideoSwipeCard({
    super.key,
    required this.video,
    this.play = false,
    this.stamp,
    this.strength = 0,
  });

  final GalleryPhoto video;
  final bool play;
  final SwipeChoice? stamp;
  final double strength;

  @override
  ConsumerState<VideoSwipeCard> createState() => _VideoSwipeCardState();
}

class _VideoSwipeCardState extends ConsumerState<VideoSwipeCard> {
  VideoPlayerController? _controller;
  bool _paused = false;
  bool _loading = false;

  /// Vidéo illisible : la miniature reste, on ne réessaie pas.
  bool _failed = false;

  /// Carte du dessus et écran visible : un écran ouvert par-dessus (menu,
  /// récap) met la vidéo en pause.
  bool _active = false;

  @override
  void didUpdateWidget(VideoSwipeCard old) {
    super.didUpdateWidget(old);
    if (widget.video.id != old.video.id) {
      unawaited(_dispose());
      _paused = false;
      _failed = false;
    }
  }

  /// Appelée à chaque construction : charge ou met en pause selon [active].
  void _sync(bool active) {
    if (active == _active && (_controller != null || !active)) return;
    _active = active;
    if (active && _controller == null) {
      if (!_failed) unawaited(_load());
    } else {
      unawaited(_apply());
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    final id = widget.video.id;
    final file = await ref.read(gallerySourceProvider).videoFile(id);
    if (!mounted || file == null || id != widget.video.id) {
      _loading = false;
      _failed = file == null;
      return;
    }
    final controller = VideoPlayerController.file(
      file,
      // iOS : la musique de l'utilisateur continue, la vidéo est muette.
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      await controller.setLooping(true);
    } on Object catch (error) {
      debugPrint('Lecture impossible ($id) : $error');
      await controller.dispose();
      _loading = false;
      _failed = true;
      return;
    }
    _loading = false;
    if (!mounted || id != widget.video.id) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
    await _apply();
  }

  /// Met le lecteur dans l'état voulu : lecture, pause, son.
  Future<void> _apply() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setVolume(ref.read(videoSoundProvider) ? 1 : 0);
    if (_active && !_paused) {
      await controller.play();
    } else {
      await controller.pause();
    }
  }

  Future<void> _dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  @override
  void dispose() {
    unawaited(_dispose());
    super.dispose();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    unawaited(_apply());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tidy = TidyColors.of(context);
    final images = ref.watch(photoImagesProvider);
    final sound = ref.watch(videoSoundProvider);
    ref.listen(videoSoundProvider, (_, _) => unawaited(_apply()));
    _sync(widget.play && (ModalRoute.of(context)?.isCurrent ?? true));
    final video = widget.video;
    final size = video.sizeBytes;
    final length = l10n.videoLength(video.duration!);
    final caption = [
      l10n.shortDate(video.takenAt),
      if (size != null && size > 0) l10n.fileSize(size).toUpperCase(),
    ].join(' · ');
    final controller = _controller;

    return SwipeCardFrame(
      caption: caption,
      stamp: widget.stamp,
      strength: widget.strength,
      trailing: [
        if (video.isFavorite)
          Icon(Icons.star_rounded, color: tidy.favorite, size: 20),
      ],
      image: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: images.large(video),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            semanticLabel: '${l10n.swipeVideo} · $caption',
            errorBuilder: (context, _, _) =>
                const PhotoPlaceholder(icon: Icons.videocam_outlined),
          ),
          if (controller != null && controller.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          Positioned(
            left: 16,
            top: 16,
            child: _Chip(
              icon: Icons.videocam_outlined,
              text: '${l10n.swipeVideo} · $length',
            ),
          ),
          if (widget.play)
            Positioned(
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  _VideoButton(
                    icon: _paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    tooltip: _paused ? l10n.videoPlay : l10n.videoPause,
                    onPressed: _togglePause,
                  ),
                  const SizedBox(width: 8),
                  _VideoButton(
                    icon: sound
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    tooltip: sound ? l10n.videoMute : l10n.videoUnmute,
                    onPressed: ref.read(videoSoundProvider.notifier).toggle,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoButton extends StatelessWidget {
  const _VideoButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainer,
        foregroundColor: scheme.onSurface,
      ),
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(text, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

/// Les premières photos d'une rafale, en vignettes.
class _Strip extends StatelessWidget {
  const _Strip({required this.photos});

  final List<GalleryPhoto> photos;

  @override
  Widget build(BuildContext context) {
    const shown = 4;
    final extra = photos.length - shown;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          for (final (i, photo) in photos.take(shown).indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: PhotoThumbnail(photo: photo, size: 120)),
          ],
          if (extra > 0) ...[
            const SizedBox(width: 6),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(AppTheme.radiusThumbnail),
                ),
                child: Center(
                  child: Text(
                    '+$extra',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tidy = TidyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tidy.mint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: tidy.onMint),
        ),
      ),
    );
  }
}

/// Tampon « Supprimer / Garder / Favori » qui apparaît pendant le geste.
class SwipeStamp extends StatelessWidget {
  const SwipeStamp({super.key, required this.choice, required this.strength});

  final SwipeChoice choice;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final (icon, text, color, alignment) = switch (choice) {
      SwipeChoice.trash => (
        Icons.close_rounded,
        l10n.swipeTrash,
        tidy.delete,
        Alignment.topRight,
      ),
      SwipeChoice.keep => (
        Icons.check_rounded,
        l10n.swipeKeep,
        tidy.keep,
        Alignment.topLeft,
      ),
      SwipeChoice.favorite => (
        Icons.star_rounded,
        l10n.swipeFavorite,
        theme.colorScheme.onSurface,
        Alignment.bottomCenter,
      ),
    };
    final iconColor = choice == SwipeChoice.favorite ? tidy.favorite : color;

    return Opacity(
      opacity: strength,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    text.toUpperCase(),
                    // Texte neutre : pas de texte tomate en petite taille.
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
