import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'auth_interceptor.dart';

class DioClient {
  static String get baseUrl {
    // For Android Emulator, 10.0.2.2 points to host's localhost
    if (!kIsWeb && Platform.isAndroid) return "http://10.0.2.2:5186";
    // For Windows, iOS, Web, etc.
    return "http://localhost:5186";
  }

  late Dio dio;

  factory DioClient() => DioClient._internal();

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(AuthInterceptor());
    
    // Add logging to identify exact connection parameters being used
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
      logPrint: (obj) => debugPrint('Dio: $obj'),
    ));
  }
}