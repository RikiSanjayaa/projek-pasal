import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'data_service.dart';
import 'sync_progress.dart';

/// Manages automatic sync timing, state, and progress
class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _syncIntervalKey = 'sync_interval_days';

  /// Default sync interval in days
  static const int defaultSyncIntervalDays = 7;

  /// Notifier for sync state changes
  final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);

  /// Notifier for update availability
  final ValueNotifier<bool> updateAvailable = ValueNotifier(false);

  /// Notifier for detailed sync progress
  final ValueNotifier<SyncProgress?> progress = ValueNotifier(null);

  /// Last sync timestamp
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Initialize sync manager - call on app startup
  Future<void> initialize() async {
    await _loadLastSyncTime();
  }

  /// Load last sync timestamp from storage
  Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastSyncKey);
      if (timestamp != null) {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      print("Error loading last sync time: $e");
    }
  }

  /// Save current time as last sync timestamp
  Future<void> _saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastSyncTime = DateTime.now();
      await prefs.setInt(_lastSyncKey, _lastSyncTime!.millisecondsSinceEpoch);
    } catch (e) {
      print("Error saving last sync time: $e");
    }
  }

  /// Get configured sync interval in days
  Future<int> getSyncIntervalDays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_syncIntervalKey) ?? defaultSyncIntervalDays;
    } catch (e) {
      return defaultSyncIntervalDays;
    }
  }

  /// Set sync interval in days
  Future<void> setSyncIntervalDays(int days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_syncIntervalKey, days);
    } catch (e) {
      print("Error saving sync interval: $e");
    }
  }

  /// Check if sync is needed based on time interval
  Future<bool> isSyncDue() async {
    if (_lastSyncTime == null) return true;

    final intervalDays = await getSyncIntervalDays();
    final daysSinceLastSync = DateTime.now().difference(_lastSyncTime!).inDays;

    return daysSinceLastSync >= intervalDays;
  }

  /// Get days since last sync
  int get daysSinceLastSync {
    if (_lastSyncTime == null) return -1;
    return DateTime.now().difference(_lastSyncTime!).inDays;
  }

  /// Get human-readable last sync text
  String get lastSyncText {
    if (_lastSyncTime == null) return "Belum pernah sinkronisasi";

    final days = daysSinceLastSync;
    if (days == 0) {
      final hours = DateTime.now().difference(_lastSyncTime!).inHours;
      if (hours == 0) {
        final minutes = DateTime.now().difference(_lastSyncTime!).inMinutes;
        if (minutes < 5) return "Baru saja";
        return "$minutes menit yang lalu";
      }
      return "$hours jam yang lalu";
    } else if (days == 1) {
      return "Kemarin";
    } else if (days < 7) {
      return "$days hari yang lalu";
    } else if (days < 30) {
      final weeks = (days / 7).floor();
      return "$weeks minggu yang lalu";
    } else {
      final months = (days / 30).floor();
      return "$months bulan yang lalu";
    }
  }

  /// Check for updates on app launch
  /// Also verifies account is still active
  Future<bool> checkOnLaunch() async {
    state.value = SyncState.checking;

    try {
      // Verify account is still active
      final activeStatus = await authService.verifyActiveStatus();
      if (activeStatus != ActiveStatusResult.active &&
          activeStatus != ActiveStatusResult.error) {
        // Account deactivated or expired - auth service handles logout
        state.value = SyncState.idle;
        return false;
      }

      final syncDue = await isSyncDue();

      if (!syncDue) {
        state.value = SyncState.idle;
        updateAvailable.value = false;
        return false;
      }

      final hasUpdates = await DataService.checkForUpdates();
      updateAvailable.value = hasUpdates;
      state.value = SyncState.idle;

      return hasUpdates;
    } catch (e) {
      print("Error checking for updates on launch: $e");
      state.value = SyncState.error;
      return false;
    }
  }

  /// Perform sync with detailed progress tracking
  /// Uses incremental sync if we have a previous sync timestamp
  /// Verifies account is still active before syncing
  Future<SyncResult> performSync() async {
    state.value = SyncState.syncing;
    progress.value = SyncProgress.initial(isIncremental: _lastSyncTime != null);

    // Verify account is still active before syncing
    final activeStatus = await authService.verifyActiveStatus();
    if (activeStatus == ActiveStatusResult.inactive) {
      state.value = SyncState.error;
      return SyncResult(
        success: false,
        message: 'Akun telah dinonaktifkan. Silakan hubungi administrator.',
        synced: false,
        error: SyncError(
          type: SyncErrorType.unknown,
          message: 'Account deactivated',
        ),
      );
    }
    if (activeStatus == ActiveStatusResult.expired) {
      state.value = SyncState.error;
      return SyncResult(
        success: false,
        message: 'Akun telah kadaluarsa. Silakan hubungi administrator.',
        synced: false,
        error: SyncError(
          type: SyncErrorType.unknown,
          message: 'Account expired',
        ),
      );
    }

    try {
      final result = await DataService.syncDataWithProgress(
        lastSyncTime: _lastSyncTime,
        onProgress: (p) {
          progress.value = p;
        },
      );

      if (result.success) {
        await _saveLastSyncTime();
        updateAvailable.value = false;
        state.value = SyncState.idle;
      } else if (progress.value?.phase == SyncPhase.cancelled) {
        state.value = SyncState.idle;
      } else {
        state.value = SyncState.error;
      }

      return result;
    } catch (e) {
      print("Error performing sync: $e");
      state.value = SyncState.error;
      progress.value = SyncProgress(
        phase: SyncPhase.error,
        currentOperation: classifyError(e).userMessage,
        startTime: DateTime.now(),
        errorMessage: e.toString(),
      );
      return SyncResult(
        success: false,
        message: classifyError(e).userMessage,
        synced: false,
        error: classifyError(e),
      );
    }
  }

  /// Cancel ongoing sync
  void cancelSync() {
    DataService.cancelSync();
  }

  /// Dismiss update notification
  void dismissUpdate() {
    updateAvailable.value = false;
  }

  /// Force check for updates (ignores time interval)
  /// Also verifies account is still active
  Future<bool> forceCheckUpdates() async {
    state.value = SyncState.checking;

    try {
      // Verify account is still active
      final activeStatus = await authService.verifyActiveStatus();
      if (activeStatus != ActiveStatusResult.active &&
          activeStatus != ActiveStatusResult.error) {
        // Account deactivated or expired - auth service handles logout
        state.value = SyncState.idle;
        return false;
      }

      final hasUpdates = await DataService.checkForUpdates();
      updateAvailable.value = hasUpdates;
      state.value = SyncState.idle;
      return hasUpdates;
    } catch (e) {
      print("Error force checking updates: $e");
      state.value = SyncState.error;
      return false;
    }
  }

  /// Clear progress after sync completes or is dismissed
  void clearProgress() {
    progress.value = null;
  }
}

/// Sync state enum
enum SyncState { idle, checking, syncing, error }

/// Global sync manager instance
final syncManager = SyncManager();

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
