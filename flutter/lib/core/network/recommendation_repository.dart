import 'package:dio/dio.dart';
import '../models/song_model.dart';
import 'dio_client.dart';

class RecommendationRepository {
  final Dio _dio = DioClient().dio;

  /// GET /recommendations/suggested - personalized suggestions from most played history.
  /// Requires authentication. Returns empty list on 401 or error.
  Future<List<Song>> getSuggested() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/recommendations/suggested');
      final data = response.data;
      if (data == null) return [];
      final items = data['items'] as List<dynamic>?;
      if (items == null) return [];
      return items
          .map((e) => Song.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return [];
      return [];
    } catch (_) {
      return [];
    }
  }
}
