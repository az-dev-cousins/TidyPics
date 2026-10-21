import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/achievements.dart';
import '../../../data/models/duplicates.dart';
import '../../../data/models/gallery_photo.dart';
import '../../../data/models/photo_groups.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../data/sources/local_db.dart';
import '../../gallery/application/gallery_controller.dart';
import '../../settings/application/settings_controller.dart';

/// Ce que l'utilisateur fait d'un élément pendant le tri (F1).
enum SwipeChoice {
  /// Swipe droite.
  keep,

  /// Swipe haut : garder et mettre en favori système.
  favorite,

  /// Swipe gauche : au panier de suppression.
  trash,
}

/// Les tris ciblés, ouverts depuis le menu.
enum SwipeFocus { month, screenshots, duplicates }

/// Ce qu'on trie : toute la galerie, ou une partie (un mois, les captures,
/// les doublons).
@immutable
class SwipeScope {
  const SwipeScope.all() : year = null, month = null, focus = null;
  const SwipeScope.month(int this.year, int this.month)
    : focus = SwipeFocus.month;

  /// Seulement les captures d'écran (F14).
  const SwipeScope.screenshots()
    : year = null,
      month = null,
      focus = SwipeFocus.screenshots;

  /// Seulement les copies des doublons : l'original reste gardé (F11).
  const SwipeScope.duplicates()
    : year = null,
      month = null,
      focus = SwipeFocus.duplicates;

  final int? year;
  final int? month;
  final SwipeFocus? focus;

  bool get isMonth => focus == SwipeFocus.month;
  bool get screenshots => focus == SwipeFocus.screenshots;
  bool get duplicates => focus == SwipeFocus.duplicates;

  /// Une partie de la galerie seulement : on y entre depuis le menu et on y
  /// revient à la fin.
  bool get isFocused => focus != null;

  @override
  bool operator ==(Object other) =>
      other is SwipeScope &&
      other.year == year &&
      other.month == month &&
      other.focus == focus;

  @override
  int get hashCode => Object.hash(year, month, focus);
}

@immutable
class SwipeRecord {
  const SwipeRecord(this.item, this.choice) : keptIds = null;

  /// Rafale triée photo par photo : [keptIds] gardées, les autres au panier.
  const SwipeRecord.resolved(this.item, Set<String> this.keptIds)
    : choice = null;

  /// L'élément tel qu'il était avant la décision.
  final PhotoItem item;
  final SwipeChoice? choice;
  final Set<String>? keptIds;

  /// Photos de l'élément parties au panier.
  Iterable<GalleryPhoto> get trashed => item.photos.where(
    (p) => choice == SwipeChoice.trash || (keptIds?.contains(p.id) == false),
  );
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

  /// Éléments restant à trier. Le premier est la carte affichée.
  final List<PhotoItem> queue;

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

  PhotoItem? get current => queue.firstOrNull;
  bool get isDone => queue.isEmpty && !waitingForGallery;
  bool get canUndo => history.isNotEmpty;
  bool get checkpointDue => cartCount > 0 && sortedCount >= nextCheckpointAt;

  /// Avancée vers le prochain récap (0 à 1).
  double get checkpointProgress =>
      (1 - (nextCheckpointAt - sortedCount) / threshold).clamp(0, 1).toDouble();

  SwipeState copyWith({
    List<PhotoItem>? queue,
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

/// Une session de tri : la file d'éléments et les décisions prises.
///
/// L'état change tout de suite, et chaque décision est enregistrée sur le
/// téléphone dans la foulée : un kill de l'app ne perd rien.
class SwipeSession extends AsyncNotifier<SwipeState> {
  SwipeSession(this.scope);

  final SwipeScope scope;

  /// Nombre de décisions que l'on peut annuler.
  static const undoDepth = 10;

  /// Éléments dont on lit la taille à l'avance.
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
    var queue = await _loadQueue(library);
    final cartCount = (await library.cart()).length;
    // Le scan s'est terminé pendant la lecture : on relit la file.
    if (queue.isEmpty && scanEndedWhileBuilding) {
      queue = await _loadQueue(library);
    }
    building = false;

    final initial = SwipeState(
      queue: queue,
      cartCount: cartCount,
      nextCheckpointAt: _threshold,
      threshold: _threshold,
      waitingForGallery:
          !scope.isFocused &&
          queue.isEmpty &&
          ref.read(gallerySyncProvider) != SyncStatus.done,
    );
    unawaited(_prefetchSizes(initial.queue, generation));
    return initial;
  }

  /// Les éléments à trier : groupés (rafales, JPG + RAW), dans l'ordre voulu.
  Future<List<PhotoItem>> _loadQueue(LibraryRepository library) async {
    final settings = ref.read(settingsProvider);
    final watch = Stopwatch()..start();
    final photos = scope.isMonth
        ? await library.monthPhotos(scope.year!, scope.month!)
        : await library.unsortedPhotos(SortOrder.oldestFirst);
    // Doublons : seulement les copies, la meilleure version reste.
    if (scope.duplicates) {
      final hashed = await library.watchHashedPhotos().first;
      final resolved = await library.watchDecidedIds().first;
      final groups = findDuplicates(
        hashed,
        burstGap: Duration(seconds: settings.burstGapSeconds),
        resolved: resolved,
      );
      return [
        for (final group in groups)
          for (final copy in group.photos.skip(1)) PhotoItem.single(copy),
      ];
    }
    // Captures d'écran : une par une, de la plus ancienne à la plus récente.
    if (scope.screenshots) {
      return [
        for (final p in photos)
          if (p.isScreenshot) PhotoItem.single(p),
      ];
    }
    // Une paire JPG + RAW arrive comme une seule carte : on peut supprimer
    // les deux d'un coup. Le tri des RAW reste là pour décider du RAW seul.
    final items = groupPhotos(
      photos,
      bursts: settings.groupBursts,
      burstGap: Duration(seconds: settings.burstGapSeconds),
      similarGap: settings.similarBursts ? similarBurstGap : null,
    );
    // Mesure de la file, en mode profile (flutter run --profile).
    if (kProfileMode) {
      debugPrint(
        'File de tri : ${photos.length} photos, ${items.length} cartes, '
        '${watch.elapsedMilliseconds} ms',
      );
    }
    // Un mois se trie dans l'ordre chronologique.
    if (scope.isMonth) return items;
    // Les grosses vidéos d'abord, dans le désordre : c'est là qu'on libère
    // le plus de place, le plus vite.
    final big = [
      for (final item in items)
        if (item.cover.isBigVideo) item,
    ]..shuffle();
    final rest = [
      for (final item in items)
        if (!item.cover.isBigVideo) item,
    ];
    return [
      ...big,
      ...switch (settings.sortOrder) {
        SortOrder.random => rest..shuffle(),
        SortOrder.oldestFirst => rest,
        SortOrder.newestFirst => rest.reversed,
      },
    ];
  }

  SwipeState? get _ready => state.value;

  /// Succès « première rafale triée ».
  void _noteBurst(PhotoItem item) {
    if (item.kind != PhotoItemKind.burst) return;
    unawaited(
      ref
          .read(progressRepositoryProvider)
          .recordMilestone(Milestone.burstSorted),
    );
  }

  Future<T> _write<T>(Future<T> Function() write) async {
    _pendingWrites++;
    try {
      return await write();
    } finally {
      _pendingWrites--;
    }
  }

  /// Applique la décision à l'élément courant et passe au suivant.
  void _advance(SwipeRecord record) {
    final current = _ready!;
    final history = [...current.history, record];
    if (history.length > undoDepth) history.removeAt(0);
    final queue = current.queue.sublist(1);
    var next = current.copyWith(
      queue: queue,
      history: history,
      sortedCount: current.sortedCount + record.item.photos.length,
      cartCount: current.cartCount + record.trashed.length,
    );
    // Seuil atteint sans rien au panier : pas de récap, on repousse.
    if (next.sortedCount >= next.nextCheckpointAt && next.cartCount == 0) {
      next = next.copyWith(nextCheckpointAt: next.sortedCount + _threshold);
    }
    state = AsyncData(next);
    unawaited(_prefetchSizes(queue, _generation));
  }

  Future<void> decide(SwipeChoice choice) async {
    final item = _ready?.current;
    if (item == null) return;
    _advance(SwipeRecord(item, choice));

    final library = ref.read(libraryRepositoryProvider);
    final gallery = ref.read(gallerySourceProvider);
    _noteBurst(item);
    await _write(() async {
      switch (choice) {
        case SwipeChoice.keep:
          for (final photo in item.photos) {
            await library.decide(photo, Decision.kept);
          }
        case SwipeChoice.favorite:
          // Rafale : seule la photo de couverture devient favorite. Paire
          // JPG + RAW : c'est la même photo, les deux fichiers le deviennent.
          final favorites = item.kind == PhotoItemKind.burst
              ? [item.cover]
              : item.photos;
          for (final photo in item.photos) {
            final fav = favorites.contains(photo);
            await library.decide(
              photo,
              fav ? Decision.favorite : Decision.kept,
            );
            if (fav && !photo.isFavorite) {
              await gallery.setFavorite(photo.id, favorite: true);
            }
          }
        case SwipeChoice.trash:
          for (final photo in item.photos) {
            await library.addToCart(await _withSize(photo));
          }
      }
    });
  }

  /// Rafale triée photo par photo : [keptIds] gardées, les autres au panier.
  Future<void> resolveGroup(Set<String> keptIds) async {
    final item = _ready?.current;
    if (item == null) return;
    _advance(SwipeRecord.resolved(item, keptIds));
    final library = ref.read(libraryRepositoryProvider);
    _noteBurst(item);
    await _write(() async {
      for (final photo in item.photos) {
        if (keptIds.contains(photo.id)) {
          await library.decide(photo, Decision.kept);
        } else {
          await library.addToCart(await _withSize(photo));
        }
      }
    });
  }

  /// « Passer » : pas de décision, l'élément reviendra en fin de file.
  void skip() {
    final current = _ready;
    if (current == null || current.queue.length < 2) return;
    final queue = [...current.queue.sublist(1), current.queue.first];
    state = AsyncData(current.copyWith(queue: queue));
    unawaited(_prefetchSizes(queue, _generation));
  }

  /// Annule la dernière décision : l'élément revient en tête de file.
  Future<void> undo() async {
    final current = _ready;
    if (current == null || !current.canUndo) return;
    final last = current.history.last;
    state = AsyncData(
      current.copyWith(
        queue: [last.item, ...current.queue],
        history: current.history.sublist(0, current.history.length - 1),
        sortedCount: current.sortedCount - last.item.photos.length,
        cartCount: current.cartCount - last.trashed.length,
      ),
    );

    final library = ref.read(libraryRepositoryProvider);
    final gallery = ref.read(gallerySourceProvider);
    final trashed = last.trashed.map((p) => p.id).toSet();
    await _write(() async {
      for (final photo in last.item.photos) {
        if (trashed.contains(photo.id)) {
          await library.removeFromCart(photo.id);
          continue;
        }
        await library.undecide(photo);
        if (last.choice == SwipeChoice.favorite && !photo.isFavorite) {
          await gallery.setFavorite(photo.id, favorite: false);
        }
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
        .where((r) => r.trashed.every((p) => inCart.contains(p.id)))
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

  PhotoItem _withSizes(PhotoItem item, Map<String, GalleryPhoto> sized) {
    if (!item.photos.any((p) => sized.containsKey(p.id))) return item;
    final photos = [for (final p in item.photos) sized[p.id] ?? p];
    return switch (item.kind) {
      PhotoItemKind.single => PhotoItem.single(photos.single),
      PhotoItemKind.burst => PhotoItem.burst(photos),
      PhotoItemKind.rawPair => PhotoItem.rawPair(
        jpg: photos[0],
        raw: photos[1],
      ),
    };
  }

  /// Lit la taille des prochains éléments, pour l'afficher sur la carte.
  Future<void> _prefetchSizes(List<PhotoItem> queue, int generation) async {
    final missing = queue
        .take(prefetch)
        .expand((i) => i.photos)
        .where((p) => p.sizeBytes == null)
        .toList();
    if (missing.isEmpty) return;
    final sized = <String, GalleryPhoto>{};
    for (final photo in missing) {
      try {
        sized[photo.id] = await _withSize(photo);
      } on Object catch (error) {
        // Simple confort d'affichage : on n'interrompt pas le tri pour ça.
        debugPrint('Taille illisible pour ${photo.id} : $error');
        return;
      }
    }
    if (!ref.mounted) return;
    final latest = _ready;
    if (latest == null || generation != _generation) return;
    state = AsyncData(
      latest.copyWith(
        queue: [for (final i in latest.queue) _withSizes(i, sized)],
        history: [
          for (final r in latest.history)
            r.keptIds == null
                ? SwipeRecord(_withSizes(r.item, sized), r.choice)
                : SwipeRecord.resolved(_withSizes(r.item, sized), r.keptIds!),
        ],
      ),
    );
  }
}

final swipeSessionProvider = AsyncNotifierProvider.autoDispose
    .family<SwipeSession, SwipeState, SwipeScope>(SwipeSession.new);
