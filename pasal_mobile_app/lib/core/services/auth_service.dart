import 'dart:io';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Authentication state enum
enum AuthState { unknown, authenticated, unauthenticated, expired }

/// Result type for expiry check
enum ExpiryCheckResult { valid, expired, noData }

/// Result type for login
enum LoginResultType { success, failure, expired, deviceConflict }

/// Login result class
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

/// Authentication service for mobile app users
/// Handles login, logout, device binding, and expiry checks
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Secure storage keys
  static const String _deviceIdKey = 'device_id';
  static const String _expiresAtKey = 'user_expires_at';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';

  // Notifiers for UI
  final ValueNotifier<AuthState> state = ValueNotifier(AuthState.unknown);
  final ValueNotifier<int?> daysUntilExpiry = ValueNotifier(null);
  final ValueNotifier<String?> userName = ValueNotifier(null);

  /// Initialize auth service - call on app startup
  Future<void> initialize() async {
    // Load user name from storage for display
    final name = await _secureStorage.read(key: _userNameKey);
    userName.value = name;
  }

  /// Generate or retrieve device ID
  /// Generates a UUID on first call and stores it securely
  Future<String> getDeviceId() async {
    String? deviceId = await _secureStorage.read(key: _deviceIdKey);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _secureStorage.write(key: _deviceIdKey, value: deviceId);
    }
    return deviceId;
  }

  /// Get human-readable device name
  Future<String> getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return '${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return '${info.name} (${info.model})';
      }
    } catch (e) {
      print('Error getting device name: $e');
    }
    return 'Unknown Device';
  }

  /// Login with email and password
  /// Handles device binding and expiry checks
  Future<LoginResult> login(String email, String password) async {
    try {
      // 1. Sign in with Supabase
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return LoginResult.failure('Login gagal. Periksa email dan password.');
      }

      final userId = response.user!.id;

      // 2. Get user profile from users table
      final userProfile = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (userProfile == null) {
        // User exists in auth but not in users table (might be an admin)
        await _supabase.auth.signOut();
        return LoginResult.failure(
            'Akun tidak ditemukan. Hubungi administrator.');
      }

      // 3. Check if user is active
      if (userProfile['is_active'] != true) {
        await _supabase.auth.signOut();
        return LoginResult.failure(
            'Akun tidak aktif. Hubungi administrator.');
      }

      // 4. Check if user is expired
      final expiresAt = DateTime.parse(userProfile['expires_at']);
      if (expiresAt.isBefore(clock.now())) {
        await _supabase.auth.signOut();
        return LoginResult.expired(
            'Akun telah kadaluarsa. Hubungi administrator untuk memperpanjang.');
      }

      // 5. Check device binding
      final deviceId = await getDeviceId();
      final existingDevices = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true);

      // Check if another device is active
      for (var device in existingDevices) {
        if (device['device_id'] != deviceId) {
          await _supabase.auth.signOut();
          final otherDeviceName = device['device_name'] ?? 'perangkat lain';
          return LoginResult.deviceConflict(
              'Akun sedang aktif di $otherDeviceName. '
              'Logout dari perangkat tersebut terlebih dahulu, '
              'atau hubungi administrator jika perangkat hilang.');
        }
      }

      // 6. Register/update this device
      final deviceName = await getDeviceName();
      await _supabase.from('user_devices').upsert(
        {
          'user_id': userId,
          'device_id': deviceId,
          'device_name': deviceName,
          'is_active': true,
          'last_active_at': clock.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,device_id',
      );

      // 7. Store expiry and user info locally for offline check
      await _secureStorage.write(
        key: _expiresAtKey,
        value: expiresAt.toIso8601String(),
      );
      await _secureStorage.write(key: _userEmailKey, value: email);
      await _secureStorage.write(
        key: _userNameKey,
        value: userProfile['nama'] ?? email,
      );

      // 8. Update state
      userName.value = userProfile['nama'] ?? email;
      _updateExpiryState(expiresAt);
      state.value = AuthState.authenticated;

      return LoginResult.success();
    } on AuthException catch (e) {
      return LoginResult.failure(
          e.message.contains('Invalid login')
              ? 'Email atau password salah.'
              : e.message);
    } catch (e) {
      print('Login error: $e');
      return LoginResult.failure('Terjadi kesalahan. Coba lagi nanti.');
    }
  }

  /// Check if user session exists and is valid
  Future<bool> hasValidSession() async {
    final session = _supabase.auth.currentSession;
    if (session == null) return false;

    // Also check local expiry
    final expiryResult = await checkExpiryOffline();
    return expiryResult == ExpiryCheckResult.valid;
  }

  /// Check expiry on app start (works offline)
  /// Returns expired if local expires_at is in the past
  Future<ExpiryCheckResult> checkExpiryOffline() async {
    final expiresAtStr = await _secureStorage.read(key: _expiresAtKey);
    if (expiresAtStr == null) {
      return ExpiryCheckResult.noData;
    }

    try {
      final expiresAt = DateTime.parse(expiresAtStr);
      _updateExpiryState(expiresAt);

      if (expiresAt.isBefore(clock.now())) {
        state.value = AuthState.expired;
        return ExpiryCheckResult.expired;
      }

      state.value = AuthState.authenticated;
      return ExpiryCheckResult.valid;
    } catch (e) {
      print('Error parsing expires_at: $e');
      return ExpiryCheckResult.noData;
    }
  }

  /// Update expiry warning state
  void _updateExpiryState(DateTime expiresAt) {
    final days = expiresAt.difference(clock.now()).inDays;
    daysUntilExpiry.value = days;
  }

  /// Logout and clear device binding
  Future<void> logout() async {
    try {
      final deviceId = await getDeviceId();
      final userId = _supabase.auth.currentUser?.id;

      // Deactivate device on server
      if (userId != null) {
        await _supabase
            .from('user_devices')
            .update({'is_active': false})
            .eq('user_id', userId)
            .eq('device_id', deviceId);
      }

      // Sign out from Supabase
      await _supabase.auth.signOut();
    } catch (e) {
      print('Logout error (continuing with local cleanup): $e');
    }

    // Always clear local storage
    await _clearLocalAuth();
    state.value = AuthState.unauthenticated;
    daysUntilExpiry.value = null;
    userName.value = null;
  }

  /// Clear local auth data
  Future<void> _clearLocalAuth() async {
    await _secureStorage.delete(key: _expiresAtKey);
    await _secureStorage.delete(key: _userEmailKey);
    await _secureStorage.delete(key: _userNameKey);
    // Note: We keep device_id as it's device-specific, not user-specific
  }

  /// Update last active timestamp (call periodically or on app resume)
  Future<void> updateLastActive() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final deviceId = await getDeviceId();

      if (userId != null) {
        await _supabase
            .from('user_devices')
            .update({
              'last_active_at': clock.now().toUtc().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('device_id', deviceId);
      }
    } catch (e) {
      // Silently fail - this is not critical
      print('Update last active error: $e');
    }
  }

  /// Check if user is currently logged in (Supabase session exists)
  bool get isLoggedIn => _supabase.auth.currentSession != null;

  /// Get current user email
  String? get currentUserEmail => _supabase.auth.currentUser?.email;
}

/// Global auth service instance
final authService = AuthService();
