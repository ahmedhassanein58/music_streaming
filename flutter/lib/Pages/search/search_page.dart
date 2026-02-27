import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/audio_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:music_client/core/models/playlist_model.dart';
import 'package:music_client/core/models/song_model.dart';
import 'package:music_client/core/network/playlist_repository.dart';
import 'package:music_client/core/network/song_repository.dart';
import 'package:music_client/core/network/history_repository.dart';
import 'package:music_client/core/providers/auth_provider.dart';
import 'package:music_client/Pages/home.dart';

// ── Genre categories shown in the idle browse screen ──────────────────────
class _Category {
  final String label;
  final Color color;
  final IconData icon;
  const _Category(this.label, this.color, this.icon);
}

const _kCategories = <_Category>[
  _Category('Pop',        Color(0xFFE91E8C), Icons.music_note),
  _Category('Rock',       Color(0xFFE53935), Icons.flash_on),
  _Category('Hip Hop',    Color(0xFF7B1FA2), Icons.mic),
  _Category('Jazz',       Color(0xFFFF6D00), Icons.library_music),
  _Category('Classical',  Color(0xFF1565C0), Icons.queue_music),
  _Category('Electronic', Color(0xFF00838F), Icons.graphic_eq),
  _Category('R&B',        Color(0xFF2E7D32), Icons.favorite),
  _Category('Country',    Color(0xFF827717), Icons.landscape),
];

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
  List<Song> _trending = [];
  bool _isLoading = false;
  bool _trendingLoading = true;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    try {
      final result = await _songRepo.list(page: 0, pageSize: 40);
      if (mounted) {
        final shuffled = List<Song>.from(result.items)..shuffle(Random());
        setState(() {
          _trending = shuffled.take(10).toList();
          _trendingLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _trendingLoading = false);
    }
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
      return _buildBrowseView();
    }
    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 56, color: Colors.grey[600]),
            const SizedBox(height: 16),
            const Text(
              'No songs found',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different keyword',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
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

  Widget _buildBrowseView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── Browse by genre ────────────────────────────────────────────
        const Text(
          'Browse by Genre',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.4,
          children: _kCategories
              .map((cat) => _CategoryCard(
                    label: cat.label,
                    color: cat.color,
                    icon: cat.icon,
                    onTap: () {
                      _queryController.text = cat.label;
                      _search(cat.label);
                    },
                  ))
              .toList(),
        ),
        // ── Trending songs ─────────────────────────────────────────────
        const SizedBox(height: 28),
        const Text(
          'Trending Now',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        if (_trendingLoading)
          const _TrendingSkeletonList()
        else if (_trending.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Nothing to show right now',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          )
        else
          ..._trending.map(
            (song) => SongTile(
              song: song,
              onTap: () => _playSong(song),
              onAddToQueue: () => _addToQueue(song),
              onAddToPlaylist: _showAddToPlaylistDialog,
            ),
          ),
      ],
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

// ── Trending skeleton ──────────────────────────────────────────────────────
class _TrendingSkeletonList extends StatefulWidget {
  const _TrendingSkeletonList();

  @override
  State<_TrendingSkeletonList> createState() => _TrendingSkeletonListState();
}

class _TrendingSkeletonListState extends State<_TrendingSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  BoxDecoration _shimmer({double radius = 8}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value, 0),
          colors: const [
            Color(0xFF111827),
            Color(0xFF1F2F45),
            Color(0xFF111827),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Column(
        children: List.generate(
          6,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Cover thumbnail
                Container(
                  width: 56,
                  height: 56,
                  decoration: _shimmer(radius: 10),
                ),
                const SizedBox(width: 14),
                // Title + artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: _shimmer(radius: 4),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 11,
                        width: 120,
                        decoration: _shimmer(radius: 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Play button placeholder
                Container(
                  width: 32,
                  height: 32,
                  decoration: _shimmer(radius: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Genre category card ────────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
