import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_client/audio_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:music_client/core/models/playlist_model.dart';
import 'package:music_client/core/network/playlist_repository.dart';
import 'package:music_client/core/providers/auth_provider.dart';
import 'package:share_plus/share_plus.dart';

class Player extends ConsumerWidget {
  const Player({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                          onPressed: () => _showPlayerOptions(context, ref, mediaItem),
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
                        
                        // Progress Bar (position + duration from player so slider works for streams)
                        StreamBuilder<Duration?>(
                          stream: audioHandler.durationStream,
                          builder: (context, durSnapshot) {
                            final duration = durSnapshot.data ?? mediaItem.duration ?? Duration.zero;
                            return StreamBuilder<Duration>(
                              stream: audioHandler.positionStream,
                              builder: (context, posSnapshot) {
                                final position = posSnapshot.data ?? Duration.zero;
                                final clampedPosition = duration.inMilliseconds > 0
                                    ? (position > duration ? duration : position)
                                    : position;

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
                                            (duration.inMilliseconds).toDouble().clamp(1.0, double.infinity),
                                          ),
                                          max: (duration.inMilliseconds).toDouble().clamp(1.0, double.infinity),
                                          onChanged: duration.inMilliseconds > 0
                                              ? (value) {
                                                  audioHandler.seek(Duration(milliseconds: value.toInt()));
                                                }
                                              : null,
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
  
  static void _showPlayerOptions(BuildContext context, WidgetRef ref, MediaItem mediaItem) {
    final trackId = mediaItem.extras?['trackId']?.toString();
    final authState = ref.read(authProvider);
    final isAuthenticated = authState.status == AuthStatus.authenticated;
    final playlistRepo = PlaylistRepository();
    final handler = AppAudioHandler.instance;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                mediaItem.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (isAuthenticated && trackId != null && trackId.isNotEmpty) ...[
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.white70),
                title: const Text('Add to playlist', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  _showAddToPlaylistSheet(context, ref, trackId, playlistRepo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite_border, color: Colors.white70),
                title: const Text('Like', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _addToLikedPlaylist(context, ref, trackId, playlistRepo);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: Colors.white70),
              title: const Text('Remove from queue', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await handler.removeCurrentFromQueue();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Removed from queue'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white70),
              title: const Text('Share', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await Share.share(
                  'Check out "${mediaItem.title}" by ${mediaItem.artist ?? "Unknown"} on EchoNova!',
                  subject: mediaItem.title,
                );
              },
            ),
            if (!isAuthenticated)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Sign in to add to playlist or like',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static void _showAddToPlaylistSheet(
    BuildContext context,
    WidgetRef ref,
    String trackId,
    PlaylistRepository playlistRepo,
  ) async {
    List<Playlist> playlists;
    try {
      playlists = await playlistRepo.list();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load playlists: $e'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a playlist first in Library'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final chosen = await showModalBottomSheet<Playlist>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Add to playlist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
            ...playlists.map((p) => ListTile(
              leading: const Icon(Icons.playlist_play, color: Colors.white70),
              title: Text(p.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('${p.tracksId.length} tracks', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              onTap: () => Navigator.pop(ctx, p),
            )),
          ],
        ),
      ),
    );
    if (chosen != null && context.mounted) {
      try {
        await playlistRepo.addTracks(chosen.id, [trackId]);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added to ${chosen.name}'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  static Future<void> _addToLikedPlaylist(
    BuildContext context,
    WidgetRef ref,
    String trackId,
    PlaylistRepository playlistRepo,
  ) async {
    try {
      final playlists = await playlistRepo.list();
      Playlist? liked;
      try {
        liked = playlists.firstWhere((p) => p.name == 'Liked');
      } catch (_) {}
      if (liked == null) {
        liked = await playlistRepo.create(CreatePlaylistRequest(name: 'Liked'));
      }
      await playlistRepo.addTracks(liked.id, [trackId]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to Liked'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
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
