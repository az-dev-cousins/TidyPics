import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';
import '../../gallery/application/gallery_controller.dart';
import '../application/checkpoint_controller.dart';
import 'manage_media_sheet.dart';

/// D'où l'on arrive au checkpoint : ça change le titre et le second bouton.
enum CheckpointOrigin {
  /// Le panier a atteint le seuil pendant le tri.
  threshold,

  /// « Je m'arrête là ».
  stop,

  /// Sortie du tri (croix ou retour).
  leave,

  /// Ouverture de l'app avec un panier en attente.
  launch,

  /// Depuis l'accueil.
  home,
}

enum CheckpointResult { trashed, continued, later }

/// Récap du panier avant l'envoi à la corbeille (F3).
class CheckpointPage extends ConsumerStatefulWidget {
  const CheckpointPage({super.key, required this.origin});

  final CheckpointOrigin origin;

  @override
  ConsumerState<CheckpointPage> createState() => _CheckpointPageState();
}

class _CheckpointPageState extends ConsumerState<CheckpointPage> {
  bool _working = false;

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

  Future<void> _keep(CartEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _actions.keep(entry.photo);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.checkpointKept),
          action: SnackBarAction(
            label: l10n.actionUndo,
            onPressed: () => unawaited(_actions.putBack(entry.photo)),
          ),
        ),
      );
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
    if (cart.isEmpty || _working) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    try {
      final outcome = await _actions.trashAll(cart);
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
              l10n.photoCount(outcome.count),
              l10n.fileSize(outcome.bytes),
            ),
          ),
        ),
      );
      context.pop(CheckpointResult.trashed);
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
    final count = cart?.length ?? 0;
    final bytes = cart?.fold<int>(0, (s, e) => s + e.sizeBytes) ?? 0;
    final fromThreshold = widget.origin == CheckpointOrigin.threshold;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.origin == CheckpointOrigin.launch
              ? l10n.checkpointPendingTitle(count)
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
                                l10n.photoCount(count),
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
                            return Semantics(
                              button: true,
                              label:
                                  '${l10n.swipeKeep} · '
                                  '${l10n.shortDate(entry.photo.takenAt)}',
                              child: GestureDetector(
                                onTap: _working ? null : () => _keep(entry),
                                child: PhotoThumbnail(
                                  key: ValueKey(entry.photo.id),
                                  photo: entry.photo,
                                ),
                              ),
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
                  if (count > 0) ...[
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
                      onPressed: _working ? null : _onDelete,
                      icon: _working
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline_rounded),
                      label: Text(
                        _working
                            ? l10n.checkpointWorking
                            : l10n.checkpointDelete(
                                count,
                                l10n.fileSize(bytes),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextButton(
                    onPressed: _working
                        ? null
                        : () => context.pop(
                            fromThreshold
                                ? CheckpointResult.continued
                                : CheckpointResult.later,
                          ),
                    child: Text(
                      fromThreshold
                          ? l10n.checkpointContinue
                          : count == 0
                          ? l10n.actionBackHome
                          : l10n.checkpointLater,
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
