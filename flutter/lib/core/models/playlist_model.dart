class Playlist {
  final String id;
  final String userId;
  final String name;
  final List<String> tracksId;

  const Playlist({
    required this.id,
    required this.userId,
    required this.name,
    required this.tracksId,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      name: json['name'] ?? '',
      tracksId: (json['tracksId'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'tracksId': tracksId,
      };
}

class CreatePlaylistRequest {
  final String name;
  final List<String>? tracksId;

  CreatePlaylistRequest({required this.name, this.tracksId});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'name': name};
    if (tracksId != null) map['tracksId'] = tracksId;
    return map;
  }
}

class UpdatePlaylistRequest {
  final String? name;
  final List<String>? tracksId;

  UpdatePlaylistRequest({this.name, this.tracksId});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (tracksId != null) map['tracksId'] = tracksId;
    return map;
  }
}

class AddTracksRequest {
  final List<String> trackIds;

  AddTracksRequest({required this.trackIds});

  Map<String, dynamic> toJson() => {'trackIds': trackIds};
}
