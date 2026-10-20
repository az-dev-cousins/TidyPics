import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/data/providers.dart';
import 'package:tidypics/features/cart/application/checkpoint_controller.dart';

import '../../helpers/fake_gallery_source.dart';
import '../../helpers/test_container.dart';

void main() {
  Future<(FakeGallerySource, CheckpointActions)> start({
    Map<String, Object> settings = const {},
    bool granted = true,
  }) async {
    final gallery = FakeGallerySource(photos: samplePhotos(3))
      ..manageMediaSupported = true
      ..manageMediaGranted = granted;
    final container = await testContainer(
      db: memoryDb(),
      gallery: gallery,
      settings: {'onboarding_done': true, ...settings},
    );
    final library = container.read(libraryRepositoryProvider);
    await library.sync(gallery.photos);
    await library.addToCart(gallery.photos.first);
    return (gallery, container.read(checkpointActionsProvider));
  }

  test("en quittant l'app : rien sans le réglage", () async {
    final (gallery, actions) = await start();
    expect((await actions.trashOnLeave()).count, 0);
    expect(gallery.trashed, isEmpty);
  });

  test(
    "en quittant l'app : le panier part avec « Gestion des médias »",
    () async {
      final (gallery, actions) = await start(
        settings: {'auto_trash_on_leave': true},
      );
      expect((await actions.trashOnLeave()).count, 1);
      expect(gallery.trashed, ['p0']);
    },
  );

  test("en quittant l'app : jamais sans « Gestion des médias »", () async {
    final (gallery, actions) = await start(
      settings: {'auto_trash_on_leave': true},
      granted: false,
    );
    expect((await actions.trashOnLeave()).count, 0);
    expect(gallery.trashed, isEmpty);
  });

  test('effacement direct si le réglage est activé', () async {
    final (gallery, actions) = await start(settings: {'delete_directly': true});
    expect((await actions.trashAllFromCart()).count, 1);
    expect(gallery.trashed, isEmpty);
    expect(gallery.systemTrash, isEmpty);
  });
}
