import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../utils/platform_utils.dart';
import 'api_service.dart';

bool get isAndroid => !kIsWeb && Platform.isAndroid;
bool get isIOS => !kIsWeb && Platform.isIOS;
bool get isWeb => kIsWeb;

enum AuthState { unknown, authenticated, unauthenticated, expired }

/// Hasil pemeriksaan sesi lokal.
/// [leaseExpired]: akses offline 30 hari dari server sudah habis; sesi harus
/// diperbarui lewat koneksi ke server. [noData]: tidak ada sesi yang sah
/// (termasuk sesi lama tanpa metadata akses), login ulang diperlukan.
enum ExpiryCheckResult { valid, expired, leaseExpired, noData }

enum ActiveStatusResult { active, inactive, expired, error }

enum DeactivationReason {
  none,
  accountInactive,
  accountExpired,
  accountDeleted,
  yearlyPasswordCheck,
  sessionInvalid,
  deviceRevoked,
}

enum AccountType {
  mobile('mobile'),
  admin('admin');

  const AccountType(this.apiValue);
  final String apiValue;

  static AccountType? fromApi(Object? value) {
    for (final type in AccountType.values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }
}

enum LoginResultType { success, failure, expired, deviceConflict }

class LoginResult {
  final bool success;
  final String? error;
  final LoginResultType type;

  LoginResult._(this.success, this.error, this.type);

  factory LoginResult.success() =>
      LoginResult._(true, null, LoginResultType.success);
  factory LoginResult.failure(String error) =>
      LoginResult._(false, error, LoginResultType.failure);
  factory LoginResult.expired(String error) =>
      LoginResult._(false, error, LoginResultType.expired);
  factory LoginResult.deviceConflict(String error) =>
      LoginResult._(false, error, LoginResultType.deviceConflict);
}

/// Metadata akses dari server (`access` pada login dan `/mobile/me`).
class AccessInfo {
  final AccountType accountType;
  final DateTime? expiresAt;
  final DateTime offlineAccessUntil;

  const AccessInfo._(this.accountType, this.expiresAt, this.offlineAccessUntil);

  /// Mengembalikan null bila metadata tidak lengkap atau tidak konsisten.
  /// Admin tidak boleh punya masa kedaluwarsa akun.
  static AccessInfo? parse(Object? raw) {
    if (raw is! Map) return null;
    final type = AccountType.fromApi(raw['account_type']);
    if (type == null) return null;

    final expiresRaw = raw['expires_at'];
    DateTime? expiresAt;
    if (expiresRaw != null) {
      if (expiresRaw is! String) return null;
      expiresAt = DateTime.tryParse(expiresRaw)?.toUtc();
      if (expiresAt == null) return null;
    }
    if (type == AccountType.admin && expiresAt != null) return null;

    final leaseRaw = raw['offline_access_until'];
    if (leaseRaw is! String) return null;
    final lease = DateTime.tryParse(leaseRaw)?.toUtc();
    if (lease == null) return null;

    return AccessInfo._(type, expiresAt, lease);
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    ApiService.onSessionRejected = _handleSessionRejected;
  }

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _deviceIdKey = ApiService.deviceIdKey;
  static const String _expiresAtKey = 'user_expires_at';
  static const String _accountTypeKey = 'account_type';
  static const String _offlineAccessUntilKey = 'offline_access_until';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _userIdKey = 'user_id';
  // Flag lama; tidak pernah dipercaya lagi dan dihapus saat inisialisasi.
  static const String _legacyIsAdminKey = 'is_admin';
  static const String _lastPasswordVerificationKey =
      'last_password_verification';

  final ValueNotifier<AuthState> state = ValueNotifier(AuthState.unknown);
  final ValueNotifier<int?> daysUntilExpiry = ValueNotifier(null);
  final ValueNotifier<String?> userName = ValueNotifier(null);
  final ValueNotifier<AccountType?> accountType = ValueNotifier(null);

  /// Masa kedaluwarsa akun; null untuk admin atau akun tanpa batas.
  final ValueNotifier<DateTime?> accountExpiresAt = ValueNotifier(null);

  /// Batas akses offline yang diterbitkan server.
  final ValueNotifier<DateTime?> offlineAccessUntil = ValueNotifier(null);
  final ValueNotifier<DeactivationReason> deactivationReason = ValueNotifier(
    DeactivationReason.none,
  );
  String? _currentUserEmail;
  Future<void>? _forcedLogout;
  Future<void> _mutationTail = Future<void>.value();

  /// Menjalankan mutasi sesi lokal (token + cache + notifier) satu per satu
  /// sehingga respons terlambat tidak bisa menyisipkan data sesi lama di
  /// antara login/logout. Jangan memanggil [_serialized] dari dalam [action].
  Future<T> _serialized<T>(Future<T> Function() action) {
    final run = _mutationTail.then((_) => action());
    _mutationTail = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<void> initialize() async {
    await _secureStorage.delete(key: _legacyIsAdminKey);
    userName.value = await _secureStorage.read(key: _userNameKey);
    _currentUserEmail = await _secureStorage.read(key: _userEmailKey);
    accountType.value = AccountType.fromApi(
      await _secureStorage.read(key: _accountTypeKey),
    );
    accountExpiresAt.value = _tryParseDate(
      await _secureStorage.read(key: _expiresAtKey),
    );
    offlineAccessUntil.value = _tryParseDate(
      await _secureStorage.read(key: _offlineAccessUntilKey),
    );
    _publishExpiry(accountExpiresAt.value);
  }

  static DateTime? _tryParseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value)?.toUtc();

  Future<String> getDeviceId() async {
    String? deviceId = await _secureStorage.read(key: _deviceIdKey);
    if (deviceId != null) return deviceId;

    deviceId = 'caripasal-device-${const Uuid().v4()}';
    await _secureStorage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  Future<String> getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (isWeb) {
        final info = await deviceInfo.webBrowserInfo;
        return 'Web Browser (${info.browserName.name})';
      } else if (isAndroid) {
        final info = await deviceInfo.androidInfo;
        return '${info.brand} ${info.model}';
      } else if (isIOS) {
        final info = await deviceInfo.iosInfo;
        return '${info.name} (${info.model})';
      }
    } catch (e) {
      print('Error getting device name: $e');
    }
    return 'Unknown Device';
  }

  String get platformName {
    if (isWeb) return 'web';
    if (isAndroid) return 'android';
    if (isIOS) return 'ios';
    return 'unknown';
  }

  Future<LoginResult> login(String email, String password) async {
    try {
      final deviceId = await getDeviceId();
      final deviceName = await getDeviceName();
      final response = await ApiService.dio.post<Map<String, dynamic>>(
        '/mobile/login',
        data: {
          'email': email,
          'password': password,
          'device_id': deviceId,
          'device_name': deviceName,
          'platform': platformName,
        },
      );

      final data = response.data ?? {};
      final token = data['token'];
      final user = data['user'];
      final access = AccessInfo.parse(data['access']);
      if (token is! String ||
          token.isEmpty ||
          user is! Map ||
          access == null) {
        return LoginResult.failure('Login gagal. Response server tidak valid.');
      }

      final now = clock.now();
      final expiresAt = access.expiresAt;
      if (expiresAt != null && !expiresAt.isAfter(now)) {
        return LoginResult.expired('Masa aktif akun Anda telah berakhir.');
      }
      if (!access.offlineAccessUntil.isAfter(now)) {
        return LoginResult.failure('Login gagal. Response server tidak valid.');
      }

      await _serialized(() async {
        await _persistAccess(
          access: access,
          user: user,
          fallbackEmail: email,
          fallbackName: email,
        );
        if (access.accountType == AccountType.mobile) {
          await _secureStorage.write(
            key: _lastPasswordVerificationKey,
            value: now.toUtc().toIso8601String(),
          );
        } else {
          await _secureStorage.delete(key: _lastPasswordVerificationKey);
        }
        await ApiService.setToken(token);
        state.value = AuthState.authenticated;
      });
      return LoginResult.success();
    } on DioException catch (e) {
      final message = ApiService.messageFromError(e);
      if (message.toLowerCase().contains('perangkat') ||
          message.toLowerCase().contains('device')) {
        return LoginResult.deviceConflict(message);
      }
      if (message.toLowerCase().contains('expired') ||
          message.toLowerCase().contains('berakhir')) {
        return LoginResult.expired(message);
      }
      return LoginResult.failure(message);
    } catch (e) {
      print('Login error: $e');
      return LoginResult.failure('Terjadi kesalahan. Coba lagi nanti.');
    }
  }

  /// Menyimpan metadata akses server dan data pengguna ke storage aman dan
  /// notifier. Token ditulis terpisah oleh pemanggil.
  Future<void> _persistAccess({
    required AccessInfo access,
    required Map user,
    required String? fallbackEmail,
    required String? fallbackName,
  }) async {
    final id = user['id']?.toString();
    final email = (user['email'] as String?) ?? fallbackEmail;
    final name = (user['nama'] ?? user['name']) as String? ?? fallbackName;

    await _secureStorage.write(
      key: _accountTypeKey,
      value: access.accountType.apiValue,
    );
    await _secureStorage.write(
      key: _offlineAccessUntilKey,
      value: access.offlineAccessUntil.toIso8601String(),
    );
    final expiresAt = access.expiresAt;
    if (expiresAt != null) {
      await _secureStorage.write(
        key: _expiresAtKey,
        value: expiresAt.toIso8601String(),
      );
    } else {
      await _secureStorage.delete(key: _expiresAtKey);
    }
    if (id != null) await _secureStorage.write(key: _userIdKey, value: id);
    if (email != null) {
      await _secureStorage.write(key: _userEmailKey, value: email);
      _currentUserEmail = email;
    }
    if (name != null) {
      await _secureStorage.write(key: _userNameKey, value: name);
      userName.value = name;
    }

    accountType.value = access.accountType;
    offlineAccessUntil.value = access.offlineAccessUntil;
    _publishExpiry(expiresAt);
  }

  Future<bool> resetPassword(String email) async {
    try {
      await ApiService.dio.post(
        '/password/forgot',
        data: {'email': email},
      );
      return true;
    } catch (e) {
      print('Reset password error: $e');
      return false;
    }
  }

  Future<bool> hasValidSession() async {
    return await checkSession() == ExpiryCheckResult.valid;
  }

  /// Memeriksa sesi lokal tanpa jaringan: token, metadata akses dari server,
  /// masa aktif akun (hanya akun mobile), cek password tahunan (hanya akun
  /// mobile), dan batas akses offline. Flag lama seperti `is_admin` tidak
  /// pernah memberi akses.
  Future<ExpiryCheckResult> checkSession() => _serialized(() async {
    final result = await _evaluateSession();
    // Read and publish one consistent session, including missing metadata.
    if (result == ExpiryCheckResult.noData &&
        state.value == AuthState.authenticated) {
      deactivationReason.value = DeactivationReason.sessionInvalid;
      await _endLocalSessionUnlocked();
    }
    return result;
  });

  Future<ExpiryCheckResult> _evaluateSession() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) return ExpiryCheckResult.noData;

    final type = AccountType.fromApi(
      await _secureStorage.read(key: _accountTypeKey),
    );
    final lease = _tryParseDate(
      await _secureStorage.read(key: _offlineAccessUntilKey),
    );
    if (type == null || lease == null) return ExpiryCheckResult.noData;

    DateTime? expiresAt;
    if (type == AccountType.mobile) {
      final raw = await _secureStorage.read(key: _expiresAtKey);
      if (raw != null) {
        expiresAt = _tryParseDate(raw);
        if (expiresAt == null) return ExpiryCheckResult.noData;
      }
    }

    accountType.value = type;
    offlineAccessUntil.value = lease;
    _publishExpiry(expiresAt);

    final now = clock.now();
    if (expiresAt != null && !expiresAt.isAfter(now)) {
      state.value = AuthState.expired;
      return ExpiryCheckResult.expired;
    }

    if (type == AccountType.mobile) {
      final lastVerification = _tryParseDate(
        await _secureStorage.read(key: _lastPasswordVerificationKey),
      );
      if (lastVerification != null &&
          now.difference(lastVerification).inDays > 365) {
        state.value = AuthState.expired;
        return ExpiryCheckResult.expired;
      }
    }

    if (!lease.isAfter(now)) {
      state.value = AuthState.expired;
      return ExpiryCheckResult.leaseExpired;
    }

    state.value = AuthState.authenticated;
    return ExpiryCheckResult.valid;
  }

  /// True bila sesi terkunci karena akses offline habis (bukan masa aktif akun).
  bool get isOfflineLeaseExpired {
    final lease = offlineAccessUntil.value;
    final expires = accountExpiresAt.value;
    final now = clock.now();
    final accountExpired = expires != null && !expires.isAfter(now);
    return !accountExpired && lease != null && !lease.isAfter(now);
  }

  /// Seperti [checkSession], tetapi bila hanya akses offline yang habis dicoba
  /// memperbaruinya ke server lebih dulu (berhasil bila online dan sesi masih
  /// sah di server).
  Future<ExpiryCheckResult> restoreSession() async {
    final result = await checkSession();
    if (result != ExpiryCheckResult.leaseExpired) return result;
    final status = await verifyActiveStatus();
    if (status == ActiveStatusResult.error) return result;
    return checkSession();
  }

  void _publishExpiry(DateTime? expiresAt) {
    accountExpiresAt.value = expiresAt;
    daysUntilExpiry.value = expiresAt?.difference(clock.now()).inDays;
  }

  /// [expectedToken]: token sesi yang dimaksud; bila sudah berganti (login
  /// baru) logout lokal dibatalkan. Default: token saat ini.
  Future<void> logout({String? expectedToken}) async {
    final token = expectedToken ?? await ApiService.getToken();
    try {
      final deviceId = await getDeviceId();
      await ApiService.dio.post(
        '/mobile/logout',
        data: {'device_id': deviceId},
      );
    } catch (e) {
      print('Logout error (continuing with local cleanup): $e');
    }

    await _serialized(() async {
      if (await ApiService.getToken() != token) return;
      await _endLocalSessionUnlocked();
    });
  }

  /// Hanya dipanggil di dalam [_serialized].
  Future<void> _endLocalSessionUnlocked() async {
    await _clearLocalAuth();
    await ApiService.clearToken();
    _currentUserEmail = null;
    state.value = AuthState.unauthenticated;
    daysUntilExpiry.value = null;
    userName.value = null;
    accountType.value = null;
    accountExpiresAt.value = null;
    offlineAccessUntil.value = null;
  }

  /// Mengakhiri sesi [expectedToken] secara lokal tanpa memanggil server,
  /// dipakai saat server sendiri sudah menolak token (401/403). Bila token
  /// tersimpan sudah berbeda (login baru) tidak terjadi apa-apa. Panggilan
  /// bersamaan berbagi satu proses sehingga pemberitahuan hanya muncul sekali.
  Future<void> _forceLogout(DeactivationReason reason, String expectedToken) {
    final inFlight = _forcedLogout;
    if (inFlight != null) return inFlight;
    return _forcedLogout = _serialized(() async {
      if (await ApiService.getToken() != expectedToken) return;
      deactivationReason.value = reason;
      await _endLocalSessionUnlocked();
    }).whenComplete(() => _forcedLogout = null);
  }

  /// Menolak hanya bila token yang ditolak masih token sesi saat ini; respons
  /// terlambat dari sesi lama tidak boleh mengeluarkan login yang baru.
  Future<void> _handleSessionRejected(
    int statusCode,
    String? requestToken,
  ) async {
    if (requestToken == null) return;
    return _forceLogout(
      statusCode == 401
          ? DeactivationReason.sessionInvalid
          : DeactivationReason.deviceRevoked,
      requestToken,
    );
  }

  Future<void> _clearLocalAuth() async {
    await _secureStorage.delete(key: _expiresAtKey);
    await _secureStorage.delete(key: _accountTypeKey);
    await _secureStorage.delete(key: _offlineAccessUntilKey);
    await _secureStorage.delete(key: _userEmailKey);
    await _secureStorage.delete(key: _userNameKey);
    await _secureStorage.delete(key: _userIdKey);
    await _secureStorage.delete(key: _legacyIsAdminKey);
    await _secureStorage.delete(key: _lastPasswordVerificationKey);
  }

  Future<void> updateLastActive() async {
    try {
      final deviceId = await getDeviceId();
      final deviceName = await getDeviceName();
      await ApiService.dio.post(
        '/mobile/device/heartbeat',
        data: {
          'device_id': deviceId,
          'device_name': deviceName,
          'platform': platformName,
        },
      );
    } catch (e) {
      print('Update last active error: $e');
    }
  }

  bool get isLoggedIn => state.value == AuthState.authenticated;

  Future<bool> get isLoggedInAsync async =>
      (await ApiService.getToken()) != null;

  String? get currentUserEmail => _currentUserEmail;

  Future<String?> getCurrentUserEmail() {
    return _secureStorage.read(key: _userEmailKey);
  }

  void clearDeactivationReason() {
    deactivationReason.value = DeactivationReason.none;
  }

  String? get deactivationMessage {
    switch (deactivationReason.value) {
      case DeactivationReason.none:
        return null;
      case DeactivationReason.accountInactive:
        return 'Akun Anda telah dinonaktifkan. Silakan hubungi administrator.';
      case DeactivationReason.accountExpired:
        return 'Akun Anda telah kadaluarsa. Silakan hubungi administrator untuk memperpanjang.';
      case DeactivationReason.accountDeleted:
        return 'Akun Anda tidak ditemukan. Silakan hubungi administrator.';
      case DeactivationReason.yearlyPasswordCheck:
        return 'Demi keamanan, silakan login ulang untuk memverifikasi password setiap 1 tahun.';
      case DeactivationReason.sessionInvalid:
        return 'Sesi Anda tidak lagi valid. Silakan login ulang.';
      case DeactivationReason.deviceRevoked:
        return 'Perangkat ini tidak lagi diizinkan untuk akun Anda. Silakan login ulang atau hubungi administrator.';
    }
  }

  Future<ActiveStatusResult> verifyActiveStatus() async {
    final token = await ApiService.getToken();
    if (token == null) return ActiveStatusResult.error;

    try {
      final response = await ApiService.dio.get<Map<String, dynamic>>(
        '/mobile/me',
      );
      final user = response.data?['user'];
      if (user is! Map) {
        await _forceLogout(DeactivationReason.accountDeleted, token);
        return await ApiService.getToken() == null
            ? ActiveStatusResult.inactive
            : ActiveStatusResult.error;
      }

      // Metadata akses yang rusak tidak boleh memperpanjang akses offline,
      // tetapi juga bukan bukti sesi dicabut.
      final access = AccessInfo.parse(response.data?['access']);
      if (access == null) return ActiveStatusResult.error;

      if (user['is_active'] == false) {
        if (await ApiService.getToken() != token) return ActiveStatusResult.error;
        deactivationReason.value = DeactivationReason.accountInactive;
        await logout(expectedToken: token);
        return ActiveStatusResult.inactive;
      }

      switch (await _commitStatus(token, access, user)) {
        case _StatusCommit.stale:
          return ActiveStatusResult.error;
        case _StatusCommit.committed:
          return ActiveStatusResult.active;
        case _StatusCommit.typeMismatch:
          await _forceLogout(DeactivationReason.sessionInvalid, token);
          return ActiveStatusResult.inactive;
        case _StatusCommit.accountExpired:
          deactivationReason.value = DeactivationReason.accountExpired;
          await logout(expectedToken: token);
          state.value = AuthState.expired;
          return ActiveStatusResult.expired;
        case _StatusCommit.passwordCheckDue:
          deactivationReason.value = DeactivationReason.yearlyPasswordCheck;
          await logout(expectedToken: token);
          return ActiveStatusResult.expired;
      }
    } on DioException catch (e) {
      if (ApiService.isSessionRejection(e)) {
        final current = await ApiService.getToken();
        if (current != token) {
          // Hook sudah mengeluarkan sesi ini, atau sesi lain sudah menggantikan.
          return current == null &&
                  deactivationReason.value != DeactivationReason.none
              ? ActiveStatusResult.inactive
              : ActiveStatusResult.error;
        }
        await _forceLogout(
          e.response?.statusCode == 401
              ? DeactivationReason.sessionInvalid
              : DeactivationReason.deviceRevoked,
          token,
        );
        return ActiveStatusResult.inactive;
      }
      print('Error verifying active status: ${ApiService.messageFromError(e)}');
      return ActiveStatusResult.error;
    } catch (e) {
      print('Error verifying active status: $e');
      return ActiveStatusResult.error;
    }
  }

  /// Satu transaksi serial: memastikan [token] masih sesi saat ini, memeriksa
  /// kebijakan terhadap cache tersimpan, lalu menyimpan metadata. Metadata
  /// dari respons sesi lama tidak pernah menempel ke token lain.
  Future<_StatusCommit> _commitStatus(
    String token,
    AccessInfo access,
    Map user,
  ) {
    return _serialized(() async {
      if (await ApiService.getToken() != token) return _StatusCommit.stale;

      final storedType = AccountType.fromApi(
        await _secureStorage.read(key: _accountTypeKey),
      );
      if (storedType != null && storedType != access.accountType) {
        return _StatusCommit.typeMismatch;
      }

      final now = clock.now();
      final expiresAt = access.expiresAt;
      if (expiresAt != null && !expiresAt.isAfter(now)) {
        return _StatusCommit.accountExpired;
      }

      if (access.accountType == AccountType.mobile) {
        final lastVerification = _tryParseDate(
          await _secureStorage.read(key: _lastPasswordVerificationKey),
        );
        if (lastVerification != null &&
            now.difference(lastVerification).inDays > 365) {
          return _StatusCommit.passwordCheckDue;
        }
      }

      await _persistAccess(
        access: access,
        user: user,
        fallbackEmail: _currentUserEmail,
        fallbackName: userName.value,
      );
      return _StatusCommit.committed;
    });
  }
}

enum _StatusCommit {
  stale,
  committed,
  typeMismatch,
  accountExpired,
  passwordCheckDue,
}

final authService = AuthService();
