import 'package:dio/dio.dart';
import '../models/playlist_model.dart';
import 'dio_client.dart';

class PlaylistRepository {
  final Dio _dio = DioClient().dio;

  Future<List<Playlist>> list() async {
    try {
      final response = await _dio.get<List<dynamic>>('/playlists');
      final list = response.data;
      if (list == null) return [];
      return list
          .map((e) => Playlist.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Playlist> get(String playlistId) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/playlists/$playlistId');
      return Playlist.fromJson(Map<String, dynamic>.from(response.data ?? {}));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Playlist> create(CreatePlaylistRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/playlists',
        data: request.toJson(),
      );
      return Playlist.fromJson(Map<String, dynamic>.from(response.data ?? {}));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Playlist> update(String playlistId, UpdatePlaylistRequest request) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/playlists/$playlistId',
        data: request.toJson(),
      );
      return Playlist.fromJson(Map<String, dynamic>.from(response.data ?? {}));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> delete(String playlistId) async {
    try {
      await _dio.delete('/playlists/$playlistId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Playlist> addTracks(String playlistId, List<String> trackIds) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/playlists/$playlistId/tracks',
        data: AddTracksRequest(trackIds: trackIds).toJson(),
      );
      return Playlist.fromJson(Map<String, dynamic>.from(response.data ?? {}));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Playlist> removeTrack(String playlistId, String trackId) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/playlists/$playlistId/tracks/$trackId',
      );
      return Playlist.fromJson(Map<String, dynamic>.from(response.data ?? {}));
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
