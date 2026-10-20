import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/library_repository.dart';
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
