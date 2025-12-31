import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_service.dart';

/// Manages automatic sync timing and state
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
  /// Returns true if updates are available and sync is due
  Future<bool> checkOnLaunch() async {
    state.value = SyncState.checking;
    
    try {
      // First check if sync is due based on time
      final syncDue = await isSyncDue();
      
      if (!syncDue) {
        state.value = SyncState.idle;
        updateAvailable.value = false;
        return false;
      }

      // Check server for actual updates
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

  /// Perform sync and update timestamp
  Future<SyncResult> performSync() async {
    state.value = SyncState.syncing;
    
    try {
      final result = await DataService.syncDataWithResult();
      
      if (result.success) {
        await _saveLastSyncTime();
        updateAvailable.value = false;
        state.value = SyncState.idle;
      } else {
        state.value = SyncState.error;
      }
      
      return result;
    } catch (e) {
      print("Error performing sync: $e");
      state.value = SyncState.error;
      return SyncResult(
        success: false,
        message: classifyError(e).userMessage,
        synced: false,
        error: classifyError(e),
      );
    }
  }

  /// Dismiss update notification
  void dismissUpdate() {
    updateAvailable.value = false;
  }

  /// Force check for updates (ignores time interval)
  Future<bool> forceCheckUpdates() async {
    state.value = SyncState.checking;
    
    try {
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
}

/// Sync state enum
enum SyncState {
  idle,
  checking,
  syncing,
  error,
}

/// Global sync manager instance
final syncManager = SyncManager();
