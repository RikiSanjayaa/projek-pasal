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
  });
}
