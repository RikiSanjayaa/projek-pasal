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

enum ExpiryCheckResult { valid, expired, noData }

enum ActiveStatusResult { active, inactive, expired, error }

enum DeactivationReason {
  none,
  accountInactive,
  accountExpired,
  accountDeleted,
  yearlyPasswordCheck,
}

enum LoginResultType { success, successAdmin, failure, expired, deviceConflict }

class LoginResult {
  final bool success;
  final String? error;
  final LoginResultType type;

  LoginResult._(this.success, this.error, this.type);

  factory LoginResult.success() =>
      LoginResult._(true, null, LoginResultType.success);
  factory LoginResult.successAdmin() =>
      LoginResult._(true, null, LoginResultType.successAdmin);
  factory LoginResult.failure(String error) =>
      LoginResult._(false, error, LoginResultType.failure);
  factory LoginResult.expired(String error) =>
      LoginResult._(false, error, LoginResultType.expired);
  factory LoginResult.deviceConflict(String error) =>
      LoginResult._(false, error, LoginResultType.deviceConflict);
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _deviceIdKey = ApiService.deviceIdKey;
  static const String _expiresAtKey = 'user_expires_at';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _userIdKey = 'user_id';
  static const String _isAdminKey = 'is_admin';
  static const String _lastPasswordVerificationKey =
      'last_password_verification';

  final ValueNotifier<AuthState> state = ValueNotifier(AuthState.unknown);
  final ValueNotifier<int?> daysUntilExpiry = ValueNotifier(null);
  final ValueNotifier<String?> userName = ValueNotifier(null);
  final ValueNotifier<bool> isAdmin = ValueNotifier(false);
  final ValueNotifier<DeactivationReason> deactivationReason = ValueNotifier(
    DeactivationReason.none,
  );
  String? _currentUserEmail;

  Future<void> initialize() async {
    userName.value = await _secureStorage.read(key: _userNameKey);
    _currentUserEmail = await _secureStorage.read(key: _userEmailKey);
    isAdmin.value = await _secureStorage.read(key: _isAdminKey) == 'true';
  }

  Future<String> getDeviceId() async {
    String? deviceId = await _secureStorage.read(key: _deviceIdKey);
    if (deviceId != null) return deviceId;

    final deviceInfo = DeviceInfoPlugin();
    try {
      if (isWeb) {
        final info = await deviceInfo.webBrowserInfo;
        deviceId = '${info.browserName.name}_${info.userAgent?.hashCode ?? 0}';
      } else if (isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceId = info.id;
      } else if (isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceId = info.identifierForVendor;
      }
    } catch (e) {
      print('Error getting device ID: $e');
    }

    deviceId ??= const Uuid().v4();
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
      final token = data['token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      if (token == null || user == null) {
        return LoginResult.failure('Login gagal. Response server tidak valid.');
      }

      final expiresAt = user['expires_at'] != null
          ? DateTime.parse(user['expires_at'] as String)
          : null;

      await ApiService.setToken(token);
      await _secureStorage.write(key: _userIdKey, value: user['id'] as String?);
      await _secureStorage.write(key: _userEmailKey, value: email);
      _currentUserEmail = email;
      await _secureStorage.write(
        key: _userNameKey,
        value: (user['nama'] as String?) ?? email,
      );
      await _secureStorage.write(key: _isAdminKey, value: 'false');
      await _secureStorage.write(
        key: _lastPasswordVerificationKey,
        value: clock.now().toUtc().toIso8601String(),
      );
      if (expiresAt != null) {
        await _secureStorage.write(
          key: _expiresAtKey,
          value: expiresAt.toIso8601String(),
        );
        _updateExpiryState(expiresAt);
      }

      userName.value = (user['nama'] as String?) ?? email;
      isAdmin.value = false;
      state.value = AuthState.authenticated;
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

  Future<bool> resetPassword(String email) async {
    try {
      await ApiService.dio.post(
        '/password/forgot',
        data: {'email': email, 'user_type': 'mobile'},
      );
      return true;
    } catch (e) {
      print('Reset password error: $e');
      return false;
    }
  }

  Future<bool> hasValidSession() async {
    final token = await ApiService.getToken();
    if (token == null) return false;
    final expiryResult = await checkExpiryOffline();
    return expiryResult == ExpiryCheckResult.valid;
  }

  Future<ExpiryCheckResult> checkExpiryOffline() async {
    final adminFlag = await _secureStorage.read(key: _isAdminKey);
    if (adminFlag == 'true') {
      isAdmin.value = true;
      state.value = AuthState.authenticated;
      return ExpiryCheckResult.valid;
    }

    final expiresAtStr = await _secureStorage.read(key: _expiresAtKey);
    if (expiresAtStr == null) return ExpiryCheckResult.noData;

    try {
      final expiresAt = DateTime.parse(expiresAtStr);
      _updateExpiryState(expiresAt);
      if (expiresAt.isBefore(clock.now())) {
        state.value = AuthState.expired;
        return ExpiryCheckResult.expired;
      }

      final lastVerificationStr = await _secureStorage.read(
        key: _lastPasswordVerificationKey,
      );
      if (lastVerificationStr != null) {
        final lastVerification = DateTime.parse(lastVerificationStr);
        if (clock.now().difference(lastVerification).inDays > 365) {
          state.value = AuthState.expired;
          return ExpiryCheckResult.expired;
        }
      }

      state.value = AuthState.authenticated;
      return ExpiryCheckResult.valid;
    } catch (e) {
      print('Error parsing expires_at: $e');
      return ExpiryCheckResult.noData;
    }
  }

  void _updateExpiryState(DateTime expiresAt) {
    daysUntilExpiry.value = expiresAt.difference(clock.now()).inDays;
  }

  Future<void> logout() async {
    try {
      final deviceId = await getDeviceId();
      await ApiService.dio.post(
        '/mobile/logout',
        data: {'device_id': deviceId},
      );
    } catch (e) {
      print('Logout error (continuing with local cleanup): $e');
    }

    await _clearLocalAuth();
    await ApiService.clearToken();
    _currentUserEmail = null;
    state.value = AuthState.unauthenticated;
    daysUntilExpiry.value = null;
    userName.value = null;
    isAdmin.value = false;
  }

  Future<void> _clearLocalAuth() async {
    await _secureStorage.delete(key: _expiresAtKey);
    await _secureStorage.delete(key: _userEmailKey);
    await _secureStorage.delete(key: _userNameKey);
    await _secureStorage.delete(key: _userIdKey);
    await _secureStorage.delete(key: _isAdminKey);
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
    }
  }

  Future<ActiveStatusResult> verifyActiveStatus() async {
    final token = await ApiService.getToken();
    if (token == null) return ActiveStatusResult.error;

    try {
      final response = await ApiService.dio.get<Map<String, dynamic>>(
        '/mobile/me',
      );
      final user = response.data?['user'] as Map<String, dynamic>?;
      if (user == null) {
        deactivationReason.value = DeactivationReason.accountDeleted;
        await logout();
        return ActiveStatusResult.inactive;
      }

      if (user['is_active'] != true) {
        deactivationReason.value = DeactivationReason.accountInactive;
        await logout();
        return ActiveStatusResult.inactive;
      }

      final expiresAt = user['expires_at'] != null
          ? DateTime.parse(user['expires_at'] as String)
          : null;
      if (expiresAt != null && expiresAt.isBefore(clock.now())) {
        deactivationReason.value = DeactivationReason.accountExpired;
        await logout();
        state.value = AuthState.expired;
        return ActiveStatusResult.expired;
      }

      if (expiresAt != null) {
        await _secureStorage.write(
          key: _expiresAtKey,
          value: expiresAt.toIso8601String(),
        );
        _updateExpiryState(expiresAt);
      }

      final lastVerificationStr = await _secureStorage.read(
        key: _lastPasswordVerificationKey,
      );
      if (lastVerificationStr != null) {
        final lastVerification = DateTime.parse(lastVerificationStr);
        if (clock.now().difference(lastVerification).inDays > 365) {
          deactivationReason.value = DeactivationReason.yearlyPasswordCheck;
          await logout();
          return ActiveStatusResult.expired;
        }
      }

      return ActiveStatusResult.active;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        deactivationReason.value = DeactivationReason.accountInactive;
        await logout();
        return ActiveStatusResult.inactive;
      }
      print('Error verifying active status: ${ApiService.messageFromError(e)}');
      return ActiveStatusResult.error;
    } catch (e) {
      print('Error verifying active status: $e');
      return ActiveStatusResult.error;
    }
  }
}

final authService = AuthService();
