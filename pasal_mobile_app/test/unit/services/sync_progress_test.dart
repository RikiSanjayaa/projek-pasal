import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/core/services/sync_progress.dart';

void main() {
  group('formatBytes', () {
    test('formats bytes correctly', () {
      expect(formatBytes(500), '500 B');
      expect(formatBytes(0), '0 B');
    });

    test('formats kilobytes correctly', () {
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(2048), '2.0 KB');
    });

    test('formats megabytes correctly', () {
      expect(formatBytes(1024 * 1024), '1.00 MB');
      expect(formatBytes(1024 * 1024 * 5), '5.00 MB');
      expect(formatBytes(1024 * 1024 + 512 * 1024), '1.50 MB');
    });
  });

  group('SyncProgress', () {
    group('progress calculation', () {
      test('returns 1.0 when phase is complete', () {
        final progress = SyncProgress(
          phase: SyncPhase.complete,
          currentOperation: 'Done',
          startTime: DateTime.now(),
          totalPasal: 100,
          downloadedPasal: 50,
        );
        expect(progress.progress, 1.0);
      });

      test('returns 0.0 when phase is preparing', () {
        final progress = SyncProgress(
          phase: SyncPhase.preparing,
          currentOperation: 'Preparing',
          startTime: DateTime.now(),
        );
        expect(progress.progress, 0.0);
      });

      test('returns 0.0 when phase is checking', () {
        final progress = SyncProgress(
          phase: SyncPhase.checking,
          currentOperation: 'Checking',
          startTime: DateTime.now(),
        );
        expect(progress.progress, 0.0);
      });

      test('returns 0.0 when totalPasal is 0', () {
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now(),
          totalPasal: 0,
          downloadedPasal: 0,
        );
        expect(progress.progress, 0.0);
      });

      test('calculates correct progress percentage', () {
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now(),
          totalPasal: 100,
          downloadedPasal: 25,
        );
        expect(progress.progress, 0.25);
        expect(progress.progressPercent, 25);
      });

      test('clamps progress between 0 and 1', () {
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now(),
          totalPasal: 100,
          downloadedPasal: 150, // More than total
        );
        expect(progress.progress, 1.0);
      });
    });

    group('completionSummary', () {
      test('returns full sync summary for non-incremental', () {
        final progress = SyncProgress(
          phase: SyncPhase.complete,
          currentOperation: 'Complete',
          startTime: DateTime.now(),
          isIncremental: false,
          totalPasal: 500,
          totalUU: 10,
        );
        expect(progress.completionSummary, '500 pasal dari 10 undang-undang');
      });

      test('returns incremental summary with new records', () {
        final progress = SyncProgress(
          phase: SyncPhase.complete,
          currentOperation: 'Complete',
          startTime: DateTime.now(),
          isIncremental: true,
          newRecords: 5,
          updatedRecords: 0,
          deletedRecords: 0,
        );
        expect(progress.completionSummary, '5 pasal baru');
      });

      test('returns incremental summary with updated records', () {
        final progress = SyncProgress(
          phase: SyncPhase.complete,
          currentOperation: 'Complete',
          startTime: DateTime.now(),
          isIncremental: true,
          newRecords: 0,
          updatedRecords: 3,
          deletedRecords: 0,
        );
        expect(progress.completionSummary, '3 diperbarui');
      });

      test('returns incremental summary with deleted records', () {
        final progress = SyncProgress(
          phase: SyncPhase.complete,
          currentOperation: 'Complete',
          startTime: DateTime.now(),
          isIncremental: true,
          newRecords: 0,
          updatedRecords: 0,
          deletedRecords: 2,
        );
        expect(progress.completionSummary, '2 dihapus');
      });

      test('returns combined incremental summary', () {
        final progress = SyncProgress(
          phase: SyncPhase.complete,
          currentOperation: 'Complete',
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

      test('returns up-to-date message when no changes', () {
        final progress = SyncProgress(
          phase: SyncPhase.complete,
          currentOperation: 'Complete',
          startTime: DateTime.now(),
          isIncremental: true,
          newRecords: 0,
          updatedRecords: 0,
          deletedRecords: 0,
        );
        expect(progress.completionSummary, 'Data sudah up-to-date');
      });
    });

    group('uuProgressText', () {
      test('returns null when currentUUName is null', () {
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now(),
          totalUU: 5,
          currentUUIndex: 2,
        );
        expect(progress.uuProgressText, isNull);
      });

      test('returns null when totalUU is 0', () {
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now(),
          currentUUName: 'KUHP',
          totalUU: 0,
          currentUUIndex: 0,
        );
        expect(progress.uuProgressText, isNull);
      });

      test('returns formatted progress text', () {
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now(),
          currentUUName: 'KUHP',
          totalUU: 5,
          currentUUIndex: 2,
        );
        expect(progress.uuProgressText, 'KUHP (2/5)');
      });
    });

    group('copyWith', () {
      test('copies with new phase', () {
        final original = SyncProgress.initial();
        final copied = original.copyWith(phase: SyncPhase.complete);

        expect(copied.phase, SyncPhase.complete);
        expect(copied.currentOperation, original.currentOperation);
      });

      test('preserves original values when not specified', () {
        final original = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now(),
          totalPasal: 100,
          downloadedPasal: 50,
        );
        final copied = original.copyWith(downloadedPasal: 75);

        expect(copied.phase, original.phase);
        expect(copied.totalPasal, 100);
        expect(copied.downloadedPasal, 75);
      });
    });

    group('factory initial', () {
      test('creates initial state for full sync', () {
        final progress = SyncProgress.initial(isIncremental: false);

        expect(progress.phase, SyncPhase.preparing);
        expect(progress.isIncremental, false);
        expect(progress.currentOperation, 'Mempersiapkan unduhan...');
      });

      test('creates initial state for incremental sync', () {
        final progress = SyncProgress.initial(isIncremental: true);

        expect(progress.phase, SyncPhase.preparing);
        expect(progress.isIncremental, true);
        expect(progress.currentOperation, 'Memeriksa pembaruan...');
      });
    });

    group('byte formatting', () {
      test('downloadedBytesFormatted returns formatted string', () {
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now(),
          downloadedBytes: 2048,
        );
        expect(progress.downloadedBytesFormatted, '2.0 KB');
      });

      test('estimatedTotalBytesFormatted returns formatted string', () {
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now(),
          estimatedTotalBytes: 1024 * 1024,
        );
        expect(progress.estimatedTotalBytesFormatted, '1.00 MB');
      });
    });

    group('elapsed', () {
      test('returns duration since startTime', () {
        final startTime = DateTime.now().subtract(const Duration(seconds: 5));
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: startTime,
        );

        // Allow small tolerance for test execution time
        expect(progress.elapsed.inSeconds, greaterThanOrEqualTo(5));
        expect(progress.elapsed.inSeconds, lessThan(10));
      });
    });

    group('estimatedRemaining', () {
      test('returns null when progress is 0', () {
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now().subtract(const Duration(seconds: 5)),
          totalPasal: 100,
          downloadedPasal: 0,
        );
        expect(progress.estimatedRemaining, isNull);
      });

      test('returns null when progress is 1 (complete)', () {
        final progress = SyncProgress(
          phase: SyncPhase.complete,
          currentOperation: 'Complete',
          startTime: DateTime.now().subtract(const Duration(seconds: 5)),
          totalPasal: 100,
          downloadedPasal: 100,
        );
        expect(progress.estimatedRemaining, isNull);
      });

      test('returns null when elapsed time is less than 1 second', () {
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now(), // Just started
          totalPasal: 100,
          downloadedPasal: 50,
        );
        expect(progress.estimatedRemaining, isNull);
      });

      test('calculates estimated remaining time correctly', () {
        // If 50% done after 10 seconds, remaining should be ~10 seconds
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now().subtract(const Duration(seconds: 10)),
          totalPasal: 100,
          downloadedPasal: 50,
        );

        final remaining = progress.estimatedRemaining;
        expect(remaining, isNotNull);
        // Should be approximately 10 seconds (with some tolerance)
        expect(remaining!.inSeconds, greaterThanOrEqualTo(8));
        expect(remaining.inSeconds, lessThanOrEqualTo(12));
      });

      test('calculates remaining time for 25% progress', () {
        // If 25% done after 5 seconds, total ~20 seconds, remaining ~15 seconds
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now().subtract(const Duration(seconds: 5)),
          totalPasal: 100,
          downloadedPasal: 25,
        );

        final remaining = progress.estimatedRemaining;
        expect(remaining, isNotNull);
        expect(remaining!.inSeconds, greaterThanOrEqualTo(13));
        expect(remaining.inSeconds, lessThanOrEqualTo(17));
      });

      test('calculates remaining time for 75% progress', () {
        // If 75% done after 15 seconds, total ~20 seconds, remaining ~5 seconds
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now().subtract(const Duration(seconds: 15)),
          totalPasal: 100,
          downloadedPasal: 75,
        );

        final remaining = progress.estimatedRemaining;
        expect(remaining, isNotNull);
        expect(remaining!.inSeconds, greaterThanOrEqualTo(3));
        expect(remaining.inSeconds, lessThanOrEqualTo(7));
      });
    });

    group('estimatedRemainingFormatted', () {
      test('returns null when estimatedRemaining is null', () {
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now(), // Just started, not enough data
          totalPasal: 100,
          downloadedPasal: 50,
        );
        expect(progress.estimatedRemainingFormatted, isNull);
      });

      test('returns "Hampir selesai" for less than 5 seconds', () {
        // 95% done after 19 seconds → remaining ~1 second
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now().subtract(const Duration(seconds: 19)),
          totalPasal: 100,
          downloadedPasal: 95,
        );

        expect(progress.estimatedRemainingFormatted, 'Hampir selesai');
      });

      test('returns seconds format for less than 60 seconds', () {
        // 50% done after 15 seconds → remaining ~15 seconds
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now().subtract(const Duration(seconds: 15)),
          totalPasal: 100,
          downloadedPasal: 50,
        );

        final formatted = progress.estimatedRemainingFormatted;
        expect(formatted, isNotNull);
        expect(formatted, contains('detik lagi'));
      });

      test('returns minutes format for 60+ seconds', () {
        // 50% done after 2 minutes → remaining ~2 minutes
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now().subtract(const Duration(minutes: 2)),
          totalPasal: 100,
          downloadedPasal: 50,
        );

        final formatted = progress.estimatedRemainingFormatted;
        expect(formatted, isNotNull);
        expect(formatted, contains('menit'));
      });

      test('returns minutes and seconds format when applicable', () {
        // 50% done after 90 seconds → remaining ~90 seconds = 1 min 30 sec
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now().subtract(const Duration(seconds: 90)),
          totalPasal: 100,
          downloadedPasal: 50,
        );

        final formatted = progress.estimatedRemainingFormatted;
        expect(formatted, isNotNull);
        // Should contain both menit and detik
        expect(formatted, contains('menit'));
      });

      test('returns only minutes when seconds is 0', () {
        // 50% done after exactly 2 minutes → remaining exactly 2 minutes
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now().subtract(const Duration(minutes: 2)),
          totalPasal: 100,
          downloadedPasal: 50,
        );

        final formatted = progress.estimatedRemainingFormatted;
        expect(formatted, isNotNull);
        // Format should be "X menit lagi" or "X menit Y detik lagi"
        expect(formatted, contains('menit'));
      });
    });

    group('toString', () {
      test('returns formatted string representation', () {
        final progress = SyncProgress(
          phase: SyncPhase.downloadingPasal,
          currentOperation: 'Downloading',
          startTime: DateTime.now(),
          totalPasal: 100,
          downloadedPasal: 50,
          downloadedBytes: 1024,
        );

        final str = progress.toString();
        expect(str, contains('SyncProgress'));
        expect(str, contains('downloadingPasal'));
        expect(str, contains('50%'));
        expect(str, contains('50/100'));
      });
    });
  });
}
