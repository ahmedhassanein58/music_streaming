// auth_interceptor.dart
import 'package:dio/dio.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  final TokenStorage _storage = TokenStorage();

  @override
  void onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler) async {

    final token = await _storage.getToken();

    if (token != null) {
      options.headers["Authorization"] = "Bearer $token";
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {

    if (err.response?.statusCode == 401) {
      // Token expired or invalid
      await _storage.clear();
      // TODO: navigate to login
    }

    return handler.next(err);
  }
}