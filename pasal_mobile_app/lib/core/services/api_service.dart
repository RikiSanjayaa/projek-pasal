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
