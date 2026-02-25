class HistoryItem {
  final String id;
  final String userId;
  final String trackId;
  final int playCount;
  final DateTime? lastPlayed;
  final String? title;
  final String? artist;

  const HistoryItem({
    required this.id,
    required this.userId,
    required this.trackId,
    required this.playCount,
    this.lastPlayed,
    this.title,
    this.artist,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? lastPlayed;
    final last = json['lastPlayed'];
    if (last != null) {
      if (last is String) {
        lastPlayed = DateTime.tryParse(last);
      }
    }
    return HistoryItem(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      trackId: json['trackId']?.toString() ?? '',
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      lastPlayed: lastPlayed,
      title: json['title']?.toString(),
      artist: json['artist']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'trackId': trackId,
        'playCount': playCount,
        'lastPlayed': lastPlayed?.toIso8601String(),
        if (title != null) 'title': title,
        if (artist != null) 'artist': artist,
      };
}

class RecordPlayRequest {
  final String trackId;

  RecordPlayRequest({required this.trackId});

  Map<String, dynamic> toJson() => {'trackId': trackId};
}
