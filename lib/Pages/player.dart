import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_client/audio_service.dart';
import 'package:audio_service/audio_service.dart';

class Player extends StatelessWidget {
  const Player({super.key});

  @override
  Widget build(BuildContext context) {
    final audioHandler = AppAudioHandler.instance;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF020617),
              Color(0xFF020617),
            ],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<MediaItem?>(
            stream: audioHandler.mediaItem,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        "No song playing",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              final mediaItem = snapshot.data!;
              
              return Column(
                children: [
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          onPressed: () => context.pop(),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Album Art with shadow
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.4),
                                blurRadius: 40,
                                spreadRadius: 2,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.network(
                              mediaItem.artUri?.toString() ?? '',
                              width: double.infinity,
                              height: 350,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: double.infinity,
                                  height: 350,
                                  color: const Color(0xFF020617),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: double.infinity,
                                  height: 350,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.blue[700]!,
                                        Colors.indigo[900]!,
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.music_note,
                                    size: 120,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Song Info
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Column(
                            children: [
                              Text(
                                mediaItem.title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              if (mediaItem.artist != null)
                                Text(
                                  mediaItem.artist!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[400],
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Progress Bar
                        StreamBuilder<Duration>(
                          stream: AudioService.position,
                          builder: (context, snapshot) {
                            final position = snapshot.data ?? Duration.zero;
                            final duration = mediaItem.duration ?? Duration.zero;
                            
                            // Clamp position to duration to prevent overflow visuals
                            final clampedPosition = position > duration ? duration : position;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0),
                              child: Column(
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 8,
                                      ),
                                      activeTrackColor: Theme.of(context).colorScheme.primary,
                                      inactiveTrackColor: Colors.grey[700],
                                      thumbColor: Theme.of(context).colorScheme.primary,
                                    ),
                                    child: Slider(
                                      value: clampedPosition.inMilliseconds.toDouble().clamp(
                                        0.0,
                                        duration.inMilliseconds.toDouble(),
                                      ),
                                      max: duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                                      onChanged: (value) {
                                        audioHandler.seek(Duration(milliseconds: value.toInt()));
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(clampedPosition),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(duration),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Playback Controls
                        StreamBuilder<PlaybackState>(
                          stream: audioHandler.playbackState,
                          builder: (context, playbackSnapshot) {
                            final isPlaying = playbackSnapshot.data?.playing ?? false;
                            
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _ControlButton(
                                  icon: Icons.skip_previous,
                                  size: 40,
                                  onPressed: () => audioHandler.skipToPrevious(),
                                ),
                                const SizedBox(width: 24),
                                _ControlButton(
                                  icon: isPlaying ? Icons.pause : Icons.play_arrow,
                                  size: 64,
                                  isPrimary: true,
                                  onPressed: () {
                                    if (isPlaying) {
                                      audioHandler.pause();
                                    } else {
                                      audioHandler.play();
                                    }
                                  },
                                ),
                                const SizedBox(width: 24),
                                _ControlButton(
                                  icon: Icons.skip_next,
                                  size: 40,
                                  onPressed: () => audioHandler.skipToNext(),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.size,
    this.isPrimary = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isPrimary
          ? BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: IconButton(
        icon: Icon(icon),
        iconSize: size,
        color: isPrimary ? Colors.white : null,
        onPressed: onPressed,
      ),
    );
  }
}
