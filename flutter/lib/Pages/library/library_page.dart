import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_client/audio_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:music_client/core/models/playlist_model.dart';
import 'package:music_client/core/models/history_model.dart';
import 'package:music_client/core/models/audio_feature.dart';
import 'package:music_client/core/models/song_model.dart';
import 'package:music_client/core/network/playlist_repository.dart';
import 'package:music_client/core/network/history_repository.dart';
import 'package:music_client/core/network/song_repository.dart';
import 'package:music_client/core/providers/auth_provider.dart';
import 'package:music_client/Pages/home.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PlaylistRepository _playlistRepo = PlaylistRepository();
  final HistoryRepository _historyRepo = HistoryRepository();
  final SongRepository _songRepo = SongRepository();

  List<Playlist> _playlists = [];
  List<HistoryItem> _history = [];
  bool _playlistsLoading = true;
  bool _historyLoading = true;
  String? _playlistsError;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPlaylists();
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylists() async {
    final authState = ref.read(authProvider);
    if (authState.status != AuthStatus.authenticated) {
      setState(() {
        _playlists = [];
        _playlistsLoading = false;
      });
      return;
    }
    setState(() {
      _playlistsLoading = true;
      _playlistsError = null;
    });
    try {
      final list = await _playlistRepo.list();
      if (mounted) {
        setState(() {
          _playlists = list;
          _playlistsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _playlistsError = e.toString();
          _playlists = [];
          _playlistsLoading = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    final authState = ref.read(authProvider);
    if (authState.status != AuthStatus.authenticated) {
      setState(() {
        _history = [];
        _historyLoading = false;
      });
      return;
    }
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final list = await _historyRepo.list();
      if (mounted) {
        setState(() {
          _history = list;
          _historyLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = e.toString();
          _history = [];
          _historyLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.status == AuthStatus.authenticated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Playlists'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: !isAuthenticated
          ? _buildSignedOutView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPlaylistsTab(),
                _buildHistoryTab(),
              ],
            ),
      floatingActionButton: isAuthenticated
          ? FloatingActionButton(
              onPressed: () => _showCreatePlaylistDialog(context),
              child: const Icon(Icons.add),
              tooltip: 'Create playlist',
            )
          : null,
      bottomNavigationBar: const MainBottomNavigationBar(),
    );
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create playlist'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Playlist name',
            hintText: 'e.g. Favorites',
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      try {
        await _playlistRepo.create(CreatePlaylistRequest(name: result));
        if (mounted) {
          _loadPlaylists();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Playlist created'),
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

  Widget _buildSignedOutView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_music_outlined, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'Sign in to see your playlists and history',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/login'),
            icon: const Icon(Icons.login),
            label: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsTab() {
    if (_playlistsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_playlistsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_playlistsError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[300])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPlaylists,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_playlists.isEmpty) {
      return const Center(
        child: Text('No playlists yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPlaylists,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _playlists.length,
        itemBuilder: (context, index) {
          final p = _playlists[index];
          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.playlist_play),
            ),
            title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            subtitle: Text('${p.tracksId.length} tracks', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            onTap: () => _openPlaylistDetail(p),
          );
        },
      ),
    );
  }

  void _openPlaylistDetail(Playlist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _PlaylistDetailPage(
          playlist: playlist,
          playlistRepo: _playlistRepo,
          songRepo: _songRepo,
          historyRepo: _historyRepo,
          onRecordPlay: _recordPlayIfAuthenticated,
          onAddToPlaylist: _showAddToPlaylistDialogFromLibrary,
        ),
      ),
    ).then((_) => _loadPlaylists());
  }

  Future<void> _showAddToPlaylistDialogFromLibrary(Song song) async {
    List<Playlist> playlists;
    try {
      playlists = await _playlistRepo.list();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load playlists: $e'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    if (!mounted) return;
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a playlist first'),
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
            SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
          );
        }
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

  Widget _buildHistoryTab() {
    if (_historyLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_historyError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_historyError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[300])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_history.isEmpty) {
      return const Center(
        child: Text('No play history yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final h = _history[index];
          return _HistoryTile(
            item: h,
            onPlay: _playSongFromTrackId,
          );
        },
      ),
    );
  }

  Future<void> _playSongFromTrackId(String trackId) async {
    try {
      final song = await _songRepo.getByTrackId(trackId);
      if (song.s3Url.isEmpty) return;
      final handler = AppAudioHandler.instance;
      final mediaItem = MediaItem(
        id: song.s3Url,
        title: song.title,
        artist: song.artist,
        album: song.genre.isNotEmpty ? song.genre.join(', ') : null,
      );
      await handler.playMediaItem(mediaItem);
      await _recordPlayIfAuthenticated(trackId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play track'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

class _PlaylistDetailPage extends StatefulWidget {
  final Playlist playlist;
  final PlaylistRepository playlistRepo;
  final SongRepository songRepo;
  final HistoryRepository historyRepo;
  final Future<void> Function(String trackId) onRecordPlay;
  final Future<void> Function(Song song)? onAddToPlaylist;

  const _PlaylistDetailPage({
    required this.playlist,
    required this.playlistRepo,
    required this.songRepo,
    required this.historyRepo,
    required this.onRecordPlay,
    this.onAddToPlaylist,
  });

  @override
  State<_PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<_PlaylistDetailPage> {
  late Playlist _playlist;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
  }

  Future<void> _removeTrack(Song song) async {
    try {
      await widget.playlistRepo.removeTrack(_playlist.id, song.trackId);
      if (!mounted) return;
      final updated = await widget.playlistRepo.get(_playlist.id);
      setState(() => _playlist = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from playlist'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _playlist;
    final playlistRepo = widget.playlistRepo;
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete playlist?'),
                  content: Text('Remove "${playlist.name}"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                try {
                  await playlistRepo.delete(playlist.id);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: playlist.tracksId.isEmpty
          ? const Center(child: Text('No tracks in this playlist', style: TextStyle(color: Colors.grey)))
          : FutureBuilder<List<Song>>(
              future: _fetchTracks(playlist.tracksId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final songs = snapshot.data!;
                return ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(song.title.isNotEmpty ? song.title : 'Unknown'),
                      subtitle: Text(song.artist.isNotEmpty ? song.artist : 'Unknown artist'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () => _playAndRecord(context, song),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == 'add_to_queue') _addToQueue(context, song);
                              if (value == 'add_to_playlist' && widget.onAddToPlaylist != null) {
                                widget.onAddToPlaylist!(song);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'add_to_queue', child: Text('Add to queue')),
                              if (widget.onAddToPlaylist != null)
                                const PopupMenuItem(value: 'add_to_playlist', child: Text('Add to playlist')),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            tooltip: 'Remove from playlist',
                            onPressed: () => _removeTrack(song),
                          ),
                        ],
                      ),
                      onTap: () => _playAndRecord(context, song),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<List<Song>> _fetchTracks(List<String> trackIds) async {
    if (trackIds.isEmpty) return [];
    final songs = await widget.songRepo.getByTrackIds(trackIds);
    final byTrackId = {for (final s in songs) s.trackId: s};
    return trackIds.map((id) {
      final s = byTrackId[id];
      if (s != null) return s;
      return Song(
        id: '',
        trackId: id,
        title: 'Unknown track',
        artist: 'Unknown artist',
        genre: const [],
        audioFeature: const AudioFeature(),
        s3Url: '',
      );
    }).toList();
  }

  Future<void> _playAndRecord(BuildContext context, Song song) async {
    if (song.s3Url.isEmpty) return;
    try {
      final handler = AppAudioHandler.instance;
      await handler.playMediaItem(MediaItem(
        id: song.s3Url,
        title: song.title,
        artist: song.artist,
        album: song.genre.isNotEmpty ? song.genre.join(', ') : null,
      ));
      await widget.onRecordPlay(song.trackId);
    } catch (_) {}
  }

  Future<void> _addToQueue(BuildContext context, Song song) async {
    if (song.s3Url.isEmpty) return;
    try {
      final handler = AppAudioHandler.instance;
      await handler.addQueueItem(MediaItem(
        id: song.s3Url,
        title: song.title,
        artist: song.artist,
        album: song.genre.isNotEmpty ? song.genre.join(', ') : null,
      ));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to queue'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (_) {}
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryItem item;
  final void Function(String trackId) onPlay;

  const _HistoryTile({
    required this.item,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final title = item.title?.isNotEmpty == true ? item.title! : 'Unknown track';
    final artist = item.artist?.isNotEmpty == true ? item.artist! : 'Unknown artist';
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.music_note)),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        '$artist • ${item.playCount} plays',
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: () => onPlay(item.trackId),
      ),
    );
  }
}
