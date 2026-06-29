import 'package:audio_service/audio_service.dart';
import 'song_model.dart';

extension SongPlayback on Song {
  Uri? get coverArtUri {
    if (coverUrl == null || coverUrl!.isEmpty) return null;
    return Uri.tryParse(coverUrl!);
  }

  MediaItem toMediaItem() => MediaItem(
        id: s3Url,
        title: title,
        artist: artist,
        album: genre.isNotEmpty ? genre.join(', ') : null,
        artUri: coverArtUri,
        extras: {'trackId': trackId},
      );
}
