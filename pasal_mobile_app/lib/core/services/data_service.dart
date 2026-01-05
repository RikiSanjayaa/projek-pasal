import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/undang_undang_model.dart';
import '../../models/pasal_model.dart';
import '../database/app_database.dart';
import 'sync_progress.dart';

class DataService {
  static late AppDatabase _database;
  static final SupabaseClient supabase = Supabase.instance.client;

  /// Stream controller for sync progress updates
  static StreamController<SyncProgress>? _progressController;

  /// Flag to check if sync should be cancelled
  static bool _isCancelled = false;

  static Future<void> initialize() async {
    _database = AppDatabase();
    print("Drift database initialized");
  }

  /// Get the progress stream for UI updates
  static Stream<SyncProgress>? get progressStream =>
      _progressController?.stream;

  /// Cancel ongoing sync operation
  static void cancelSync() {
    _isCancelled = true;
  }

  /// Check if there are updates available on the server
  static Future<bool> checkForUpdates() async {
    try {
      final localLatest = await _database.getLatestPasalTimestamp();
      if (localLatest == null) return true;

      final response = await supabase
          .from('pasal')
          .select('updated_at')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['updated_at'] != null) {
        final serverLatest = DateTime.parse(response['updated_at']);
        if (serverLatest.difference(localLatest).inSeconds > 5) {
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
  static Future<SyncResult> smartSync() async {
    try {
      final hasUpdates = await checkForUpdates();
      if (!hasUpdates) {
        return SyncResult(
          success: true,
          message: "Data sudah up-to-date",
          synced: false,
        );
      }
      final syncSuccess = await syncData();
      return SyncResult(
        success: syncSuccess,
        message: syncSuccess ? "Sync berhasil" : "Sync gagal",
        synced: true,
      );
    } catch (e) {
      final syncError = classifyError(e);
      return SyncResult(
        success: false,
        message: syncError.userMessage,
        synced: false,
        error: syncError,
      );
    }
  }

  /// Full sync with progress tracking
  /// Returns: SyncResult with status, message, and error details if failed
  static Future<SyncResult> syncDataWithProgress({
    DateTime? lastSyncTime,
    required void Function(SyncProgress) onProgress,
  }) async {
    _isCancelled = false;
    _progressController = StreamController<SyncProgress>.broadcast();

    // Forward stream events to callback
    _progressController!.stream.listen(onProgress);

    try {
      final isIncremental = lastSyncTime != null;
      final startTime = DateTime.now();

      // Initial progress
      _emitProgress(SyncProgress.initial(isIncremental: isIncremental));

      bool success;
      SyncProgress finalProgress;

      if (isIncremental) {
        (success, finalProgress) = await _incrementalSyncWithProgress(
          lastSyncTime,
          startTime,
        );
      } else {
        (success, finalProgress) = await _fullSyncWithProgress(startTime);
      }

      if (_isCancelled) {
        _emitProgress(
          finalProgress.copyWith(
            phase: SyncPhase.cancelled,
            currentOperation: "Sinkronisasi dibatalkan",
          ),
        );
        return SyncResult(
          success: false,
          message: "Sinkronisasi dibatalkan oleh pengguna",
          synced: false,
        );
      }

      return SyncResult(
        success: success,
        message: success ? finalProgress.completionSummary : "Sync gagal",
        synced: success,
      );
    } catch (e) {
      final syncError = classifyError(e);
      _emitProgress(
        SyncProgress(
          phase: SyncPhase.error,
          currentOperation: syncError.userMessage,
          startTime: DateTime.now(),
          errorMessage: syncError.userMessage,
        ),
      );
      return SyncResult(
        success: false,
        message: syncError.userMessage,
        synced: false,
        error: syncError,
      );
    } finally {
      await _progressController?.close();
      _progressController = null;
    }
  }

  /// Legacy sync method (without progress) for backward compatibility
  static Future<SyncResult> syncDataWithResult({DateTime? lastSyncTime}) async {
    try {
      final success = await syncData(lastSyncTime: lastSyncTime);
      final isIncremental = lastSyncTime != null;
      return SyncResult(
        success: success,
        message: success
            ? (isIncremental
                  ? "Incremental sync berhasil"
                  : "Full sync berhasil")
            : "Sync gagal",
        synced: success,
      );
    } catch (e) {
      final syncError = classifyError(e);
      return SyncResult(
        success: false,
        message: syncError.userMessage,
        synced: false,
        error: syncError,
      );
    }
  }

  /// Legacy sync without progress tracking
  static Future<bool> syncData({DateTime? lastSyncTime}) async {
    try {
      final isIncremental = lastSyncTime != null;
      if (isIncremental) {
        final (success, _) = await _incrementalSyncWithProgress(
          lastSyncTime,
          DateTime.now(),
        );
        return success;
      } else {
        final (success, _) = await _fullSyncWithProgress(DateTime.now());
        return success;
      }
    } catch (e) {
      print("Sync Error: $e");
      return false;
    }
  }

  /// Emit progress update
  static void _emitProgress(SyncProgress progress) {
    _progressController?.add(progress);
  }

  /// Check if sync was cancelled
  static bool _checkCancelled() => _isCancelled;

  /// Full sync with progress tracking
  static Future<(bool, SyncProgress)> _fullSyncWithProgress(
    DateTime startTime,
  ) async {
    int totalBytes = 0;
    int downloadedPasal = 0;
    int totalPasal = 0;

    try {
      // Phase 1: Download UU list
      _emitProgress(
        SyncProgress(
          phase: SyncPhase.downloadingUU,
          currentOperation: "Mengunduh daftar undang-undang...",
          startTime: startTime,
        ),
      );

      if (_checkCancelled()) return (false, _cancelledProgress(startTime));

      final List<dynamic> responseUU = await supabase
          .from('undang_undang')
          .select()
          .order('tahun', ascending: false);

      final uuBytes = jsonEncode(responseUU).length;
      totalBytes += uuBytes;

      final totalUU = responseUU.length;

      // Phase 2: Get total pasal count for progress estimation
      _emitProgress(
        SyncProgress(
          phase: SyncPhase.checking,
          currentOperation: "Menghitung jumlah pasal...",
          startTime: startTime,
          totalUU: totalUU,
          downloadedBytes: totalBytes,
        ),
      );

      // Get pasal counts per UU for accurate progress
      final Map<String, int> pasalCounts = {};
      for (var uu in responseUU) {
        final uuId = uu['id'] as String;
        final countResponse = await supabase
            .from('pasal')
            .select('id')
            .eq('undang_undang_id', uuId);
        pasalCounts[uuId] = (countResponse as List).length;
        totalPasal += pasalCounts[uuId]!;
      }

      if (_checkCancelled()) return (false, _cancelledProgress(startTime));

      // Phase 3: Download pasal links
      _emitProgress(
        SyncProgress(
          phase: SyncPhase.downloadingLinks,
          currentOperation: "Mengunduh relasi antar pasal...",
          startTime: startTime,
          totalUU: totalUU,
          totalPasal: totalPasal,
          downloadedBytes: totalBytes,
        ),
      );

      final linksResponse = await supabase
          .from('pasal_links')
          .select('source_pasal_id, target_pasal_id')
          .eq('is_active', true);

      final linksBytes = jsonEncode(linksResponse).length;
      totalBytes += linksBytes;

      final Map<String, List<String>> linksMap = {};
      for (var link in linksResponse) {
        final sourceId = link['source_pasal_id'] as String;
        final targetId = link['target_pasal_id'] as String;
        linksMap.putIfAbsent(sourceId, () => []).add(targetId);
      }

      if (_checkCancelled()) return (false, _cancelledProgress(startTime));

      // Phase 4: Clear and sync each UU
      await _database.clearAllUndangUndang();

      for (int i = 0; i < responseUU.length; i++) {
        if (_checkCancelled()) return (false, _cancelledProgress(startTime));

        final item = responseUU[i];
        final uu = UndangUndangModel.fromJson(item);

        _emitProgress(
          SyncProgress(
            phase: SyncPhase.downloadingPasal,
            currentOperation: "Mengunduh ${uu.kode}...",
            startTime: startTime,
            isIncremental: false,
            totalUU: totalUU,
            currentUUIndex: i + 1,
            currentUUName: uu.kode,
            totalPasal: totalPasal,
            downloadedPasal: downloadedPasal,
            downloadedBytes: totalBytes,
            estimatedTotalBytes: _estimateTotalBytes(
              totalBytes,
              downloadedPasal,
              totalPasal,
            ),
          ),
        );

        // Insert UU
        await _database.insertUndangUndang(
          UndangUndangTableCompanion(
            id: Value(uu.id),
            kode: Value(uu.kode),
            nama: Value(uu.nama),
            namaLengkap: Value(uu.namaLengkap),
            deskripsi: Value(uu.deskripsi),
            tahun: Value(uu.tahun),
            isActive: Value(uu.isActive),
            updatedAt: Value(uu.updatedAt),
          ),
        );

        // Download and save pasal for this UU
        final pasalResponse = await supabase
            .from('pasal')
            .select()
            .eq('undang_undang_id', uu.id);

        final pasalBytes = jsonEncode(pasalResponse).length;
        totalBytes += pasalBytes;

        final pasalCompanions = <PasalTableCompanion>[];
        for (var pasalItem in pasalResponse) {
          final pasal = PasalModel.fromJson(pasalItem);
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
              isActive: Value(pasal.isActive),
              createdAt: Value(pasal.createdAt),
              updatedAt: Value(pasal.updatedAt),
            ),
          );
          downloadedPasal++;
        }

        if (pasalCompanions.isNotEmpty) {
          await _database.insertAllPasal(pasalCompanions);
        }

        // Update progress after each UU
        _emitProgress(
          SyncProgress(
            phase: SyncPhase.downloadingPasal,
            currentOperation: "Menyimpan ${uu.kode}...",
            startTime: startTime,
            isIncremental: false,
            totalUU: totalUU,
            currentUUIndex: i + 1,
            currentUUName: uu.kode,
            totalPasal: totalPasal,
            downloadedPasal: downloadedPasal,
            downloadedBytes: totalBytes,
            estimatedTotalBytes: _estimateTotalBytes(
              totalBytes,
              downloadedPasal,
              totalPasal,
            ),
          ),
        );
      }

      // Phase 5: Complete
      final finalProgress = SyncProgress(
        phase: SyncPhase.complete,
        currentOperation: "Sinkronisasi selesai!",
        startTime: startTime,
        isIncremental: false,
        totalUU: totalUU,
        currentUUIndex: totalUU,
        totalPasal: totalPasal,
        downloadedPasal: downloadedPasal,
        downloadedBytes: totalBytes,
        estimatedTotalBytes: totalBytes,
      );

      _emitProgress(finalProgress);
      return (true, finalProgress);
    } catch (e) {
      print("Full Sync Error: $e");
      return (
        false,
        SyncProgress(
          phase: SyncPhase.error,
          currentOperation: classifyError(e).userMessage,
          startTime: startTime,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Incremental sync with progress tracking
  static Future<(bool, SyncProgress)> _incrementalSyncWithProgress(
    DateTime lastSyncTime,
    DateTime startTime,
  ) async {
    int totalBytes = 0;
    int newRecords = 0;
    int updatedRecords = 0;
    int deletedRecords = 0;

    try {
      final sinceTimestamp = lastSyncTime.toUtc().toIso8601String();

      // Phase 1: Check for updated UU
      _emitProgress(
        SyncProgress(
          phase: SyncPhase.downloadingUU,
          currentOperation: "Memeriksa pembaruan undang-undang...",
          startTime: startTime,
          isIncremental: true,
        ),
      );

      if (_checkCancelled())
        return (false, _cancelledProgress(startTime, isIncremental: true));

      final List<dynamic> updatedUU = await supabase
          .from('undang_undang')
          .select()
          .gt('updated_at', sinceTimestamp);

      totalBytes += jsonEncode(updatedUU).length;

      for (var item in updatedUU) {
        final uu = UndangUndangModel.fromJson(item);
        await _database.upsertUndangUndang(
          UndangUndangTableCompanion(
            id: Value(uu.id),
            kode: Value(uu.kode),
            nama: Value(uu.nama),
            namaLengkap: Value(uu.namaLengkap),
            deskripsi: Value(uu.deskripsi),
            tahun: Value(uu.tahun),
            isActive: Value(uu.isActive),
            updatedAt: Value(uu.updatedAt),
          ),
        );
      }

      if (_checkCancelled())
        return (false, _cancelledProgress(startTime, isIncremental: true));

      // Phase 2: Check for updated pasal
      _emitProgress(
        SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: "Memeriksa pembaruan pasal...",
          startTime: startTime,
          isIncremental: true,
          downloadedBytes: totalBytes,
        ),
      );

      final List<dynamic> updatedPasal = await supabase
          .from('pasal')
          .select()
          .gt('updated_at', sinceTimestamp);

      totalBytes += jsonEncode(updatedPasal).length;
      final totalUpdates = updatedPasal.length;

      if (_checkCancelled())
        return (false, _cancelledProgress(startTime, isIncremental: true));

      // Phase 3: Fetch links for updated pasal
      final Set<String> updatedPasalIds = updatedPasal
          .map((p) => p['id'] as String)
          .toSet();

      Map<String, List<String>> linksMap = {};
      if (updatedPasalIds.isNotEmpty) {
        _emitProgress(
          SyncProgress(
            phase: SyncPhase.downloadingLinks,
            currentOperation: "Memperbarui relasi pasal...",
            startTime: startTime,
            isIncremental: true,
            totalPasal: totalUpdates,
            downloadedBytes: totalBytes,
          ),
        );

        final linksResponse = await supabase
            .from('pasal_links')
            .select('source_pasal_id, target_pasal_id')
            .eq('is_active', true)
            .inFilter('source_pasal_id', updatedPasalIds.toList());

        totalBytes += jsonEncode(linksResponse).length;

        for (var link in linksResponse) {
          final sourceId = link['source_pasal_id'] as String;
          final targetId = link['target_pasal_id'] as String;

          linksMap.putIfAbsent(sourceId, () => []).add(targetId);
        }
      }

      if (_checkCancelled())
        return (false, _cancelledProgress(startTime, isIncremental: true));

      // Phase 4: Upsert pasal
      _emitProgress(
        SyncProgress(
          phase: SyncPhase.saving,
          currentOperation: "Menyimpan pembaruan...",
          startTime: startTime,
          isIncremental: true,
          totalPasal: totalUpdates,
          downloadedBytes: totalBytes,
        ),
      );

      for (int i = 0; i < updatedPasal.length; i++) {
        if (_checkCancelled())
          return (false, _cancelledProgress(startTime, isIncremental: true));

        final item = updatedPasal[i];
        final pasal = PasalModel.fromJson(item);
        final relatedIds = linksMap[pasal.id] ?? [];

        // Check if this is new or updated
        final existing = await _database.getPasalById(pasal.id);
        if (existing == null) {
          newRecords++;
        } else if (!pasal.isActive) {
          deletedRecords++;
        } else {
          updatedRecords++;
        }

        await _database.upsertPasal(
          PasalTableCompanion(
            id: Value(pasal.id),
            undangUndangId: Value(pasal.undangUndangId),
            nomor: Value(pasal.nomor),
            isi: Value(pasal.isi),
            penjelasan: Value(pasal.penjelasan),
            judul: Value(pasal.judul),
            keywords: Value(jsonEncode(pasal.keywords)),
            relatedIds: Value(jsonEncode(relatedIds)),
            isActive: Value(pasal.isActive),
            createdAt: Value(pasal.createdAt),
            updatedAt: Value(pasal.updatedAt),
          ),
        );

        _emitProgress(
          SyncProgress(
            phase: SyncPhase.saving,
            currentOperation: "Menyimpan pasal ${i + 1}/$totalUpdates...",
            startTime: startTime,
            isIncremental: true,
            totalPasal: totalUpdates,
            downloadedPasal: i + 1,
            downloadedBytes: totalBytes,
            newRecords: newRecords,
            updatedRecords: updatedRecords,
            deletedRecords: deletedRecords,
          ),
        );
      }

      // Phase 5: Complete
      final finalProgress = SyncProgress(
        phase: SyncPhase.complete,
        currentOperation: "Pembaruan selesai!",
        startTime: startTime,
        isIncremental: true,
        totalPasal: totalUpdates,
        downloadedPasal: totalUpdates,
        downloadedBytes: totalBytes,
        newRecords: newRecords,
        updatedRecords: updatedRecords,
        deletedRecords: deletedRecords,
      );

      _emitProgress(finalProgress);
      return (true, finalProgress);
    } catch (e) {
      print("Incremental Sync Error: $e");
      return (
        false,
        SyncProgress(
          phase: SyncPhase.error,
          currentOperation: classifyError(e).userMessage,
          startTime: startTime,
          isIncremental: true,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Create cancelled progress state
  static SyncProgress _cancelledProgress(
    DateTime startTime, {
    bool isIncremental = false,
  }) {
    return SyncProgress(
      phase: SyncPhase.cancelled,
      currentOperation: "Dibatalkan",
      startTime: startTime,
      isIncremental: isIncremental,
    );
  }

  /// Estimate total bytes based on current progress
  static int _estimateTotalBytes(
    int currentBytes,
    int downloadedRecords,
    int totalRecords,
  ) {
    if (downloadedRecords == 0 || totalRecords == 0) return currentBytes * 2;
    return (currentBytes * totalRecords / downloadedRecords).round();
  }

  // ============================================================
  // Data Access Methods (unchanged)
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

  static Future<List<PasalModel>> getAllPasal() async {
    try {
      final data = await _database.getActivePasal();
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
              isActive: row.isActive,
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
      final data = await _database.searchActivePasal(query);
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
              isActive: row.isActive,
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
        isActive: data.isActive,
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
        updatedAt: row.updatedAt,
      );
    } catch (e) {
      print("Error getting UU by id: $e");
      return null;
    }
  }

  static Future<List<PasalModel>> getPasalByUU(String uuId) async {
    try {
      final data = await _database.getActivePasalByUndangUndang(uuId);
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
              isActive: row.isActive,
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
      final data = await _database.searchActivePasal(keyword);
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
              isActive: row.isActive,
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
