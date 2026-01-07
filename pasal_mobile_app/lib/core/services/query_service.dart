import 'dart:convert';
import '../database/app_database.dart';
import '../../models/undang_undang_model.dart';
import '../../models/pasal_model.dart';
import '../../models/pasal_link_model.dart';

/// Service for querying data from the local database.
///
/// This service provides read-only operations for accessing
/// Undang-Undang, Pasal, and related data from the local Drift database.
class QueryService {
  static late AppDatabase _database;

  /// Initialize the query service with the database instance.
  /// Called by DataService.initialize()
  static void initialize(AppDatabase database) {
    _database = database;
  }

  // ============================================================
  // Undang-Undang Queries
  // ============================================================

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
              deskripsi: row.deskripsi,
              tahun: row.tahun,
              isActive: row.isActive,
              updatedAt: row.updatedAt,
            ),
          )
          .toList();
    } catch (e) {
      print("Error getting all UU: $e");
      return [];
    }
  }

  static Future<UndangUndangModel?> getUUById(String uuId) async {
    try {
      final row = await _database.getUndangUndangById(uuId);
      if (row == null) return null;
      return UndangUndangModel(
        id: row.id,
        kode: row.kode,
        nama: row.nama,
        namaLengkap: row.namaLengkap,
        deskripsi: row.deskripsi,
        tahun: row.tahun,
        isActive: row.isActive,
        updatedAt: row.updatedAt,
      );
    } catch (e) {
      print("Error getting UU by id: $e");
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

  // ============================================================
  // Pasal Queries
  // ============================================================

  static Future<List<PasalModel>> getAllPasal() async {
    try {
      final data = await _database.getActivePasal();
      return data.map((row) => _rowToPasalModel(row)).toList();
    } catch (e) {
      print("Error getting all pasal: $e");
      return [];
    }
  }

  static Future<List<PasalModel>> searchPasal(String query) async {
    if (query.isEmpty) return [];
    try {
      final data = await _database.searchActivePasal(query);
      return data.map((row) => _rowToPasalModel(row)).toList();
    } catch (e) {
      print("Search error: $e");
      return [];
    }
  }

  static Future<PasalModel?> getPasalById(String id) async {
    try {
      final data = await _database.getPasalById(id);
      if (data == null) return null;
      return _rowToPasalModel(data);
    } catch (e) {
      print("Error getting pasal by id: $e");
      return null;
    }
  }

  static Future<List<PasalModel>> getPasalByUU(String uuId) async {
    try {
      final data = await _database.getActivePasalByUndangUndang(uuId);
      return data.map((row) => _rowToPasalModel(row)).toList();
    } catch (e) {
      print("Error getting pasal by UU: $e");
      return [];
    }
  }

  static Future<List<PasalModel>> getPasalByKeyword(String keyword) async {
    try {
      final data = await _database.searchActivePasal(keyword);
      return data.map((row) => _rowToPasalModel(row)).toList();
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

  // ============================================================
  // Pasal Links Queries
  // ============================================================

  /// Get pasal links for a given pasal ID (with keterangan)
  static Future<List<PasalLinkWithTarget>> getPasalLinks(String pasalId) async {
    try {
      final links = await _database.getLinksBySourcePasal(pasalId);
      final results = <PasalLinkWithTarget>[];

      for (final link in links) {
        final targetPasal = await getPasalById(link.targetPasalId);
        if (targetPasal != null) {
          results.add(
            PasalLinkWithTarget(
              targetPasal: targetPasal,
              keterangan: link.keterangan,
            ),
          );
        }
      }

      return results;
    } catch (e) {
      print("Error getting pasal links: $e");
      return [];
    }
  }

  // ============================================================
  // Helper Methods
  // ============================================================

  /// Convert a database row to PasalModel
  static PasalModel _rowToPasalModel(PasalTableData row) {
    return PasalModel(
      id: row.id,
      undangUndangId: row.undangUndangId,
      nomor: row.nomor,
      isi: row.isi,
      penjelasan: row.penjelasan,
      judul: row.judul,
      keywords: _parseJsonArray(row.keywords),
      relatedIds: _parseJsonArray(row.relatedIds),
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Parse a JSON array string to List<String>
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
