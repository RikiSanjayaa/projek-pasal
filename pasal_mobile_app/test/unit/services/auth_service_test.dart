import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/core/services/api_service.dart';
import 'package:pasal_mobile_app/core/services/auth_service.dart';

typedef _Responder = FutureOr<ResponseBody> Function(RequestOptions options);

/// Dio adapter that answers from a closure and records requests.
class _FakeAdapter implements HttpClientAdapter {
  _Responder responder = (_) => _json(500, {'message': 'unconfigured'});
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

/// In-memory secure storage whose writes can be paused to freeze a commit
/// mid-flight.
class _GatedStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> data = {};
  Completer<void>? gate;
  Completer<void> writeBlocked = Completer<void>();
  String? pausedReadKey;
  Completer<void>? readGate;
  final readBlocked = Completer<void>();

  Future<void> _maybePause() async {
    final g = gate;
    if (g == null) return;
    if (!writeBlocked.isCompleted) writeBlocked.complete();
    await g.future;
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => data.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    await _maybePause();
    data.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      data.clear();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    final value = data[key];
    if (key == pausedReadKey && readGate != null) {
      if (!readBlocked.isCompleted) readBlocked.complete();
      await readGate!.future;
    }
    return value;
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(data);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    await _maybePause();
    data[key] = value;
  }
}

ResponseBody _json(int status, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

ResponseBody _html(int status) {
  return ResponseBody.fromString(
    '<!DOCTYPE html><html>Cloudflare</html>',
    status,
    headers: {
      Headers.contentTypeHeader: ['text/html'],
    },
  );
}

Map<String, dynamic> _access(
  AccountType type, {
  DateTime? expiresAt,
  required DateTime lease,
}) {
  return {
    'account_type': type.apiValue,
    'expires_at': expiresAt?.toUtc().toIso8601String(),
    'offline_access_until': lease.toUtc().toIso8601String(),
  };
}

Map<String, dynamic> _loginBody(
  AccountType type, {
  DateTime? expiresAt,
  required DateTime lease,
  String name = 'Budi',
}) {
  return {
    'token': 'token-${type.apiValue}',
    'user': {'id': 'u1', 'nama': name, 'email': 'u@example.com'},
    'access': _access(type, expiresAt: expiresAt, lease: lease),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final adapter = _FakeAdapter();
  final t0 = DateTime.utc(2026, 11, 8, 12);
  late HttpClientAdapter originalAdapter;

  Future<T> at<T>(DateTime time, Future<T> Function() body) =>
      withClock(Clock.fixed(time), body);

  Future<String?> stored(String key) =>
      const FlutterSecureStorage().read(key: key);

  setUpAll(() => originalAdapter = ApiService.dio.httpClientAdapter);
  tearDownAll(() => ApiService.dio.httpClientAdapter = originalAdapter);

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    adapter.requests.clear();
    adapter.responder = (_) => _json(500, {'message': 'unconfigured'});
    ApiService.dio.httpClientAdapter = adapter;
    authService.state.value = AuthState.unknown;
    authService.deactivationReason.value = DeactivationReason.none;
    await authService.initialize();
  });

  Future<LoginResult> loginAs(
    AccountType type, {
    DateTime? expiresAt,
    DateTime? lease,
    DateTime? now,
  }) {
    adapter.responder = (_) => _json(
      200,
      _loginBody(
        type,
        expiresAt: expiresAt,
        lease: lease ?? t0.add(const Duration(days: 30)),
      ),
    );
    return at(
      now ?? t0,
      () => authService.login('u@example.com', 'secret'),
    );
  }

  group('login', () {
    test('stores the server-reported admin type without expiry or user_type in the request', () async {
      final result = await loginAs(AccountType.admin);

      expect(result.success, isTrue);
      expect(adapter.requests.single.data.containsKey('user_type'), isFalse);
      expect(authService.accountType.value, AccountType.admin);
      expect(authService.accountExpiresAt.value, isNull);
      expect(authService.daysUntilExpiry.value, isNull);
      expect(await stored('user_expires_at'), isNull);
      expect(await stored('last_password_verification'), isNull);
      expect(await ApiService.getToken(), 'token-admin');
    });

    test('mobile login stores expiry and lease from the server', () async {
      final expires = t0.add(const Duration(days: 90));
      adapter.responder = (_) => _json(
        200,
        _loginBody(AccountType.mobile, expiresAt: expires, lease: t0.add(const Duration(days: 30))),
      );

      final result = await at(
        t0,
        () => authService.login('u@example.com', 'secret'),
      );

      expect(result.success, isTrue);
      expect(adapter.requests.single.data.containsKey('user_type'), isFalse);
      expect(authService.accountExpiresAt.value, expires);
      expect(authService.daysUntilExpiry.value, 90);
      expect(authService.offlineAccessUntil.value, t0.add(const Duration(days: 30)));
    });

    final Map<String, void Function(Map<String, dynamic>)> malformed = {
      'missing access': (Map<String, dynamic> b) => b.remove('access'),
      'missing lease': (Map<String, dynamic> b) =>
          (b['access'] as Map).remove('offline_access_until'),
      'garbled lease': (Map<String, dynamic> b) =>
          (b['access'] as Map)['offline_access_until'] = 'soon',
      'unknown account type': (Map<String, dynamic> b) =>
          (b['access'] as Map)['account_type'] = 'superuser',
      'lease already past': (Map<String, dynamic> b) =>
          (b['access'] as Map)['offline_access_until'] =
              t0.subtract(const Duration(days: 1)).toIso8601String(),
      'admin with account expiry': (Map<String, dynamic> b) =>
          (b['access'] as Map)['expires_at'] =
              t0.add(const Duration(days: 5)).toIso8601String(),
    };
    for (final entry in malformed.entries) {
      test('rejects malformed access metadata: ${entry.key}', () async {
        final body = _loginBody(
          AccountType.admin,
          lease: t0.add(const Duration(days: 30)),
        );
        entry.value(body);
        adapter.responder = (_) => _json(200, body);

        final result = await at(
          t0,
          () => authService.login('a@example.com', 'x'),
        );

        expect(result.success, isFalse);
        expect(await ApiService.getToken(), isNull);
      });
    }

    test('switching from mobile to admin drops the previous expiry', () async {
      await loginAs(AccountType.mobile, expiresAt: t0.add(const Duration(days: 10)));
      await loginAs(AccountType.admin);

      expect(await stored('user_expires_at'), isNull);
      expect(await stored('last_password_verification'), isNull);
      expect(authService.accountExpiresAt.value, isNull);
    });
  });

  group('local session policy', () {
    test('legacy is_admin flag never grants access and is purged', () async {
      FlutterSecureStorage.setMockInitialValues({
        'is_admin': 'true',
        'mobile_api_token': 'old-token',
      });

      await authService.initialize();

      expect(await authService.checkSession(), ExpiryCheckResult.noData);
      expect(await authService.hasValidSession(), isFalse);
      expect(await stored('is_admin'), isNull);
    });

    test('legacy cached expiry without server lease metadata needs relogin', () async {
      FlutterSecureStorage.setMockInitialValues({
        'mobile_api_token': 'old-token',
        'user_expires_at': t0.add(const Duration(days: 100)).toIso8601String(),
      });

      expect(await authService.checkSession(), ExpiryCheckResult.noData);
    });

    test('admin has no account expiry or annual password check', () async {
      await loginAs(
        AccountType.admin,
        lease: t0.add(const Duration(days: 500)),
      );

      final later = t0.add(const Duration(days: 400));
      expect(
        await at(later, authService.checkSession),
        ExpiryCheckResult.valid,
      );
    });

    test('mobile account expiry still locks the session', () async {
      await loginAs(
        AccountType.mobile,
        expiresAt: t0.add(const Duration(days: 10)),
      );

      expect(
        await at(t0.add(const Duration(days: 9)), authService.checkSession),
        ExpiryCheckResult.valid,
      );
      expect(
        await at(t0.add(const Duration(days: 11)), authService.checkSession),
        ExpiryCheckResult.expired,
      );
      expect(authService.state.value, AuthState.expired);
    });

    test('mobile annual password check still applies', () async {
      await loginAs(
        AccountType.mobile,
        expiresAt: t0.add(const Duration(days: 900)),
        lease: t0.add(const Duration(days: 900)),
      );

      expect(
        await at(t0.add(const Duration(days: 364)), authService.checkSession),
        ExpiryCheckResult.valid,
      );
      expect(
        await at(t0.add(const Duration(days: 366)), authService.checkSession),
        ExpiryCheckResult.expired,
      );
    });

    test('offline lease locks both account types once it passes', () async {
      for (final type in AccountType.values) {
        await loginAs(type, expiresAt: type == AccountType.mobile ? t0.add(const Duration(days: 365)) : null);

        expect(
          await at(t0.add(const Duration(days: 29)), authService.checkSession),
          ExpiryCheckResult.valid,
          reason: type.name,
        );
        expect(
          await at(t0.add(const Duration(days: 31)), authService.checkSession),
          ExpiryCheckResult.leaseExpired,
          reason: type.name,
        );
        expect(authService.state.value, AuthState.expired);
      }
    });

    test('lease expiry while the app stays open flips the auth state', () async {
      await loginAs(AccountType.admin);
      final transitions = <AuthState>[];
      authService.state.addListener(() => transitions.add(authService.state.value));

      await at(t0.add(const Duration(days: 10)), authService.checkSession);
      await at(t0.add(const Duration(days: 30, minutes: 1)), authService.checkSession);

      expect(transitions, [AuthState.expired]);
    });
  });

  group('verifyActiveStatus', () {
    test('a successful /me refreshes the lease and user metadata', () async {
      await loginAs(AccountType.admin);
      final refreshed = t0.add(const Duration(days: 20));
      adapter.responder = (_) => _json(200, {
        'user': {'id': 'u1', 'nama': 'Nama Baru', 'email': 'baru@example.com', 'is_active': true},
        'access': _access(AccountType.admin, lease: refreshed.add(const Duration(days: 30))),
      });

      final status = await at(refreshed, authService.verifyActiveStatus);

      expect(status, ActiveStatusResult.active);
      expect(authService.offlineAccessUntil.value, refreshed.add(const Duration(days: 30)));
      expect(authService.userName.value, 'Nama Baru');
      expect(authService.currentUserEmail, 'baru@example.com');
      expect(
        await at(t0.add(const Duration(days: 45)), authService.checkSession),
        ExpiryCheckResult.valid,
      );
    });

    test('malformed access metadata neither extends the lease nor logs out', () async {
      await loginAs(AccountType.admin);
      adapter.responder = (_) => _json(200, {
        'user': {'id': 'u1', 'is_active': true},
        'access': {'account_type': 'admin'},
      });

      final status = await at(t0.add(const Duration(days: 5)), authService.verifyActiveStatus);

      expect(status, ActiveStatusResult.error);
      expect(authService.offlineAccessUntil.value, t0.add(const Duration(days: 30)));
      expect(await ApiService.getToken(), isNotNull);
    });

    test('connection failure is temporary and keeps the session', () async {
      await loginAs(AccountType.mobile);
      adapter.responder = (o) => throw DioException.connectionError(
        requestOptions: o,
        reason: 'offline',
      );

      final status = await at(t0.add(const Duration(days: 1)), authService.verifyActiveStatus);

      expect(status, ActiveStatusResult.error);
      expect(await ApiService.getToken(), isNotNull);
      expect(authService.deactivationReason.value, DeactivationReason.none);
    });

    test('server 5xx and proxy HTML 403 are temporary, not revocation', () async {
      await loginAs(AccountType.mobile);

      adapter.responder = (_) => _json(503, {'message': 'down'});
      expect(await authService.verifyActiveStatus(), ActiveStatusResult.error);

      adapter.responder = (_) => _html(403);
      expect(await authService.verifyActiveStatus(), ActiveStatusResult.error);

      expect(await ApiService.getToken(), isNotNull);
      expect(authService.deactivationReason.value, DeactivationReason.none);
    });

    test('JSON 403 (revoked device) logs out immediately without calling logout', () async {
      await loginAs(AccountType.admin);
      adapter.responder = (_) => _json(403, {'message': 'Perangkat tidak aktif.'});
      final states = <AuthState>[];
      authService.state.addListener(() => states.add(authService.state.value));

      final status = await authService.verifyActiveStatus();

      expect(status, ActiveStatusResult.inactive);
      expect(await ApiService.getToken(), isNull);
      expect(await stored('account_type'), isNull);
      expect(await stored('offline_access_until'), isNull);
      expect(authService.deactivationReason.value, DeactivationReason.deviceRevoked);
      expect(states, [AuthState.unauthenticated]);
      expect(adapter.requests.where((r) => r.path == '/mobile/logout'), isEmpty);
    });

    test('401 logs out as an invalid session', () async {
      await loginAs(AccountType.mobile);
      adapter.responder = (_) => _json(401, {'message': 'Unauthenticated.'});

      await authService.verifyActiveStatus();

      expect(await ApiService.getToken(), isNull);
      expect(authService.deactivationReason.value, DeactivationReason.sessionInvalid);
    });

    test('a 403 on any other authenticated call also ends the session', () async {
      await loginAs(AccountType.admin);
      adapter.responder = (_) => _json(403, {'message': 'Perangkat dicabut.'});

      await authService.updateLastActive();

      expect(await ApiService.getToken(), isNull);
      expect(authService.deactivationReason.value, DeactivationReason.deviceRevoked);
    });

    test('account type change on the server ends the session', () async {
      await loginAs(AccountType.mobile);
      adapter.responder = (_) => _json(200, {
        'user': {'id': 'u1', 'is_active': true},
        'access': _access(AccountType.admin, lease: t0.add(const Duration(days: 30))),
      });

      await at(t0, authService.verifyActiveStatus);

      expect(await ApiService.getToken(), isNull);
    });

    test('expired ordinary account is logged out online', () async {
      await loginAs(AccountType.mobile, expiresAt: t0.add(const Duration(days: 5)));
      adapter.responder = (o) => o.path == '/mobile/logout'
          ? _json(200, {})
          : _json(200, {
              'user': {'id': 'u1', 'is_active': true},
              'access': _access(
                AccountType.mobile,
                expiresAt: t0.add(const Duration(days: 5)),
                lease: t0.add(const Duration(days: 35)),
              ),
            });

      final status = await at(t0.add(const Duration(days: 6)), authService.verifyActiveStatus);

      expect(status, ActiveStatusResult.expired);
      expect(await ApiService.getToken(), isNull);
      expect(authService.deactivationReason.value, DeactivationReason.accountExpired);
    });
  });

  group('stale responses', () {
    test('a delayed 403 for an old token does not log out a newer login', () async {
      await loginAs(AccountType.mobile);
      final gate = Completer<void>();
      adapter.responder = (o) async {
        await gate.future;
        return _json(403, {'message': 'Perangkat dicabut.'});
      };
      final sent = adapter.requests.length;
      final pending = authService.updateLastActive();
      while (adapter.requests.length == sent) {
        await Future<void>.delayed(Duration.zero);
      }

      await ApiService.setToken('newer-token');
      gate.complete();
      await pending;

      expect(await ApiService.getToken(), 'newer-token');
      expect(authService.state.value, AuthState.authenticated);
      expect(authService.deactivationReason.value, DeactivationReason.none);
    });

    test('a delayed /me after logout is not persisted', () async {
      await loginAs(AccountType.admin);
      final gate = Completer<void>();
      adapter.responder = (o) async {
        if (o.path == '/mobile/logout') return _json(200, {});
        await gate.future;
        return _json(200, {
          'user': {'id': 'u1', 'nama': 'Hantu', 'is_active': true},
          'access': _access(AccountType.admin, lease: t0.add(const Duration(days: 60))),
        });
      };
      final sent = adapter.requests.length;
      final pending = authService.verifyActiveStatus();
      while (adapter.requests.length == sent) {
        await Future<void>.delayed(Duration.zero);
      }

      await authService.logout();
      gate.complete();
      final status = await pending;

      expect(status, ActiveStatusResult.error);
      expect(await ApiService.getToken(), isNull);
      expect(await stored('account_type'), isNull);
      expect(await stored('offline_access_until'), isNull);
      expect(authService.userName.value, isNull);
      expect(authService.state.value, AuthState.unauthenticated);
    });

    test('losing token or metadata while authenticated ends the session', () async {
      await loginAs(AccountType.admin);
      await const FlutterSecureStorage().delete(key: 'offline_access_until');

      final result = await authService.checkSession();

      expect(result, ExpiryCheckResult.noData);
      expect(authService.state.value, AuthState.unauthenticated);
      expect(await ApiService.getToken(), isNull);
      expect(authService.deactivationReason.value, DeactivationReason.sessionInvalid);
    });
  });

  group('serialized session mutations', () {
    test('a local check frozen mid-read cannot restore a logged-out session', () async {
      final storage = _GatedStorage();
      FlutterSecureStoragePlatform.instance = storage;
      await authService.initialize();
      await loginAs(AccountType.mobile, expiresAt: t0.add(const Duration(days: 90)));
      storage.pausedReadKey = 'last_password_verification';
      storage.readGate = Completer<void>();

      final check = at(t0, authService.checkSession);
      await storage.readBlocked.future;
      adapter.responder = (_) => _json(200, {});
      final logout = authService.logout();
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      storage.readGate!.complete();
      await Future.wait([check, logout]);

      expect(await ApiService.getToken(), isNull);
      expect(authService.state.value, AuthState.unauthenticated);
      expect(authService.accountType.value, isNull);
      expect(authService.offlineAccessUntil.value, isNull);
    });

    test('a /me commit frozen mid-write cannot leak admin data into a later ordinary login', () async {
      final storage = _GatedStorage();
      FlutterSecureStoragePlatform.instance = storage;
      await authService.initialize();
      await loginAs(AccountType.admin);

      adapter.responder = (o) {
        if (o.path == '/mobile/logout') return _json(200, {});
        return _json(200, {
          'user': {'id': 'admin1', 'nama': 'Admin Lama', 'email': 'admin@example.com', 'is_active': true},
          'access': _access(AccountType.admin, lease: t0.add(const Duration(days: 60))),
        });
      };

      storage.writeBlocked = Completer<void>();
      storage.gate = Completer<void>();
      final me = authService.verifyActiveStatus();
      await storage.writeBlocked.future; // /me is committing, writes paused

      final logout = authService.logout();
      adapter.responder = (o) {
        if (o.path == '/mobile/logout') return _json(200, {});
        return _json(
          200,
          _loginBody(
            AccountType.mobile,
            expiresAt: t0.add(const Duration(days: 90)),
            lease: t0.add(const Duration(days: 30)),
            name: 'Mobile Budi',
          ),
        );
      };
      final login = at(
        t0,
        () => authService.login('m@example.com', 'secret'),
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      // Nothing may have overtaken the paused commit.
      expect(storage.data['account_type'], 'admin');
      expect(storage.data['mobile_api_token'], 'token-admin');

      storage.gate!.complete();
      storage.gate = null;
      await Future.wait([me, logout, login]);

      expect((await login).success, isTrue);
      expect(storage.data['mobile_api_token'], 'token-mobile');
      expect(storage.data['account_type'], 'mobile');
      expect(storage.data['user_name'], 'Mobile Budi');
      expect(storage.data['user_email'], 'u@example.com');
      expect(storage.data['user_expires_at'], t0.add(const Duration(days: 90)).toIso8601String());
      expect(storage.data['offline_access_until'], t0.add(const Duration(days: 30)).toIso8601String());
      expect(authService.accountType.value, AccountType.mobile);
      expect(authService.userName.value, 'Mobile Budi');
      expect(authService.state.value, AuthState.authenticated);
    });

    test('a stale logout does not wipe a newer session', () async {
      await loginAs(AccountType.admin);
      final gate = Completer<void>();
      adapter.responder = (o) async {
        await gate.future;
        return _json(200, {});
      };
      final sent = adapter.requests.length;
      final pendingLogout = authService.logout();
      while (adapter.requests.length == sent) {
        await Future<void>.delayed(Duration.zero);
      }

      await loginAs(AccountType.mobile);
      adapter.responder = (_) => _json(200, {});
      gate.complete();
      await pendingLogout;

      expect(await ApiService.getToken(), 'token-mobile');
      expect(authService.accountType.value, AccountType.mobile);
    });
  });

  group('restoreSession', () {
    test('an expired lease is renewed when the server still accepts the session', () async {
      await loginAs(AccountType.admin);
      final later = t0.add(const Duration(days: 40));
      adapter.responder = (_) => _json(200, {
        'user': {'id': 'u1', 'is_active': true},
        'access': _access(AccountType.admin, lease: later.add(const Duration(days: 30))),
      });

      expect(await at(later, authService.restoreSession), ExpiryCheckResult.valid);
      expect(authService.state.value, AuthState.authenticated);
    });

    test('an expired lease stays locked while offline', () async {
      await loginAs(AccountType.admin);
      adapter.responder = (o) => throw DioException.connectionError(
        requestOptions: o,
        reason: 'offline',
      );

      final result = await at(
        t0.add(const Duration(days: 40)),
        authService.restoreSession,
      );

      expect(result, ExpiryCheckResult.leaseExpired);
      expect(authService.state.value, AuthState.expired);
    });
  });

  group('resetPassword', () {
    test('sends only the email, never a user_type', () async {
      adapter.responder = (_) => _json(200, {'message': 'ok'});

      await authService.resetPassword('a@example.com');

      expect(adapter.requests.single.data, {'email': 'a@example.com'});
    });
  });
}
