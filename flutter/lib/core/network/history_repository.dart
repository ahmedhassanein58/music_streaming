import 'package:dio/dio.dart';
import '../models/history_model.dart';
import 'dio_client.dart';

class HistoryRepository {
  final Dio _dio = DioClient().dio;

  Future<List<HistoryItem>> list() async {
    try {
      final response = await _dio.get<List<dynamic>>('/history');
      final list = response.data;
      if (list == null) return [];
      return list
          .map((e) =>
              HistoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Record a play (POST or PUT /history with body { trackId }).
  Future<void> recordPlay(String trackId) async {
    try {
      await _dio.put(
        '/history',
        data: RecordPlayRequest(trackId: trackId).toJson(),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Check your server.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot connect to server at ${DioClient.baseUrl}. Is the backend running?';
    }
    if (e.response != null) {
      return e.response?.data?['message']?.toString() ??
          'Server error: ${e.response?.statusCode}';
    }
    return 'Network error: ${e.message}';
  }
}
