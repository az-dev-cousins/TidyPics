import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_db.g.dart';

/// Décision prise sur une photo (le panier est une table à part).
enum Decision { kept, favorite, trashed }

/// Index de la galerie, reconstruit à chaque scan.
///
/// On ne garde que les métadonnées : jamais l'image elle-même.
@DataClassName('PhotoRow')
class Photos extends Table {
  TextColumn get id => text()();
  DateTimeColumn get takenAt => dateTime()();
  TextColumn get title => text().nullable()();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();

  /// Taille du fichier en octets, lue à la demande (`null` tant qu'inconnue).
  IntColumn get sizeBytes => integer().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// Durée d'une vidéo en millisecondes ; `null` pour une photo.
  IntColumn get durationMs => integer().nullable()();

  /// Dossier du fichier (Android), ex. `DCIM/Camera/`.
  TextColumn get folder => text().nullable()();

  /// Empreinte visuelle (dHash 64 bits), calculée en tâche de fond.
  IntColumn get visualHash => integer().nullable()();

  /// Couleur moyenne des quatre quarts, calculée avec l'empreinte.
  IntColumn get visualColor => integer().nullable()();

  /// Empreinte détaillée (256 bits, 32 octets).
  BlobColumn get visualDetail => blob().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Ce que l'utilisateur a décidé pour une photo. Une photo sans ligne ici
/// et absente du panier est « à trier ».
@DataClassName('DecisionRow')
class PhotoDecisions extends Table {
  TextColumn get assetId => text()();
  IntColumn get decision => intEnum<Decision>()();
  DateTimeColumn get decidedAt => dateTime()();

  /// Pour un favori : la photo l'était-elle déjà avant ? Sert à l'annulation.
  BoolColumn get wasFavorite => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {assetId};
}

/// Panier de suppression : enregistré à chaque swipe gauche.
@DataClassName('CartRow')
class CartItems extends Table {
  TextColumn get assetId => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {assetId};
}

/// Journal des photos envoyées à la corbeille système (F4).
@DataClassName('TrashRow')
class TrashLog extends Table {
  TextColumn get assetId => text()();
  TextColumn get title => text().nullable()();
  DateTimeColumn get takenAt => dateTime().nullable()();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get trashedAt => dateTime()();

  /// Miniature JPEG (~10 Ko) : la photo n'est plus lisible une fois à la
  /// corbeille.
  BlobColumn get thumbnail => blob().nullable()();

  /// Durée d'une vidéo en millisecondes ; `null` pour une photo.
  IntColumn get durationMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {assetId};
}

enum StatsEventType { trashed, restored }

/// Événements qui alimentent les statistiques (F7).
@DataClassName('StatsEventRow')
class StatsEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get type => intEnum<StatsEventType>()();
  IntColumn get bytes => integer()();
  IntColumn get photoCount => integer()();
  DateTimeColumn get at => dateTime()();
}

@DriftDatabase(
  tables: [Photos, PhotoDecisions, CartItems, TrashLog, StatsEvents],
)
class LocalDb extends _$LocalDb {
  LocalDb([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'tidypics'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v2 : les vidéos.
      if (from < 2) {
        await m.addColumn(photos, photos.durationMs);
        await m.addColumn(trashLog, trashLog.durationMs);
      }
      // v3 : dossier et empreinte visuelle.
      if (from < 3) {
        await m.addColumn(photos, photos.folder);
        await m.addColumn(photos, photos.visualHash);
        await m.addColumn(photos, photos.visualColor);
        await m.addColumn(photos, photos.visualDetail);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
