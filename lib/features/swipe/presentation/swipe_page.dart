import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/gallery_photo.dart';
import '../../../data/models/photo_groups.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';
import '../../cart/presentation/checkpoint_page.dart';
import '../../gallery/application/gallery_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../application/swipe_session.dart';
import 'photo_actions.dart';
import 'session_panel.dart';
import 'swipe_card.dart';
import 'swipe_deck.dart';

/// Le récap « photos en attente » n'est proposé qu'une fois par ouverture
/// de l'app (F3).
class LaunchCheckpoint extends Notifier<bool> {
  @override
  bool build() => false;

  /// Renvoie `true` la première fois seulement.
  bool claim() {
    if (state) return false;
    state = true;
    return true;
  }
}

final launchCheckpointProvider = NotifierProvider<LaunchCheckpoint, bool>(
  LaunchCheckpoint.new,
);

/// Écran de tri par swipe (F1) : l'écran principal de l'app, ou le tri
/// d'un seul mois (F2) quand [scope] le précise.
class SwipePage extends ConsumerStatefulWidget {
  const SwipePage({super.key, this.scope = const SwipeScope.all()});

  final SwipeScope scope;

  @override
  ConsumerState<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends ConsumerState<SwipePage> {
  final _deck = GlobalKey<SwipeDeckState>();
  bool _checkpointOpen = false;

  SwipeScope get _scope => widget.scope;
  bool get _isMonth => _scope.isMonth;

  /// Un mois ou les captures : ouvert depuis le menu, on y revient à la fin.
  bool get _isFocused => _scope.isFocused;
  SwipeSession get _session => ref.read(swipeSessionProvider(_scope).notifier);

  @override
  void initState() {
    super.initState();
    if (!_isFocused) unawaited(_maybeShowPendingCart());
  }

  /// Ouverture de l'app avec des photos encore au panier : récap.
  Future<void> _maybeShowPendingCart() async {
    final cart = await ref.read(libraryRepositoryProvider).cart();
    if (!mounted || cart.isEmpty) return;
    if (!ref.read(launchCheckpointProvider.notifier).claim()) return;
    await _openCheckpoint(CheckpointOrigin.launch);
  }

  Future<void> _openCheckpoint(CheckpointOrigin origin) async {
    if (_checkpointOpen) return;
    _checkpointOpen = true;
    final result = await context.push<CheckpointResult>(
      AppRoutes.checkpoint(origin),
    );
    _checkpointOpen = false;
    if (!mounted) return;
    // Fermé sans supprimer : le récap reviendra au prochain seuil.
    if (origin == CheckpointOrigin.threshold &&
        result != CheckpointResult.trashed) {
      _session.postponeCheckpoint();
    }
    await _session.refreshCart();
    if (!mounted) return;
    if (origin == CheckpointOrigin.stop) _endSession();
  }

  /// Fin de session : un mois revient à la liste des mois, sinon le menu.
  void _endSession() {
    if (_isFocused) {
      context.pop();
      return;
    }
    // La prochaine session repartira de zéro.
    ref.invalidate(swipeSessionProvider(_scope));
    unawaited(context.push(AppRoutes.home));
  }

  /// « Je m'arrête là » : récap si le panier n'est pas vide.
  Future<void> _stop() async {
    final cart = ref.read(swipeSessionProvider(_scope)).value?.cartCount ?? 0;
    if (cart == 0) {
      _endSession();
      return;
    }
    await _openCheckpoint(CheckpointOrigin.stop);
  }

  void _press(SwipeChoice choice) => _deck.currentState?.swipe(choice);

  Future<void> _undo() async {
    final last = ref
        .read(swipeSessionProvider(_scope))
        .value
        ?.history
        .lastOrNull;
    if (last == null) return;
    _deck.currentState?.prepareReturn(last.choice ?? SwipeChoice.keep);
    await _session.undo();
  }

  /// Rafale : tri photo par photo, puis on passe à l'élément suivant.
  Future<void> _pickBest(PhotoItem item) async {
    final kept = await context.push<Set<String>>(AppRoutes.burst, extra: item);
    if (kept != null && mounted) await _session.resolveGroup(kept);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _press(SwipeChoice.trash);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _press(SwipeChoice.keep);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _press(SwipeChoice.favorite);
    } else if (key == LogicalKeyboardKey.backspace) {
      unawaited(_undo());
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = swipeSessionProvider(_scope);
    final session = ref.watch(provider);
    final cartBytes = ref.watch(librarySummaryProvider).value?.cartBytes ?? 0;

    ref
      ..listen(provider, (previous, next) {
        final was = previous?.value?.checkpointDue ?? false;
        if (!was && (next.value?.checkpointDue ?? false)) {
          unawaited(_openCheckpoint(CheckpointOrigin.threshold));
        }
      })
      // Réglages du tri changés : nouvelle session.
      ..listen(
        settingsProvider.select(
          (s) => (
            s.sortOrder,
            s.checkpointThreshold,
            s.groupBursts,
            s.burstGapSeconds,
          ),
        ),
        (_, _) => ref.invalidate(provider),
      );

    final state = session.value;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          leading: _isFocused
              ? const BackButton()
              : IconButton(
                  tooltip: l10n.swipeMenu,
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => context.push(AppRoutes.home),
                ),
          title: _isMonth
              ? Text(l10n.monthName(DateTime(_scope.year!, _scope.month!)))
              : _scope.screenshots
              ? Text(l10n.screenshotsTitle)
              : _scope.duplicates
              ? Text(l10n.duplicatesTitle)
              : null,
          actions: [
            TextButton(
              onPressed: state == null ? null : _stop,
              child: Text(l10n.swipeStop),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: switch (session) {
            AsyncData(value: final state) => LayoutBuilder(
              builder: (context, constraints) {
                // Tablette en paysage : le panier et la session à droite.
                final wide = SessionPanel.fits(constraints);
                final deck = Center(
                  child: ConstrainedBox(
                    // Tablette : la carte reste centrée, avec une largeur
                    // maximum.
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: [
                        if (!wide)
                          _SessionBar(
                            state: state,
                            cartBytes: cartBytes,
                            onCartTap: () =>
                                _openCheckpoint(CheckpointOrigin.home),
                          ),
                        Expanded(child: _content(state)),
                        _ActionBar(
                          enabled: state.current != null,
                          canUndo: state.canUndo,
                          canSkip: state.queue.length > 1,
                          onPress: _press,
                          onUndo: _undo,
                          onSkip: _session.skip,
                        ),
                      ],
                    ),
                  ),
                );
                if (!wide) return deck;
                return Row(
                  children: [
                    Expanded(child: deck),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: SessionPanel.width,
                      child: SessionPanel(
                        state: state,
                        onOpenCart: () =>
                            _openCheckpoint(CheckpointOrigin.home),
                      ),
                    ),
                  ],
                );
              },
            ),
            AsyncError() => _Message(
              icon: Icons.error_outline_rounded,
              title: l10n.homeScanFailed,
              body: '',
              action: l10n.swipeMenu,
              onAction: () => context.push(AppRoutes.home),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }

  Widget _content(SwipeState state) {
    final l10n = AppLocalizations.of(context);
    final current = state.current;
    if (state.waitingForGallery) {
      return _Message(
        icon: Icons.photo_library_outlined,
        title: l10n.homeScanning,
        body: '',
        loading: true,
      );
    }
    if (current == null) {
      final nothingSorted = state.sortedCount == 0 && !state.canUndo;
      return _Message(
        icon: nothingSorted
            ? Icons.photo_library_outlined
            : Icons.check_circle_outline_rounded,
        title: _isMonth
            ? l10n.monthDoneTitle
            : _scope.screenshots
            ? l10n.screenshotsDoneTitle
            : _scope.duplicates
            ? l10n.duplicatesDoneTitle
            : nothingSorted
            ? l10n.swipeEmptyTitle
            : l10n.swipeDoneTitle,
        body: _isFocused
            ? ''
            : nothingSorted
            ? l10n.swipeEmptyBody
            : l10n.swipeDoneBody,
        action: state.cartCount > 0
            ? l10n.swipeStop
            : _isMonth
            ? l10n.monthBack
            : l10n.swipeMenu,
        onAction: _stop,
      );
    }
    final next = state.queue.length > 1 ? state.queue[1] : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: _Precache(
        photo: next?.cover,
        child: SwipeDeck(
          key: _deck,
          currentKey: current.id,
          nextKey: next?.id,
          currentCard: (context, {required isCurrent, stamp, strength = 0}) =>
              GestureDetector(
                // Appui long : partager, ouvrir dans la galerie.
                onLongPress: () =>
                    showPhotoActions(context, ref, current.cover),
                child: ItemSwipeCard(
                  item: current,
                  badge: _scope.duplicates ? l10n.duplicateCopyBadge : null,
                  stamp: stamp,
                  strength: strength,
                  play: isCurrent,
                  onPickBest: () => _pickBest(current),
                  onMore: () => showPhotoActions(context, ref, current.cover),
                ),
              ),
          nextCard: next == null
              ? null
              : (context) => ItemSwipeCard(item: next),
          onSwiped: _session.decide,
        ),
      ),
    );
  }
}

/// Décode la photo d'après avant qu'elle soit visible : aucun écran blanc.
class _Precache extends ConsumerStatefulWidget {
  const _Precache({required this.photo, required this.child});

  final GalleryPhoto? photo;
  final Widget child;

  @override
  ConsumerState<_Precache> createState() => _PrecacheState();
}

class _PrecacheState extends ConsumerState<_Precache> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache();
  }

  @override
  void didUpdateWidget(_Precache oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo?.id != widget.photo?.id) _precache();
  }

  void _precache() {
    final photo = widget.photo;
    if (photo == null) return;
    final image = ref.read(photoImagesProvider).large(photo);
    unawaited(precacheImage(image, context, onError: (_, _) {}));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// En haut du tri : photos triées, panier, et avancée vers le récap.
class _SessionBar extends StatelessWidget {
  const _SessionBar({
    required this.state,
    required this.cartBytes,
    required this.onCartTap,
  });

  final SwipeState state;
  final int cartBytes;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final left = state.nextCheckpointAt - state.sortedCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Pill(
                icon: Icon(Icons.check_rounded, size: 18, color: tidy.keep),
                text: l10n.swipeSorted(state.sortedCount),
              ),
              const Spacer(),
              _Pill(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: tidy.delete,
                ),
                text: state.cartCount == 0
                    ? l10n.homeCartEmpty
                    : '${state.cartCount} · ${l10n.fileSize(cartBytes)}',
                semanticLabel: l10n.homeCart,
                onTap: state.cartCount == 0 ? null : onCartTap,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(end: state.checkpointProgress),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: tidy.line,
              ),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: state.cartCount > 0 ? 1 : 0,
            child: Text(
              l10n.swipeCheckpointIn(left < 1 ? 1 : left),
              style: theme.textTheme.labelSmall?.copyWith(color: tidy.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.text,
    this.semanticLabel,
    this.onTap,
  });

  final Widget icon;
  final String text;
  final String? semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        shape: StadiumBorder(side: BorderSide(color: tidy.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.8, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    text,
                    key: ValueKey(text),
                    style: theme.textTheme.labelLarge,
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

/// Un bouton pour chaque geste (accessibilité), plus annuler et passer.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.enabled,
    required this.canUndo,
    required this.canSkip,
    required this.onPress,
    required this.onUndo,
    required this.onSkip,
  });

  final bool enabled;
  final bool canUndo;
  final bool canSkip;
  final ValueChanged<SwipeChoice> onPress;
  final VoidCallback onUndo;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tidy = TidyColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            tooltip: l10n.swipeUndo,
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo_rounded),
          ),
          SwipeRoundButton(
            tooltip: l10n.swipeTrash,
            size: 64,
            onPressed: enabled ? () => onPress(SwipeChoice.trash) : null,
            border: BorderSide(color: tidy.delete, width: 2),
            background: scheme.surfaceContainer,
            child: Icon(Icons.close_rounded, color: tidy.delete, size: 32),
          ),
          SwipeRoundButton(
            tooltip: l10n.swipeFavorite,
            size: 52,
            onPressed: enabled ? () => onPress(SwipeChoice.favorite) : null,
            border: BorderSide(color: tidy.line),
            background: scheme.surfaceContainer,
            child: Icon(Icons.star_rounded, color: tidy.favorite, size: 28),
          ),
          SwipeRoundButton(
            tooltip: l10n.swipeKeep,
            size: 64,
            onPressed: enabled ? () => onPress(SwipeChoice.keep) : null,
            background: tidy.keep,
            child: Icon(Icons.check_rounded, color: tidy.onKeep, size: 32),
          ),
          IconButton(
            tooltip: l10n.swipeSkip,
            onPressed: enabled && canSkip ? onSkip : null,
            icon: const Icon(Icons.redo_rounded),
          ),
        ],
      ),
    );
  }
}

/// Bouton rond du tri (supprimer, favori, garder).
class SwipeRoundButton extends StatelessWidget {
  const SwipeRoundButton({
    super.key,
    required this.tooltip,
    required this.size,
    required this.onPressed,
    required this.background,
    required this.child,
    this.border = BorderSide.none,
  });

  final String tooltip;
  final double size;
  final VoidCallback? onPressed;
  final Color background;
  final BorderSide border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onPressed == null ? 0.4 : 1,
        child: Material(
          color: background,
          shape: CircleBorder(side: border),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Semantics(
              button: true,
              label: tooltip,
              excludeSemantics: true,
              child: SizedBox.square(
                dimension: size,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tidy.inkMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (loading) ...[
              const SizedBox(height: 24),
              const SizedBox(width: 160, child: LinearProgressIndicator()),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
