import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/core/services/sync_manager.dart';

void main() {
  group('SyncErrorType', () {
    test('has all expected values', () {
      expect(SyncErrorType.values.length, 4);
      expect(SyncErrorType.values, contains(SyncErrorType.network));
      expect(SyncErrorType.values, contains(SyncErrorType.server));
      expect(SyncErrorType.values, contains(SyncErrorType.database));
      expect(SyncErrorType.values, contains(SyncErrorType.unknown));
    });
  });

  group('SyncError', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final error = SyncError(
          type: SyncErrorType.network,
          message: 'Network error',
        );

        expect(error.type, SyncErrorType.network);
        expect(error.message, 'Network error');
        expect(error.details, isNull);
      });

      test('creates instance with details', () {
        final error = SyncError(
          type: SyncErrorType.server,
          message: 'Server error',
          details: 'Connection refused',
        );

        expect(error.details, 'Connection refused');
      });
    });

    group('userMessage', () {
      test('returns Indonesian network error message', () {
        final error = SyncError(type: SyncErrorType.network, message: 'test');
        expect(
          error.userMessage,
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
        );
      });

      test('returns Indonesian server error message', () {
        final error = SyncError(type: SyncErrorType.server, message: 'test');
        expect(
          error.userMessage,
          'Server sedang mengalami gangguan. Coba lagi nanti.',
        );
      });

      test('returns Indonesian database error message', () {
        final error = SyncError(type: SyncErrorType.database, message: 'test');
        expect(error.userMessage, 'Gagal menyimpan data ke penyimpanan lokal.');
      });

      test('returns Indonesian unknown error message', () {
        final error = SyncError(type: SyncErrorType.unknown, message: 'test');
        expect(error.userMessage, 'Terjadi kesalahan yang tidak diketahui.');
      });
    });

    group('toString', () {
      test('formats correctly', () {
        final error = SyncError(
          type: SyncErrorType.network,
          message: 'Connection failed',
        );
        expect(
          error.toString(),
          'SyncError(type: SyncErrorType.network, message: Connection failed)',
        );
      });
    });
  });

  group('SyncResult', () {
    group('constructor', () {
      test('creates successful result', () {
        final result = SyncResult(
          success: true,
          message: 'Sync complete',
          synced: true,
        );

        expect(result.success, isTrue);
        expect(result.message, 'Sync complete');
        expect(result.synced, isTrue);
        expect(result.error, isNull);
      });

      test('creates failed result with error', () {
        final error = SyncError(
          type: SyncErrorType.network,
          message: 'Network failed',
        );
        final result = SyncResult(
          success: false,
          message: 'Sync failed',
          synced: false,
          error: error,
        );

        expect(result.success, isFalse);
        expect(result.synced, isFalse);
        expect(result.error, isNotNull);
        expect(result.error?.type, SyncErrorType.network);
      });
    });

    group('toString', () {
      test('formats correctly', () {
        final result = SyncResult(success: true, message: 'Done', synced: true);
        expect(
          result.toString(),
          'SyncResult(success: true, message: Done, synced: true)',
        );
      });
    });
  });

  group('classifyError', () {
    group('network errors', () {
      test('classifies SocketException as network error', () {
        final error = classifyError(const SocketException('No route to host'));
        expect(error.type, SyncErrorType.network);
        expect(error.message, 'Network error');
      });

      test('classifies connection error strings', () {
        expect(
          classifyError(Exception('Connection refused')).type,
          SyncErrorType.network,
        );
        expect(
          classifyError(Exception('Network unreachable')).type,
          SyncErrorType.network,
        );
        expect(
          classifyError(Exception('Connection timeout')).type,
          SyncErrorType.network,
        );
        expect(
          classifyError(Exception('Host not found')).type,
          SyncErrorType.network,
        );
      });
    });

    group('server errors', () {
      test('classifies PostgreSQL errors as server error', () {
        final error = classifyError(
          Exception('PostgreSQL: relation not found'),
        );
        expect(error.type, SyncErrorType.server);
        expect(error.message, 'Server error');
      });

      test('classifies Supabase errors as server error', () {
        final error = classifyError(Exception('Supabase: Auth failed'));
        expect(error.type, SyncErrorType.server);
      });

      test('classifies HTTP 5xx errors as server error', () {
        expect(
          classifyError(Exception('Error 500: Internal server error')).type,
          SyncErrorType.server,
        );
        expect(
          classifyError(Exception('502 Bad Gateway')).type,
          SyncErrorType.server,
        );
        expect(
          classifyError(Exception('503 Service Unavailable')).type,
          SyncErrorType.server,
        );
      });
    });

    group('database errors', () {
      test('classifies Drift errors as database error', () {
        final error = classifyError(Exception('Drift: Table not found'));
        expect(error.type, SyncErrorType.database);
        expect(error.message, 'Database error');
      });

      test('classifies SQLite errors as database error', () {
        final error = classifyError(Exception('SQLite error: disk I/O'));
        expect(error.type, SyncErrorType.database);
      });

      test('classifies generic database errors', () {
        final error = classifyError(Exception('Database locked'));
        expect(error.type, SyncErrorType.database);
      });
    });

    group('unknown errors', () {
      test('classifies unrecognized errors as unknown', () {
        final error = classifyError(Exception('Something strange happened'));
        expect(error.type, SyncErrorType.unknown);
        expect(error.message, 'Unknown error');
      });

      test('preserves error details', () {
        final originalError = Exception('Custom error message');
        final error = classifyError(originalError);
        expect(error.details, contains('Custom error message'));
      });
    });

    group('case insensitivity', () {
      test('handles uppercase error strings', () {
        expect(
          classifyError(Exception('NETWORK ERROR')).type,
          SyncErrorType.network,
        );
        expect(
          classifyError(Exception('POSTGRESQL failure')).type,
          SyncErrorType.server,
        );
        expect(
          classifyError(Exception('DATABASE crashed')).type,
          SyncErrorType.database,
        );
      });
    });
  });
}
