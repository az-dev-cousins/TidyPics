import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/gallery_photo.dart';
import '../../../data/providers.dart';
import '../../../data/sources/local_db.dart';
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
    this.history = const [],
    this.sortedCount = 0,
  });

  /// Photos restant à trier. La première est la carte affichée.
  final List<GalleryPhoto> queue;

  /// Dernières décisions, la plus récente à la fin.
  final List<SwipeRecord> history;

  /// Photos triées pendant cette session.
  final int sortedCount;

  /// Photos dans le panier (toutes sessions confondues).
  final int cartCount;

  /// Taille du panier à laquelle le checkpoint sera proposé.
  final int nextCheckpointAt;

  GalleryPhoto? get current => queue.firstOrNull;
  bool get isDone => queue.isEmpty;
  bool get canUndo => history.isNotEmpty;
  bool get checkpointDue => cartCount > 0 && cartCount >= nextCheckpointAt;

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

  int get _threshold => ref.read(settingsProvider).checkpointThreshold;

  @override
  Future<SwipeState> build() async {
    final library = ref.read(libraryRepositoryProvider);
    final order = ref.read(settingsProvider).sortOrder;
    final queue = await library.unsortedPhotos(order);
    final cartCount = (await library.cart()).length;
    final initial = SwipeState(
      queue: queue,
      cartCount: cartCount,
      nextCheckpointAt: _nextThreshold(cartCount),
    );
    unawaited(_prefetchSizes(initial.queue));
    return initial;
  }

  /// Prochain multiple du seuil, strictement au-dessus de [cartCount].
  int _nextThreshold(int cartCount) =>
      (cartCount ~/ _threshold + 1) * _threshold;

  SwipeState? get _ready => state.value;

  Future<void> decide(SwipeChoice choice) async {
    final current = _ready;
    final photo = current?.current;
    if (current == null || photo == null) return;

    final history = [...current.history, SwipeRecord(photo, choice)];
    if (history.length > undoDepth) history.removeAt(0);
    final queue = current.queue.sublist(1);
    final next = current.copyWith(
      queue: queue,
      history: history,
      sortedCount: current.sortedCount + 1,
      cartCount: current.cartCount + (choice == SwipeChoice.trash ? 1 : 0),
    );
    state = AsyncData(next);
    unawaited(_prefetchSizes(queue));

    final library = ref.read(libraryRepositoryProvider);
    switch (choice) {
      case SwipeChoice.keep:
        await library.decide(photo, Decision.kept);
      case SwipeChoice.favorite:
        await library.decide(photo, Decision.favorite);
        if (!photo.isFavorite) {
          await ref
              .read(gallerySourceProvider)
              .setFavorite(photo.id, favorite: true);
        }
      case SwipeChoice.trash:
        final sized = await _withSize(photo);
        await library.addToCart(sized);
    }
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
    switch (last.choice) {
      case SwipeChoice.keep:
        await library.undecide(last.photo);
      case SwipeChoice.favorite:
        await library.undecide(last.photo);
        if (!last.photo.isFavorite) {
          await ref
              .read(gallerySourceProvider)
              .setFavorite(last.photo.id, favorite: false);
        }
      case SwipeChoice.trash:
        await library.removeFromCart(last.photo.id);
    }
  }

  /// « Continuer » au checkpoint : il reviendra au prochain seuil.
  void postponeCheckpoint() {
    final current = _ready;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(nextCheckpointAt: _nextThreshold(current.cartCount)),
    );
  }

  /// À appeler au retour du checkpoint : le panier a pu être vidé, et les
  /// photos retirées du panier ne peuvent plus être annulées.
  Future<void> refreshCart() async {
    final current = _ready;
    if (current == null) return;
    final cart = await ref.read(libraryRepositoryProvider).cart();
    final inCart = cart.map((e) => e.photo.id).toSet();
    final latest = _ready ?? current;
    state = AsyncData(
      latest.copyWith(
        cartCount: cart.length,
        nextCheckpointAt: _nextThreshold(cart.length),
        // Une photo partie à la corbeille ne peut plus revenir dans la file.
        history: latest.history
            .where(
              (r) =>
                  r.choice != SwipeChoice.trash || inCart.contains(r.photo.id),
            )
            .toList(),
      ),
    );
  }

  Future<GalleryPhoto> _withSize(GalleryPhoto photo) async {
    if (photo.sizeBytes != null) return photo;
    final size = await ref.read(gallerySourceProvider).fileSize(photo.id);
    await ref.read(libraryRepositoryProvider).setSize(photo.id, size);
    return photo.copyWith(sizeBytes: size);
  }

  /// Lit la taille des prochaines photos, pour l'afficher sur la carte.
  Future<void> _prefetchSizes(List<GalleryPhoto> queue) async {
    final missing = queue
        .take(prefetch)
        .where((p) => p.sizeBytes == null)
        .toList();
    for (final photo in missing) {
      final sized = await _withSize(photo);
      final latest = _ready;
      if (latest == null) return;
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
