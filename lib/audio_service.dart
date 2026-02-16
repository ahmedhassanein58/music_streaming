import "package:audio_service/audio_service.dart";
import "package:just_audio/just_audio.dart";

class AppAudioHandler extends BaseAudioHandler 
{
  final _player = AudioPlayer();
  
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToQueueItem(int index) => _player.seek(Duration.zero, index: index);

  @override
  Future<void> playMediaItem(MediaItem item) async
  {
    this.mediaItem.add(item);
    await _player.setUrl(item.id);
    await _player.play();
  }

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) async {
    await _player.setUrl(uri.toString());
    await _player.play();
  }
}