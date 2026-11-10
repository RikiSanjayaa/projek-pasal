import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../models/pasal_model.dart';
import '../../models/pasal_versi_model.dart';
import '../../models/undang_undang_model.dart';
import '../database/app_database.dart';
import 'api_service.dart';
import 'query_service.dart';
import 'sync_manager.dart';
import 'sync_progress.dart';

class DataService {
  static late AppDatabase _database;

  /// Hanya untuk tes: pakai database [db] (mis. in-memory).
  @visibleForTesting
  static void useDatabase(AppDatabase db) {
    _database = db;
    QueryService.initialize(db);
  }

  /// Aturan sync inkremental untuk riwayat: ganti seluruh versi lokal setiap
  /// pasal di [updatedPasal] dan [deletedPasalIds] dengan [versiRows].
  /// [versiRows] null (kunci `pasal_versi` tidak ada, server lama) = tidak
  /// mengubah apa pun.
  @visibleForTesting
  static Future<void> applyIncrementalVersi({
    required List<dynamic>? versiRows,
    required List<dynamic> updatedPasal,
    required List<String> deletedPasalIds,
  }) async {
    if (versiRows == null) return;
    final changedIds = <String>{
      for (final item in updatedPasal)
        if ((item as Map)['id'] != null) item['id'].toString(),
      ...deletedPasalIds,
    };
    await _database.replacePasalVersi(changedIds, _versiCompanions(versiRows));
  }

  static StreamController<SyncProgress>? _progressController;
  static bool _isCancelled = false;

  static Future<void> initialize() async {
    _database = AppDatabase();
    QueryService.initialize(_database);
    print("Drift database initialized");
  }

  static Future<bool> hasLocalPasal() async {
    final query = _database.selectOnly(_database.pasalTable)
      ..addColumns([_database.pasalTable.id])
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  static Stream<SyncProgress>? get progressStream =>
      _progressController?.stream;

  static void cancelSync() {
    _isCancelled = true;
  }

  static Future<bool> checkForUpdates() async {
    try {
      final lastSync = syncManager.lastSyncTime;
      final response = await ApiService.dio.get<Map<String, dynamic>>(
        '/mobile/sync/check',
        queryParameters: {
          if (lastSync != null)
            'since': lastSync
                .subtract(const Duration(seconds: 10))
                .toUtc()
                .toIso8601String(),
        },
      );
      await syncManager.recordServerMeta(response.data);
      return response.data?['has_updates'] == true;
    } catch (e) {
      print("Check for updates error: $e");
      return false;
    }
  }

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

  static Future<SyncResult> syncDataWithProgress({
    DateTime? lastSyncTime,
    required void Function(SyncProgress) onProgress,
  }) async {
    _isCancelled = false;
    _progressController = StreamController<SyncProgress>.broadcast();
    _progressController!.stream.listen(onProgress);

    try {
      final startTime = DateTime.now();
      _emitProgress(SyncProgress.initial(isIncremental: lastSyncTime != null));

      final (success, finalProgress) = lastSyncTime == null
          ? await _fullSyncWithProgress(startTime)
          : await _incrementalSyncWithProgress(lastSyncTime, startTime);

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

  static Future<bool> syncData({DateTime? lastSyncTime}) async {
    try {
      final (success, _) = lastSyncTime == null
          ? await _fullSyncWithProgress(DateTime.now())
          : await _incrementalSyncWithProgress(lastSyncTime, DateTime.now());
      return success;
    } catch (e) {
      print("Sync Error: $e");
      return false;
    }
  }

  static void _emitProgress(SyncProgress progress) {
    _progressController?.add(progress);
  }

  static bool _checkCancelled() => _isCancelled;

  static Future<(bool, SyncProgress)> _fullSyncWithProgress(
    DateTime startTime,
  ) async {
    try {
      _emitProgress(
        SyncProgress(
          phase: SyncPhase.downloadingUU,
          currentOperation: "Mengunduh data lengkap...",
          startTime: startTime,
        ),
      );
      if (_checkCancelled()) return (false, _cancelledProgress(startTime));

      final response = await ApiService.dio.get<Map<String, dynamic>>(
        '/mobile/sync/full',
      );
      final body = response.data ?? {};
      final uuRows = List<dynamic>.from(body['undang_undang'] ?? []);
      final pasalRows = List<dynamic>.from(body['pasal'] ?? []);
      final linkRows = List<dynamic>.from(body['pasal_links'] ?? []);
      final versiRows = List<dynamic>.from(body['pasal_versi'] ?? []);
      final totalBytes = jsonEncode(body).length;

      _emitProgress(
        SyncProgress(
          phase: SyncPhase.saving,
          currentOperation: "Menyimpan data lokal...",
          startTime: startTime,
          totalUU: uuRows.length,
          totalPasal: pasalRows.length,
          downloadedBytes: totalBytes,
          estimatedTotalBytes: totalBytes,
        ),
      );

      await _database.clearAllPasalLinks();
      await _database.clearAllPasal();
      await _database.clearAllPasalVersi();
      await _database.clearAllUndangUndang();

      final linksMap = _buildLinksMap(linkRows);
      await _database.insertAllPasalLinks(_linkCompanions(linkRows));
      await _database.insertAllUndangUndang(_uuCompanions(uuRows));
      await _database.insertAllPasal(_pasalCompanions(pasalRows, linksMap));
      await _database.insertAllPasalVersi(_versiCompanions(versiRows));
      await syncManager.recordServerMeta(body);

      final finalProgress = SyncProgress(
        phase: SyncPhase.complete,
        currentOperation: "Sinkronisasi selesai!",
        startTime: startTime,
        isIncremental: false,
        totalUU: uuRows.length,
        currentUUIndex: uuRows.length,
        totalPasal: pasalRows.length,
        downloadedPasal: pasalRows.length,
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

  static Future<(bool, SyncProgress)> _incrementalSyncWithProgress(
    DateTime lastSyncTime,
    DateTime startTime,
  ) async {
    int newRecords = 0;
    int updatedRecords = 0;
    int deletedRecords = 0;

    try {
      final sinceTimestamp = lastSyncTime
          .subtract(const Duration(minutes: 5))
          .toUtc()
          .toIso8601String();

      _emitProgress(
        SyncProgress(
          phase: SyncPhase.downloadingUU,
          currentOperation: "Memeriksa pembaruan data...",
          startTime: startTime,
          isIncremental: true,
        ),
      );

      final response = await ApiService.dio.get<Map<String, dynamic>>(
        '/mobile/sync/updates',
        queryParameters: {'since': sinceTimestamp},
      );
      final body = response.data ?? {};
      final updatedUU = List<dynamic>.from(body['updated_uu'] ?? []);
      final updatedPasal = List<dynamic>.from(body['updated_pasal'] ?? []);
      final updatedLinks = List<dynamic>.from(body['updated_links'] ?? []);
      final deletedUUIds = List<String>.from(body['deleted_uu_ids'] ?? []);
      final deletedPasalIds = List<String>.from(
        body['deleted_pasal_ids'] ?? [],
      );
      final deletedLinkIds = List<String>.from(body['deleted_link_ids'] ?? []);
      // Kunci hilang (server lama) = riwayat lokal dibiarkan.
      final versiRows = body['pasal_versi'] == null
          ? null
          : List<dynamic>.from(body['pasal_versi']);
      final totalBytes = jsonEncode(body).length;

      for (final id in deletedLinkIds) {
        await _database.deletePasalLinksById(id);
        deletedRecords++;
      }
      for (final id in deletedPasalIds) {
        await _database.deletePasalLinksBySourcePasalId(id);
        await _database.deletePasalLinksByTargetPasalId(id);
        await _database.deletePasalVersiByPasalId(id);
        await _database.deletePasalById(id);
        deletedRecords++;
      }
      for (final id in deletedUUIds) {
        await _database.deleteUndangUndangWithRelatedData(id);
        deletedRecords++;
      }

      for (final item in updatedUU) {
        final uu = UndangUndangModel.fromJson(Map<String, dynamic>.from(item));
        await _database.upsertUndangUndang(_uuCompanion(uu));
        updatedRecords++;
      }

      final linksMap = _buildLinksMap(updatedLinks);
      for (final item in updatedLinks) {
        await _database.upsertPasalLink(
          _linkCompanion(Map<String, dynamic>.from(item)),
        );
        updatedRecords++;
      }

      for (final item in updatedPasal) {
        final pasal = PasalModel.fromJson(Map<String, dynamic>.from(item));
        final existing = await _database.getPasalById(pasal.id);
        await _database.upsertPasal(_pasalCompanion(pasal, linksMap[pasal.id]));
        existing == null ? newRecords++ : updatedRecords++;
      }

      await applyIncrementalVersi(
        versiRows: versiRows,
        updatedPasal: updatedPasal,
        deletedPasalIds: deletedPasalIds,
      );
      await syncManager.recordServerMeta(body);

      final finalProgress = SyncProgress(
        phase: SyncPhase.complete,
        currentOperation: "Pembaruan selesai!",
        startTime: startTime,
        isIncremental: true,
        totalPasal: updatedPasal.length,
        downloadedPasal: updatedPasal.length,
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

  /// Semua versi sebuah pasal, dari yang tertua ke terbaru.
  static Future<List<PasalVersiModel>> getPasalVersi(String pasalId) async {
    final rows = await _database.getVersiByPasalId(pasalId);
    return rows
        .map(
          (r) => PasalVersiModel(
            id: r.id,
            pasalId: r.pasalId,
            urutan: r.urutan,
            status: r.status,
            sumber: r.sumber,
            judulSumber: r.judulSumber,
            diundangkan: r.diundangkan,
            berlakuSejak: r.berlakuSejak,
            naskahResmi: r.naskahResmi,
            isi: r.isi,
            penjelasan: r.penjelasan,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          ),
        )
        .toList();
  }

  static List<PasalVersiTableCompanion> _versiCompanions(List<dynamic> rows) {
    return rows.map((row) {
      final v = PasalVersiModel.fromJson(Map<String, dynamic>.from(row));
      return PasalVersiTableCompanion(
        id: Value(v.id),
        pasalId: Value(v.pasalId),
        urutan: Value(v.urutan),
        status: Value(v.status),
        sumber: Value(v.sumber),
        judulSumber: Value(v.judulSumber),
        diundangkan: Value(v.diundangkan),
        berlakuSejak: Value(v.berlakuSejak),
        naskahResmi: Value(v.naskahResmi),
        isi: Value(v.isi),
        penjelasan: Value(v.penjelasan),
        createdAt: Value(v.createdAt),
        updatedAt: Value(v.updatedAt),
      );
    }).toList();
  }

  static List<UndangUndangTableCompanion> _uuCompanions(List<dynamic> rows) {
    return rows
        .map(
          (row) => _uuCompanion(
            UndangUndangModel.fromJson(Map<String, dynamic>.from(row)),
          ),
        )
        .toList();
  }

  static UndangUndangTableCompanion _uuCompanion(UndangUndangModel uu) {
    return UndangUndangTableCompanion(
      id: Value(uu.id),
      kode: Value(uu.kode),
      nama: Value(uu.nama),
      namaLengkap: Value(uu.namaLengkap),
      deskripsi: Value(uu.deskripsi),
      tahun: Value(uu.tahun),
      isActive: Value(uu.isActive),
      updatedAt: Value(uu.updatedAt),
      officialUrl: Value(uu.officialUrl),
      sourceUrl: Value(uu.sourceUrl),
    );
  }

  static List<PasalTableCompanion> _pasalCompanions(
    List<dynamic> rows,
    Map<String, List<String>> linksMap,
  ) {
    return rows.map((row) {
      final pasal = PasalModel.fromJson(Map<String, dynamic>.from(row));
      return _pasalCompanion(pasal, linksMap[pasal.id]);
    }).toList();
  }

  static PasalTableCompanion _pasalCompanion(
    PasalModel pasal,
    List<String>? relatedIds,
  ) {
    return PasalTableCompanion(
      id: Value(pasal.id),
      undangUndangId: Value(pasal.undangUndangId),
      nomor: Value(pasal.nomor),
      isi: Value(pasal.isi),
      penjelasan: Value(pasal.penjelasan),
      judul: Value(pasal.judul),
      bab: Value(pasal.bab),
      relatedIds: Value(jsonEncode(relatedIds ?? pasal.relatedIds)),
      isActive: Value(pasal.isActive),
      createdAt: Value(pasal.createdAt),
      updatedAt: Value(pasal.updatedAt),
      verificationStatus: Value(pasal.verificationStatus),
      verifiedAt: Value(pasal.verifiedAt),
    );
  }

  static List<PasalLinksTableCompanion> _linkCompanions(List<dynamic> rows) {
    return rows
        .map((row) => _linkCompanion(Map<String, dynamic>.from(row)))
        .toList();
  }

  static PasalLinksTableCompanion _linkCompanion(Map<String, dynamic> link) {
    return PasalLinksTableCompanion(
      id: Value(link['id'] as String),
      sourcePasalId: Value(link['source_pasal_id'] as String),
      targetPasalId: Value(link['target_pasal_id'] as String),
      keterangan: Value(link['keterangan'] as String?),
      isActive: Value(link['is_active'] as bool? ?? true),
      createdAt: Value(
        link['created_at'] != null ? DateTime.parse(link['created_at']) : null,
      ),
    );
  }

  static Map<String, List<String>> _buildLinksMap(List<dynamic> rows) {
    final linksMap = <String, List<String>>{};
    for (final row in rows) {
      final link = Map<String, dynamic>.from(row);
      if (link['is_active'] == false) continue;
      final sourceId = link['source_pasal_id'] as String;
      final targetId = link['target_pasal_id'] as String;
      linksMap.putIfAbsent(sourceId, () => []).add(targetId);
    }
    return linksMap;
  }

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
}
