import 'package:dio/dio.dart';
import 'dio_client.dart';
import '../models/user_model.dart';

class UserRepository {
  final Dio _dio = DioClient().dio;

  Future<User> getCurrentUser() async {
    try {
      final response = await _dio.get("/users/me");
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<User> updateUser(UpdateMeRequest request) async {
    try {
      final response = await _dio.patch(
        "/users/me",
        data: request.toJson(),
      );
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      return e.response?.data["message"] ?? "An error occurred";
    }
    return "Network error";
  }
}
