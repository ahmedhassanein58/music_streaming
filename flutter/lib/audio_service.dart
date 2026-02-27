import "dart:async";
import "package:audio_service/audio_service.dart";
import "package:just_audio/just_audio.dart";
import "package:audio_session/audio_session.dart";

class AppAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  static AppAudioHandler? _instance;
  final _player = AudioPlayer();
  final List<MediaItem> _queue = [];
  int _currentIndex = -1;

  static AppAudioHandler get instance {
    if (_instance == null) {
      throw StateError("AppAudioHandler not initialized");
    }
    return _instance!;
  }

  static Future<AppAudioHandler> init() async {
    if (_instance != null) return _instance!;

    final handler = await AudioService.init(
      builder: () => AppAudioHandler._internal(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.echonova.musicplayer.channel.audio',
        androidNotificationChannelName: 'Music playback',
      ),
    );
    _instance = handler;
    return _instance!;
  }
  
  AppAudioHandler._internal() {
    _init();
    // Broadcast state on events (buffering, error, etc)
    _player.playbackEventStream.listen(_broadcastState, onError: (Object e, StackTrace stackTrace) {
      // print('Audio Player Error: $e');
    });
    // Also broadcast on play/pause state changes
    _player.playerStateStream.listen((state) {
      _broadcastState();
    });
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            _player.pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            _player.play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });

    session.becomingNoisyEventStream.listen((_) {
      _player.pause();
    });
  }
  
  void _broadcastState([PlaybackEvent? event]) {
    final playing = _player.playing;
    final queueIndex = _currentIndex >= 0 ? _currentIndex : null;
    
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: queueIndex,
    ));
  }

  Future<void> _playFromQueueIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    final item = _queue[_currentIndex];
    mediaItem.add(item);
    await _player.stop();
    await _player.setUrl(item.id);
    await _player.play();
    _broadcastState();
  }

  /// Stream of current track duration (for progress bar when MediaItem.duration is null).
  Stream<Duration?> get durationStream => _player.durationStream;
  /// Current position (for progress bar).
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Future<void> play() => _player.play();
  
  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_currentIndex + 1 < _queue.length) {
      await _playFromQueueIndex(_currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentIndex - 1 >= 0 && _queue.isNotEmpty) {
      await _playFromQueueIndex(_currentIndex - 1);
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
    _currentIndex = -1;
    _queue.clear();
    queue.add(const []);
    mediaItem.add(null);
    _broadcastState();
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    _queue
      ..clear()
      ..add(mediaItem);
    queue.add(List.unmodifiable(_queue));
    await _playFromQueueIndex(0);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    _queue.add(mediaItem);
    queue.add(List.unmodifiable(_queue));
    if (_currentIndex == -1 && _queue.isNotEmpty) {
      await _playFromQueueIndex(0);
    } else {
      _broadcastState();
    }
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    _queue.addAll(mediaItems);
    queue.add(List.unmodifiable(_queue));
    if (_currentIndex == -1 && _queue.isNotEmpty) {
      await _playFromQueueIndex(0);
    } else {
      _broadcastState();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _playFromQueueIndex(index);
  }

  /// Remove the currently playing item from the queue. Plays next if available.
  Future<void> removeCurrentFromQueue() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    _queue.removeAt(_currentIndex);
    if (_queue.isEmpty) {
      await stop();
      return;
    }
    if (_currentIndex >= _queue.length) _currentIndex = _queue.length - 1;
    queue.add(List.unmodifiable(_queue));
    await _playFromQueueIndex(_currentIndex);
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await super.onTaskRemoved();
  }
}