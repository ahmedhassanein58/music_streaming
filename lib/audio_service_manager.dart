import 'package:audio_service/audio_service.dart';
import 'package:music_client/audio_service.dart';

class AudioServiceManager {
  static AudioHandler? _audioHandler;

  static AudioHandler get audioHandler {
    if (_audioHandler == null) {
      throw StateError("AudioServiceManager not initialized");
    }
    return _audioHandler!;
  }

  static Future<AudioHandler> init() async {
    if (_audioHandler != null) return _audioHandler!;

    _audioHandler = await AudioService.init(
      builder: () => AppAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.echonova.musicplayer.channel.audio',
        androidNotificationChannelName: 'Music playback',
      ),
    );
    return _audioHandler!;
  }
}
