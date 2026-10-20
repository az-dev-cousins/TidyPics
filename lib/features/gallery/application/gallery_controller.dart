import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/duplicates.dart';
import '../../../data/models/gallery_photo.dart';
import '../../../data/models/photo_groups.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../data/repositories/trash_repository.dart';
import '../../../data/sources/gallery_source.dart';
import '../../settings/application/settings_controller.dart';

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
    // Lus avant les attentes : le provider peut être libéré entre-temps.
    final gallery = ref.read(gallerySourceProvider);
    final library = ref.read(libraryRepositoryProvider);
    final trash = ref.read(trashRepositoryProvider);
    try {
      var photos = const <GalleryPhoto>[];
      final watch = Stopwatch()..start();
      do {
        _again = false;
        photos = await gallery.fetchAll();
        final fetched = watch.elapsedMilliseconds;
        if (!ref.mounted) return;
        await library.sync(photos);
        if (!ref.mounted) return;
        // Mesure du scan, en mode profile (flutter run --profile).
        if (kProfileMode) {
          debugPrint(
            'Scan : ${photos.length} photos, lecture $fetched ms, '
            'base ${watch.elapsedMilliseconds - fetched} ms',
          );
        }
        watch.reset();
      } while (_again);
      await trash.purgeExpired();
      // Restaurées ou effacées depuis l'app Galerie : le journal suit.
      await trash.syncWithSystemTrash(photos.map((p) => p.id).toSet());
      if (ref.mounted) state = SyncStatus.done;
    } on Object catch (error, stack) {
      debugPrint('Scan de la galerie impossible : $error\n$stack');
      if (ref.mounted) state = SyncStatus.failed;
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

final monthsProvider = StreamProvider<List<MonthSummary>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchMonths(),
);

final freedHistoryProvider =
    StreamProvider.family<List<FreedBucket>, StatsPeriod>(
      (ref, period) => ref.watch(trashRepositoryProvider).watchHistory(period),
    );

/// Paires JPG + RAW, relues quand la galerie ou le panier changent.
final rawPairsProvider = FutureProvider.autoDispose<List<PhotoItem>>((ref) {
  ref
    ..watch(librarySummaryProvider)
    ..watch(cartProvider);
  return ref.watch(libraryRepositoryProvider).rawPairs();
});

/// RAW restant à trier (tuile du menu).
final rawToSortProvider = FutureProvider.autoDispose<List<RawToSort>>((ref) {
  ref
    ..watch(librarySummaryProvider)
    ..watch(cartProvider);
  return ref.watch(libraryRepositoryProvider).rawFilesToSort();
});

/// Stockage du téléphone, relu à chaque ouverture du menu.
final deviceStorageProvider = FutureProvider.autoDispose<DeviceStorage?>(
  (ref) => ref.watch(gallerySourceProvider).deviceStorage(),
);

/// Calcule les empreintes visuelles en tâche de fond, après chaque scan
/// (doublons F11, rafales F5). Vrai pendant le calcul.
class VisualHashController extends Notifier<bool> {
  /// Miniatures lues en même temps, puis empreintes enregistrées par lot.
  static const _parallel = 8;
  static const _batch = 64;

  @override
  bool build() {
    ref.listen(gallerySyncProvider, (_, status) {
      if (status == SyncStatus.done) unawaited(Future.microtask(run));
    }, fireImmediately: true);
    return false;
  }

  Future<void> run() async {
    if (state) return;
    state = true;
    final gallery = ref.read(gallerySourceProvider);
    final library = ref.read(libraryRepositoryProvider);
    final hasher = ref.read(visualHasherProvider);
    try {
      while (ref.mounted) {
        final photos = await library.photosToHash(limit: _batch);
        if (photos.isEmpty || !ref.mounted) break;
        final thumbnails = <Uint8List?>[];
        for (var i = 0; i < photos.length; i += _parallel) {
          thumbnails.addAll(
            await Future.wait(
              photos.skip(i).take(_parallel).map((p) async {
                try {
                  return await gallery.thumbnail(p.id, size: 64);
                } on Object {
                  return null;
                }
              }),
            ),
          );
        }
        final hashes = await hasher(thumbnails);
        if (!ref.mounted) break;
        await library.setVisualHashes({
          for (final (i, photo) in photos.indexed) photo.id: hashes[i],
        });
      }
    } on Object catch (error, stack) {
      debugPrint('Empreintes visuelles impossibles : $error\n$stack');
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

final visualHashProvider = NotifierProvider<VisualHashController, bool>(
  VisualHashController.new,
);

/// Avancée du calcul des empreintes.
final hashProgressProvider =
    StreamProvider.autoDispose<({int done, int total})>(
      (ref) => ref.watch(libraryRepositoryProvider).watchHashProgress(),
    );

/// Groupes de doublons (F11), recalculés au fil des empreintes.
final duplicatesProvider = StreamProvider.autoDispose<List<DuplicateGroup>>((
  ref,
) {
  final gap = ref.watch(
    settingsProvider.select((s) => Duration(seconds: s.burstGapSeconds)),
  );
  return ref
      .watch(libraryRepositoryProvider)
      .watchHashedPhotos()
      .map((photos) => findDuplicates(photos, burstGap: gap));
});
