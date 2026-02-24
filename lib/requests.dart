import "package:dio/dio.dart";
import "package:music_client/core/network/dio_client.dart";
import "package:music_client/requests_format.dart";
import "package:music_client/responces_format.dart";

class AuthApi 
{
  
  Dio _dio = DioClient().dio;

  Future<LoginResponse> login(LoginRequest request) async {
    final response = await _dio.post(
      "http://10.0.2.2:5186/auth/login",
      data: request.toJson(),
    );
    print(response.data);
    return LoginResponse.fromJson(response.data);
  }
}