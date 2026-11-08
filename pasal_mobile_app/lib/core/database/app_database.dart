import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  TextColumn get officialUrl => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get catatanTeks => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PasalTable extends Table {
  TextColumn get id => text()();
  TextColumn get undangUndangId => text()();
  TextColumn get nomor => text()();
  TextColumn get isi => text()();
  TextColumn get penjelasan => text().nullable()();
  TextColumn get catatan => text().nullable()();
  TextColumn get judul => text().nullable()();
  TextColumn get keywords =>
      text().withDefault(const Constant('[]'))(); // JSON array as string
  TextColumn get relatedIds => text().withDefault(
    const Constant('[]'),
  )(); // JSON array as string (deprecated, use PasalLinksTable)
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get verificationStatus =>
      text().withDefault(const Constant('perlu_verifikasi'))();
  DateTimeColumn get verifiedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {undangUndangId, nomor},
  ];
}

// Table for pasal links (relationships between pasal) with keterangan
class PasalLinksTable extends Table {
  TextColumn get id => text()();
  TextColumn get sourcePasalId => text()();
  TextColumn get targetPasalId => text()();
  TextColumn get keterangan => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {sourcePasalId, targetPasalId},
  ];
}

// Riwayat versi isi pasal. Server mengirim seluruh riwayat per pasal, jadi
// klien mengganti semua versi sebuah pasal sekaligus.
@TableIndex(name: 'idx_pasal_versi_pasal_id', columns: {#pasalId})
class PasalVersiTable extends Table {
  TextColumn get id => text()();
  TextColumn get pasalId => text()();
  IntColumn get urutan => integer()();
  TextColumn get status => text()();
  TextColumn get sumber => text().nullable()();
  TextColumn get judulSumber => text().nullable()();
  TextColumn get diundangkan => text().nullable()();
  TextColumn get berlakuSejak => text().nullable()();
  TextColumn get naskahResmi => text().nullable()();
  TextColumn get isi => text()();
  TextColumn get penjelasan => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [UndangUndangTable, PasalTable, PasalLinksTable, PasalVersiTable],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Untuk tes: pakai executor sendiri (mis. `NativeDatabase.memory()`).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

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
      if (from < 4) {
        // Create pasal_links_table for proper relationship storage with keterangan
        await customStatement('''
              CREATE TABLE IF NOT EXISTS pasal_links_table (
                id TEXT NOT NULL PRIMARY KEY,
                source_pasal_id TEXT NOT NULL,
                target_pasal_id TEXT NOT NULL,
                keterangan TEXT,
                is_active INTEGER NOT NULL DEFAULT 1,
                created_at INTEGER,
                UNIQUE(source_pasal_id, target_pasal_id)
              )
            ''');
      }
      if (from < 5) {
        // Verification workflow: pasal status + official/source links on UU
        await customStatement(
          "ALTER TABLE pasal_table ADD COLUMN verification_status TEXT NOT NULL DEFAULT 'perlu_verifikasi'",
        );
        await customStatement(
          'ALTER TABLE pasal_table ADD COLUMN verified_at INTEGER',
        );
        await customStatement(
          'ALTER TABLE undang_undang_table ADD COLUMN official_url TEXT',
        );
        await customStatement(
          'ALTER TABLE undang_undang_table ADD COLUMN source_url TEXT',
        );
      }
      if (from < 6) {
        // Riwayat perubahan pasal; data lama dibiarkan, versi diisi saat sync.
        await m.createTable(pasalVersiTable);
        await m.createIndex(idxPasalVersiPasalId);
      }
      if (from < 7) {
        // Catatan status teks UU dan catatan editorial pasal; diisi saat sync.
        await m.addColumn(undangUndangTable, undangUndangTable.catatanTeks);
        await m.addColumn(pasalTable, pasalTable.catatan);
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
      onConflict: DoUpdate((old) => data, target: [pasalTable.id]),
    );
  }

  Future<void> upsertAllPasal(List<PasalTableCompanion> data) {
    return batch((batch) {
      for (final item in data) {
        batch.insert(
          pasalTable,
          item,
          onConflict: DoUpdate((old) => item, target: [pasalTable.id]),
        );
      }
    });
  }

  Future<void> upsertUndangUndang(UndangUndangTableCompanion data) {
    return into(undangUndangTable).insert(
      data,
      onConflict: DoUpdate((old) => data, target: [undangUndangTable.id]),
    );
  }

  Future<void> upsertAllUndangUndang(List<UndangUndangTableCompanion> data) {
    return batch((batch) {
      for (final item in data) {
        batch.insert(
          undangUndangTable,
          item,
          onConflict: DoUpdate((old) => item, target: [undangUndangTable.id]),
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
    return (select(
      pasalTable,
    )..where((tbl) => tbl.isActive.equals(true))).get();
  }

  // Get active pasal by UU
  Future<List<PasalTableData>> getActivePasalByUndangUndang(
    String undangUndangId,
  ) {
    return (select(pasalTable)..where(
          (tbl) =>
              tbl.undangUndangId.equals(undangUndangId) &
              tbl.isActive.equals(true),
        ))
        .get();
  }

  // Search only active pasal
  Future<List<PasalTableData>> searchActivePasal(String query) {
    return (select(pasalTable)..where(
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

  // ============================================================
  // Pasal Links queries
  // ============================================================

  // Get all links for a source pasal
  Future<List<PasalLinksTableData>> getLinksBySourcePasal(
    String sourcePasalId,
  ) {
    return (select(pasalLinksTable)..where(
          (tbl) =>
              tbl.sourcePasalId.equals(sourcePasalId) &
              tbl.isActive.equals(true),
        ))
        .get();
  }

  // Insert a single pasal link
  Future<void> insertPasalLink(PasalLinksTableCompanion data) {
    return into(pasalLinksTable).insert(data, mode: InsertMode.replace);
  }

  // Insert all pasal links in batch
  Future<void> insertAllPasalLinks(List<PasalLinksTableCompanion> data) {
    return batch((batch) {
      batch.insertAll(pasalLinksTable, data, mode: InsertMode.replace);
    });
  }

  // Clear all pasal links
  Future<void> clearAllPasalLinks() {
    return delete(pasalLinksTable).go();
  }

  // ============================================================
  // Pasal versi (riwayat perubahan) queries
  // ============================================================

  // Semua versi satu pasal, dari yang tertua ke terbaru
  Future<List<PasalVersiTableData>> getVersiByPasalId(String pasalId) {
    return (select(pasalVersiTable)
          ..where((tbl) => tbl.pasalId.equals(pasalId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.urutan)]))
        .get();
  }

  Future<void> insertAllPasalVersi(List<PasalVersiTableCompanion> data) {
    return batch((batch) {
      batch.insertAll(pasalVersiTable, data, mode: InsertMode.replace);
    });
  }

  Future<void> clearAllPasalVersi() {
    return delete(pasalVersiTable).go();
  }

  Future<int> deletePasalVersiByPasalId(String pasalId) {
    return (delete(
      pasalVersiTable,
    )..where((tbl) => tbl.pasalId.equals(pasalId))).go();
  }

  // Ganti seluruh riwayat pasal-pasal ini dengan [data] (hapus lalu isi ulang)
  Future<void> replacePasalVersi(
    Iterable<String> pasalIds,
    List<PasalVersiTableCompanion> data,
  ) {
    return transaction(() async {
      final ids = pasalIds.toSet().toList();
      // Dipecah agar tidak melewati batas variabel SQLite
      for (var i = 0; i < ids.length; i += 500) {
        final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
        await (delete(
          pasalVersiTable,
        )..where((tbl) => tbl.pasalId.isIn(chunk))).go();
      }
      await insertAllPasalVersi(data);
    });
  }

  // Upsert pasal link
  Future<void> upsertPasalLink(PasalLinksTableCompanion data) {
    return into(pasalLinksTable).insert(
      data,
      onConflict: DoUpdate((old) => data, target: [pasalLinksTable.id]),
    );
  }

  // ============================================================
  // Active-only queries for sync filtering
  // ============================================================

  // Get only active undang-undang
  Future<List<UndangUndangTableData>> getActiveUndangUndang() {
    return (select(
      undangUndangTable,
    )..where((tbl) => tbl.isActive.equals(true))).get();
  }

  // ============================================================
  // Deletion methods for sync cleanup
  // ============================================================

  // Delete undang-undang by ID
  Future<int> deleteUndangUndangById(String id) {
    return (delete(undangUndangTable)..where((tbl) => tbl.id.equals(id))).go();
  }

  // Delete all pasal by undang-undang ID
  Future<int> deletePasalByUndangUndangId(String undangUndangId) {
    return (delete(
      pasalTable,
    )..where((tbl) => tbl.undangUndangId.equals(undangUndangId))).go();
  }

  // Delete pasal links by source pasal ID
  Future<int> deletePasalLinksBySourcePasalId(String sourcePasalId) {
    return (delete(
      pasalLinksTable,
    )..where((tbl) => tbl.sourcePasalId.equals(sourcePasalId))).go();
  }

  // Delete pasal links by target pasal ID
  Future<int> deletePasalLinksByTargetPasalId(String targetPasalId) {
    return (delete(
      pasalLinksTable,
    )..where((tbl) => tbl.targetPasalId.equals(targetPasalId))).go();
  }

  Future<int> deletePasalLinksById(String id) {
    return (delete(pasalLinksTable)..where((tbl) => tbl.id.equals(id))).go();
  }

  // Delete inactive undang-undang and their related data
  Future<void> deleteInactiveUndangUndang() async {
    final inactiveUU = await (select(
      undangUndangTable,
    )..where((tbl) => tbl.isActive.equals(false))).get();

    for (final uu in inactiveUU) {
      // Get all pasal for this UU to delete their links
      final pasalList = await getPasalByUndangUndang(uu.id);
      for (final pasal in pasalList) {
        await deletePasalLinksBySourcePasalId(pasal.id);
        await deletePasalLinksByTargetPasalId(pasal.id);
        await deletePasalVersiByPasalId(pasal.id);
      }
      // Delete all pasal for this UU
      await deletePasalByUndangUndangId(uu.id);
      // Delete the UU itself
      await deleteUndangUndangById(uu.id);
    }
  }

  // Delete a single UU and all its related data (pasal and links)
  Future<void> deleteUndangUndangWithRelatedData(String uuId) async {
    // Get all pasal for this UU to delete their links
    final pasalList = await getPasalByUndangUndang(uuId);
    for (final pasal in pasalList) {
      await deletePasalLinksBySourcePasalId(pasal.id);
      await deletePasalLinksByTargetPasalId(pasal.id);
      await deletePasalVersiByPasalId(pasal.id);
    }
    // Delete all pasal for this UU
    await deletePasalByUndangUndangId(uuId);
    // Delete the UU itself
    await deleteUndangUndangById(uuId);
  }

  // Delete inactive pasal and their links
  Future<void> deleteInactivePasal() async {
    final inactivePasal = await (select(
      pasalTable,
    )..where((tbl) => tbl.isActive.equals(false))).get();

    for (final pasal in inactivePasal) {
      await deletePasalLinksBySourcePasalId(pasal.id);
      await deletePasalLinksByTargetPasalId(pasal.id);
      await deletePasalVersiByPasalId(pasal.id);
      await deletePasalById(pasal.id);
    }
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'pasal_database',
    native: const DriftNativeOptions(shareAcrossIsolates: false),
    web: DriftWebOptions(
      // URL absolut: worker drift tidak punya base URL, jadi path relatif gagal dibuat
      // ("Failed to construct 'URL'") di browser tanpa SharedWorker, misalnya Safari iOS.
      sqlite3Wasm: Uri.base.resolve('sqlite3.wasm'),
      driftWorker: Uri.base.resolve('drift_worker.dart.js'),
    ),
  );
}
