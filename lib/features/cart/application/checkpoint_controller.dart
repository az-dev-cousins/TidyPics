import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/gallery_photo.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../data/repositories/trash_repository.dart';
import '../../settings/application/settings_controller.dart';

/// Actions du récap (F3) : rendre des photos au tri, envoyer le reste à la
/// corbeille, proposer « Gestion des médias ».
class CheckpointActions {
  CheckpointActions(this._ref);

  final Ref _ref;

  /// Photos décochées au récap : elles quittent le panier et reviendront
  /// plus tard dans le tri.
  Future<void> release(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    await _ref.read(libraryRepositoryProvider).releaseFromCart(ids);
  }

  /// Vrai s'il faut expliquer « Gestion des médias » avant d'envoyer :
  /// Android 12+, pas encore accordée et jamais proposée.
  Future<bool> shouldOfferManageMedia() async {
    if (_ref.read(settingsProvider).manageMediaAsked) return false;
    final gallery = _ref.read(gallerySourceProvider);
    if (!await gallery.supportsManageMedia()) return false;
    return !await gallery.canManageMedia();
  }

  Future<void> requestManageMedia() async {
    await _ref.read(settingsProvider.notifier).markManageMediaAsked();
    await _ref.read(gallerySourceProvider).requestManageMedia();
  }

  Future<void> declineManageMedia() =>
      _ref.read(settingsProvider.notifier).markManageMediaAsked();

  /// Une suppression est en cours : la popup système met l'app en pause, il
  /// ne faut pas qu'une autre (envoi en quittant l'app) parte en même temps.
  static bool _busy = false;

  /// Envoie tout le panier à la corbeille système, en un seul lot.
  Future<TrashOutcome> trashAll(
    List<CartEntry> cart, {
    ValueChanged<double>? onProgress,
  }) async {
    if (_busy) return TrashOutcome.none;
    _busy = true;
    try {
      return await _trashAll(cart, onProgress);
    } finally {
      _busy = false;
    }
  }

  Future<TrashOutcome> _trashAll(
    List<CartEntry> cart,
    ValueChanged<double>? onProgress,
  ) async {
    final gallery = _ref.read(gallerySourceProvider);
    final library = _ref.read(libraryRepositoryProvider);
    final photos = <GalleryPhoto>[];
    for (final entry in cart) {
      var photo = entry.photo;
      if (entry.sizeBytes == 0) {
        final size = await gallery.fileSize(photo.id);
        await library.setSize(photo.id, size);
        photo = photo.copyWith(sizeBytes: size);
      }
      photos.add(photo);
    }
    final permanent =
        _ref.read(settingsProvider).deleteDirectly &&
        gallery.hasRestorableTrash;
    return _ref
        .read(trashRepositoryProvider)
        .trash(photos, permanent: permanent, onProgress: onProgress);
  }

  /// Tout le panier, tel qu'il est en base.
  Future<TrashOutcome> trashAllFromCart() async =>
      trashAll(await _ref.read(libraryRepositoryProvider).cart());

  /// Option Android 12+ : en quittant l'app, le panier part à la corbeille,
  /// sans popup grâce à « Gestion des médias ». Rien ne se passe sinon.
  Future<TrashOutcome> trashOnLeave() async {
    if (!_ref.read(settingsProvider).autoTrashOnLeave) return TrashOutcome.none;
    final gallery = _ref.read(gallerySourceProvider);
    if (!await gallery.canManageMedia()) return TrashOutcome.none;
    return trashAllFromCart();
  }
}

final checkpointActionsProvider = Provider<CheckpointActions>(
  CheckpointActions.new,
);
