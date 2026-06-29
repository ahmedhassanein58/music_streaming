import 'package:dio/dio.dart';
import '../models/song_model.dart';
import 'dio_client.dart';

class MoodWeight {
  final String emotion;
  final double weight;

  MoodWeight({required this.emotion, required this.weight});

  factory MoodWeight.fromJson(Map<String, dynamic> json) {
    return MoodWeight(
      emotion: json['emotion']?.toString() ?? 'neutral',
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
    );
  }
}

class EmotionScanResult {
  final String emotion;
  final double confidence;
  final List<MoodWeight> moodMix;
  final List<String> mappedGenres;
  final Map<String, double> probabilities;
  final List<Song> recommendations;

  EmotionScanResult({
    required this.emotion,
    required this.confidence,
    required this.moodMix,
    required this.mappedGenres,
    required this.probabilities,
    required this.recommendations,
  });

  factory EmotionScanResult.fromJson(Map<String, dynamic> json) {
    final probsRaw = json['probabilities'] as Map<String, dynamic>? ?? {};
    final probs = probsRaw.map((k, v) => MapEntry(k, (v as num).toDouble()));

    final recs = (json['recommendations'] as List<dynamic>? ?? [])
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();

    final mix = (json['moodMix'] as List<dynamic>? ?? [])
        .map((e) => MoodWeight.fromJson(e as Map<String, dynamic>))
        .toList();

    return EmotionScanResult(
      emotion: json['emotion']?.toString() ?? 'neutral',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      moodMix: mix,
      mappedGenres: (json['mappedGenres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      probabilities: probs,
      recommendations: recs,
    );
  }
}

class EmotionRepository {
  final Dio _dio = DioClient().dio;

  Future<EmotionScanResult> scanMood(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(
        '/emotion/scan',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return EmotionScanResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response != null) {
        throw e.response?.data?['message']?.toString() ??
            e.response?.data?['detail']?.toString() ??
            'Emotion scan failed';
      }
      final msg = e.message ?? 'Unknown network error';
      if (msg.contains('connection') || msg.contains('Connection')) {
        throw 'Cannot reach backend at ${DioClient.baseUrl}. Is the .NET API running?';
      }
      throw 'Network error: $msg';
    }
  }
}
