import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/gallery_photo.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../data/sources/local_db.dart';
import '../../gallery/application/gallery_controller.dart';
import '../../settings/application/settings_controller.dart';

/// Ce que l'utilisateur fait d'une photo pendant le tri (F1).
enum SwipeChoice {
  /// Swipe droite.
  keep,

  /// Swipe haut : garder et mettre en favori système.
  favorite,

  /// Swipe gauche : au panier de suppression.
  trash,
}

@immutable
class SwipeRecord {
  const SwipeRecord(this.photo, this.choice);

  /// La photo telle qu'elle était avant la décision.
  final GalleryPhoto photo;
  final SwipeChoice choice;
}

@immutable
class SwipeState {
  const SwipeState({
    required this.queue,
    required this.cartCount,
    required this.nextCheckpointAt,
    required this.threshold,
    this.history = const [],
    this.sortedCount = 0,
    this.waitingForGallery = false,
  });

  /// Photos restant à trier. La première est la carte affichée.
  final List<GalleryPhoto> queue;

  /// Dernières décisions, la plus récente à la fin.
  final List<SwipeRecord> history;

  /// Photos triées pendant cette session.
  final int sortedCount;

  /// Photos dans le panier (toutes sessions confondues).
  final int cartCount;

  /// Nombre de photos triées auquel le récap sera proposé.
  final int nextCheckpointAt;

  /// Écart entre deux récaps (réglage).
  final int threshold;

  /// Premier lancement : la galerie n'est pas encore lue.
  final bool waitingForGallery;

  GalleryPhoto? get current => queue.firstOrNull;
  bool get isDone => queue.isEmpty && !waitingForGallery;
  bool get canUndo => history.isNotEmpty;
  bool get checkpointDue => cartCount > 0 && sortedCount >= nextCheckpointAt;

  /// Avancée vers le prochain récap (0 à 1).
  double get checkpointProgress =>
      (1 - (nextCheckpointAt - sortedCount) / threshold).clamp(0, 1).toDouble();

  SwipeState copyWith({
    List<GalleryPhoto>? queue,
    List<SwipeRecord>? history,
    int? sortedCount,
    int? cartCount,
    int? nextCheckpointAt,
  }) => SwipeState(
    queue: queue ?? this.queue,
    history: history ?? this.history,
    sortedCount: sortedCount ?? this.sortedCount,
    cartCount: cartCount ?? this.cartCount,
    nextCheckpointAt: nextCheckpointAt ?? this.nextCheckpointAt,
    threshold: threshold,
    waitingForGallery: waitingForGallery,
  );
}

/// Une session de tri : la file de photos et les décisions prises.
///
/// L'état change tout de suite, et chaque décision est enregistrée sur le
/// téléphone dans la foulée : un kill de l'app ne perd rien.
class SwipeSession extends AsyncNotifier<SwipeState> {
  /// Nombre de décisions que l'on peut annuler.
  static const undoDepth = 10;

  /// Photos dont on lit la taille à l'avance.
  static const prefetch = 3;

  /// Écritures en cours : le panier en base peut être en retard sur l'état.
  int _pendingWrites = 0;

  /// Incrémenté à chaque nouvelle session : une lecture lancée par une
  /// session précédente ne touche pas à la suivante.
  int _generation = 0;

  int get _threshold => ref.read(settingsProvider).checkpointThreshold;

  @override
  Future<SwipeState> build() async {
    final generation = ++_generation;
    var building = true;
    var scanEndedWhileBuilding = false;

    ref
      // Galerie lue après le début de la session (premier lancement, photos
      // ajoutées) : on recharge si la file était vide.
      ..listen(gallerySyncProvider, (previous, next) {
        if (next != SyncStatus.done) return;
        if (building) {
          scanEndedWhileBuilding = true;
          return;
        }
        final current = state.value;
        if (current != null &&
            current.queue.isEmpty &&
            current.sortedCount == 0) {
          ref.invalidateSelf();
        }
      })
      // Panier modifié ailleurs (récap, menu) : on suit.
      ..listen(cartProvider, (previous, next) {
        final cart = next.value;
        if (cart != null && _pendingWrites == 0) _syncCart(cart);
      });

    final library = ref.read(libraryRepositoryProvider);
    final order = ref.read(settingsProvider).sortOrder;
    var queue = await library.unsortedPhotos(order);
    final cartCount = (await library.cart()).length;
    // Le scan s'est terminé pendant la lecture : on relit la file.
    if (queue.isEmpty && scanEndedWhileBuilding) {
      queue = await library.unsortedPhotos(order);
    }
    building = false;

    final initial = SwipeState(
      queue: queue,
      cartCount: cartCount,
      nextCheckpointAt: _threshold,
      threshold: _threshold,
      waitingForGallery:
          queue.isEmpty && ref.read(gallerySyncProvider) != SyncStatus.done,
    );
    unawaited(_prefetchSizes(initial.queue, generation));
    return initial;
  }

  SwipeState? get _ready => state.value;

  Future<T> _write<T>(Future<T> Function() write) async {
    _pendingWrites++;
    try {
      return await write();
    } finally {
      _pendingWrites--;
    }
  }

  Future<void> decide(SwipeChoice choice) async {
    final current = _ready;
    final photo = current?.current;
    if (current == null || photo == null) return;

    final history = [...current.history, SwipeRecord(photo, choice)];
    if (history.length > undoDepth) history.removeAt(0);
    final queue = current.queue.sublist(1);
    var next = current.copyWith(
      queue: queue,
      history: history,
      sortedCount: current.sortedCount + 1,
      cartCount: current.cartCount + (choice == SwipeChoice.trash ? 1 : 0),
    );
    // Seuil atteint sans rien au panier : pas de récap, on repousse.
    if (next.sortedCount >= next.nextCheckpointAt && next.cartCount == 0) {
      next = next.copyWith(nextCheckpointAt: next.sortedCount + _threshold);
    }
    state = AsyncData(next);
    unawaited(_prefetchSizes(queue, _generation));

    final library = ref.read(libraryRepositoryProvider);
    final gallery = ref.read(gallerySourceProvider);
    await _write(() async {
      switch (choice) {
        case SwipeChoice.keep:
          await library.decide(photo, Decision.kept);
        case SwipeChoice.favorite:
          await library.decide(photo, Decision.favorite);
          if (!photo.isFavorite) {
            await gallery.setFavorite(photo.id, favorite: true);
          }
        case SwipeChoice.trash:
          final sized = await _withSize(photo);
          await library.addToCart(sized);
      }
    });
  }

  /// « Passer » : pas de décision, la photo reviendra en fin de file.
  void skip() {
    final current = _ready;
    if (current == null || current.queue.length < 2) return;
    state = AsyncData(
      current.copyWith(
        queue: [...current.queue.sublist(1), current.queue.first],
      ),
    );
  }

  /// Annule la dernière décision : la photo revient en tête de file.
  Future<void> undo() async {
    final current = _ready;
    if (current == null || !current.canUndo) return;
    final last = current.history.last;
    final wasTrash = last.choice == SwipeChoice.trash;
    state = AsyncData(
      current.copyWith(
        queue: [last.photo, ...current.queue],
        history: current.history.sublist(0, current.history.length - 1),
        sortedCount: current.sortedCount - 1,
        cartCount: current.cartCount - (wasTrash ? 1 : 0),
      ),
    );

    final library = ref.read(libraryRepositoryProvider);
    final gallery = ref.read(gallerySourceProvider);
    await _write(() async {
      switch (last.choice) {
        case SwipeChoice.keep:
          await library.undecide(last.photo);
        case SwipeChoice.favorite:
          await library.undecide(last.photo);
          if (!last.photo.isFavorite) {
            await gallery.setFavorite(last.photo.id, favorite: false);
          }
        case SwipeChoice.trash:
          await library.removeFromCart(last.photo.id);
      }
    });
  }

  /// Récap fermé sans supprimer : il reviendra au prochain seuil.
  void postponeCheckpoint() {
    final current = _ready;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(nextCheckpointAt: current.sortedCount + _threshold),
    );
  }

  /// Relit le panier en base (après le récap).
  Future<void> refreshCart() async =>
      _syncCart(await ref.read(libraryRepositoryProvider).cart());

  void _syncCart(List<CartEntry> cart) {
    final current = _ready;
    if (current == null) return;
    final inCart = cart.map((e) => e.photo.id).toSet();
    // Une photo partie à la corbeille ou rendue au tri ne peut plus être
    // annulée depuis la session.
    final history = current.history
        .where(
          (r) => r.choice != SwipeChoice.trash || inCart.contains(r.photo.id),
        )
        .toList();
    if (cart.length == current.cartCount &&
        history.length == current.history.length) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        cartCount: cart.length,
        history: history,
        nextCheckpointAt: cart.isEmpty
            ? current.sortedCount + _threshold
            : current.nextCheckpointAt,
      ),
    );
  }

  Future<GalleryPhoto> _withSize(GalleryPhoto photo) async {
    if (photo.sizeBytes != null) return photo;
    final library = ref.read(libraryRepositoryProvider);
    final size = await ref.read(gallerySourceProvider).fileSize(photo.id);
    await library.setSize(photo.id, size);
    return photo.copyWith(sizeBytes: size);
  }

  /// Lit la taille des prochaines photos, pour l'afficher sur la carte.
  Future<void> _prefetchSizes(List<GalleryPhoto> queue, int generation) async {
    final missing = queue
        .take(prefetch)
        .where((p) => p.sizeBytes == null)
        .toList();
    for (final photo in missing) {
      final GalleryPhoto sized;
      try {
        sized = await _withSize(photo);
      } on Object catch (error) {
        // Simple confort d'affichage : on n'interrompt pas le tri pour ça.
        debugPrint('Taille illisible pour ${photo.id} : $error');
        return;
      }
      if (!ref.mounted) return;
      final latest = _ready;
      if (latest == null || generation != _generation) return;
      state = AsyncData(
        latest.copyWith(
          queue: [for (final p in latest.queue) p.id == sized.id ? sized : p],
          history: [
            for (final r in latest.history)
              r.photo.id == sized.id ? SwipeRecord(sized, r.choice) : r,
          ],
        ),
      );
    }
  }
}

final swipeSessionProvider =
    AsyncNotifierProvider.autoDispose<SwipeSession, SwipeState>(
      SwipeSession.new,
    );
