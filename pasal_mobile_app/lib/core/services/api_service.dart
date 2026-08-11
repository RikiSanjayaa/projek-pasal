import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env.dart';

class ApiService {
  ApiService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String tokenKey = 'mobile_api_token';
  static const String deviceIdKey = 'device_id';

  static final Dio dio =
      Dio(
          BaseOptions(
            baseUrl: Env.apiBaseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 60),
            headers: {'Accept': 'application/json'},
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await _storage.read(key: tokenKey);
              final deviceId = await _storage.read(key: deviceIdKey);
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              if (deviceId != null && deviceId.isNotEmpty) {
                options.headers['X-Device-ID'] = deviceId;
              }
              handler.next(options);
            },
          ),
        );

  static Future<void> setToken(String token) {
    return _storage.write(key: tokenKey, value: token);
  }

  static Future<String?> getToken() {
    return _storage.read(key: tokenKey);
  }

  static Future<void> clearToken() {
    return _storage.delete(key: tokenKey);
  }

  static String messageFromError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final statusCode = error.response?.statusCode;
      final server = error.response?.headers.value('server') ?? '';
      final mitigated = error.response?.headers.value('cf-mitigated') ?? '';
      final isHtmlResponse = data is String &&
          (data.contains('<!DOCTYPE html') || data.contains('<html'));
      final isCloudflareBlock =
          server.toLowerCase().contains('cloudflare') ||
          mitigated.isNotEmpty ||
          (data is String && data.toLowerCase().contains('cloudflare'));

      if (statusCode == 403 && (isCloudflareBlock || isHtmlResponse)) {
        return 'Akses ke server sedang diblokir proteksi keamanan. Hubungi admin server untuk membuka akses API aplikasi mobile.';
      }
      final rawError = error.error?.toString().toLowerCase() ?? '';
      final message = error.message?.toLowerCase() ?? '';
      if (error.type == DioExceptionType.badCertificate ||
          rawError.contains('certificate_verify_failed') ||
          rawError.contains('handshake') ||
          message.contains('certificate_verify_failed') ||
          message.contains('handshake')) {
        return 'Sertifikat HTTPS server tidak valid atau belum dipercaya perangkat. Hubungi admin server untuk memperbaiki SSL domain API.';
      }
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      if (data is Map && data['errors'] is Map) {
        final errors = data['errors'] as Map;
        if (errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Tidak dapat terhubung ke server.';
      }
    }
    return error.toString();
  }
}
