// dio_client.dart
import 'package:dio/dio.dart';
import 'auth_interceptor.dart';

class DioClient {
  // static final DioClient _instance = DioClient._internal();
  late Dio dio;

  factory DioClient() => DioClient._internal();

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: "http://10.0.2.2:5186",
        connectTimeout: const Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(AuthInterceptor());
  }
}