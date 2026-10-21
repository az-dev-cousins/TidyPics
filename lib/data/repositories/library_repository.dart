import 'package:drift/drift.dart';

import '../models/gallery_photo.dart';
import '../models/photo_groups.dart';
import '../models/visual_hash.dart';
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

/// Un mois de la galerie et l'avancée de son tri (F2, tri ciblé).
class MonthSummary {
  const MonthSummary({
    required this.year,
    required this.month,
    required this.total,
    required this.sorted,
    this.cover,
  });

  final int year;
  final int month;
  final int total;

  /// Une photo du mois, pour illustrer sa carte.
  final GalleryPhoto? cover;

  /// Photos du mois gardées ou au panier.
  final int sorted;

  double get progress => total == 0 ? 0 : sorted / total;
  bool get isDone => total > 0 && sorted >= total;
}

/// Un RAW à trier et son JPG (s'il existe encore).
class RawToSort {
  const RawToSort({required this.raw, this.jpg, this.jpgInCart = false});

  final GalleryPhoto raw;
  final GalleryPhoto? jpg;

  /// Le JPG attend au panier : garder ce RAW le laisserait seul.
  final bool jpgInCart;

  /// RAW sans JPG gardé (JPG supprimé, au panier, ou jamais pris).
  bool get isOrphan => jpg == null || jpgInCart;

  RawToSort withSizes({int? raw, int? jpg}) => RawToSort(
    raw: raw == null ? this.raw : this.raw.copyWith(sizeBytes: raw),
    jpg: jpg == null ? this.jpg : this.jpg?.copyWith(sizeBytes: jpg),
    jpgInCart: jpgInCart,
  );
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
              sizeBytes: Value(photo.sizeBytes),
              durationMs: Value(photo.duration?.inMilliseconds),
              folder: Value(photo.folder),
            ),
            // Taille inconnue de la galerie (iOS) : celle déjà lue est
            // conservée.
            onConflict: DoUpdate(
              (_) => PhotosCompanion(
                takenAt: Value(photo.takenAt),
                title: Value(photo.title),
                width: Value(photo.width),
                height: Value(photo.height),
                isFavorite: Value(photo.isFavorite),
                durationMs: Value(photo.duration?.inMilliseconds),
                folder: Value(photo.folder),
                sizeBytes: photo.sizeBytes == null
                    ? const Value.absent()
                    : Value(photo.sizeBytes),
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

  /// Photos dont l'empreinte visuelle reste à calculer (pas les vidéos).
  Future<List<GalleryPhoto>> photosToHash({int limit = 64}) async {
    final query = _db.select(_db.photos)
      ..where((t) => t.visualHash.isNull() & t.durationMs.isNull())
      ..limit(limit);
    return query.map(_toPhoto).get();
  }

  /// Enregistre des empreintes. 0 = illisible : on ne la recalcule pas.
  Future<void> setVisualHashes(Map<String, VisualPrint> prints) =>
      _db.batch((batch) {
        for (final MapEntry(:key, :value) in prints.entries) {
          batch.update(
            _db.photos,
            PhotosCompanion(
              visualHash: Value(value.hash),
              visualColor: Value(value.color),
              visualDetail: Value(value.detail),
            ),
            where: (t) => t.id.equals(key),
          );
        }
      });

  /// Avancée du calcul des empreintes : (faites, à faire en tout).
  Stream<({int done, int total})> watchHashProgress() => _db
      .customSelect(
        'SELECT COUNT(*) AS total, COUNT(visual_hash) AS done '
        'FROM photos WHERE duration_ms IS NULL',
        readsFrom: {_db.photos},
      )
      .watchSingle()
      .map(
        (row) => (done: row.read<int>('done'), total: row.read<int>('total')),
      );

  /// Photos qui ont déjà une décision (gardée, favorite).
  Stream<Set<String>> watchDecidedIds() {
    final query = _db.selectOnly(_db.photoDecisions)
      ..addColumns([_db.photoDecisions.assetId]);
    return query
        .map((r) => r.read(_db.photoDecisions.assetId)!)
        .watch()
        .map((ids) => ids.toSet());
  }

  /// Photos à comparer pour les doublons : empreinte connue, hors panier.
  Stream<List<GalleryPhoto>> watchHashedPhotos() {
    final p = _db.photos;
    return (_db.select(p).join([
          leftOuterJoin(_db.cartItems, _db.cartItems.assetId.equalsExp(p.id)),
        ])..where(p.visualHash.isNotNull() & _db.cartItems.assetId.isNull()))
        .map((r) => _toPhoto(r.readTable(p)))
        .watch();
  }

  /// Les mois qui ont des photos, du plus récent au plus ancien.
  Stream<List<MonthSummary>> watchMonths() {
    final p = _db.photos;
    return (_db.select(p).join([
      leftOuterJoin(
        _db.photoDecisions,
        _db.photoDecisions.assetId.equalsExp(p.id),
      ),
      leftOuterJoin(_db.cartItems, _db.cartItems.assetId.equalsExp(p.id)),
    ])).watch().map((rows) {
      // Regroupé en Dart, en heure locale : 20 000 lignes restent rapides.
      final byMonth = <(int, int), (int, int)>{};
      final covers = <(int, int), GalleryPhoto>{};
      for (final row in rows) {
        final photo = row.readTable(p);
        final date = photo.takenAt.toLocal();
        final sorted =
            row.readTableOrNull(_db.photoDecisions) != null ||
            row.readTableOrNull(_db.cartItems) != null;
        final key = (date.year, date.month);
        covers.putIfAbsent(key, () => _toPhoto(photo));
        final (total, done) = byMonth[key] ?? (0, 0);
        byMonth[key] = (total + 1, done + (sorted ? 1 : 0));
      }
      final keys = byMonth.keys.toList()
        ..sort((a, b) => a.$1 != b.$1 ? b.$1 - a.$1 : b.$2 - a.$2);
      return [
        for (final key in keys)
          MonthSummary(
            year: key.$1,
            month: key.$2,
            total: byMonth[key]!.$1,
            sorted: byMonth[key]!.$2,
            cover: covers[key],
          ),
      ];
    });
  }

  /// Paires JPG + RAW de la galerie (F6), hors photos au panier.
  Future<List<PhotoItem>> rawPairs() async {
    final p = _db.photos;
    final query = _db.select(p).join([
      leftOuterJoin(_db.cartItems, _db.cartItems.assetId.equalsExp(p.id)),
    ])..where(_db.cartItems.assetId.isNull());
    final photos = await query.map((r) => _toPhoto(r.readTable(p))).get();
    return findRawPairs(photos)..sort((a, b) => b.takenAt.compareTo(a.takenAt));
  }

  /// Les RAW pas encore triés (tri des RAW, F6), chacun avec son JPG s'il
  /// existe. Les RAW sont triés uniquement ici, jamais dans le tri normal.
  Future<List<RawToSort>> rawFilesToSort() async {
    final decided =
        (await (_db.selectOnly(_db.photoDecisions)
                  ..addColumns([_db.photoDecisions.assetId]))
                .map((r) => r.read(_db.photoDecisions.assetId)!)
                .get())
            .toSet();
    final inCart =
        (await (_db.selectOnly(_db.cartItems)
                  ..addColumns([_db.cartItems.assetId]))
                .map((r) => r.read(_db.cartItems.assetId)!)
                .get())
            .toSet();
    final photos = await _db.select(_db.photos).map(_toPhoto).get();
    final jpgOf = {
      for (final pair in findRawPairs(photos))
        pair.photos[1].id: pair.photos[0],
    };
    return [
      for (final photo in photos)
        if (photo.isRaw &&
            !decided.contains(photo.id) &&
            !inCart.contains(photo.id))
          RawToSort(
            raw: photo,
            jpg: jpgOf[photo.id],
            jpgInCart: inCart.contains(jpgOf[photo.id]?.id),
          ),
    ]..sort((a, b) => a.raw.takenAt.compareTo(b.raw.takenAt));
  }

  /// Toutes les photos d'un mois, même déjà vues ou gardées (tri ciblé).
  /// Seules celles au panier sont exclues : elles attendent le récap.
  Future<List<GalleryPhoto>> monthPhotos(int year, int month) async {
    final p = _db.photos;
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    final query =
        _db.select(p).join([
            leftOuterJoin(_db.cartItems, _db.cartItems.assetId.equalsExp(p.id)),
          ])
          ..where(
            p.takenAt.isBiggerOrEqualValue(start) &
                p.takenAt.isSmallerThanValue(end) &
                _db.cartItems.assetId.isNull(),
          )
          ..orderBy([OrderingTerm.asc(p.takenAt)]);
    return query.map((r) => _toPhoto(r.readTable(p))).get();
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
    await _recordActivity(at);
  }

  /// Note le jour pour les séries de succès (une ligne par jour).
  Future<void> _recordActivity(DateTime? at) {
    final d = at ?? DateTime.now();
    return _db
        .into(_db.activityDays)
        .insert(
          ActivityDaysCompanion.insert(
            day: Value(d.year * 10000 + d.month * 100 + d.day),
          ),
          mode: InsertMode.insertOrIgnore,
        );
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

  /// Au panier. Une décision précédente (tri par mois : photo déjà gardée)
  /// est effacée : la photo ne compte qu'une fois.
  Future<void> addToCart(GalleryPhoto photo, {DateTime? at}) async {
    await (_db.delete(
      _db.photoDecisions,
    )..where((t) => t.assetId.equals(photo.id))).go();
    await _db
        .into(_db.cartItems)
        .insertOnConflictUpdate(
          CartItemsCompanion.insert(
            assetId: photo.id,
            sizeBytes: Value(photo.sizeBytes ?? 0),
            addedAt: at ?? DateTime.now(),
          ),
        );
    await _recordActivity(at);
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
    duration: row.durationMs == null
        ? null
        : Duration(milliseconds: row.durationMs!),
    folder: row.folder,
    visualHash: row.visualHash,
    visualColor: row.visualColor,
    visualDetail: row.visualDetail,
  );
}
