import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tidypics/data/providers.dart';
import 'package:tidypics/data/repositories/settings_repository.dart';
import 'package:tidypics/data/sources/local_db.dart';
import 'package:tidypics/features/reminders/application/reminders.dart';

import 'fake_gallery_source.dart';
import 'fake_reminders.dart';

/// Base Drift en mémoire, neuve pour chaque test.
LocalDb memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return LocalDb(NativeDatabase.memory());
}

/// Réglages en mémoire (aucun fichier écrit).
Future<SettingsRepository> memorySettings([
  Map<String, Object> values = const {},
]) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(values);
  return SettingsRepository(
    await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: SettingsRepository.keys,
      ),
    ),
  );
}

/// Les overrides communs : base en mémoire, fausse galerie, réglages.
Future<List<Override>> testOverrides({
  required LocalDb db,
  required FakeGallerySource gallery,
  Map<String, Object> settings = const {'onboarding_done': true},
  FakeReminderScheduler? reminders,
}) async => [
  reminderSchedulerProvider.overrideWithValue(
    reminders ?? FakeReminderScheduler(),
  ),
  localDbProvider.overrideWithValue(db),
  gallerySourceProvider.overrideWithValue(gallery),
  settingsRepositoryProvider.overrideWithValue(await memorySettings(settings)),
  // Pas d'isolate dans les tests : même calcul, sur place.
  visualHasherProvider.overrideWithValue(
    (thumbnails) async => visualPrints(thumbnails),
  ),
];

/// Un conteneur Riverpod prêt pour les tests de logique.
Future<ProviderContainer> testContainer({
  required LocalDb db,
  required FakeGallerySource gallery,
  Map<String, Object> settings = const {'onboarding_done': true},
}) async {
  // Enregistré avant le conteneur : les nettoyages passent dans l'ordre
  // inverse, donc le conteneur est libéré avant la fermeture de la base.
  addTearDown(db.close);
  return ProviderContainer.test(
    overrides: await testOverrides(
      db: db,
      gallery: gallery,
      settings: settings,
    ),
  );
}
