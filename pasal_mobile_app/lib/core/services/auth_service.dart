import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../utils/platform_utils.dart';

// Platform detection helper
bool get isAndroid => !kIsWeb && Platform.isAndroid;
bool get isIOS => !kIsWeb && Platform.isIOS;
bool get isWeb => kIsWeb;

/// Authentication state enum
enum AuthState { unknown, authenticated, unauthenticated, expired }

/// Result type for expiry check
enum ExpiryCheckResult { valid, expired, noData }

/// Result type for active status verification
enum ActiveStatusResult { active, inactive, expired, error }

/// Reason for forced logout/deactivation
enum DeactivationReason {
  none,
  accountInactive,
  accountExpired,
  accountDeleted,
}

/// Result type for login
enum LoginResultType { success, successAdmin, failure, expired, deviceConflict }

/// Login result class
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
  static const String _isAdminKey = 'is_admin';

  // Notifiers for UI
  final ValueNotifier<AuthState> state = ValueNotifier(AuthState.unknown);
  final ValueNotifier<int?> daysUntilExpiry = ValueNotifier(null);
  final ValueNotifier<String?> userName = ValueNotifier(null);
  final ValueNotifier<bool> isAdmin = ValueNotifier(false);
  final ValueNotifier<DeactivationReason> deactivationReason = ValueNotifier(
    DeactivationReason.none,
  );

  /// Initialize auth service - call on app startup
  Future<void> initialize() async {
    // Load user name and admin status from storage for display
    final name = await _secureStorage.read(key: _userNameKey);
    userName.value = name;
    final adminFlag = await _secureStorage.read(key: _isAdminKey);
    isAdmin.value = adminFlag == 'true';
  }

  /// Get hardware-based device ID
  /// Uses Android ID or iOS identifierForVendor for consistency across app reinstalls/data clears
  /// Falls back to generated UUID only if hardware ID is unavailable
  Future<String> getDeviceId() async {
    // First check if we have a cached device ID
    String? deviceId = await _secureStorage.read(key: _deviceIdKey);
    if (deviceId != null) {
      return deviceId;
    }

    // Get hardware-based device ID
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (isWeb) {
        // For web, use browser fingerprinting via device_info_plus
        final info = await deviceInfo.webBrowserInfo;
        deviceId = '${info.browserName.name}_${info.userAgent?.hashCode ?? 0}';
      } else if (isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceId = info.id; // Android ID - persists across app data clears
      } else if (isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceId = info
            .identifierForVendor; // Vendor ID - persists while app is installed
      }
    } catch (e) {
      print('Error getting hardware device ID: $e');
    }

    // Fallback to UUID if hardware ID is unavailable
    deviceId ??= const Uuid().v4();

    // Cache the device ID for faster access
    await _secureStorage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  /// Get human-readable device name
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
        // User not in users table - check if they're an admin
        final adminProfile = await _supabase
            .from('admin_users')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (adminProfile == null) {
          // Not in either table
          await _supabase.auth.signOut();
          return LoginResult.failure(
            'Akun tidak ditemukan. Hubungi administrator.',
          );
        }

        // Check if admin is active
        if (adminProfile['is_active'] != true) {
          await _supabase.auth.signOut();
          return LoginResult.failure(
            'Akun admin tidak aktif. Hubungi super administrator.',
          );
        }

        // Admin login successful - no device binding or expiry for admins
        await _secureStorage.write(key: _userEmailKey, value: email);
        await _secureStorage.write(
          key: _userNameKey,
          value: adminProfile['nama'] ?? email,
        );
        await _secureStorage.write(key: _isAdminKey, value: 'true');

        userName.value = adminProfile['nama'] ?? email;
        isAdmin.value = true;
        daysUntilExpiry.value = null; // Admins don't expire
        state.value = AuthState.authenticated;

        return LoginResult.successAdmin();
      }

      // 3. Check if user is active
      if (userProfile['is_active'] != true) {
        await _supabase.auth.signOut();
        return LoginResult.failure('Akun tidak aktif. Hubungi administrator.');
      }

      // 4. Check if user is expired
      final expiresAt = DateTime.parse(userProfile['expires_at']);
      if (expiresAt.isBefore(clock.now())) {
        await _supabase.auth.signOut();
        return LoginResult.expired(
          'Akun telah kadaluarsa. Hubungi administrator untuk memperpanjang.',
        );
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
            'atau hubungi administrator jika perangkat hilang.',
          );
        }
      }

      // 6. Register/update this device
      final deviceName = await getDeviceName();
      await _supabase.from('user_devices').upsert({
        'user_id': userId,
        'device_id': deviceId,
        'device_name': deviceName,
        'is_active': true,
        'last_active_at': clock.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,device_id');

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
      await _secureStorage.write(key: _isAdminKey, value: 'false');

      // 8. Update state
      userName.value = userProfile['nama'] ?? email;
      isAdmin.value = false;
      _updateExpiryState(expiresAt);
      state.value = AuthState.authenticated;

      return LoginResult.success();
    } on AuthException catch (e) {
      return LoginResult.failure(
        e.message.contains('Invalid login')
            ? 'Email atau password salah.'
            : e.message,
      );
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
  /// Admins never expire, so they always return valid
  Future<ExpiryCheckResult> checkExpiryOffline() async {
    // Check if user is admin - admins don't expire
    final adminFlag = await _secureStorage.read(key: _isAdminKey);
    if (adminFlag == 'true') {
      isAdmin.value = true;
      state.value = AuthState.authenticated;
      return ExpiryCheckResult.valid;
    }

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
      final userId = _supabase.auth.currentUser?.id;

      // Deactivate device on server (only for regular users, not admins)
      if (userId != null && !isAdmin.value) {
        final deviceId = await getDeviceId();
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
    isAdmin.value = false;
  }

  /// Clear local auth data
  Future<void> _clearLocalAuth() async {
    await _secureStorage.delete(key: _expiresAtKey);
    await _secureStorage.delete(key: _userEmailKey);
    await _secureStorage.delete(key: _userNameKey);
    await _secureStorage.delete(key: _isAdminKey);
    // Note: We keep device_id as it's device-specific, not user-specific
  }

  /// Update last active timestamp (call periodically or on app resume)
  /// Skipped for admins since they don't have device records
  Future<void> updateLastActive() async {
    // Skip for admins - they don't have device records
    if (isAdmin.value) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      final deviceId = await getDeviceId();

      if (userId != null) {
        await _supabase
            .from('user_devices')
            .update({'last_active_at': clock.now().toUtc().toIso8601String()})
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

  /// Clear the deactivation reason (call after showing message to user)
  void clearDeactivationReason() {
    deactivationReason.value = DeactivationReason.none;
  }

  /// Get user-friendly message for deactivation reason
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
    }
  }

  /// Verify if the current user's account is still active on the server
  /// Call this before sync or on app resume to detect deactivated accounts
  /// Returns [ActiveStatusResult] indicating the account status
  /// If inactive/expired, automatically logs out the user
  Future<ActiveStatusResult> verifyActiveStatus() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return ActiveStatusResult.error;
    }

    try {
      if (isAdmin.value) {
        // Check admin_users table for admins
        final adminProfile = await _supabase
            .from('admin_users')
            .select('is_active')
            .eq('id', userId)
            .maybeSingle();

        if (adminProfile == null) {
          // Admin record deleted
          deactivationReason.value = DeactivationReason.accountDeleted;
          await logout();
          return ActiveStatusResult.inactive;
        }

        if (adminProfile['is_active'] != true) {
          deactivationReason.value = DeactivationReason.accountInactive;
          await logout();
          return ActiveStatusResult.inactive;
        }

        return ActiveStatusResult.active;
      } else {
        // Check users table for regular users
        final userProfile = await _supabase
            .from('users')
            .select('is_active, expires_at')
            .eq('id', userId)
            .maybeSingle();

        if (userProfile == null) {
          // User record deleted
          deactivationReason.value = DeactivationReason.accountDeleted;
          await logout();
          return ActiveStatusResult.inactive;
        }

        if (userProfile['is_active'] != true) {
          deactivationReason.value = DeactivationReason.accountInactive;
          await logout();
          return ActiveStatusResult.inactive;
        }

        // Check expiry for regular users
        final expiresAt = DateTime.parse(userProfile['expires_at']);
        if (expiresAt.isBefore(clock.now())) {
          deactivationReason.value = DeactivationReason.accountExpired;
          await logout();
          state.value = AuthState.expired;
          return ActiveStatusResult.expired;
        }

        // Update local expiry data
        await _secureStorage.write(
          key: _expiresAtKey,
          value: expiresAt.toIso8601String(),
        );
        _updateExpiryState(expiresAt);

        return ActiveStatusResult.active;
      }
    } catch (e) {
      print('Error verifying active status: $e');
      return ActiveStatusResult.error;
    }
  }
}

/// Global auth service instance
final authService = AuthService();
