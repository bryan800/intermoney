import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();

  // Base URL for your secure backend
  static const String baseUrl = 'https://api.interflex.com/v1';

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // Adding Interceptors for Security
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add JWT token to every request
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // Anti-tampering headers. Production builds should derive this from a
        // hardware-backed device key enrolled during onboarding.
        options.headers['X-Device-Id'] = 'TRUSTED_DEVICE_FINGERPRINT';
        options.headers['X-App-Version'] = '1.0.0';
        options.headers['X-Request-Id'] =
            DateTime.now().microsecondsSinceEpoch.toString();

        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Handle session expiration (401)
        if (e.response?.statusCode == 401) {
          // Trigger logout or refresh token logic
        }
        return handler.next(e);
      },
    ));

    // Note: SSL Pinning should be implemented here using a custom HttpClientAdapter
  }

  Future<Response> securePost(String path, dynamic data) async {
    try {
      return await _dio.post(path, data: data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> secureGet(String path) async {
    try {
      return await _dio.get(path);
    } catch (e) {
      rethrow;
    }
  }
}
