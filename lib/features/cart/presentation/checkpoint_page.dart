import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';
import '../../gallery/application/gallery_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../application/checkpoint_controller.dart';
import 'manage_media_sheet.dart';

/// D'où l'on arrive au récap : ça change le titre et le second bouton.
enum CheckpointOrigin {
  /// Le seuil de photos triées est atteint pendant le tri.
  threshold,

  /// « Je m'arrête là ».
  stop,

  /// Ouverture de l'app avec un panier en attente.
  launch,

  /// Depuis le menu.
  home,
}

enum CheckpointResult { trashed, continued, later }

/// Récap du panier avant l'envoi à la corbeille (F3).
///
/// Un tap décoche une photo : elle reste visible (on peut changer d'avis),
/// n'est pas supprimée et reviendra plus tard dans le tri.
class CheckpointPage extends ConsumerStatefulWidget {
  const CheckpointPage({super.key, required this.origin});

  final CheckpointOrigin origin;

  @override
  ConsumerState<CheckpointPage> createState() => _CheckpointPageState();
}

class _CheckpointPageState extends ConsumerState<CheckpointPage> {
  bool _working = false;

  /// Avancée de l'envoi, de 0 à 1 (`null` tant qu'elle est inconnue).
  double? _progress;
  bool _leaving = false;

  /// Photos décochées : pas supprimées, rendues au tri en partant.
  final _excluded = <String>{};

  /// L'utilisateur est parti accorder « Gestion des médias » : on supprime
  /// à son retour dans l'app.
  bool _awaitingManageMedia = false;
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () {
      if (_awaitingManageMedia) {
        _awaitingManageMedia = false;
        unawaited(_trash());
      }
    },
  );

  CheckpointActions get _actions => ref.read(checkpointActionsProvider);

  bool get _fromThreshold => widget.origin == CheckpointOrigin.threshold;

  @override
  void initState() {
    super.initState();
    _lifecycle; // Démarre l'écoute.
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  List<CartEntry> _selected(List<CartEntry> cart) =>
      cart.where((e) => !_excluded.contains(e.photo.id)).toList();

  /// « 2 photos et 1 vidéo ».
  String _items(AppLocalizations l10n, List<CartEntry> entries) {
    final videos = entries.where((e) => e.photo.isVideo).length;
    return l10n.items(photos: entries.length - videos, videos: videos);
  }

  void _toggle(CartEntry entry) {
    setState(() {
      if (!_excluded.remove(entry.photo.id)) _excluded.add(entry.photo.id);
    });
  }

  /// Quitte le récap sans supprimer : les photos décochées retournent au
  /// tri, les autres restent au panier.
  Future<void> _leave(CheckpointResult result) async {
    if (_leaving) return;
    _leaving = true;
    await _actions.release(_excluded);
    if (mounted) context.pop(result);
  }

  Future<void> _onDelete() async {
    if (await _actions.shouldOfferManageMedia()) {
      if (!mounted) return;
      final allow = await showManageMediaSheet(context);
      if (allow == true) {
        _awaitingManageMedia = true;
        await _actions.requestManageMedia();
        return;
      }
      await _actions.declineManageMedia();
    }
    await _trash();
  }

  Future<void> _trash() async {
    final cart = ref.read(cartProvider).value ?? const [];
    final selected = _selected(cart);
    if (selected.isEmpty || _working) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _working = true;
      _progress = null;
    });
    try {
      final outcome = await _actions.trashAll(
        selected,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      if (outcome.count == 0) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.checkpointRefused)));
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.checkpointDone(
              l10n.items(photos: outcome.photos, videos: outcome.videos),
              l10n.fileSize(outcome.bytes),
            ),
          ),
        ),
      );
      await _leave(CheckpointResult.trashed);
    } on Object catch (error) {
      debugPrint('Envoi à la corbeille impossible : $error');
      messenger.showSnackBar(SnackBar(content: Text(l10n.checkpointFailed)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final cart = ref.watch(cartProvider).value;
    final selected = cart == null ? const <CartEntry>[] : _selected(cart);
    final count = selected.length;
    final bytes = selected.fold<int>(0, (s, e) => s + e.sizeBytes);
    final permanent =
        ref.watch(settingsProvider.select((s) => s.deleteDirectly)) &&
        !Platform.isIOS;
    final laterResult = _fromThreshold
        ? CheckpointResult.continued
        : CheckpointResult.later;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_working) unawaited(_leave(laterResult));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.origin == CheckpointOrigin.launch
                ? l10n.checkpointPendingTitle(_items(l10n, cart ?? const []))
                : l10n.checkpointTitle,
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: cart == null
                  ? const Center(child: CircularProgressIndicator())
                  : cart.isEmpty
                  ? Center(
                      child: Text(
                        l10n.checkpointEmpty,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: tidy.inkMuted,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.checkpointSummary(
                                  _items(l10n, selected),
                                  l10n.fileSize(bytes),
                                ),
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.checkpointHint,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: tidy.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 120,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                ),
                            itemCount: cart.length,
                            itemBuilder: (context, i) {
                              final entry = cart[i];
                              return _CartTile(
                                key: ValueKey(entry.photo.id),
                                entry: entry,
                                excluded: _excluded.contains(entry.photo.id),
                                onTap: _working ? null : () => _toggle(entry),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (cart != null && cart.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.restore_rounded,
                            size: 18,
                            color: tidy.inkMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              Platform.isIOS
                                  ? l10n.checkpointSafetyIos
                                  : permanent
                                  ? l10n.checkpointSafetyPermanent
                                  : l10n.checkpointSafetyAndroid,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tidy.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: tidy.delete,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        onPressed: _working || count == 0 ? null : _onDelete,
                        icon: _working
                            ? SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: _progress,
                                ),
                              )
                            : const Icon(Icons.delete_outline_rounded),
                        label: Text(
                          _working
                              ? _progress == null
                                    ? l10n.checkpointWorking
                                    : l10n.checkpointWorkingProgress(
                                        (_progress! * 100).floor(),
                                      )
                              : l10n.checkpointDelete(
                                  _items(l10n, selected),
                                  l10n.fileSize(bytes),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextButton(
                      onPressed: _working ? null : () => _leave(laterResult),
                      child: Text(
                        _fromThreshold
                            ? l10n.checkpointContinue
                            : cart == null || cart.isEmpty
                            ? l10n.actionBack
                            : l10n.checkpointLater,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Une photo du panier : cochée (sera supprimée) ou décochée (reviendra
/// plus tard dans le tri).
class _CartTile extends StatelessWidget {
  const _CartTile({
    super.key,
    required this.entry,
    required this.excluded,
    required this.onTap,
  });

  final CartEntry entry;
  final bool excluded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tidy = TidyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      toggled: !excluded,
      label:
          '${l10n.shortDate(entry.photo.takenAt)} · '
          '${excluded ? l10n.checkpointExcluded : l10n.checkpointIncluded}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: excluded ? 0.35 : 1,
              child: PhotoThumbnail(photo: entry.photo),
            ),
            // Coin haut droit : ✕ = sera supprimée, ↺ = revient au tri.
            Positioned(
              top: 6,
              right: 6,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: DecoratedBox(
                  key: ValueKey(excluded),
                  decoration: BoxDecoration(
                    color: excluded ? scheme.surfaceContainer : tidy.delete,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.surfaceContainer,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      excluded ? Icons.undo_rounded : Icons.close_rounded,
                      size: 16,
                      color: excluded ? tidy.inkMuted : scheme.onError,
                    ),
                  ),
                ),
              ),
            ),
            // Badge RAW : distingue les deux fichiers d'une paire JPG + RAW.
            if (entry.photo.isRaw)
              Positioned(
                left: 6,
                top: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      l10n.swipeRaw,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onPrimary),
                    ),
                  ),
                ),
              ),
            if (excluded)
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Text(
                  l10n.checkpointExcludedShort,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurface),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      AppTheme.radiusThumbnail,
                    ),
                    border: Border.all(
                      color: excluded ? tidy.line : tidy.delete,
                      width: excluded ? 1 : 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
