import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:tidypics/data/models/gallery_photo.dart';
import 'package:tidypics/data/sources/gallery_source.dart';

/// Fausse galerie en mémoire pour les tests.
class FakeGallerySource implements GallerySource {
  FakeGallerySource({
    List<GalleryPhoto>? photos,
    this.access = GalleryAccess.full,
    this.sizes = const {},
    this.images = const {},
  }) : photos = [...?photos];

  List<GalleryPhoto> photos;
  GalleryAccess access;

  /// Accès renvoyé par [requestAccess] (par défaut : [access]).
  GalleryAccess? accessAfterRequest;
  Map<String, int> sizes;

  /// Miniatures encodées par photo (sinon trois octets illisibles).
  Map<String, Uint8List> images;

  /// Simule le refus de la popup système de suppression.
  bool refuseTrash = false;
  bool manageMediaSupported = false;
  bool manageMediaGranted = false;

  final favorites = <String, bool>{};
  final trashed = <String>[];
  final restored = <String>[];
  int trashCalls = 0;
  int manageMediaRequests = 0;

  final _changes = StreamController<void>.broadcast();

  void notifyChange() => _changes.add(null);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<GalleryAccess> currentAccess() async => access;

  @override
  Future<GalleryAccess> requestAccess() async {
    access = accessAfterRequest ?? access;
    return access;
  }

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> extendLimitedAccess() async {}

  @override
  Future<List<GalleryPhoto>> fetchAll() async => [...photos];

  @override
  Future<int> countPhotosSince(DateTime since) async =>
      photos.where((p) => !p.takenAt.isBefore(since)).length;

  @override
  Future<int> fileSize(String id) async => sizes[id] ?? 1000;

  /// Photos dont la miniature est illisible (ex. certains RAW).
  final unreadableThumbnails = <String>{};

  @override
  Future<Uint8List?> thumbnail(String id, {int size = 200}) async {
    if (unreadableThumbnails.contains(id)) {
      throw StateError('Miniature illisible');
    }
    return images[id] ?? Uint8List.fromList([1, 2, 3]);
  }

  /// Pas de lecteur vidéo dans les tests : la carte garde sa miniature.
  @override
  Future<File?> mediaFile(String id) async => null;

  final openedInGallery = <String>[];

  @override
  bool get canOpenInGallery => true;

  @override
  Future<bool> openInGallery(String id) async {
    openedInGallery.add(id);
    return true;
  }

  @override
  Future<bool> setFavorite(String id, {required bool favorite}) async {
    favorites[id] = favorite;
    return true;
  }

  @override
  Future<List<String>> moveToTrash(
    List<GalleryPhoto> list, {
    ValueChanged<int>? onProgress,
  }) async {
    trashCalls++;
    if (refuseTrash) return const [];
    final ids = list.map((p) => p.id).toList();
    onProgress?.call(ids.length);
    trashed.addAll(ids);
    systemTrash.addAll(ids);
    photos.removeWhere((p) => ids.contains(p.id));
    return ids;
  }

  @override
  Future<List<String>> restoreFromTrash(List<GalleryPhoto> list) async {
    final ids = list.map((p) => p.id).toList();
    restored.addAll(ids);
    systemTrash.removeAll(ids);
    photos.addAll(list);
    return ids;
  }

  @override
  bool get hasRestorableTrash => true;

  /// Photos dans la corbeille système (simulée).
  final systemTrash = <String>{};
  bool refuseDeleteForever = false;

  @override
  Future<Set<String>> stillInTrash(List<String> ids) async =>
      ids.where(systemTrash.contains).toSet();

  @override
  Future<List<String>> deleteForever(List<String> ids) async {
    if (refuseDeleteForever) return const [];
    systemTrash.removeAll(ids);
    return ids;
  }

  DeviceStorage? storage = const DeviceStorage(
    total: 128000000000,
    free: 40000000000,
    photos: 30000000000,
  );

  @override
  Future<DeviceStorage?> deviceStorage() async => storage;

  @override
  Future<bool> supportsManageMedia() async => manageMediaSupported;

  @override
  Future<bool> canManageMedia() async => manageMediaGranted;

  @override
  Future<void> requestManageMedia() async => manageMediaRequests++;
}

/// Photos de test : `p0`, `p1`… prises un jour d'écart à partir de 2020.
List<GalleryPhoto> samplePhotos(int count, {String prefix = 'p'}) => [
  for (var i = 0; i < count; i++)
    GalleryPhoto(
      id: '$prefix$i',
      takenAt: DateTime(2020).add(Duration(days: i)),
      title: 'IMG_$i.JPG',
      width: 400,
      height: 300,
    ),
];
