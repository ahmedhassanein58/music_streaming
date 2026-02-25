import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_client/audio_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/core/models/song_model.dart';
import 'package:music_client/core/models/playlist_model.dart';
import 'package:music_client/core/network/playlist_repository.dart';
import 'package:music_client/core/network/song_repository.dart';
import 'package:music_client/core/network/history_repository.dart';
import 'package:music_client/Pages/profile_drawer.dart';
import 'package:music_client/core/providers/auth_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool isLoading = true;
  bool isError = false;
  String? errorMessage;
  List<Song> suggested = [];
  Map<String, List<Song>> genreSections = {};
  List<Song> allSongs = [];
  final SongRepository _songRepo = SongRepository();
  final HistoryRepository _historyRepo = HistoryRepository();
  final PlaylistRepository _playlistRepo = PlaylistRepository();

  @override
  void initState() {
    super.initState();
    _fetchSongs();
  }

  Future<void> _fetchSongs() async {
    try {
      final result = await _songRepo.list(page: 0, pageSize: 60);
      final items = result.items;
      if (items.isEmpty && mounted) {
        setState(() {
          suggested = [];
          genreSections = {};
          allSongs = [];
          isLoading = false;
          isError = false;
          errorMessage = null;
        });
        return;
      }
      final genres = <String>{};
      for (final s in items) {
        for (final g in s.genre) {
          if (g.isNotEmpty) genres.add(g);
        }
      }
      suggested = items.length >= 10 ? items.sublist(0, 10) : items;
      allSongs = items;
      final sectionMap = <String, List<Song>>{};
      final genreList = genres.toList()..sort();
      for (final g in genreList.take(2)) {
        try {
          final res = await _songRepo.list(genre: g, page: 0, pageSize: 10);
          if (res.items.isNotEmpty) sectionMap[g] = res.items;
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          genreSections = sectionMap;
          isLoading = false;
          isError = false;
          errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isError = true;
          isLoading = false;
          errorMessage = e.toString();
        });
      }
    }
  }

  void _retry() {
    setState(() {
      isLoading = true;
      isError = false;
      errorMessage = null;
    });
    _fetchSongs();
  }

  Future<void> _recordPlayIfAuthenticated(String trackId) async {
    final authState = ref.read(authProvider);
    if (authState.status != AuthStatus.authenticated) return;
    try {
      await _historyRepo.recordPlay(trackId);
    } catch (_) {
      // Best-effort; do not block playback
    }
  }

  Future<void> _playSong(Song song) async {
    final playUrl = song.s3Url;
    if (playUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Play URL not available for this song'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          ),
        );
      }
      return;
    }

    try {
      final handler = AppAudioHandler.instance;
      final mediaItem = MediaItem(
        id: playUrl,
        title: song.title,
        artist: song.artist,
        album: song.genre.isNotEmpty ? song.genre.join(', ') : null,
      );

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

      await _recordPlayIfAuthenticated(song.trackId);
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

  Future<void> _addToQueue(Song song) async {
    final playUrl = song.s3Url;
    if (playUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Play URL not available for this song'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          ),
        );
      }
      return;
    }

    try {
      final handler = AppAudioHandler.instance;
      final mediaItem = MediaItem(
        id: playUrl,
        title: song.title,
        artist: song.artist,
        album: song.genre.isNotEmpty ? song.genre.join(', ') : null,
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
      return ErrorView(message: errorMessage, onRetry: _retry);
    }
    if (suggested.isEmpty && genreSections.isEmpty && allSongs.isEmpty) {
      return EmptyView(onRefresh: _retry);
    }
    final audioHandler = AppAudioHandler.instance;
    return RefreshIndicator(
      onRefresh: _fetchSongs,
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, mediaSnapshot) {
          final currentMediaId = mediaSnapshot.data?.id;
          return StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, stateSnapshot) {
              final isPlaying = stateSnapshot.data?.playing ?? false;
              final sections = <Widget>[];
              if (suggested.isNotEmpty) {
                sections.add(_SectionTitle('Suggested for you'));
                sections.add(_HorizontalSongStrip(
                  songs: suggested,
                  currentMediaId: currentMediaId,
                  isPlaying: isPlaying,
                  onPlay: _playSong,
                  onAddToQueue: _addToQueue,
                  onAddToPlaylist: onAddToPlaylist,
                ));
              }
              for (final e in genreSections.entries) {
                if (e.value.isEmpty) continue;
                sections.add(_GenreSectionWithImage(
                  genre: e.key,
                  songs: e.value,
                  currentMediaId: currentMediaId,
                  isPlaying: isPlaying,
                  onPlay: _playSong,
                  onAddToQueue: _addToQueue,
                  onAddToPlaylist: onAddToPlaylist,
                ));
              }
              if (allSongs.isNotEmpty) {
                sections.add(_SectionTitle('All songs'));
                sections.add(_VerticalSongList(
                  songs: allSongs,
                  currentMediaId: currentMediaId,
                  isPlaying: isPlaying,
                  audioHandler: audioHandler,
                  onPlay: _playSong,
                  onAddToQueue: _addToQueue,
                  onAddToPlaylist: onAddToPlaylist,
                ));
              }
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: sections,
              );
            },
          );
        },
      ),
    );
  }

  void Function(Song)? get onAddToPlaylist => _showAddToPlaylistDialog;

  Future<void> _showAddToPlaylistDialog(Song song) async {
    final authState = ref.read(authProvider);
    if (authState.status != AuthStatus.authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in to add to playlist'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    List<Playlist> playlists;
    try {
      playlists = await _playlistRepo.list();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load playlists: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (!mounted) return;
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Add "${song.title}" to playlist',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            ...playlists.map(
              (p) => ListTile(
                leading: const Icon(Icons.playlist_play),
                title: Text(p.name),
                subtitle: Text('${p.tracksId.length} tracks'),
                onTap: () => Navigator.pop(ctx, p),
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      try {
        await _playlistRepo.addTracks(chosen.id, [song.trackId]);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added to ${chosen.name}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
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
  final String? message;
  final VoidCallback onRetry;

  const ErrorView({super.key, this.message, required this.onRetry});

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
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Genre section with a photo card and horizontal song strip.
class _GenreSectionWithImage extends StatelessWidget {
  final String genre;
  final List<Song> songs;
  final String? currentMediaId;
  final bool isPlaying;
  final void Function(Song) onPlay;
  final void Function(Song) onAddToQueue;
  final void Function(Song)? onAddToPlaylist;

  const _GenreSectionWithImage({
    required this.genre,
    required this.songs,
    required this.currentMediaId,
    required this.isPlaying,
    required this.onPlay,
    required this.onAddToQueue,
    this.onAddToPlaylist,
  });

  static String _imageUrlForGenre(String name) {
    final seed = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return 'https://picsum.photos/seed/${seed.isEmpty ? "genre" : seed}/400/200';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _imageUrlForGenre(genre),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note, size: 48, color: Colors.grey),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        genre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _HorizontalSongStrip(
          songs: songs,
          currentMediaId: currentMediaId,
          isPlaying: isPlaying,
          onPlay: onPlay,
          onAddToQueue: onAddToQueue,
          onAddToPlaylist: onAddToPlaylist,
        ),
      ],
    );
  }
}

class _HorizontalSongStrip extends StatelessWidget {
  final List<Song> songs;
  final String? currentMediaId;
  final bool isPlaying;
  final void Function(Song) onPlay;
  final void Function(Song) onAddToQueue;
  final void Function(Song)? onAddToPlaylist;

  const _HorizontalSongStrip({
    required this.songs,
    required this.currentMediaId,
    required this.isPlaying,
    required this.onPlay,
    required this.onAddToQueue,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          final isCurrentlyPlaying = currentMediaId != null && currentMediaId == song.s3Url;
          return _CompactSongCard(
            song: song,
            isCurrentlyPlaying: isCurrentlyPlaying,
            isPlaying: isCurrentlyPlaying && isPlaying,
            onTap: () => onPlay(song),
            onAddToQueue: () => onAddToQueue(song),
            onAddToPlaylist: onAddToPlaylist != null ? () => onAddToPlaylist!(song) : null,
          );
        },
      ),
    );
  }
}

class _VerticalSongList extends StatelessWidget {
  final List<Song> songs;
  final String? currentMediaId;
  final bool isPlaying;
  final AppAudioHandler audioHandler;
  final void Function(Song) onPlay;
  final void Function(Song) onAddToQueue;
  final void Function(Song)? onAddToPlaylist;

  const _VerticalSongList({
    required this.songs,
    required this.currentMediaId,
    required this.isPlaying,
    required this.audioHandler,
    required this.onPlay,
    required this.onAddToQueue,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isCurrentlyPlaying = currentMediaId != null && currentMediaId == song.s3Url;
        return SongTile(
          song: song,
          isCurrentlyPlaying: isCurrentlyPlaying,
          isPlaying: isCurrentlyPlaying && isPlaying,
          onTap: () {
            if (isCurrentlyPlaying) {
              if (isPlaying) {
                audioHandler.pause();
              } else {
                audioHandler.play();
              }
            } else {
              onPlay(song);
            }
          },
          onAddToQueue: () => onAddToQueue(song),
          onAddToPlaylist: onAddToPlaylist,
        );
      },
    );
  }
}

class _CompactSongCard extends StatelessWidget {
  final Song song;
  final bool isCurrentlyPlaying;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onAddToQueue;
  final VoidCallback? onAddToPlaylist;

  const _CompactSongCard({
    required this.song,
    required this.isCurrentlyPlaying,
    required this.isPlaying,
    required this.onTap,
    required this.onAddToQueue,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 130,
            height: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 130,
                  height: 118,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isCurrentlyPlaying
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                        : Colors.grey[800],
                  ),
                  child: Icon(
                    isCurrentlyPlaying ? Icons.graphic_eq : Icons.music_note,
                    size: 40,
                    color: isCurrentlyPlaying
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  song.title.isNotEmpty ? song.title : 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  song.artist.isNotEmpty ? song.artist : 'Unknown artist',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SongTile extends StatelessWidget {
  final Song song;
  final bool isCurrentlyPlaying;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onAddToQueue;
  final void Function(Song)? onAddToPlaylist;

  const SongTile({
    super.key,
    required this.song,
    this.isCurrentlyPlaying = false,
    this.isPlaying = false,
    required this.onTap,
    required this.onAddToQueue,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: isCurrentlyPlaying
          ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
          : Colors.white.withOpacity(0.03),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrentlyPlaying
            ? BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 1)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isCurrentlyPlaying ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Colors.grey[800],
          ),
          child: isCurrentlyPlaying
              ? Icon(Icons.graphic_eq, color: Theme.of(context).colorScheme.primary, size: 28)
              : const Icon(Icons.music_note, color: Colors.grey, size: 28),
        ),
        title: Text(
          song.title.isNotEmpty ? song.title : 'Unknown Title',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: isCurrentlyPlaying ? Theme.of(context).colorScheme.primary : Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          isCurrentlyPlaying
              ? (isPlaying ? 'Now playing' : 'Paused')
              : (song.artist.isNotEmpty ? song.artist : 'Unknown Artist'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: isCurrentlyPlaying ? Theme.of(context).colorScheme.primary.withOpacity(0.9) : Colors.grey[400],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                (isCurrentlyPlaying && isPlaying) ? Icons.pause_circle_filled : Icons.play_circle_fill,
              ),
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
                } else if (value == 'add_to_playlist' && onAddToPlaylist != null) {
                  onAddToPlaylist!(song);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'add_to_queue',
                  child: Text('Add to queue'),
                ),
                if (onAddToPlaylist != null)
                  const PopupMenuItem<String>(
                    value: 'add_to_playlist',
                    child: Text('Add to playlist'),
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
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          mediaItem.artUri?.toString() ?? '',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint(stackTrace.toString());
                            return Container(
                              width: 44,
                              height: 44,
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
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.library_music_outlined),
          label: 'Library',
        ),
        const BottomNavigationBarItem(
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
