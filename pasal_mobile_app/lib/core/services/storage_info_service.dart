import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sync_progress.dart';
import '../database/app_database.dart';

/// Storage information for displaying to users
class StorageInfo {
  /// Size of the local database in bytes
  final int databaseSize;

  /// Total number of pasal stored locally
  final int pasalCount;

  /// Total number of undang-undang stored locally
  final int uuCount;

  /// Storage type description (e.g., "File Lokal" or "IndexedDB")
  final String storageType;

  /// Whether the storage info was successfully retrieved
  final bool isAvailable;

  const StorageInfo({
    required this.databaseSize,
    required this.pasalCount,
    required this.uuCount,
    required this.storageType,
    required this.isAvailable,
  });

  /// Get formatted database size string
  String get formattedSize {
    if (!isAvailable || databaseSize == 0) {
      return kIsWeb ? 'Browser Storage' : 'Tidak tersedia';
    }
    return formatBytes(databaseSize);
  }

  /// Get storage summary
  String get summary {
    if (pasalCount == 0 && uuCount == 0) {
      return 'Belum ada data tersimpan';
    }
    return '$pasalCount pasal dari $uuCount UU';
  }

  /// Factory for empty/unavailable storage info
  factory StorageInfo.empty() => const StorageInfo(
    databaseSize: 0,
    pasalCount: 0,
    uuCount: 0,
    storageType: 'Tidak tersedia',
    isAvailable: false,
  );
}

/// Service to get storage information
class StorageInfoService {
  static final StorageInfoService _instance = StorageInfoService._internal();
  factory StorageInfoService() => _instance;
  StorageInfoService._internal();

  final AppDatabase _db = AppDatabase();

  /// Get current storage information
  Future<StorageInfo> getStorageInfo() async {
    try {
      // Get counts from database
      final allPasal = await _db.getActivePasal();
      final allUU = await _db.getActiveUndangUndang();

      // Get database size (0 for web)
      final dbSize = await getDatabaseSize();

      // Determine storage type
      final String storageType;
      if (kIsWeb) {
        storageType = 'IndexedDB (Browser)';
      } else {
        storageType = 'File SQLite Lokal';
      }

      return StorageInfo(
        databaseSize: dbSize,
        pasalCount: allPasal.length,
        uuCount: allUU.length,
        storageType: storageType,
        isAvailable: true,
      );
    } catch (e) {
      debugPrint('Error getting storage info: $e');
      return StorageInfo.empty();
    }
  }
}

/// Global instance
final storageInfoService = StorageInfoService();
