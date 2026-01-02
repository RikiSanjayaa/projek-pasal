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

  /// Smart sync: Only syncs if there are updates available
  /// Returns: SyncResult with status, message, and error details if failed
  static Future<SyncResult> smartSync() async {
    try {
      final hasUpdates = await checkForUpdates();

      if (!hasUpdates) {
        print("Data sudah up-to-date, tidak perlu sync.");
        return SyncResult(
          success: true,
          message: "Data sudah up-to-date",
          synced: false,
        );
      }

      print("Ada update baru, memulai sync...");
      final syncSuccess = await syncData();

      return SyncResult(
        success: syncSuccess,
        message: syncSuccess ? "Sync berhasil" : "Sync gagal",
        synced: true,
      );
    } catch (e) {
      print("Smart sync error: $e");
      final syncError = classifyError(e);
      return SyncResult(
        success: false,
        message: syncError.userMessage,
        synced: false,
        error: syncError,
      );
    }
  }

  /// Full sync with detailed error handling
  /// Returns: SyncResult with status, message, and error details if failed
  static Future<SyncResult> syncDataWithResult() async {
    try {
      final success = await syncData();
      return SyncResult(
        success: success,
        message: success ? "Sync berhasil" : "Sync gagal",
        synced: success,
      );
    } catch (e) {
      print("Sync error: $e");
      final syncError = classifyError(e);
      return SyncResult(
        success: false,
        message: syncError.userMessage,
        synced: false,
        error: syncError,
      );
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

      // Fetch all pasal_links from Supabase (only active ones)
      print("Mulai download pasal_links...");
      final Map<String, List<String>> linksMap = await _fetchPasalLinks();
      print("Ditemukan ${linksMap.length} pasal dengan links.");

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
            deskripsi: Value(uu.deskripsi),
            tahun: Value(uu.tahun),
            isActive: Value(uu.isActive),
          ),
        );

        await _syncPasalForUU(uu.id, uu.kode, linksMap);
      }
      return true;
    } catch (e) {
      print("Sync Error: $e");
      return false;
    }
  }

  /// Fetches all active pasal_links and builds a map of source_pasal_id -> [target_pasal_ids]
  static Future<Map<String, List<String>>> _fetchPasalLinks() async {
    try {
      final List<dynamic> responseLinks = await supabase
          .from('pasal_links')
          .select('source_pasal_id, target_pasal_id')
          .eq('is_active', true);

      final Map<String, List<String>> linksMap = {};
      for (var link in responseLinks) {
        final sourceId = link['source_pasal_id'] as String;
        final targetId = link['target_pasal_id'] as String;

        if (!linksMap.containsKey(sourceId)) {
          linksMap[sourceId] = [];
        }
        linksMap[sourceId]!.add(targetId);
      }
      return linksMap;
    } catch (e) {
      print("Error fetching pasal_links: $e");
      return {};
    }
  }

  static Future<void> _syncPasalForUU(
    String uuId,
    String kodeUU,
    Map<String, List<String>> linksMap,
  ) async {
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

        // Get related pasal IDs from the links map
        final relatedIds = linksMap[pasal.id] ?? [];

        pasalCompanions.add(
          PasalTableCompanion(
            id: Value(pasal.id),
            undangUndangId: Value(pasal.undangUndangId),
            nomor: Value(pasal.nomor),
            isi: Value(pasal.isi),
            penjelasan: Value(pasal.penjelasan),
            judul: Value(pasal.judul),
            keywords: Value(jsonEncode(pasal.keywords)),
            relatedIds: Value(jsonEncode(relatedIds)),
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
              deskripsi: row.deskripsi,
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
      );
    } catch (e) {
      print("Error getting UU by id: $e");
      return null;
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

/// Result class for sync operations
class SyncResult {
  final bool success;
  final String message;
  final bool synced;
  final SyncError? error;

  SyncResult({
    required this.success,
    required this.message,
    required this.synced,
    this.error,
  });

  @override
  String toString() =>
      'SyncResult(success: $success, message: $message, synced: $synced)';
}

/// Error types for better error handling
enum SyncErrorType { network, server, database, unknown }

/// Detailed error information for sync failures
class SyncError {
  final SyncErrorType type;
  final String message;
  final String? details;

  SyncError({required this.type, required this.message, this.details});

  /// Returns a user-friendly error message based on error type
  String get userMessage {
    switch (type) {
      case SyncErrorType.network:
        return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      case SyncErrorType.server:
        return 'Server sedang mengalami gangguan. Coba lagi nanti.';
      case SyncErrorType.database:
        return 'Gagal menyimpan data ke penyimpanan lokal.';
      case SyncErrorType.unknown:
        return 'Terjadi kesalahan yang tidak diketahui.';
    }
  }

  @override
  String toString() => 'SyncError(type: $type, message: $message)';
}

/// Helper to determine error type from exception
SyncError classifyError(dynamic e) {
  final errorString = e.toString().toLowerCase();

  if (errorString.contains('socket') ||
      errorString.contains('connection') ||
      errorString.contains('network') ||
      errorString.contains('timeout') ||
      errorString.contains('host')) {
    return SyncError(
      type: SyncErrorType.network,
      message: 'Network error',
      details: e.toString(),
    );
  }

  if (errorString.contains('postgresql') ||
      errorString.contains('supabase') ||
      errorString.contains('500') ||
      errorString.contains('502') ||
      errorString.contains('503')) {
    return SyncError(
      type: SyncErrorType.server,
      message: 'Server error',
      details: e.toString(),
    );
  }

  if (errorString.contains('drift') ||
      errorString.contains('sqlite') ||
      errorString.contains('database')) {
    return SyncError(
      type: SyncErrorType.database,
      message: 'Database error',
      details: e.toString(),
    );
  }

  return SyncError(
    type: SyncErrorType.unknown,
    message: 'Unknown error',
    details: e.toString(),
  );
}
