import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/undang_undang_model.dart';
import '../../models/pasal_model.dart';
import '../database/app_database.dart';

class DataService {
  static late AppDatabase _database;
  static final SupabaseClient supabase = Supabase.instance.client;

  static Future<void> initialize() async {
    _database = AppDatabase();
    print("Drift database initialized");
  }

  static Future<bool> checkForUpdates() async {
    try {
      final allLocal = await getAllPasal();
      if (allLocal.isEmpty) return true;

      List<PasalModel> tempSort = List.from(allLocal);
      tempSort.sort((a, b) {
        final tA = a.updatedAt ?? a.createdAt ?? DateTime(2000);
        final tB = b.updatedAt ?? b.createdAt ?? DateTime(2000);
        return tB.compareTo(tA);
      });

      final DateTime localLatest =
          tempSort.first.updatedAt ??
          tempSort.first.createdAt ??
          DateTime(2000);

      final response = await supabase
          .from('pasal')
          .select('updated_at, created_at')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        DateTime serverLatest;
        if (response['updated_at'] != null) {
          serverLatest = DateTime.parse(response['updated_at']);
        } else if (response['created_at'] != null) {
          serverLatest = DateTime.parse(response['created_at']);
        } else {
          return false;
        }

        if (serverLatest.difference(localLatest).inSeconds > 5) {
          print(
            "Update tersedia! Beda waktu: ${serverLatest.difference(localLatest).inSeconds} detik",
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      print("Check for updates error: $e");
      return false;
    }
  }

  static Future<bool> syncData() async {
    try {
      print("Mulai download data UU...");

      // Fetch all Undang-Undang from Supabase
      final List<dynamic> responseUU = await supabase
          .from('undang_undang')
          .select()
          .order('tahun', ascending: false);

      print("Ditemukan ${responseUU.length} UU di Server.");

      // Clear and insert UU data
      await _database.clearAllUndangUndang();

      for (var item in responseUU) {
        final uu = UndangUndangModel.fromJson(item);
        await _database.insertUndangUndang(
          UndangUndangTableCompanion(
            id: Value(uu.id),
            kode: Value(uu.kode),
            nama: Value(uu.nama),
            namaLengkap: Value(uu.namaLengkap),
            tahun: Value(uu.tahun),
            isActive: Value(uu.isActive),
          ),
        );

        await _syncPasalForUU(uu.id, uu.kode);
      }
      return true;
    } catch (e) {
      print("Sync Error: $e");
      return false;
    }
  }

  static Future<void> _syncPasalForUU(String uuId, String kodeUU) async {
    try {
      final List<dynamic> responsePasal = await supabase
          .from('pasal')
          .select()
          .eq('undang_undang_id', uuId);

      print("   Download $kodeUU: Dapat ${responsePasal.length} pasal.");

      // Clear existing pasal for this UU and insert new ones
      final pasalCompanions = <PasalTableCompanion>[];

      for (var item in responsePasal) {
        final pasal = PasalModel.fromJson(item);
        pasalCompanions.add(
          PasalTableCompanion(
            id: Value(pasal.id),
            undangUndangId: Value(pasal.undangUndangId),
            nomor: Value(pasal.nomor),
            isi: Value(pasal.isi),
            penjelasan: Value(pasal.penjelasan),
            judul: Value(pasal.judul),
            keywords: Value(jsonEncode(pasal.keywords)),
            relatedIds: Value(jsonEncode(pasal.relatedIds)),
            createdAt: Value(pasal.createdAt),
            updatedAt: Value(pasal.updatedAt),
          ),
        );
      }

      if (pasalCompanions.isNotEmpty) {
        await _database.insertAllPasal(pasalCompanions);
      }
    } catch (e) {
      print("Gagal sync pasal $kodeUU: $e");
    }
  }

  static Future<List<UndangUndangModel>> getAllUU() async {
    try {
      final data = await _database.getAllUndangUndang();
      return data
          .map(
            (row) => UndangUndangModel(
              id: row.id,
              kode: row.kode,
              nama: row.nama,
              namaLengkap: row.namaLengkap,
              tahun: row.tahun,
              isActive: row.isActive,
            ),
          )
          .toList();
    } catch (e) {
      print("Error getting all UU: $e");
      return [];
    }
  }

  static Future<List<PasalModel>> getAllPasal() async {
    try {
      final data = await _database.getAllPasal();
      return data
          .map(
            (row) => PasalModel(
              id: row.id,
              undangUndangId: row.undangUndangId,
              nomor: row.nomor,
              isi: row.isi,
              penjelasan: row.penjelasan,
              judul: row.judul,
              keywords: _parseJsonArray(row.keywords),
              relatedIds: _parseJsonArray(row.relatedIds),
              createdAt: row.createdAt,
              updatedAt: row.updatedAt,
            ),
          )
          .toList();
    } catch (e) {
      print("Error getting all pasal: $e");
      return [];
    }
  }

  static Future<List<PasalModel>> searchPasal(String query) async {
    if (query.isEmpty) return [];
    try {
      final data = await _database.searchPasal(query);
      return data
          .map(
            (row) => PasalModel(
              id: row.id,
              undangUndangId: row.undangUndangId,
              nomor: row.nomor,
              isi: row.isi,
              penjelasan: row.penjelasan,
              judul: row.judul,
              keywords: _parseJsonArray(row.keywords),
              relatedIds: _parseJsonArray(row.relatedIds),
              createdAt: row.createdAt,
              updatedAt: row.updatedAt,
            ),
          )
          .toList();
    } catch (e) {
      print("Search error: $e");
      return [];
    }
  }

  static Future<PasalModel?> getPasalById(String id) async {
    try {
      final data = await _database.getPasalById(id);
      if (data == null) return null;

      return PasalModel(
        id: data.id,
        undangUndangId: data.undangUndangId,
        nomor: data.nomor,
        isi: data.isi,
        penjelasan: data.penjelasan,
        judul: data.judul,
        keywords: _parseJsonArray(data.keywords),
        relatedIds: _parseJsonArray(data.relatedIds),
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
      );
    } catch (e) {
      print("Error getting pasal by id: $e");
      return null;
    }
  }

  static Future<String> getKodeUU(String uuId) async {
    try {
      final uu = await _database.getUndangUndangById(uuId);
      return uu?.kode ?? "UU";
    } catch (e) {
      return "UU";
    }
  }

  static Future<List<PasalModel>> getPasalByUU(String uuId) async {
    try {
      final data = await _database.getPasalByUndangUndang(uuId);
      return data
          .map(
            (row) => PasalModel(
              id: row.id,
              undangUndangId: row.undangUndangId,
              nomor: row.nomor,
              isi: row.isi,
              penjelasan: row.penjelasan,
              judul: row.judul,
              keywords: _parseJsonArray(row.keywords),
              relatedIds: _parseJsonArray(row.relatedIds),
              createdAt: row.createdAt,
              updatedAt: row.updatedAt,
            ),
          )
          .toList();
    } catch (e) {
      print("Error getting pasal by UU: $e");
      return [];
    }
  }

  static Future<List<PasalModel>> getPasalByKeyword(String keyword) async {
    try {
      final data = await _database.searchPasal(keyword);
      return data
          .map(
            (row) => PasalModel(
              id: row.id,
              undangUndangId: row.undangUndangId,
              nomor: row.nomor,
              isi: row.isi,
              penjelasan: row.penjelasan,
              judul: row.judul,
              keywords: _parseJsonArray(row.keywords),
              relatedIds: _parseJsonArray(row.relatedIds),
              createdAt: row.createdAt,
              updatedAt: row.updatedAt,
            ),
          )
          .toList();
    } catch (e) {
      print("Error getting pasal by keyword: $e");
      return [];
    }
  }
  static Future<List<PasalModel>> getLatestUpdates({int limit = 5}) async {
    try {
      final all = await getAllPasal();
      all.sort((a, b) {
        final tA = a.updatedAt ?? a.createdAt ?? DateTime(2000);
        final tB = b.updatedAt ?? b.createdAt ?? DateTime(2000);
        return tB.compareTo(tA);
      });
      return all.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // Helper method to parse JSON arrays stored as strings
  static List<String> _parseJsonArray(String jsonString) {
    try {
      if (jsonString.isEmpty || jsonString == '[]') return [];
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return List<String>.from(decoded);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
