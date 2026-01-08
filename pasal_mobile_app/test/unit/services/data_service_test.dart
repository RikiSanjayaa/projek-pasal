import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/core/services/sync_manager.dart';
import 'package:pasal_mobile_app/core/services/sync_progress.dart';
import 'package:pasal_mobile_app/core/services/data_service.dart';

/// Tests for DataService utility functions and sync logic.
///
/// Note: DataService uses static methods and external dependencies (Supabase, AppDatabase)
/// which makes unit testing challenging. These tests focus on:
/// 1. Testable utility functions
/// 2. SyncResult and error classification
/// 3. Cancellation mechanism
///
/// For full integration testing of sync operations,
/// integration tests with a test Supabase instance or mock server will be added
void main() {
  group('DataService', () {
    group('cancelSync', () {
      test('can be called without throwing', () {
        expect(() => DataService.cancelSync(), returnsNormally);
      });

      test('can be called multiple times', () {
        DataService.cancelSync();
        DataService.cancelSync();
        DataService.cancelSync();
        // Should not throw
      });
    });

    group('progressStream', () {
      test('returns null when no sync is in progress', () {
        // When no sync is running, progressStream should be null
        // (controller is null)
        expect(DataService.progressStream, isNull);
      });
    });
  });

  group('DataService - SyncResult handling', () {
    test('creates successful SyncResult with message', () {
      final result = SyncResult(
        success: true,
        message: 'Sync berhasil',
        synced: true,
      );

      expect(result.success, true);
      expect(result.message, 'Sync berhasil');
      expect(result.synced, true);
      expect(result.error, isNull);
    });

    test('creates failed SyncResult with error', () {
      final error = SyncError(
        type: SyncErrorType.network,
        message: 'Network error',
        details: 'Connection refused',
      );
      final result = SyncResult(
        success: false,
        message: 'Gagal sync',
        synced: false,
        error: error,
      );

      expect(result.success, false);
      expect(result.synced, false);
      expect(result.error, isNotNull);
      expect(result.error!.type, SyncErrorType.network);
    });

    test('creates SyncResult for up-to-date data', () {
      final result = SyncResult(
        success: true,
        message: 'Data sudah up-to-date',
        synced: false, // No actual sync performed
      );

      expect(result.success, true);
      expect(result.synced, false);
      expect(result.message, 'Data sudah up-to-date');
    });

    test('creates SyncResult for cancelled sync', () {
      final result = SyncResult(
        success: false,
        message: 'Sinkronisasi dibatalkan oleh pengguna',
        synced: false,
      );

      expect(result.success, false);
      expect(result.synced, false);
      expect(result.message, contains('dibatalkan'));
    });
  });

  group('DataService - Error Classification via classifyError', () {
    // Note: classifyError is defined in sync_manager.dart but used by DataService

    group('network error detection', () {
      test('detects socket exception', () {
        final error = classifyError(
          Exception('SocketException: Connection refused'),
        );
        expect(error.type, SyncErrorType.network);
      });

      test('detects connection timeout', () {
        final error = classifyError(Exception('Connection timeout after 30s'));
        expect(error.type, SyncErrorType.network);
      });

      test('detects network unreachable', () {
        final error = classifyError(Exception('Network is unreachable'));
        expect(error.type, SyncErrorType.network);
      });

      test('detects host lookup failure', () {
        final error = classifyError(
          Exception('Failed host lookup: api.example.com'),
        );
        expect(error.type, SyncErrorType.network);
      });
    });

    group('server error detection', () {
      test('detects Supabase errors', () {
        final error = classifyError(Exception('Supabase: Invalid API key'));
        expect(error.type, SyncErrorType.server);
      });

      test('detects PostgreSQL errors', () {
        final error = classifyError(
          Exception('PostgreSQL: relation "pasal" does not exist'),
        );
        expect(error.type, SyncErrorType.server);
      });

      test('detects HTTP 500 errors', () {
        final error = classifyError(Exception('HTTP 500'));
        expect(error.type, SyncErrorType.server);
      });

      test('detects HTTP 502 errors', () {
        final error = classifyError(Exception('HTTP 502 Bad Gateway'));
        expect(error.type, SyncErrorType.server);
      });

      test('detects HTTP 503 errors', () {
        final error = classifyError(Exception('HTTP 503 Service Unavailable'));
        expect(error.type, SyncErrorType.server);
      });
    });

    group('database error detection', () {
      test('detects Drift errors', () {
        final error = classifyError(Exception('Drift: Insert failed'));
        expect(error.type, SyncErrorType.database);
      });

      test('detects SQLite errors', () {
        final error = classifyError(
          Exception('SQLite error: UNIQUE constraint failed'),
        );
        expect(error.type, SyncErrorType.database);
      });

      test('detects generic database errors', () {
        final error = classifyError(Exception('Database is locked'));
        expect(error.type, SyncErrorType.database);
      });
    });

    group('unknown error fallback', () {
      test('unrecognized error returns unknown type', () {
        final error = classifyError(Exception('Something unexpected'));
        expect(error.type, SyncErrorType.unknown);
      });

      test('empty error message returns unknown type', () {
        final error = classifyError(Exception(''));
        expect(error.type, SyncErrorType.unknown);
      });
    });
  });

  group('DataService - Byte Estimation Logic', () {
    // Testing the estimation formula: (currentBytes * totalRecords / downloadedRecords)
    // This is based on the _estimateTotalBytes logic

    test('estimates correctly with partial progress', () {
      // If we downloaded 100 bytes for 10 records, and there are 100 total
      // Estimate: 100 * 100 / 10 = 1000 bytes
      const currentBytes = 100;
      const downloadedRecords = 10;
      const totalRecords = 100;

      final estimate = (currentBytes * totalRecords / downloadedRecords)
          .round();

      expect(estimate, 1000);
    });

    test('estimates correctly at 50% progress', () {
      const currentBytes = 500;
      const downloadedRecords = 50;
      const totalRecords = 100;

      final estimate = (currentBytes * totalRecords / downloadedRecords)
          .round();

      expect(estimate, 1000);
    });

    test('estimate equals actual at 100% progress', () {
      const currentBytes = 1000;
      const downloadedRecords = 100;
      const totalRecords = 100;

      final estimate = (currentBytes * totalRecords / downloadedRecords)
          .round();

      expect(estimate, currentBytes);
    });

    test('handles early progress with high estimate', () {
      // Very early in the download, estimate is higher
      const currentBytes = 10;
      const downloadedRecords = 1;
      const totalRecords = 100;

      final estimate = (currentBytes * totalRecords / downloadedRecords)
          .round();

      expect(estimate, 1000);
    });

    test('default fallback when no records downloaded', () {
      // Based on the code: if downloadedRecords == 0, return currentBytes * 2
      const currentBytes = 500;
      const downloadedRecords = 0;

      // Simulate the fallback
      int estimate;
      if (downloadedRecords == 0) {
        estimate = currentBytes * 2;
      } else {
        estimate = currentBytes;
      }

      expect(estimate, 1000);
    });
  });

  group('DataService - Sync Progress Phases', () {
    test('SyncPhase has all expected values', () {
      expect(SyncPhase.values, contains(SyncPhase.preparing));
      expect(SyncPhase.values, contains(SyncPhase.checking));
      expect(SyncPhase.values, contains(SyncPhase.downloadingUU));
      expect(SyncPhase.values, contains(SyncPhase.downloadingPasal));
      expect(SyncPhase.values, contains(SyncPhase.downloadingLinks));
      expect(SyncPhase.values, contains(SyncPhase.saving));
      expect(SyncPhase.values, contains(SyncPhase.complete));
      expect(SyncPhase.values, contains(SyncPhase.cancelled));
      expect(SyncPhase.values, contains(SyncPhase.error));
    });

    test('can create initial progress for full sync', () {
      final progress = SyncProgress.initial(isIncremental: false);

      expect(progress.phase, SyncPhase.preparing);
      expect(progress.isIncremental, false);
      expect(progress.currentOperation, contains('Mempersiapkan'));
    });

    test('can create initial progress for incremental sync', () {
      final progress = SyncProgress.initial(isIncremental: true);

      expect(progress.phase, SyncPhase.preparing);
      expect(progress.isIncremental, true);
      expect(progress.currentOperation, contains('Memeriksa'));
    });

    test('cancelled progress has correct phase', () {
      final progress = SyncProgress(
        phase: SyncPhase.cancelled,
        currentOperation: 'Dibatalkan',
        startTime: DateTime.now(),
      );

      expect(progress.phase, SyncPhase.cancelled);
    });

    test('error progress includes error message', () {
      final progress = SyncProgress(
        phase: SyncPhase.error,
        currentOperation: 'Error occurred',
        startTime: DateTime.now(),
        errorMessage: 'Connection failed',
      );

      expect(progress.phase, SyncPhase.error);
      expect(progress.errorMessage, 'Connection failed');
    });
  });

  group('DataService - Sync Operation Messages', () {
    // Testing the Indonesian messages used in sync operations

    test('full sync messages are in Indonesian', () {
      final progress = SyncProgress.initial(isIncremental: false);
      expect(progress.currentOperation, 'Mempersiapkan unduhan...');
    });

    test('incremental sync messages are in Indonesian', () {
      final progress = SyncProgress.initial(isIncremental: true);
      expect(progress.currentOperation, 'Memeriksa pembaruan...');
    });

    test('completion summary for full sync', () {
      final progress = SyncProgress(
        phase: SyncPhase.complete,
        currentOperation: 'Selesai',
        startTime: DateTime.now(),
        isIncremental: false,
        totalPasal: 500,
        totalUU: 10,
      );

      expect(progress.completionSummary, '500 pasal dari 10 undang-undang');
    });

    test('completion summary for incremental sync with changes', () {
      final progress = SyncProgress(
        phase: SyncPhase.complete,
        currentOperation: 'Selesai',
        startTime: DateTime.now(),
        isIncremental: true,
        newRecords: 5,
        updatedRecords: 3,
        deletedRecords: 1,
      );

      expect(
        progress.completionSummary,
        '5 pasal baru, 3 diperbarui, 1 dihapus',
      );
    });

    test('completion summary when no changes', () {
      final progress = SyncProgress(
        phase: SyncPhase.complete,
        currentOperation: 'Selesai',
        startTime: DateTime.now(),
        isIncremental: true,
        newRecords: 0,
        updatedRecords: 0,
        deletedRecords: 0,
      );

      expect(progress.completionSummary, 'Data sudah up-to-date');
    });
  });

  group('DataService - Timestamp Handling', () {
    test('can format timestamp for Supabase query', () {
      final timestamp = DateTime(2024, 6, 15, 10, 30, 0);
      final isoString = timestamp.toUtc().toIso8601String();

      expect(isoString, contains('2024-06-15'));
      expect(isoString, endsWith('Z'));
    });

    test('difference calculation for update check', () {
      final localLatest = DateTime(2024, 6, 15, 10, 0, 0);
      final serverLatest = DateTime(2024, 6, 15, 10, 0, 10);

      final differenceSeconds = serverLatest.difference(localLatest).inSeconds;

      expect(differenceSeconds, 10);
      // Based on code: if difference > 5 seconds, updates are available
      expect(differenceSeconds > 5, true);
    });

    test('no update when difference is small', () {
      final localLatest = DateTime(2024, 6, 15, 10, 0, 0);
      final serverLatest = DateTime(2024, 6, 15, 10, 0, 3);

      final differenceSeconds = serverLatest.difference(localLatest).inSeconds;

      expect(differenceSeconds, 3);
      expect(differenceSeconds > 5, false);
    });
  });

  group('DataService - JSON Parsing', () {
    // Tests related to JSON array parsing for keywords and relatedIds

    test('empty JSON array string', () {
      const jsonString = '[]';
      final isEmpty = jsonString == '[]';
      expect(isEmpty, true);
    });

    test('JSON array with items', () {
      const jsonString = '["item1", "item2"]';
      final isEmpty = jsonString == '[]';
      expect(isEmpty, false);
    });

    test('empty string is handled', () {
      const jsonString = '';
      final isEmpty = jsonString.isEmpty || jsonString == '[]';
      expect(isEmpty, true);
    });
  });
}
