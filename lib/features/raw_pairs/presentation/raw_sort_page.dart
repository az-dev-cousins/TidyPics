import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/gallery_photo.dart';
import '../../../data/models/photo_groups.dart';
import '../../../data/providers.dart';
import '../../../data/sources/local_db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';
import '../../cart/presentation/checkpoint_page.dart';
import '../../settings/application/settings_controller.dart';
import '../../swipe/application/swipe_session.dart';
import '../../swipe/presentation/swipe_card.dart';
import '../../swipe/presentation/swipe_deck.dart';
import '../../swipe/presentation/swipe_page.dart' show SwipeRoundButton;

/// Tri des RAW (F6) : le même swipe que le tri principal, mais on ne décide
/// que du fichier RAW. Le JPG de la même photo n'est jamais touché.
///
/// L'écran est en thème sombre, façon chambre noire, pour qu'on voie tout de
/// suite qu'on n'est pas dans le tri habituel.
class RawSortPage extends ConsumerStatefulWidget {
  const RawSortPage({super.key});

  @override
  ConsumerState<RawSortPage> createState() => _RawSortPageState();
}

class _RawSortPageState extends ConsumerState<RawSortPage> {
  final _deck = GlobalKey<SwipeDeckState>();
  List<PhotoItem>? _queue;

  /// Dernières décisions, pour « Annuler » : la paire et si le RAW est gardé.
  final _history = <(PhotoItem, bool)>[];
  int _trashedBytes = 0;
  int _trashedCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final library = ref.read(libraryRepositoryProvider);
    final gallery = ref.read(gallerySourceProvider);
    final pairs = await library.rawPairsToSort();
    // Les tailles s'affichent sur la carte : on les lit tout de suite.
    final sized = <PhotoItem>[];
    for (final pair in pairs) {
      final photos = <GalleryPhoto>[];
      for (final photo in pair.photos) {
        if (photo.sizeBytes != null) {
          photos.add(photo);
          continue;
        }
        final size = await gallery.fileSize(photo.id);
        await library.setSize(photo.id, size);
        photos.add(photo.copyWith(sizeBytes: size));
      }
      sized.add(PhotoItem.rawPair(jpg: photos[0], raw: photos[1]));
    }
    if (!mounted) return;
    setState(() => _queue = sized);
    if (!ref.read(settingsProvider).rawIntroSeen && sized.isNotEmpty) {
      await _showIntro();
    }
  }

  Future<void> _showIntro() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppTheme.dark.colorScheme.surfaceContainer,
      // La feuille s'ouvre au-dessus de l'app : on lui redonne le thème
      // sombre de l'écran.
      builder: (context) =>
          Theme(data: AppTheme.dark, child: const _RawIntro()),
    );
    await ref.read(settingsProvider.notifier).markRawIntroSeen();
    // On montre le geste une fois, sur la première carte.
    unawaited(_deck.currentState?.nudge(SwipeChoice.trash));
  }

  Future<void> _onSwiped(SwipeChoice choice) async {
    final queue = _queue;
    if (queue == null || queue.isEmpty) return;
    final pair = queue.first;
    final raw = pair.photos[1];
    final keep = choice != SwipeChoice.trash;
    setState(() {
      _queue = queue.sublist(1);
      _history.add((pair, keep));
      if (_history.length > SwipeSession.undoDepth) _history.removeAt(0);
      if (!keep) {
        _trashedCount++;
        _trashedBytes += raw.sizeBytes ?? 0;
      }
    });
    final library = ref.read(libraryRepositoryProvider);
    if (keep) {
      await library.decide(raw, Decision.kept);
    } else {
      await library.addToCart(raw);
    }
  }

  Future<void> _undo() async {
    if (_history.isEmpty) return;
    final (pair, kept) = _history.removeLast();
    final raw = pair.photos[1];
    _deck.currentState?.prepareReturn(
      kept ? SwipeChoice.keep : SwipeChoice.trash,
    );
    setState(() {
      _queue = [pair, ...?_queue];
      if (!kept) {
        _trashedCount--;
        _trashedBytes -= raw.sizeBytes ?? 0;
      }
    });
    final library = ref.read(libraryRepositoryProvider);
    if (kept) {
      await library.undecide(raw);
    } else {
      await library.removeFromCart(raw.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Thème sombre quel que soit le réglage : c'est le signe du mode RAW.
    return Theme(
      data: AppTheme.dark,
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final scheme = theme.colorScheme;
    final queue = _queue;
    final current = queue?.firstOrNull;
    final next = (queue?.length ?? 0) > 1 ? queue![1] : null;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.swipeClose,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.rawSortTitle),
        actions: [
          IconButton(
            tooltip: l10n.rawSortHelp,
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showIntro,
          ),
          IconButton(
            tooltip: l10n.swipeUndo,
            icon: const Icon(Icons.undo_rounded),
            onPressed: _history.isEmpty ? null : _undo,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: queue == null
                ? const Center(child: CircularProgressIndicator())
                : current == null
                ? _Done(
                    count: _trashedCount,
                    bytes: _trashedBytes,
                    onReview: () => context.pushReplacement(
                      AppRoutes.checkpoint(CheckpointOrigin.home),
                    ),
                    onClose: () => context.pop(),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: tidy.inkMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.rawSortJpgSafe,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: tidy.inkMuted,
                                ),
                              ),
                            ),
                            Text(
                              l10n.rawSortLeft(queue.length),
                              style: theme.textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SwipeDeck(
                            key: _deck,
                            currentKey: current.id,
                            nextKey: next?.id,
                            currentCard:
                                (
                                  context, {
                                  required isCurrent,
                                  stamp,
                                  strength = 0,
                                }) => _RawCard(
                                  pair: current,
                                  stamp: stamp,
                                  strength: strength,
                                ),
                            nextCard: next == null
                                ? null
                                : (context) => _RawCard(pair: next),
                            accepts: (c) => c != SwipeChoice.favorite,
                            onSwiped: _onSwiped,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _LabelledButton(
                              label: l10n.rawSortDelete,
                              child: SwipeRoundButton(
                                tooltip: l10n.rawSortDelete,
                                size: 64,
                                onPressed: () => _deck.currentState?.swipe(
                                  SwipeChoice.trash,
                                ),
                                border: BorderSide(
                                  color: tidy.delete,
                                  width: 2,
                                ),
                                background: scheme.surfaceContainer,
                                child: Icon(
                                  Icons.close_rounded,
                                  color: tidy.delete,
                                  size: 32,
                                ),
                              ),
                            ),
                            _LabelledButton(
                              label: l10n.rawSortKeep,
                              child: SwipeRoundButton(
                                tooltip: l10n.rawSortKeep,
                                size: 64,
                                onPressed: () =>
                                    _deck.currentState?.swipe(SwipeChoice.keep),
                                background: tidy.keep,
                                child: Icon(
                                  Icons.check_rounded,
                                  color: tidy.onKeep,
                                  size: 32,
                                ),
                              ),
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

/// Carte d'une paire : l'aperçu de la photo, un grand badge « RAW » et les
/// deux tailles, pour décider du RAW seul.
class _RawCard extends ConsumerWidget {
  const _RawCard({required this.pair, this.stamp, this.strength = 0});

  final PhotoItem pair;
  final SwipeChoice? stamp;
  final double strength;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final images = ref.watch(photoImagesProvider);
    final jpg = pair.photos[0];
    final raw = pair.photos[1];
    return SwipeCardFrame(
      caption:
          '${l10n.shortDate(pair.takenAt)} · '
          'RAW ${l10n.fileSize(raw.sizeBytes ?? 0).toUpperCase()}',
      stamp: stamp,
      strength: strength,
      trailing: [
        Text(
          l10n.rawSortJpgKept(l10n.fileSize(jpg.sizeBytes ?? 0)),
          style: theme.textTheme.labelMedium,
        ),
      ],
      // L'aperçu vient du JPG : la miniature d'un RAW n'est pas toujours
      // lisible, et c'est la même photo.
      image: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: images.large(jpg),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, _, _) =>
                const PhotoPlaceholder(icon: Icons.broken_image_outlined),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusThumbnail),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Text(
                  'RAW',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelledButton extends StatelessWidget {
  const _LabelledButton({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
      ],
    );
  }
}

/// L'explication du mode, la première fois (et via le bouton d'aide).
class _RawIntro extends StatelessWidget {
  const _RawIntro();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);

    Widget line(IconData icon, Color color, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.rawIntroTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.rawIntroBody,
              style: theme.textTheme.bodyMedium?.copyWith(color: tidy.inkMuted),
            ),
            const SizedBox(height: 20),
            line(Icons.arrow_back_rounded, tidy.delete, l10n.rawIntroLeft),
            line(Icons.arrow_forward_rounded, tidy.keep, l10n.rawIntroRight),
            line(
              Icons.lock_outline_rounded,
              theme.colorScheme.primary,
              l10n.rawIntroJpg,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.rawIntroStart),
            ),
          ],
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({
    required this.count,
    required this.bytes,
    required this.onReview,
    required this.onClose,
  });

  final int count;
  final int bytes;
  final VoidCallback onReview;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.rawSortDone,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (count > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.rawSortDoneBody(count, l10n.fileSize(bytes)),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tidy.inkMuted,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onReview,
                child: Text(l10n.rawSortReview),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(onPressed: onClose, child: Text(l10n.actionBack)),
          ],
        ),
      ),
    );
  }
}
