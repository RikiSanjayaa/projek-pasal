import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

part 'app_database.g.dart';

// Tables
class UndangUndangTable extends Table {
  TextColumn get id => text()();
  TextColumn get kode => text()();
  TextColumn get nama => text()();
  TextColumn get namaLengkap => text().nullable()();
  TextColumn get deskripsi => text().nullable()();
  IntColumn get tahun => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PasalTable extends Table {
  TextColumn get id => text()();
  TextColumn get undangUndangId => text()();
  TextColumn get nomor => text()();
  TextColumn get isi => text()();
  TextColumn get penjelasan => text().nullable()();
  TextColumn get judul => text().nullable()();
  TextColumn get keywords =>
      text().withDefault(const Constant('[]'))(); // JSON array as string
  TextColumn get relatedIds =>
      text().withDefault(const Constant('[]'))(); // JSON array as string
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {undangUndangId, nomor},
  ];
}

@DriftDatabase(tables: [UndangUndangTable, PasalTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Since data is synced from server, we can safely add columns
          if (from < 2) {
            // Add deskripsi column to undang_undang table
            await customStatement(
              'ALTER TABLE undang_undang_table ADD COLUMN deskripsi TEXT',
            );
          }
          if (from < 3) {
            // Add is_active column to pasal table for soft delete tracking
            await customStatement(
              'ALTER TABLE pasal_table ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
            );
            // Add updated_at column to undang_undang table for incremental sync
            await customStatement(
              'ALTER TABLE undang_undang_table ADD COLUMN updated_at INTEGER',
            );
          }
        },
      );

  // UndangUndang queries
  Future<List<UndangUndangTableData>> getAllUndangUndang() {
    return select(undangUndangTable).get();
  }

  Future<UndangUndangTableData?> getUndangUndangById(String id) {
    return (select(
      undangUndangTable,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertUndangUndang(UndangUndangTableCompanion data) {
    return into(undangUndangTable).insert(data, mode: InsertMode.replace);
  }

  Future<void> insertAllUndangUndang(List<UndangUndangTableCompanion> data) {
    return batch((batch) {
      batch.insertAll(undangUndangTable, data, mode: InsertMode.replace);
    });
  }

  // Pasal queries
  Future<List<PasalTableData>> getAllPasal() {
    return select(pasalTable).get();
  }

  Future<PasalTableData?> getPasalById(String id) {
    return (select(
      pasalTable,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<List<PasalTableData>> getPasalByUndangUndang(String undangUndangId) {
    return (select(
      pasalTable,
    )..where((tbl) => tbl.undangUndangId.equals(undangUndangId))).get();
  }

  Future<List<PasalTableData>> searchPasal(String query) {
    return (select(pasalTable)..where(
          (tbl) => tbl.isi.like('%$query%') | tbl.nomor.like('%$query%'),
        ))
        .get();
  }

  Future<void> insertPasal(PasalTableCompanion data) {
    return into(pasalTable).insert(data, mode: InsertMode.replace);
  }

  Future<void> insertAllPasal(List<PasalTableCompanion> data) {
    return batch((batch) {
      batch.insertAll(pasalTable, data, mode: InsertMode.replace);
    });
  }

  Future<void> clearAllPasal() {
    return delete(pasalTable).go();
  }

  Future<void> clearAllUndangUndang() {
    return delete(undangUndangTable).go();
  }

  // Upsert methods for incremental sync
  Future<void> upsertPasal(PasalTableCompanion data) {
    return into(pasalTable).insert(
      data,
      onConflict: DoUpdate(
        (old) => data,
        target: [pasalTable.id],
      ),
    );
  }

  Future<void> upsertAllPasal(List<PasalTableCompanion> data) {
    return batch((batch) {
      for (final item in data) {
        batch.insert(
          pasalTable,
          item,
          onConflict: DoUpdate(
            (old) => item,
            target: [pasalTable.id],
          ),
        );
      }
    });
  }

  Future<void> upsertUndangUndang(UndangUndangTableCompanion data) {
    return into(undangUndangTable).insert(
      data,
      onConflict: DoUpdate(
        (old) => data,
        target: [undangUndangTable.id],
      ),
    );
  }

  Future<void> upsertAllUndangUndang(List<UndangUndangTableCompanion> data) {
    return batch((batch) {
      for (final item in data) {
        batch.insert(
          undangUndangTable,
          item,
          onConflict: DoUpdate(
            (old) => item,
            target: [undangUndangTable.id],
          ),
        );
      }
    });
  }

  // Delete pasal by ID (for handling server-side hard deletes)
  Future<int> deletePasalById(String id) {
    return (delete(pasalTable)..where((tbl) => tbl.id.equals(id))).go();
  }

  // Get only active pasal
  Future<List<PasalTableData>> getActivePasal() {
    return (select(pasalTable)..where((tbl) => tbl.isActive.equals(true)))
        .get();
  }

  // Get active pasal by UU
  Future<List<PasalTableData>> getActivePasalByUndangUndang(
      String undangUndangId) {
    return (select(pasalTable)
          ..where((tbl) =>
              tbl.undangUndangId.equals(undangUndangId) &
              tbl.isActive.equals(true)))
        .get();
  }

  // Search only active pasal
  Future<List<PasalTableData>> searchActivePasal(String query) {
    return (select(pasalTable)
          ..where(
            (tbl) =>
                (tbl.isi.like('%$query%') | tbl.nomor.like('%$query%')) &
                tbl.isActive.equals(true),
          ))
        .get();
  }

  // Get latest updated_at timestamp from local database
  Future<DateTime?> getLatestPasalTimestamp() async {
    final query = selectOnly(pasalTable)
      ..addColumns([pasalTable.updatedAt])
      ..orderBy([OrderingTerm.desc(pasalTable.updatedAt)])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result?.read(pasalTable.updatedAt);
  }

  // Get latest updated_at timestamp from undang_undang
  Future<DateTime?> getLatestUndangUndangTimestamp() async {
    final query = selectOnly(undangUndangTable)
      ..addColumns([undangUndangTable.updatedAt])
      ..orderBy([OrderingTerm.desc(undangUndangTable.updatedAt)])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result?.read(undangUndangTable.updatedAt);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pasal_database.db'));
    return NativeDatabase(file, logStatements: true);
  });
}
