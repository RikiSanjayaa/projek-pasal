import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/core/database/app_database.dart';
import 'package:pasal_mobile_app/core/services/data_service.dart';

/// Tes ini memakai SQLite in-memory dan dilewati bila pustaka sqlite3 sistem
/// tidak tersedia (mis. image Flutter minimal tanpa libsqlite3).
Map<String, dynamic> _versi(String id, String pasalId, int urutan, String isi) {
  return {
    'id': id,
    'pasal_id': pasalId,
    'urutan': urutan,
    'status': urutan == 1 ? 'asli' : 'diubah',
    'sumber': 'UU 1/2026',
    'judul_sumber': null,
    'diundangkan': '2026-01-02',
    'berlaku_sejak': null,
    'naskah_resmi': null,
    'isi': isi,
    'penjelasan': null,
    'created_at': '2026-01-02T00:00:00.000000Z',
    'updated_at': '2026-01-02T00:00:00.000000Z',
  };
}

void main() {
  AppDatabase? opened;
  var sqliteOk = true;

  AppDatabase newDb() => AppDatabase.forTesting(NativeDatabase.memory());

  setUp(() async {
    try {
      final db = newDb();
      await db.getAllPasal(); // memaksa koneksi terbuka
      opened = db;
      DataService.useDatabase(db);
    } catch (_) {
      sqliteOk = false;
      opened = null;
    }
  });

  tearDown(() async {
    await opened?.close();
  });

  Future<List<String>> ids(String pasalId) async =>
      (await DataService.getPasalVersi(pasalId)).map((v) => v.id).toList();

  group('replace rule riwayat (sync inkremental)', () {
    test('mengganti seluruh versi pasal di updated_pasal', () async {
      if (!sqliteOk) return markTestSkipped('libsqlite3 tidak tersedia');
      await DataService.applyIncrementalVersi(
        versiRows: [_versi('a1', 'p1', 1, 'lama'), _versi('b1', 'p2', 1, 'x')],
        updatedPasal: [
          {'id': 'p1'},
          {'id': 'p2'},
        ],
        deletedPasalIds: [],
      );
      expect(await ids('p1'), ['a1']);

      await DataService.applyIncrementalVersi(
        versiRows: [_versi('a2', 'p1', 2, 'baru'), _versi('a1', 'p1', 1, 'lama')],
        updatedPasal: [
          {'id': 'p1'},
        ],
        deletedPasalIds: [],
      );
      final p1 = await DataService.getPasalVersi('p1');
      expect(p1.map((v) => v.id), ['a1', 'a2']); // urut urutan
      expect(await ids('p2'), ['b1']); // pasal lain tidak tersentuh
    });

    test('versi yang hilang dari server ikut terhapus', () async {
      if (!sqliteOk) return markTestSkipped('libsqlite3 tidak tersedia');
      await DataService.applyIncrementalVersi(
        versiRows: [_versi('a1', 'p1', 1, 'a'), _versi('a2', 'p1', 2, 'b')],
        updatedPasal: [
          {'id': 'p1'},
        ],
        deletedPasalIds: [],
      );
      await DataService.applyIncrementalVersi(
        versiRows: [_versi('a1', 'p1', 1, 'a')],
        updatedPasal: [
          {'id': 'p1'},
        ],
        deletedPasalIds: [],
      );
      expect(await ids('p1'), ['a1']);
    });

    test('pasal di updated_pasal tanpa baris versi dikosongkan', () async {
      if (!sqliteOk) return markTestSkipped('libsqlite3 tidak tersedia');
      await DataService.applyIncrementalVersi(
        versiRows: [_versi('a1', 'p1', 1, 'a')],
        updatedPasal: [
          {'id': 'p1'},
        ],
        deletedPasalIds: [],
      );
      await DataService.applyIncrementalVersi(
        versiRows: [],
        updatedPasal: [
          {'id': 'p1'},
        ],
        deletedPasalIds: [],
      );
      expect(await ids('p1'), isEmpty);
    });

    test('deleted_pasal_ids ikut dihapus versinya', () async {
      if (!sqliteOk) return markTestSkipped('libsqlite3 tidak tersedia');
      await DataService.applyIncrementalVersi(
        versiRows: [_versi('a1', 'p1', 1, 'a'), _versi('b1', 'p2', 1, 'b')],
        updatedPasal: [
          {'id': 'p1'},
          {'id': 'p2'},
        ],
        deletedPasalIds: [],
      );
      await DataService.applyIncrementalVersi(
        versiRows: [],
        updatedPasal: [],
        deletedPasalIds: ['p1'],
      );
      expect(await ids('p1'), isEmpty);
      expect(await ids('p2'), ['b1']);
    });

    test('kunci pasal_versi absen (null) = tidak mengubah apa pun', () async {
      if (!sqliteOk) return markTestSkipped('libsqlite3 tidak tersedia');
      await DataService.applyIncrementalVersi(
        versiRows: [_versi('a1', 'p1', 1, 'a')],
        updatedPasal: [
          {'id': 'p1'},
        ],
        deletedPasalIds: [],
      );
      await DataService.applyIncrementalVersi(
        versiRows: null,
        updatedPasal: [
          {'id': 'p1'},
        ],
        deletedPasalIds: ['p1'],
      );
      expect(await ids('p1'), ['a1']);
    });

    test('lebih dari 500 pasal dipecah per chunk', () async {
      if (!sqliteOk) return markTestSkipped('libsqlite3 tidak tersedia');
      final rows = [
        for (var i = 0; i < 1200; i++) _versi('v$i', 'p$i', 1, 'isi $i'),
      ];
      final updated = [
        for (var i = 0; i < 1200; i++) {'id': 'p$i'},
      ];
      await DataService.applyIncrementalVersi(
        versiRows: rows,
        updatedPasal: updated,
        deletedPasalIds: [],
      );
      await DataService.applyIncrementalVersi(
        versiRows: [_versi('v0', 'p0', 1, 'isi 0')],
        updatedPasal: updated,
        deletedPasalIds: [],
      );
      expect((await opened!.select(opened!.pasalVersiTable).get()).length, 1);
    });
  });

  group('migrasi skema', () {
    test('v5 -> v6 membuat pasal_versi tanpa menghapus data lama', () async {
      if (!sqliteOk) return markTestSkipped('libsqlite3 tidak tersedia');
      final old = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('''
              CREATE TABLE undang_undang_table (
                id TEXT NOT NULL PRIMARY KEY, kode TEXT NOT NULL, nama TEXT NOT NULL,
                nama_lengkap TEXT, deskripsi TEXT, tahun INTEGER NOT NULL DEFAULT 0,
                is_active INTEGER NOT NULL DEFAULT 1, updated_at INTEGER,
                official_url TEXT, source_url TEXT)''');
            raw.execute('''
              CREATE TABLE pasal_table (
                id TEXT NOT NULL PRIMARY KEY, undang_undang_id TEXT NOT NULL,
                nomor TEXT NOT NULL, isi TEXT NOT NULL, penjelasan TEXT, judul TEXT,
                keywords TEXT NOT NULL DEFAULT '[]', related_ids TEXT NOT NULL DEFAULT '[]',
                is_active INTEGER NOT NULL DEFAULT 1, created_at INTEGER, updated_at INTEGER,
                verification_status TEXT NOT NULL DEFAULT 'perlu_verifikasi', verified_at INTEGER,
                UNIQUE(undang_undang_id, nomor))''');
            raw.execute('''
              CREATE TABLE pasal_links_table (
                id TEXT NOT NULL PRIMARY KEY, source_pasal_id TEXT NOT NULL,
                target_pasal_id TEXT NOT NULL, keterangan TEXT,
                is_active INTEGER NOT NULL DEFAULT 1, created_at INTEGER,
                UNIQUE(source_pasal_id, target_pasal_id))''');
            raw.execute(
              "INSERT INTO pasal_table (id, undang_undang_id, nomor, isi) VALUES ('p1','u1','3','isi lama')",
            );
            raw.execute('PRAGMA user_version = 5');
          },
        ),
      );
      addTearDown(old.close);

      final pasal = await old.getPasalById('p1');
      expect(pasal?.isi, 'isi lama');

      await old.insertAllPasalVersi([
        PasalVersiTableCompanion.insert(
          id: 'v1',
          pasalId: 'p1',
          urutan: 1,
          status: 'asli',
          isi: 'isi lama',
        ),
      ]);
      expect((await old.getVersiByPasalId('p1')).single.id, 'v1');

      final index = await old
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_pasal_versi_pasal_id'",
          )
          .get();
      expect(index, hasLength(1));
    });
  });
}
