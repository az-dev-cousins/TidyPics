import 'package:photo_manager/photo_manager.dart';

Future<List<AssetEntity>> getGalleryPhotos() async {
  // Get the 'All Photos' album
  final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image, onlyAll: true);

  if (albums.isEmpty) return [];

  final AssetPathEntity album = albums.first;
  List<AssetEntity> photos = [];
  int page = 0;
  const int size = 1000;
  List<AssetEntity> pagePhotos =
      await album.getAssetListPaged(page: page, size: size);

  while (pagePhotos.isNotEmpty) {
    photos.addAll(pagePhotos);
    page++;
    pagePhotos = await album.getAssetListPaged(page: page, size: size);
  }

  return photos;
}
