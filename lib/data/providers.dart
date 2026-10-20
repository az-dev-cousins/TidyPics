import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/visual_hash.dart';

import 'repositories/library_repository.dart';
import 'repositories/progress_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/trash_repository.dart';
import 'sources/gallery_source.dart';
import 'sources/local_db.dart';

/// Base locale. Remplacée par une base en mémoire dans les tests.
final localDbProvider = Provider<LocalDb>((ref) {
  final db = LocalDb();
  ref.onDispose(db.close);
  return db;
});

final gallerySourceProvider = Provider<GallerySource>(
  (ref) => PhotoManagerGallerySource(),
);

/// Ouvert dans `main()` avant le lancement de l'app, puis injecté.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('Injecté dans main()'),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(localDbProvider)),
);

final trashRepositoryProvider = Provider<TrashRepository>(
  (ref) => TrashRepository(
    ref.watch(localDbProvider),
    ref.watch(gallerySourceProvider),
  ),
);

/// Calcule les empreintes visuelles de miniatures, dans un isolate pour ne
/// pas ralentir l'interface. Sur place dans les tests.
typedef VisualHasher = Future<List<VisualPrint>> Function(
  List<Uint8List?> thumbnails,
);

/// Empreintes de miniatures ([VisualHash.unreadable] si illisible).
List<VisualPrint> visualPrints(List<Uint8List?> thumbnails) => [
  for (final t in thumbnails)
    t == null
        ? VisualHash.unreadable
        : VisualHash.of(t) ?? VisualHash.unreadable,
];

final visualHasherProvider = Provider<VisualHasher>(
  (ref) =>
      (thumbnails) => Isolate.run(() => visualPrints(thumbnails)),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(localDbProvider)),
);
