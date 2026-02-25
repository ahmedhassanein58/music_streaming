// auth_interceptor.dart
import 'package:dio/dio.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  final TokenStorage _storage = TokenStorage();

  /// Set from main to redirect to login when the backend returns 401.
  static void Function()? onUnauthorized;

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
      await _storage.clear();
      onUnauthorized?.call();
    }

    return handler.next(err);
  }
}