import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:music_client/audio_service.dart';
import 'package:audio_service/audio_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/Pages/profile_drawer.dart';
import 'package:music_client/core/providers/auth_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoading = true;
  bool isError = false;
  List<dynamic> songs = [];

  @override
  void initState() {
    super.initState();
    _fetchRandomSongs();
  }

  Future<void> _fetchRandomSongs() async {
    final letters = 'abcdefghiklmnopqrstuvwxyz';
    final currentChoice = letters[Random().nextInt(letters.length)];
    
    print('Fetching songs for: $currentChoice');
    try {
      final url = Uri.parse('https://api.deezer.com/search?q=$currentChoice');
      final res = await http.get(url).timeout(const Duration(seconds: 30));

      print('Deezer API response: ${res.statusCode}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            songs = (data['data'] as List?)?.take(20).toList() ?? [];
            isLoading = false;
            isError = false;
          });
        }
      } else {
        print('Deezer API error: ${res.body}');
        _handleError();
      }
    } catch (e) {
      print('Song fetching exception: $e');
      _handleError();
    }
  }

  void _handleError() {
    if (mounted) {
      setState(() {
        isError = true;
        isLoading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      isLoading = true;
      isError = false;
    });
    _fetchRandomSongs();
  }

  Future<void> _playSong(Map<String, dynamic> song) async {
    final previewUrl = song['preview'];
    
    if (previewUrl == null || previewUrl.toString().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Preview not available for this song'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    try {
      final handler = AppAudioHandler.instance;
      final mediaItem = MediaItem(
        id: previewUrl,
        title: song['title'] ?? 'Unknown Title',
        artist: song['artist']?['name'] ?? 'Unknown Artist',
        album: song['album']?['title'] ?? 'Unknown Album',
        artUri: Uri.parse(song['album']?['cover_medium'] ?? ''),
        duration: Duration(seconds: song['duration'] ?? 30),
      );

      // Start playback without blocking navigation to the player.
      handler.playMediaItem(mediaItem).catchError((e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing song: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      });

      if (mounted) {
        context.push('/player');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing song: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _addToQueue(Map<String, dynamic> song) async {
    final previewUrl = song['preview'];

    if (previewUrl == null || previewUrl.toString().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Preview not available for this song'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    try {
      final handler = AppAudioHandler.instance;
      final mediaItem = MediaItem(
        id: previewUrl,
        title: song['title'] ?? 'Unknown Title',
        artist: song['artist']?['name'] ?? 'Unknown Artist',
        album: song['album']?['title'] ?? 'Unknown Album',
        artUri: Uri.parse(song['album']?['cover_medium'] ?? ''),
        duration: Duration(seconds: song['duration'] ?? 30),
      );

      await handler.addQueueItem(mediaItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Added to queue'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to queue: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          _ProfileIcon(),
        ],
      ),
      drawer: const ProfileDrawer(),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          const _NowPlayingBar(),
        ],
      ),
      bottomNavigationBar: const MainBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const LoadingView();
    }
    if (isError) {
      return ErrorView(onRetry: _retry);
    }
    if (songs.isEmpty) {
      return EmptyView(onRefresh: _retry);
    }
    return RefreshIndicator(
      onRefresh: _fetchRandomSongs,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return SongTile(
            song: song,
            onTap: () => _playSong(song),
            onAddToQueue: () => _addToQueue(song),
          );
        },
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading songs...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Failed to load songs',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[300],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;

  const EmptyView({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off, size: 64, color: Colors.grey[500]),
          const SizedBox(height: 16),
          Text(
            'No songs found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[300],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class SongTile extends StatelessWidget {
  final Map<String, dynamic> song;
  final VoidCallback onTap;
  final VoidCallback onAddToQueue;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    required this.onAddToQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: Colors.white.withOpacity(0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            song['album']?['cover_small'] ?? '',
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 56,
                height: 56,
                color: Colors.grey[300],
                child: const Icon(Icons.music_note),
              );
            },
          ),
        ),
        title: Text(
          song['title'] ?? 'Unknown Title',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song['artist']?['name'] ?? 'Unknown Artist',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[400],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_fill),
              color: Theme.of(context).colorScheme.primary,
              onPressed: onTap,
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: Colors.grey[300],
              ),
              onSelected: (value) {
                if (value == 'add_to_queue') {
                  onAddToQueue();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'add_to_queue',
                  child: Text('Add to queue'),
                ),
              ],
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _NowPlayingBar extends StatelessWidget {
  const _NowPlayingBar();

  @override
  Widget build(BuildContext context) {
    final audioHandler = AppAudioHandler.instance;

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaSnapshot) {
        final mediaItem = mediaSnapshot.data;
        if (mediaItem == null) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, playbackSnapshot) {
            final playbackState = playbackSnapshot.data;
            final isPlaying = playbackState?.playing ?? false;
            final processingState =
                playbackState?.processingState ?? AudioProcessingState.idle;

            // Only show bar when we have something meaningful to control.
            if (processingState == AudioProcessingState.idle &&
                !isPlaying) {
              return const SizedBox.shrink();
            }

            return Material(
            elevation: 12,
            color: const Color(0xFF050814),
              child: InkWell(
                onTap: () {
                  context.push('/player');
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          mediaItem.artUri?.toString() ?? '',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint(stackTrace.toString());
                            return Container(
                              width: 48,
                              height: 48,
                              color: Colors.grey[300],
                              child: const Icon(Icons.music_note),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              mediaItem.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            if (mediaItem.artist != null)
                              Text(
                                mediaItem.artist!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 26,
                        ),
                        color: Colors.white,
                        onPressed: () {
                          if (isPlaying) {
                            audioHandler.pause();
                          } else {
                            audioHandler.play();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          size: 24,
                        ),
                        color: Colors.white,
                        onPressed: () {
                          audioHandler.skipToNext();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class MainBottomNavigationBar extends StatelessWidget {
  const MainBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();

    int currentIndex = 0;
    if (location.startsWith('/search')) {
      currentIndex = 1;
    } else if (location.startsWith('/library')) {
      currentIndex = 2;
    } else {
      currentIndex = 0;
    }

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (index) {
        switch (index) {
          case 0:
            context.go('/');
            break;
          case 1:
            context.go('/search');
            break;
          case 2:
            context.go('/library');
            break;
          case 3:
            // "Create collection" button: for now, navigate to Library
            context.go('/library');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.library_music_outlined),
          label: 'Library',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add),
          label: 'Create',
        ),
      ],
    );
  }
}

class _ProfileIcon extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.status == AuthStatus.authenticated;

    return IconButton(
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: isAuthenticated
            ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
            : Colors.white10,
        child: Icon(
          isAuthenticated ? Icons.person : Icons.person_outline,
          size: 18,
          color: isAuthenticated
              ? Theme.of(context).colorScheme.primary
              : Colors.white70,
        ),
      ),
      onPressed: () {
        Scaffold.of(context).openDrawer();
      },
    );
  }
}
