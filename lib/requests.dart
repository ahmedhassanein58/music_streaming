import "package:music_client/requests_format.dart";
import "package:dio/dio.dart";

final dio = Dio();
Future<void> login(LoginRequest request) async {
  final response = await dio.post(
    "http://10.0.2.2:5186/auth/login",
    data: request.toJson(),
  );
  print(response.data);
}