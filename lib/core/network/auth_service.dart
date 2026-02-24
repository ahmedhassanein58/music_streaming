import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import 'dio_client.dart';
import '../models/auth_models.dart';

class AuthService {
  final Dio _dio = DioClient().dio;
  final TokenStorage _storage = TokenStorage();

  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        "/auth/login",
        data: request.toJson(),
      );
      final authResponse = AuthResponse.fromJson(response.data);
      await _storage.saveToken(authResponse.token);
      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthResponse> signup(SignupRequest request) async {
    try {
      final response = await _dio.post(
        "/auth/signup",
        data: request.toJson(),
      );
      final authResponse = AuthResponse.fromJson(response.data);
      await _storage.saveToken(authResponse.token);
      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    await _storage.clear();
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      return e.response?.data["message"] ?? "An error occurred";
    }
    return "Network error";
  }
}
