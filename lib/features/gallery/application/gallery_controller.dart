import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../data/repositories/trash_repository.dart';
import '../../../data/sources/gallery_source.dart';

/// Accès à la galerie. Relu au retour dans l'app : l'utilisateur a pu
/// changer la permission dans les réglages du téléphone.
class GalleryAccessController extends AsyncNotifier<GalleryAccess> {
  @override
  Future<GalleryAccess> build() =>
      ref.read(gallerySourceProvider).currentAccess();

  Future<GalleryAccess> request() async {
    final access = await ref.read(gallerySourceProvider).requestAccess();
    state = AsyncData(access);
    return access;
  }

  Future<void> refresh() async {
    final access = await ref.read(gallerySourceProvider).currentAccess();
    if (state.value != access) state = AsyncData(access);
  }
}

final galleryAccessProvider =
    AsyncNotifierProvider<GalleryAccessController, GalleryAccess>(
      GalleryAccessController.new,
    );

/// Indexation de la galerie dans la base locale.
enum SyncStatus { idle, scanning, done, failed }

/// Lance un scan quand l'accès est accordé, puis à chaque changement de la
/// galerie (photo prise ou supprimée ailleurs) et au retour dans l'app.
class GallerySyncController extends Notifier<SyncStatus> {
  StreamSubscription<void>? _changes;
  Timer? _debounce;
  bool _running = false;
  bool _again = false;

  @override
  SyncStatus build() {
    ref.onDispose(() {
      _debounce?.cancel();
      unawaited(_changes?.cancel());
    });
    ref.listen(galleryAccessProvider, (previous, next) {
      final access = next.value;
      if (access == GalleryAccess.full || access == GalleryAccess.limited) {
        _listenChanges();
        // Pas pendant build() : on ne modifie pas l'état d'un provider
        // en cours de construction.
        unawaited(Future.microtask(scan));
      }
    }, fireImmediately: true);
    return SyncStatus.idle;
  }

  void _listenChanges() {
    _changes ??= ref.read(gallerySourceProvider).changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 1), () => unawaited(scan()));
    });
  }

  Future<void> scan() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    if (state != SyncStatus.done) state = SyncStatus.scanning;
    try {
      do {
        _again = false;
        final photos = await ref.read(gallerySourceProvider).fetchAll();
        await ref.read(libraryRepositoryProvider).sync(photos);
      } while (_again);
      await ref.read(trashRepositoryProvider).purgeExpired();
      state = SyncStatus.done;
    } on Object catch (error, stack) {
      debugPrint('Scan de la galerie impossible : $error\n$stack');
      state = SyncStatus.failed;
    } finally {
      _running = false;
    }
  }
}

final gallerySyncProvider = NotifierProvider<GallerySyncController, SyncStatus>(
  GallerySyncController.new,
);

final librarySummaryProvider = StreamProvider<LibrarySummary>(
  (ref) => ref.watch(libraryRepositoryProvider).watchSummary(),
);

final cartProvider = StreamProvider<List<CartEntry>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchCart(),
);

final freedStatsProvider = StreamProvider<FreedStats>(
  (ref) => ref.watch(trashRepositoryProvider).watchFreed(),
);

final trashLogProvider = StreamProvider<List<TrashEntry>>(
  (ref) => ref.watch(trashRepositoryProvider).watchLog(),
);
