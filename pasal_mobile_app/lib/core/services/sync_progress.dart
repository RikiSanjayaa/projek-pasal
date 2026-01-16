import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../utils/platform_utils.dart'
    if (dart.library.html) '../utils/platform_stub_web.dart';

/// Phases of the sync process
enum SyncPhase {
  /// Initial phase - preparing to sync
  preparing,

  /// Checking for updates on server
  checking,

  /// Downloading undang-undang list
  downloadingUU,

  /// Downloading pasal for each UU
  downloadingPasal,

  /// Downloading pasal links
  downloadingLinks,

  /// Saving data to local database
  saving,

  /// Sync completed successfully
  complete,

  /// Sync was cancelled by user
  cancelled,

  /// Sync failed with error
  error,
}

/// Detailed sync progress information
class SyncProgress {
  /// Current phase of sync
  final SyncPhase phase;

  /// Human-readable description of current operation
  final String currentOperation;

  /// Whether this is an incremental sync (vs full sync)
  final bool isIncremental;

  /// Total number of UU to process
  final int totalUU;

  /// Current UU index being processed (1-based for display)
  final int currentUUIndex;

  /// Name of current UU being processed
  final String? currentUUName;

  /// Total pasal count across all UU
  final int totalPasal;

  /// Pasal downloaded so far
  final int downloadedPasal;

  /// Estimated total bytes to download
  final int estimatedTotalBytes;

  /// Bytes downloaded so far
  final int downloadedBytes;

  /// Timestamp when sync started (for time estimation)
  final DateTime startTime;

  /// Number of new records (for incremental sync summary)
  final int newRecords;

  /// Number of updated records (for incremental sync summary)
  final int updatedRecords;

  /// Number of deleted/deactivated records
  final int deletedRecords;

  /// Error message if phase is error
  final String? errorMessage;

  const SyncProgress({
    required this.phase,
    required this.currentOperation,
    this.isIncremental = false,
    this.totalUU = 0,
    this.currentUUIndex = 0,
    this.currentUUName,
    this.totalPasal = 0,
    this.downloadedPasal = 0,
    this.estimatedTotalBytes = 0,
    this.downloadedBytes = 0,
    required this.startTime,
    this.newRecords = 0,
    this.updatedRecords = 0,
    this.deletedRecords = 0,
    this.errorMessage,
  });

  /// Progress as a value between 0.0 and 1.0
  double get progress {
    if (phase == SyncPhase.complete) return 1.0;
    if (phase == SyncPhase.preparing || phase == SyncPhase.checking) return 0.0;
    if (totalPasal == 0) return 0.0;
    return (downloadedPasal / totalPasal).clamp(0.0, 1.0);
  }

  /// Progress as percentage (0-100)
  int get progressPercent => (progress * 100).round();

  /// Elapsed time since sync started
  Duration get elapsed => DateTime.now().difference(startTime);

  /// Estimated remaining time based on current progress
  Duration? get estimatedRemaining {
    if (progress <= 0 || progress >= 1) return null;
    final elapsedMs = elapsed.inMilliseconds;
    if (elapsedMs < 1000) return null; // Need at least 1 second of data

    final estimatedTotalMs = elapsedMs / progress;
    final remainingMs = estimatedTotalMs - elapsedMs;
    return Duration(milliseconds: remainingMs.round());
  }

  /// Format bytes to human readable string
  String get downloadedBytesFormatted => formatBytes(downloadedBytes);

  /// Format estimated total bytes
  String get estimatedTotalBytesFormatted => formatBytes(estimatedTotalBytes);

  /// Format remaining time to human readable string
  String? get estimatedRemainingFormatted {
    final remaining = estimatedRemaining;
    if (remaining == null) return null;

    if (remaining.inSeconds < 5) return "Hampir selesai";
    if (remaining.inSeconds < 60) return "${remaining.inSeconds} detik lagi";
    if (remaining.inMinutes < 60) {
      final mins = remaining.inMinutes;
      final secs = remaining.inSeconds % 60;
      if (secs == 0) return "$mins menit lagi";
      return "$mins menit $secs detik lagi";
    }
    return "${remaining.inMinutes} menit lagi";
  }

  /// UU progress text like "KUHP (2/5)"
  String? get uuProgressText {
    if (currentUUName == null || totalUU == 0) return null;
    return "$currentUUName ($currentUUIndex/$totalUU)";
  }

  /// Summary text for completed sync
  String get completionSummary {
    if (isIncremental) {
      final parts = <String>[];
      if (newRecords > 0) parts.add("$newRecords pasal baru");
      if (updatedRecords > 0) parts.add("$updatedRecords diperbarui");
      if (deletedRecords > 0) parts.add("$deletedRecords dihapus");
      if (parts.isEmpty) return "Data sudah up-to-date";
      return parts.join(", ");
    } else {
      return "$totalPasal pasal dari $totalUU undang-undang";
    }
  }

  /// Create a copy with updated fields
  SyncProgress copyWith({
    SyncPhase? phase,
    String? currentOperation,
    bool? isIncremental,
    int? totalUU,
    int? currentUUIndex,
    String? currentUUName,
    int? totalPasal,
    int? downloadedPasal,
    int? estimatedTotalBytes,
    int? downloadedBytes,
    DateTime? startTime,
    int? newRecords,
    int? updatedRecords,
    int? deletedRecords,
    String? errorMessage,
  }) {
    return SyncProgress(
      phase: phase ?? this.phase,
      currentOperation: currentOperation ?? this.currentOperation,
      isIncremental: isIncremental ?? this.isIncremental,
      totalUU: totalUU ?? this.totalUU,
      currentUUIndex: currentUUIndex ?? this.currentUUIndex,
      currentUUName: currentUUName ?? this.currentUUName,
      totalPasal: totalPasal ?? this.totalPasal,
      downloadedPasal: downloadedPasal ?? this.downloadedPasal,
      estimatedTotalBytes: estimatedTotalBytes ?? this.estimatedTotalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      startTime: startTime ?? this.startTime,
      newRecords: newRecords ?? this.newRecords,
      updatedRecords: updatedRecords ?? this.updatedRecords,
      deletedRecords: deletedRecords ?? this.deletedRecords,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Initial progress state
  factory SyncProgress.initial({bool isIncremental = false}) {
    return SyncProgress(
      phase: SyncPhase.preparing,
      currentOperation: isIncremental
          ? "Memeriksa pembaruan..."
          : "Mempersiapkan unduhan...",
      isIncremental: isIncremental,
      startTime: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'SyncProgress(phase: $phase, progress: $progressPercent%, '
        'pasal: $downloadedPasal/$totalPasal, bytes: $downloadedBytesFormatted)';
  }
}

/// Format bytes to human readable string (KB, MB, etc)
String formatBytes(int bytes) {
  if (bytes < 1024) return "$bytes B";
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
  return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
}

/// Get database file size in bytes
/// Note: On web platform, database is stored in IndexedDB and size is not easily accessible
Future<int> getDatabaseSize() async {
  // On web, database is stored in IndexedDB, size not easily accessible
  if (kIsWeb) {
    return 0;
  }

  try {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File('${dbFolder.path}/pasal_database.db');
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  } catch (e) {
    return 0;
  }
}

/// Get formatted database size string
Future<String> getDatabaseSizeFormatted() async {
  final size = await getDatabaseSize();
  if (kIsWeb && size == 0) {
    return 'N/A (Web)';
  }
  return formatBytes(size);
}
