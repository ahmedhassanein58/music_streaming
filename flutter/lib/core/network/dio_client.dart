import 'package:dio/dio.dart';
import '../config.dart';
import 'auth_interceptor.dart';

class DioClient {
  static String get baseUrl => AppConfig.apiBaseUrl;

  late Dio dio;

  factory DioClient() => DioClient._internal();

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    dio.interceptors.add(AuthInterceptor());
  }
}