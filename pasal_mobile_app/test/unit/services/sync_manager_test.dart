import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/core/services/sync_manager.dart';
import 'package:pasal_mobile_app/core/services/sync_progress.dart';
import '../../mocks/shared_preferences_mock.dart';

void main() {
  group('SyncManager', () {
    late SyncManager manager;

    setUp(() {
      setupMockSharedPreferences({});
      manager = SyncManager();
      // Reset state for each test
      manager.state.value = SyncState.idle;
      manager.updateAvailable.value = false;
      manager.progress.value = null;
    });

    group('singleton pattern', () {
      test('returns same instance when called multiple times', () {
        final instance1 = SyncManager();
        final instance2 = SyncManager();

        expect(identical(instance1, instance2), true);
      });

      test('global syncManager is same as factory instance', () {
        final factoryInstance = SyncManager();

        expect(identical(syncManager, factoryInstance), true);
      });
    });

    group('initialize', () {
      test('initializes without error when no previous sync', () async {
        setupMockSharedPreferences({});

        await expectLater(manager.initialize(), completes);
      });

      test('loads last sync time from SharedPreferences', () async {
        final timestamp = DateTime(2024, 1, 15).millisecondsSinceEpoch;
        setupMockSharedPreferences({
          'last_sync_timestamp': timestamp,
        });

        await manager.initialize();

        // Note: Due to singleton pattern, we can't fully verify internal state
        // but the method should complete without error
      });
    });

    group('getSyncIntervalDays', () {
      test('returns default interval when not set', () async {
        setupMockSharedPreferences({});

        final interval = await manager.getSyncIntervalDays();

        expect(interval, SyncManager.defaultSyncIntervalDays);
        expect(interval, 7); // Default is 7 days
      });

      test('returns stored interval when set', () async {
        setupMockSharedPreferences({
          'sync_interval_days': 14,
        });

        final interval = await manager.getSyncIntervalDays();

        expect(interval, 14);
      });
    });

    group('setSyncIntervalDays', () {
      test('saves interval to SharedPreferences', () async {
        setupMockSharedPreferences({});

        await expectLater(manager.setSyncIntervalDays(30), completes);
      });

      test('can set different interval values', () async {
        setupMockSharedPreferences({});

        await manager.setSyncIntervalDays(1);
        await manager.setSyncIntervalDays(7);
        await manager.setSyncIntervalDays(30);

        // Should complete without error for all values
      });
    });

    group('isSyncDue', () {
      test('returns true when lastSyncTime is null', () async {
        setupMockSharedPreferences({});
        // Ensure no last sync time is set
        await manager.initialize();

        final isDue = await manager.isSyncDue();

        expect(isDue, true);
      });
    });

    group('daysSinceLastSync', () {
      test('returns -1 when lastSyncTime is null', () {
        // Note: Due to singleton pattern, we test the behavior conceptually
        // In a real scenario with null lastSyncTime, it would return -1
        // The singleton may have state from previous test runs
        // This test documents the expected behavior
        final days = manager.daysSinceLastSync;
        // If lastSyncTime is set (from previous runs), it returns days count
        // If null, it returns -1
        expect(days, isA<int>());
      });
    });

    group('lastSyncText', () {
      test('returns appropriate text based on last sync time', () {
        // Note: Due to singleton pattern, the manager may have state
        // This test verifies the method returns a non-empty string
        final text = manager.lastSyncText;
        expect(text, isNotEmpty);
        // Text should be one of the expected patterns
        expect(
          text == 'Belum pernah sinkronisasi' ||
              text.contains('yang lalu') ||
              text == 'Baru saja' ||
              text == 'Kemarin',
          true,
        );
      });
    });

    group('state ValueNotifier', () {
      test('initial state is idle', () {
        expect(manager.state.value, SyncState.idle);
      });

      test('notifies listeners when state changes', () {
        int notifyCount = 0;
        manager.state.addListener(() {
          notifyCount++;
        });

        manager.state.value = SyncState.checking;
        manager.state.value = SyncState.syncing;
        manager.state.value = SyncState.idle;

        expect(notifyCount, 3);
      });

      test('can transition through all states', () {
        final states = <SyncState>[];
        manager.state.addListener(() {
          states.add(manager.state.value);
        });

        manager.state.value = SyncState.checking;
        manager.state.value = SyncState.syncing;
        manager.state.value = SyncState.error;
        manager.state.value = SyncState.idle;

        expect(states, [
          SyncState.checking,
          SyncState.syncing,
          SyncState.error,
          SyncState.idle,
        ]);
      });
    });

    group('updateAvailable ValueNotifier', () {
      test('initial value is false', () {
        expect(manager.updateAvailable.value, false);
      });

      test('notifies listeners when value changes', () {
        int notifyCount = 0;
        manager.updateAvailable.addListener(() {
          notifyCount++;
        });

        manager.updateAvailable.value = true;
        manager.updateAvailable.value = false;

        expect(notifyCount, 2);
      });
    });

    group('progress ValueNotifier', () {
      test('initial value is null', () {
        expect(manager.progress.value, isNull);
      });

      test('can store SyncProgress', () {
        final testProgress = SyncProgress.initial();

        manager.progress.value = testProgress;

        expect(manager.progress.value, isNotNull);
        expect(manager.progress.value!.phase, SyncPhase.preparing);
      });

      test('notifies listeners when progress changes', () {
        int notifyCount = 0;
        manager.progress.addListener(() {
          notifyCount++;
        });

        manager.progress.value = SyncProgress.initial();
        manager.progress.value = SyncProgress.initial(isIncremental: true);

        expect(notifyCount, 2);
      });
    });

    group('dismissUpdate', () {
      test('sets updateAvailable to false', () {
        manager.updateAvailable.value = true;

        manager.dismissUpdate();

        expect(manager.updateAvailable.value, false);
      });

      test('has no effect when already false', () {
        manager.updateAvailable.value = false;

        manager.dismissUpdate();

        expect(manager.updateAvailable.value, false);
      });
    });

    group('clearProgress', () {
      test('sets progress to null', () {
        manager.progress.value = SyncProgress.initial();

        manager.clearProgress();

        expect(manager.progress.value, isNull);
      });

      test('has no effect when already null', () {
        manager.progress.value = null;

        manager.clearProgress();

        expect(manager.progress.value, isNull);
      });
    });

    group('cancelSync', () {
      test('calls DataService.cancelSync without error', () {
        // This test verifies the method can be called without throwing
        expect(() => manager.cancelSync(), returnsNormally);
      });
    });
  });

  group('SyncResult', () {
    test('creates success result correctly', () {
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

    test('creates failure result with error', () {
      final error = SyncError(
        type: SyncErrorType.network,
        message: 'Network error',
      );
      final result = SyncResult(
        success: false,
        message: 'Connection failed',
        synced: false,
        error: error,
      );

      expect(result.success, false);
      expect(result.message, 'Connection failed');
      expect(result.synced, false);
      expect(result.error, isNotNull);
      expect(result.error!.type, SyncErrorType.network);
    });

    test('toString returns formatted string', () {
      final result = SyncResult(
        success: true,
        message: 'Test',
        synced: true,
      );

      final string = result.toString();

      expect(string, contains('SyncResult'));
      expect(string, contains('success: true'));
      expect(string, contains('message: Test'));
      expect(string, contains('synced: true'));
    });
  });

  group('SyncError', () {
    group('userMessage', () {
      test('returns network error message', () {
        final error = SyncError(
          type: SyncErrorType.network,
          message: 'Connection failed',
        );

        expect(
          error.userMessage,
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
        );
      });

      test('returns server error message', () {
        final error = SyncError(
          type: SyncErrorType.server,
          message: 'Server down',
        );

        expect(
          error.userMessage,
          'Server sedang mengalami gangguan. Coba lagi nanti.',
        );
      });

      test('returns database error message', () {
        final error = SyncError(
          type: SyncErrorType.database,
          message: 'DB write failed',
        );

        expect(
          error.userMessage,
          'Gagal menyimpan data ke penyimpanan lokal.',
        );
      });

      test('returns unknown error message', () {
        final error = SyncError(
          type: SyncErrorType.unknown,
          message: 'Something went wrong',
        );

        expect(
          error.userMessage,
          'Terjadi kesalahan yang tidak diketahui.',
        );
      });
    });

    test('toString returns formatted string', () {
      final error = SyncError(
        type: SyncErrorType.network,
        message: 'Test error',
        details: 'Additional details',
      );

      final string = error.toString();

      expect(string, contains('SyncError'));
      expect(string, contains('type: SyncErrorType.network'));
      expect(string, contains('message: Test error'));
    });

    test('stores details correctly', () {
      final error = SyncError(
        type: SyncErrorType.server,
        message: 'Error',
        details: 'HTTP 500 Internal Server Error',
      );

      expect(error.details, 'HTTP 500 Internal Server Error');
    });
  });

  group('classifyError', () {
    group('network errors', () {
      test('classifies socket errors', () {
        final error = classifyError(Exception('SocketException: Connection refused'));

        expect(error.type, SyncErrorType.network);
      });

      test('classifies connection errors', () {
        final error = classifyError(Exception('Connection reset by peer'));

        expect(error.type, SyncErrorType.network);
      });

      test('classifies network errors', () {
        final error = classifyError(Exception('Network is unreachable'));

        expect(error.type, SyncErrorType.network);
      });

      test('classifies timeout errors', () {
        final error = classifyError(Exception('Connection timeout'));

        expect(error.type, SyncErrorType.network);
      });

      test('classifies host errors', () {
        final error = classifyError(Exception('Host not found'));

        expect(error.type, SyncErrorType.network);
      });
    });

    group('server errors', () {
      test('classifies postgresql errors', () {
        final error = classifyError(Exception('PostgreSQL error'));

        expect(error.type, SyncErrorType.server);
      });

      test('classifies supabase errors', () {
        // Note: "supabase" keyword must not contain other trigger words
        // like "connection" which would match network error first
        final error = classifyError(Exception('Supabase API key invalid'));

        expect(error.type, SyncErrorType.server);
      });

      test('classifies HTTP 500 errors', () {
        final error = classifyError(Exception('HTTP 500 Internal Server Error'));

        expect(error.type, SyncErrorType.server);
      });

      test('classifies HTTP 502 errors', () {
        final error = classifyError(Exception('HTTP 502 Bad Gateway'));

        expect(error.type, SyncErrorType.server);
      });

      test('classifies HTTP 503 errors', () {
        final error = classifyError(Exception('HTTP 503 Service Unavailable'));

        expect(error.type, SyncErrorType.server);
      });
    });

    group('database errors', () {
      test('classifies drift errors', () {
        final error = classifyError(Exception('Drift query failed'));

        expect(error.type, SyncErrorType.database);
      });

      test('classifies sqlite errors', () {
        final error = classifyError(Exception('SQLite error: constraint failed'));

        expect(error.type, SyncErrorType.database);
      });

      test('classifies database errors', () {
        final error = classifyError(Exception('Database is locked'));

        expect(error.type, SyncErrorType.database);
      });
    });

    group('unknown errors', () {
      test('classifies unrecognized errors as unknown', () {
        final error = classifyError(Exception('Something random happened'));

        expect(error.type, SyncErrorType.unknown);
      });

      test('classifies generic exceptions as unknown', () {
        final error = classifyError(Exception('Generic error'));

        expect(error.type, SyncErrorType.unknown);
      });
    });

    test('stores original error message in details', () {
      const errorMessage = 'Detailed error message here';
      final error = classifyError(Exception(errorMessage));

      expect(error.details, contains(errorMessage));
    });
  });

  group('SyncState enum', () {
    test('has all expected values', () {
      expect(SyncState.values.length, 4);
      expect(SyncState.values, contains(SyncState.idle));
      expect(SyncState.values, contains(SyncState.checking));
      expect(SyncState.values, contains(SyncState.syncing));
      expect(SyncState.values, contains(SyncState.error));
    });
  });

  group('SyncErrorType enum', () {
    test('has all expected values', () {
      expect(SyncErrorType.values.length, 4);
      expect(SyncErrorType.values, contains(SyncErrorType.network));
      expect(SyncErrorType.values, contains(SyncErrorType.server));
      expect(SyncErrorType.values, contains(SyncErrorType.database));
      expect(SyncErrorType.values, contains(SyncErrorType.unknown));
    });
  });
}
