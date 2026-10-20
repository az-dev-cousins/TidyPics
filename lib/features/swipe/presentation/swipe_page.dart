import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/checkpoint_page.dart';
import '../../gallery/application/gallery_controller.dart';
import '../application/swipe_session.dart';
import 'swipe_deck.dart';

/// Écran de tri par swipe (F1).
class SwipePage extends ConsumerStatefulWidget {
  const SwipePage({super.key});

  @override
  ConsumerState<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends ConsumerState<SwipePage> {
  final _deck = GlobalKey<SwipeDeckState>();
  bool _checkpointOpen = false;

  SwipeSession get _session => ref.read(swipeSessionProvider.notifier);

  Future<void> _openCheckpoint(CheckpointOrigin origin) async {
    if (_checkpointOpen) return;
    _checkpointOpen = true;
    final result = await context.push<CheckpointResult>(
      AppRoutes.checkpoint(origin),
    );
    _checkpointOpen = false;
    if (!mounted) return;
    // Fermé sans supprimer : le checkpoint reviendra au prochain seuil.
    if (origin == CheckpointOrigin.threshold &&
        result != CheckpointResult.trashed) {
      _session.postponeCheckpoint();
    }
    await _session.refreshCart();
    if (!mounted) return;
    // « Plus tard » ou fin de session : retour à l'accueil.
    if (result == CheckpointResult.later ||
        origin != CheckpointOrigin.threshold) {
      context.go(AppRoutes.home);
    }
  }

  /// Quitter le tri : checkpoint si le panier n'est pas vide.
  Future<void> _leave({required bool stop}) async {
    final cart = ref.read(swipeSessionProvider).value?.cartCount ?? 0;
    if (cart == 0) {
      context.go(AppRoutes.home);
      return;
    }
    await _openCheckpoint(
      stop ? CheckpointOrigin.stop : CheckpointOrigin.leave,
    );
  }

  void _press(SwipeChoice choice) => _deck.currentState?.swipe(choice);

  Future<void> _undo() async {
    final last = ref.read(swipeSessionProvider).value?.history.lastOrNull;
    if (last == null) return;
    _deck.currentState?.prepareReturn(last.choice);
    await _session.undo();
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
    final session = ref.watch(swipeSessionProvider);
    final cartBytes = ref.watch(librarySummaryProvider).value?.cartBytes ?? 0;

    ref.listen(swipeSessionProvider, (previous, next) {
      final was = previous?.value?.checkpointDue ?? false;
      if (!was && (next.value?.checkpointDue ?? false)) {
        unawaited(_openCheckpoint(CheckpointOrigin.threshold));
      }
    });

    final state = session.value;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave(stop: false));
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: l10n.swipeClose,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _leave(stop: false),
            ),
            title: state == null
                ? null
                : Text(
                    l10n.swipeCounter(
                      state.sortedCount,
                      l10n.fileSize(cartBytes),
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
            actions: [
              TextButton(
                onPressed: state == null ? null : () => _leave(stop: true),
                child: Text(l10n.swipeStop),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            top: false,
            child: switch (session) {
              AsyncData(value: final state) => _SwipeBody(
                state: state,
                deck: _deck,
                onSwiped: (choice) => _session.decide(choice),
                onPress: _press,
                onUndo: _undo,
                onSkip: _session.skip,
                onLeave: () => _leave(stop: true),
              ),
              AsyncError() => _Message(
                icon: Icons.error_outline_rounded,
                title: l10n.homeScanFailed,
                body: '',
                action: l10n.actionBackHome,
                onAction: () => context.go(AppRoutes.home),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
    );
  }
}

class _SwipeBody extends StatelessWidget {
  const _SwipeBody({
    required this.state,
    required this.deck,
    required this.onSwiped,
    required this.onPress,
    required this.onUndo,
    required this.onSkip,
    required this.onLeave,
  });

  final SwipeState state;
  final GlobalKey<SwipeDeckState> deck;
  final ValueChanged<SwipeChoice> onSwiped;
  final ValueChanged<SwipeChoice> onPress;
  final VoidCallback onUndo;
  final VoidCallback onSkip;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = state.current;

    final Widget content;
    if (current == null) {
      final nothingSorted = state.sortedCount == 0 && !state.canUndo;
      content = _Message(
        icon: nothingSorted
            ? Icons.photo_library_outlined
            : Icons.check_circle_outline_rounded,
        title: nothingSorted ? l10n.swipeEmptyTitle : l10n.swipeDoneTitle,
        body: nothingSorted ? l10n.swipeEmptyBody : l10n.swipeDoneBody,
        action: state.cartCount > 0 ? l10n.swipeStop : l10n.actionBackHome,
        onAction: onLeave,
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: SwipeDeck(
          key: deck,
          current: current,
          next: state.queue.length > 1 ? state.queue[1] : null,
          onSwiped: onSwiped,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: ConstrainedBox(
          // Tablette : la carte reste centrée, avec une largeur maximum.
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              Expanded(child: content),
              _ActionBar(
                enabled: current != null,
                canUndo: state.canUndo,
                canSkip: state.queue.length > 1,
                onPress: onPress,
                onUndo: onUndo,
                onSkip: onSkip,
              ),
            ],
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
          _RoundButton(
            tooltip: l10n.swipeTrash,
            size: 64,
            onPressed: enabled ? () => onPress(SwipeChoice.trash) : null,
            border: BorderSide(color: tidy.delete, width: 2),
            background: scheme.surfaceContainer,
            child: Icon(Icons.close_rounded, color: tidy.delete, size: 32),
          ),
          _RoundButton(
            tooltip: l10n.swipeFavorite,
            size: 52,
            onPressed: enabled ? () => onPress(SwipeChoice.favorite) : null,
            border: BorderSide(color: tidy.line),
            background: scheme.surfaceContainer,
            child: Icon(Icons.star_rounded, color: tidy.favorite, size: 28),
          ),
          _RoundButton(
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

class _RoundButton extends StatelessWidget {
  const _RoundButton({
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
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

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
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
