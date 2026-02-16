import 'package:audio_service/audio_service.dart';
import 'package:music_client/audio_service.dart';

class AudioServiceManager
{
  static late AudioHandler _audioHandler;
  static Future<void> init() async 
  {
    _audioHandler = await AudioService.init(
      builder: () => AppAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.echonova.musicplayer.channel.audio',
        androidNotificationChannelName: 'Music playback',
      )
    );
  }
}