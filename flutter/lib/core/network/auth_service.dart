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
      if (e.response?.statusCode == 403 &&
          e.response?.data?['code'] == 'EMAIL_NOT_VERIFIED') {
        throw EmailNotVerifiedException(
          e.response?.data?['message']?.toString() ??
              'Verify your email with the OTP we sent.',
        );
      }
      throw _handleError(e);
    }
  }

  Future<SignupResponse> signup(SignupRequest request) async {
    try {
      final response = await _dio.post(
        "/auth/signup",
        data: request.toJson(),
      );
      return SignupResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthResponse> verifyOtp(String email, String otp) async {
    try {
      final response = await _dio.post(
        "/auth/verify-otp",
        data: {"email": email, "otp": otp},
      );
      final authResponse = AuthResponse.fromJson(response.data);
      await _storage.saveToken(authResponse.token);
      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> resendOtp(String email) async {
    try {
      await _dio.post(
        "/auth/send-otp",
        data: {"email": email},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    await _storage.clear();
  }

  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return "Connection timed out. Check your server.";
    }
    if (e.type == DioExceptionType.connectionError) {
      return "Cannot connect to server at ${DioClient.baseUrl}. Is the backend running?";
    }
    if (e.response != null) {
      return e.response?.data?['message']?.toString() ??
          "Server error: ${e.response?.statusCode}";
    }
    return "Network error: ${e.message}";
  }
}
