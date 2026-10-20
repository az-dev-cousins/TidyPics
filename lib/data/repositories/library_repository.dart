import 'package:drift/drift.dart';

import '../models/gallery_photo.dart';
import '../sources/local_db.dart';

/// Ordre dans lequel les photos à trier sont proposées (F2).
enum SortOrder { random, oldestFirst, newestFirst }

/// Vue d'ensemble de la galerie et du tri.
class LibrarySummary {
  const LibrarySummary({
    required this.total,
    required this.sorted,
    required this.cartCount,
    required this.cartBytes,
  });

  static const empty = LibrarySummary(
    total: 0,
    sorted: 0,
    cartCount: 0,
    cartBytes: 0,
  );

  /// Photos présentes dans la galerie.
  final int total;

  /// Photos de la galerie qui ont une décision (gardée, favori).
  final int sorted;
  final int cartCount;
  final int cartBytes;

  /// Part de la galerie déjà triée, panier compris (0 à 1).
  double get progress => total == 0 ? 0 : (sorted + cartCount) / total;

  int get unsorted => total - sorted - cartCount;
}

/// Une photo du panier, avec ce qu'il faut pour l'afficher et la supprimer.
class CartEntry {
  const CartEntry({required this.photo, required this.addedAt});

  final GalleryPhoto photo;
  final DateTime addedAt;

  int get sizeBytes => photo.sizeBytes ?? 0;
}

/// Index de la galerie, décisions et panier, tous stockés sur le téléphone.
class LibraryRepository {
  LibraryRepository(this._db);

  final LocalDb _db;

  /// Met l'index à jour avec la galerie : ajoute les nouvelles photos et
  /// oublie celles supprimées ailleurs (y compris dans le panier, sans bruit).
  Future<void> sync(List<GalleryPhoto> gallery) async {
    final ids = gallery.map((p) => p.id).toSet();
    await _db.transaction(() async {
      await _db.batch((batch) {
        for (final photo in gallery) {
          batch.insert(
            _db.photos,
            PhotosCompanion.insert(
              id: photo.id,
              takenAt: photo.takenAt,
              title: Value(photo.title),
              width: Value(photo.width),
              height: Value(photo.height),
              isFavorite: Value(photo.isFavorite),
            ),
            // La taille déjà lue est conservée.
            onConflict: DoUpdate(
              (_) => PhotosCompanion(
                takenAt: Value(photo.takenAt),
                title: Value(photo.title),
                width: Value(photo.width),
                height: Value(photo.height),
                isFavorite: Value(photo.isFavorite),
              ),
            ),
          );
        }
      });

      final known = _db.selectOnly(_db.photos)..addColumns([_db.photos.id]);
      final knownIds = await known.map((r) => r.read(_db.photos.id)!).get();
      final missing = knownIds.where((id) => !ids.contains(id)).toList();
      for (var i = 0; i < missing.length; i += 500) {
        final chunk = missing.skip(i).take(500).toList();
        await (_db.delete(_db.photos)..where((t) => t.id.isIn(chunk))).go();
        await (_db.delete(
          _db.cartItems,
        )..where((t) => t.assetId.isIn(chunk))).go();
        // Les décisions « gardée » ne servent plus à rien. On garde
        // « supprimée » pour l'historique.
        await (_db.delete(_db.photoDecisions)..where(
              (t) =>
                  t.assetId.isIn(chunk) &
                  t.decision.equalsValue(Decision.trashed).not(),
            ))
            .go();
      }
    });
  }

  Stream<LibrarySummary> watchSummary() {
    return _db
        .customSelect(
          'SELECT '
          '(SELECT COUNT(*) FROM photos) AS total, '
          '(SELECT COUNT(*) FROM photos p JOIN photo_decisions d '
          'ON d.asset_id = p.id) AS sorted, '
          '(SELECT COUNT(*) FROM cart_items) AS cart_count, '
          '(SELECT COALESCE(SUM(size_bytes), 0) FROM cart_items) AS cart_bytes',
          readsFrom: {_db.photos, _db.photoDecisions, _db.cartItems},
        )
        .watchSingle()
        .map(
          (row) => LibrarySummary(
            total: row.read<int>('total'),
            sorted: row.read<int>('sorted'),
            cartCount: row.read<int>('cart_count'),
            cartBytes: row.read<int>('cart_bytes'),
          ),
        );
  }

  /// Photos sans décision et hors du panier, dans l'ordre demandé.
  Future<List<GalleryPhoto>> unsortedPhotos(SortOrder order) async {
    final p = _db.photos;
    final query =
        _db.select(p).join([
          leftOuterJoin(
            _db.photoDecisions,
            _db.photoDecisions.assetId.equalsExp(p.id),
          ),
          leftOuterJoin(_db.cartItems, _db.cartItems.assetId.equalsExp(p.id)),
        ])..where(
          _db.photoDecisions.assetId.isNull() & _db.cartItems.assetId.isNull(),
        );
    if (order != SortOrder.random) {
      query.orderBy([
        OrderingTerm(
          expression: p.takenAt,
          mode: order == SortOrder.oldestFirst
              ? OrderingMode.asc
              : OrderingMode.desc,
        ),
      ]);
    }
    final rows = await query.map((r) => _toPhoto(r.readTable(p))).get();
    if (order == SortOrder.random) rows.shuffle();
    return rows;
  }

  Future<void> setSize(String id, int bytes) async {
    await (_db.update(_db.photos)..where((t) => t.id.equals(id))).write(
      PhotosCompanion(sizeBytes: Value(bytes)),
    );
    await (_db.update(_db.cartItems)..where((t) => t.assetId.equals(id))).write(
      CartItemsCompanion(sizeBytes: Value(bytes)),
    );
  }

  Future<void> decide(
    GalleryPhoto photo,
    Decision decision, {
    DateTime? at,
  }) async {
    await _db
        .into(_db.photoDecisions)
        .insertOnConflictUpdate(
          PhotoDecisionsCompanion.insert(
            assetId: photo.id,
            decision: decision,
            decidedAt: at ?? DateTime.now(),
            wasFavorite: Value(photo.isFavorite),
          ),
        );
    if (decision == Decision.favorite) {
      await (_db.update(_db.photos)..where((t) => t.id.equals(photo.id))).write(
        const PhotosCompanion(isFavorite: Value(true)),
      );
    }
  }

  /// Annule une décision : la photo redevient « à trier ».
  Future<void> undecide(GalleryPhoto photo) async {
    await (_db.delete(
      _db.photoDecisions,
    )..where((t) => t.assetId.equals(photo.id))).go();
    await (_db.update(_db.photos)..where((t) => t.id.equals(photo.id))).write(
      PhotosCompanion(isFavorite: Value(photo.isFavorite)),
    );
  }

  Future<void> addToCart(GalleryPhoto photo, {DateTime? at}) {
    return _db
        .into(_db.cartItems)
        .insertOnConflictUpdate(
          CartItemsCompanion.insert(
            assetId: photo.id,
            sizeBytes: Value(photo.sizeBytes ?? 0),
            addedAt: at ?? DateTime.now(),
          ),
        );
  }

  Future<void> removeFromCart(String id) =>
      (_db.delete(_db.cartItems)..where((t) => t.assetId.equals(id))).go();

  /// Sort des photos du panier sans décision : elles reviendront plus tard
  /// dans le tri (photos décochées au récap).
  Future<void> releaseFromCart(Iterable<String> ids) async {
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.skip(i).take(500).toList();
      await (_db.delete(
        _db.cartItems,
      )..where((t) => t.assetId.isIn(chunk))).go();
    }
  }

  Stream<List<CartEntry>> watchCart() {
    final query = _db.select(_db.cartItems).join([
      innerJoin(_db.photos, _db.photos.id.equalsExp(_db.cartItems.assetId)),
    ])..orderBy([OrderingTerm.desc(_db.cartItems.addedAt)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          CartEntry(
            photo: _toPhoto(row.readTable(_db.photos))
                .copyWith(sizeBytes: row.readTable(_db.cartItems).sizeBytes),
            addedAt: row.readTable(_db.cartItems).addedAt,
          ),
      ],
    );
  }

  Future<List<CartEntry>> cart() => watchCart().first;

  /// Les photos gardées pourront être reproposées (réglage F1).
  Future<void> resetKept() =>
      (_db.delete(_db.photoDecisions)..where(
            (t) => t.decision.isInValues([Decision.kept, Decision.favorite]),
          ))
          .go();

  GalleryPhoto _toPhoto(PhotoRow row) => GalleryPhoto(
    id: row.id,
    takenAt: row.takenAt,
    title: row.title,
    width: row.width,
    height: row.height,
    sizeBytes: row.sizeBytes,
    isFavorite: row.isFavorite,
  );
}
