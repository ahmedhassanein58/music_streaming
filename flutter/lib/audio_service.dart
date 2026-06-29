import "dart:async";
import "dart:io" show Platform;

import "package:audio_service/audio_service.dart";
import "package:audio_session/audio_session.dart";
import "package:audioplayers/audioplayers.dart" as ap;
import "package:flutter/foundation.dart" show kIsWeb;
import "package:just_audio/just_audio.dart";

class AppAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  static AppAudioHandler? _instance;
  final bool _useLinuxPlayer = !kIsWeb && Platform.isLinux;

  final AudioPlayer? _player = (!kIsWeb && Platform.isLinux) ? null : AudioPlayer();
  ap.AudioPlayer? _linuxPlayer;
  final List<MediaItem> _queue = [];
  int _currentIndex = -1;

  final StreamController<Duration> _linuxPositionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _linuxDurationController =
      StreamController<Duration?>.broadcast();
  Duration _linuxPosition = Duration.zero;
  Duration? _linuxDuration;
  bool _linuxPlaying = false;

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
    if (_useLinuxPlayer) {
      _linuxPlayer = ap.AudioPlayer();
      _linuxPlayer!.onPositionChanged.listen((position) {
        _linuxPosition = position;
        _linuxPositionController.add(position);
        _broadcastState();
      });
      _linuxPlayer!.onDurationChanged.listen((duration) {
        _linuxDuration = duration;
        _linuxDurationController.add(duration);
      });
      _linuxPlayer!.onPlayerStateChanged.listen((state) {
        _linuxPlaying = state == ap.PlayerState.playing;
        _broadcastState();
      });
    } else {
      _player!.playbackEventStream.listen(_broadcastState, onError: (_, __) {});
      _player!.playerStateStream.listen((_) => _broadcastState());
    }
    _initSession();
  }

  Future<void> _initSession() async {
    if (kIsWeb || Platform.isLinux || Platform.isWindows) return;

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      // Optional on desktop/web.
    }
  }

  void _broadcastState([PlaybackEvent? event]) {
    if (_useLinuxPlayer) {
      final queueIndex = _currentIndex >= 0 ? _currentIndex : null;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (_linuxPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: _linuxPlaying
            ? AudioProcessingState.ready
            : AudioProcessingState.idle,
        playing: _linuxPlaying,
        updatePosition: _linuxPosition,
        bufferedPosition: _linuxDuration ?? Duration.zero,
        speed: 1.0,
        queueIndex: queueIndex,
      ));
      return;
    }

    final playing = _player!.playing;
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
      }[_player!.processingState]!,
      playing: playing,
      updatePosition: _player!.position,
      bufferedPosition: _player!.bufferedPosition,
      speed: _player!.speed,
      queueIndex: queueIndex,
    ));
  }

  Future<void> _playFromQueueIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    final item = _queue[_currentIndex];
    mediaItem.add(item);

    if (_useLinuxPlayer) {
      await _linuxPlayer!.stop();
      await _linuxPlayer!.play(ap.UrlSource(item.id));
      _broadcastState();
      return;
    }

    await _player!.stop();
    await _player!.setUrl(item.id);
    await _player!.play();
    _broadcastState();
  }

  Stream<Duration?> get durationStream =>
      _useLinuxPlayer ? _linuxDurationController.stream : _player!.durationStream;

  Stream<Duration> get positionStream =>
      _useLinuxPlayer ? _linuxPositionController.stream : _player!.positionStream;

  @override
  Future<void> play() async {
    if (_useLinuxPlayer) {
      await _linuxPlayer!.resume();
    } else {
      await _player!.play();
    }
  }

  @override
  Future<void> pause() async {
    if (_useLinuxPlayer) {
      await _linuxPlayer!.pause();
    } else {
      await _player!.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_useLinuxPlayer) {
      await _linuxPlayer!.seek(position);
    } else {
      await _player!.seek(position);
    }
  }

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
    if (_useLinuxPlayer) {
      await _linuxPlayer!.stop();
      _linuxPosition = Duration.zero;
      _linuxDuration = null;
      _linuxPlaying = false;
    } else {
      await _player!.stop();
      await _player!.seek(Duration.zero);
    }
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
