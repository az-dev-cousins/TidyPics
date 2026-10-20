import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/gallery_photo.dart';
import '../../../data/models/photo_groups.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';
import '../../settings/application/settings_controller.dart';
import '../application/swipe_session.dart';
import 'swipe_card.dart';
import 'swipe_deck.dart';
import 'swipe_page.dart' show SwipeRoundButton;

/// Tri d'une rafale photo par photo (F5) : droite = garder, gauche = panier.
///
/// La bande du bas montre l'état de chaque photo ; un tap y revient. Une
/// fois toutes les photos décidées, un récap demande de valider. Renvoie
/// les identifiants gardés, ou `null` si l'on ferme sans valider.
class BurstPage extends ConsumerStatefulWidget {
  const BurstPage({super.key, required this.item});

  final PhotoItem item;

  @override
  ConsumerState<BurstPage> createState() => _BurstPageState();
}

class _BurstPageState extends ConsumerState<BurstPage> {
  final _deck = GlobalKey<SwipeDeckState>();
  late final List<GalleryPhoto> _photos = widget.item.photos;

  /// `true` gardée, `false` au panier, absente = pas encore décidée.
  final _kept = <String, bool>{};
  int _index = 0;

  /// Change à chaque geste : la pile repart avec une carte au centre, même
  /// quand on revient sur la même photo (récap puis « Revoir »).
  int _swipes = 0;

  @override
  void initState() {
    super.initState();
    if (!ref.read(settingsProvider).burstIntroSeen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showIntro());
      });
    }
  }

  Future<void> _showIntro() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _BurstIntro(),
    );
    await ref.read(settingsProvider.notifier).markBurstIntroSeen();
    if (mounted) unawaited(_deck.currentState?.nudge(SwipeChoice.keep));
  }

  bool get _allDecided => _photos.every((p) => _kept.containsKey(p.id));

  /// Prochaine photo sans décision après [from], en faisant le tour.
  int? _nextUndecided(int from) {
    for (var step = 1; step <= _photos.length; step++) {
      final i = (from + step) % _photos.length;
      if (!_kept.containsKey(_photos[i].id)) return i;
    }
    return null;
  }

  void _onSwiped(SwipeChoice choice) {
    setState(() {
      _kept[_photos[_index].id] = choice != SwipeChoice.trash;
      _swipes++;
      final next = _nextUndecided(_index);
      if (next != null) _index = next;
    });
    if (_allDecided) unawaited(_showRecap());
  }

  Future<void> _showRecap() async {
    final l10n = AppLocalizations.of(context);
    final kept = _kept.values.where((k) => k).length;
    final trashed = _photos.length - kept;
    final validate = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final tidy = TidyColors.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.burstRecapTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  l10n.burstRecapBody(kept, trashed),
                  style: theme.textTheme.bodyLarge,
                ),
                if (kept == 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.burstAllTrashed,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tidy.inkMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.burstValidate),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.burstReview),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (validate == true && mounted) {
      context.pop({
        for (final e in _kept.entries)
          if (e.value) e.key,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tidy = TidyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final current = _photos[_index];
    final nextIndex = _nextUndecided(_index);
    final next = nextIndex == null || nextIndex == _index
        ? null
        : _photos[nextIndex];

    return Scaffold(
      appBar: AppBar(
        // Retour au tri : la carte de la rafale y est toujours. La glisser
        // garde ou supprime toute la rafale d'un coup.
        leading: IconButton(
          tooltip: l10n.burstBack,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: l10n.rawSortHelp,
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showIntro,
          ),
          const SizedBox(width: 4),
        ],
        title: Text(l10n.swipeBurstBadge(_photos.length)),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    l10n.burstHint,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: tidy.inkMuted),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SwipeDeck(
                      key: _deck,
                      currentKey: '${current.id}-$_swipes',
                      nextKey: next?.id,
                      currentCard:
                          (
                            context, {
                            required isCurrent,
                            stamp,
                            strength = 0,
                          }) => PhotoSwipeCard(
                            photo: current,
                            stamp: stamp,
                            strength: strength,
                          ),
                      nextCard: next == null
                          ? null
                          : (context) => PhotoSwipeCard(photo: next),
                      // Pas de favori dans une rafale : garder ou panier.
                      accepts: (choice) => choice != SwipeChoice.favorite,
                      onSwiped: _onSwiped,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _StripTile(
                      photo: _photos[i],
                      kept: _kept[_photos[i].id],
                      current: i == _index,
                      onTap: () => setState(() {
                        _index = i;
                        _swipes++;
                      }),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SwipeRoundButton(
                        tooltip: l10n.swipeTrash,
                        size: 64,
                        onPressed: () =>
                            _deck.currentState?.swipe(SwipeChoice.trash),
                        border: BorderSide(color: tidy.delete, width: 2),
                        background: scheme.surfaceContainer,
                        child: Icon(
                          Icons.close_rounded,
                          color: tidy.delete,
                          size: 32,
                        ),
                      ),
                      SwipeRoundButton(
                        tooltip: l10n.swipeKeep,
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

/// Une vignette de la bande : gardée, au panier ou pas encore décidée.
class _StripTile extends StatelessWidget {
  const _StripTile({
    required this.photo,
    required this.kept,
    required this.current,
    required this.onTap,
  });

  final GalleryPhoto photo;
  final bool? kept;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tidy = TidyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = switch (kept) {
      true => l10n.burstStateKept,
      false => l10n.burstStateTrashed,
      null => l10n.burstStateUndecided,
    };
    return Semantics(
      button: true,
      selected: current,
      label: state,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 64,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: kept == false ? 0.35 : 1,
                child: PhotoThumbnail(photo: photo, size: 160),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusThumbnail),
                  border: Border.all(
                    // Photo en cours : contour encre, distinct du vert
                    // « gardée ».
                    color: current
                        ? scheme.onSurface
                        : kept == true
                        ? tidy.keep
                        : tidy.line,
                    width: current || kept == true ? 3 : 1,
                  ),
                ),
              ),
              if (kept != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: kept! ? tidy.keep : tidy.delete,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        kept! ? Icons.check_rounded : Icons.close_rounded,
                        size: 14,
                        color: kept! ? tidy.onKeep : scheme.onError,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'explication du tri d'une rafale, la première fois (puis via « ? »).
class _BurstIntro extends StatelessWidget {
  const _BurstIntro();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);

    Widget line(IconData icon, Color color, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              l10n.burstIntroTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.burstIntroBody,
              style: theme.textTheme.bodyMedium?.copyWith(color: tidy.inkMuted),
            ),
            const SizedBox(height: 20),
            line(Icons.arrow_forward_rounded, tidy.keep, l10n.burstIntroRight),
            line(Icons.arrow_back_rounded, tidy.delete, l10n.burstIntroLeft),
            line(
              Icons.view_carousel_outlined,
              theme.colorScheme.primary,
              l10n.burstIntroStrip,
            ),
            line(
              Icons.keyboard_return_rounded,
              theme.colorScheme.primary,
              l10n.burstIntroAll,
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
