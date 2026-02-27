import 'package:dio/dio.dart';
import '../models/song_model.dart';
import 'dio_client.dart';

class SongRepository {
  final Dio _dio = DioClient().dio;

  /// GET /songs with optional genre, search, page, pageSize.
  Future<SongListResponse> list({
    String? genre,
    String? search,
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (genre != null && genre.isNotEmpty) queryParams['genre'] = genre;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get<Map<String, dynamic>>(
        '/songs',
        queryParameters: queryParams,
      );
      return SongListResponse.fromJson(
          Map<String, dynamic>.from(response.data ?? {}));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// GET /songs/{trackId}
  Future<Song> getByTrackId(String trackId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/songs/$trackId');
      return Song.fromJson(Map<String, dynamic>.from(response.data ?? {}));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST /songs/by-ids with body ["829", "7762", ...]. Returns matching songs.
  Future<List<Song>> getByTrackIds(List<String> trackIds) async {
    if (trackIds.isEmpty) return [];
    try {
      final response = await _dio.post<dynamic>(
        '/songs/by-ids',
        data: trackIds,
      );
      final list = response.data as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((e) => Song.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
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
