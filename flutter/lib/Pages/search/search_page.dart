import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_client/audio_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:music_client/core/models/playlist_model.dart';
import 'package:music_client/core/models/song_model.dart';
import 'package:music_client/core/network/playlist_repository.dart';
import 'package:music_client/core/network/song_repository.dart';
import 'package:music_client/core/network/history_repository.dart';
import 'package:music_client/core/providers/auth_provider.dart';
import 'package:music_client/Pages/home.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _queryController = TextEditingController();
  final SongRepository _songRepo = SongRepository();
  final HistoryRepository _historyRepo = HistoryRepository();
  final PlaylistRepository _playlistRepo = PlaylistRepository();
  List<Song> _songs = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = _queryController.text.trim();
      if (q.isEmpty) {
        setState(() {
          _songs = [];
          _errorMessage = null;
        });
        return;
      }
      _search(q);
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _songRepo.list(search: query, page: 0, pageSize: 30);
      if (mounted) {
        setState(() {
          _songs = result.items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _songs = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _recordPlayIfAuthenticated(String trackId) async {
    final authState = ref.read(authProvider);
    if (authState.status != AuthStatus.authenticated) return;
    try {
      await _historyRepo.recordPlay(trackId);
    } catch (_) {}
  }

  Future<void> _playSong(Song song) async {
    if (song.s3Url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Play URL not available for this song'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      final handler = AppAudioHandler.instance;
      final mediaItem = MediaItem(
        id: song.s3Url,
        title: song.title,
        artist: song.artist,
        album: song.genre.isNotEmpty ? song.genre.join(', ') : null,
      );
      handler.playMediaItem(mediaItem).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      });
      await _recordPlayIfAuthenticated(song.trackId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _addToQueue(Song song) async {
    if (song.s3Url.isEmpty) return;
    try {
      final handler = AppAudioHandler.instance;
      final mediaItem = MediaItem(
        id: song.s3Url,
        title: song.title,
        artist: song.artist,
        album: song.genre.isNotEmpty ? song.genre.join(', ') : null,
      );
      await handler.addQueueItem(mediaItem);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to queue'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: 'Search songs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onSubmitted: (value) {
                final q = value.trim();
                if (q.isNotEmpty) _search(q);
              },
            ),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _queryController.text.isNotEmpty ? _search(_queryController.text.trim()) : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_queryController.text.trim().isEmpty) {
      return const Center(
        child: Text(
          'Enter a search term to find songs',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    if (_songs.isEmpty) {
      return const Center(
        child: Text(
          'No songs found',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _songs.length,
      itemBuilder: (context, index) {
        final song = _songs[index];
        return SongTile(
          song: song,
          onTap: () => _playSong(song),
          onAddToQueue: () => _addToQueue(song),
          onAddToPlaylist: _showAddToPlaylistDialog,
        );
      },
    );
  }

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
