import 'audio_feature.dart';

class Song {
  final String id;
  final String trackId;
  final String title;
  final String artist;
  final List<String> genre;
  final AudioFeature audioFeature;
  final String s3Url;
  final String? coverUrl;

  const Song({
    required this.id,
    required this.trackId,
    required this.title,
    required this.artist,
    required this.genre,
    required this.audioFeature,
    required this.s3Url,
    this.coverUrl,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id']?.toString() ?? '',
      trackId: json['trackId']?.toString() ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      genre: (json['genre'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      audioFeature: json['audioFeature'] != null
          ? AudioFeature.fromJson(
              Map<String, dynamic>.from(json['audioFeature'] as Map))
          : const AudioFeature(),
      s3Url: json['s3Url'] ?? '',
      coverUrl: json['coverUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trackId': trackId,
        'title': title,
        'artist': artist,
        'genre': genre,
        'audioFeature': audioFeature.toJson(),
        's3Url': s3Url,
        if (coverUrl != null) 'coverUrl': coverUrl,
      };
}

class SongListResponse {
  final List<Song> items;
  final int total;

  const SongListResponse({required this.items, required this.total});

  factory SongListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>?;
    return SongListResponse(
      items: list
              ?.map((e) => Song.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
