import 'dart:io';
import 'package:dio/dio.dart';
import 'auth_interceptor.dart';

class DioClient {
  static String get baseUrl {
    if (Platform.isAndroid) return "http://10.0.2.2:5186";
    return "http://localhost:5186";
  }

  late Dio dio;

  factory DioClient() => DioClient._internal();

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(AuthInterceptor());
  }
}