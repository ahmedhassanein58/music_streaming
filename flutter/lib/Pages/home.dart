import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_client/audio_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/core/models/song_model.dart';
import 'package:music_client/core/models/playlist_model.dart';
import 'package:music_client/core/network/playlist_repository.dart';
import 'package:music_client/core/network/recommendation_repository.dart';
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
  final RecommendationRepository _recRepo = RecommendationRepository();

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
      // Suggested: use recommendation API from most played history when authenticated
      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.authenticated) {
        final recs = await _recRepo.getSuggested();
        suggested = recs.isNotEmpty ? recs : (items.length >= 10 ? items.sublist(0, 10) : items);
      } else {
        suggested = items.length >= 10 ? items.sublist(0, 10) : items;
      }
      // Discover: shuffle so each visit shows different order
      allSongs = List<Song>.from(items)..shuffle(Random());
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
        extras: {'trackId': song.trackId},
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
        extras: {'trackId': song.trackId},
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
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
      return const _HomeSkeletonView();
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
      color: Theme.of(context).colorScheme.primary,
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, mediaSnapshot) {
          final currentMediaId = mediaSnapshot.data?.id;
          return StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, stateSnapshot) {
              final isPlaying = stateSnapshot.data?.playing ?? false;
              final sections = <Widget>[];
              sections.add(const _WelcomeSection());
              sections.add(const SizedBox(height: 28));
              if (suggested.isNotEmpty) {
                sections.add(_SectionTitle('Suggested for you'));
                sections.add(const SizedBox(height: 12));
                sections.add(_HorizontalSongStrip(
                  songs: suggested,
                  currentMediaId: currentMediaId,
                  isPlaying: isPlaying,
                  onPlay: _playSong,
                  onAddToQueue: _addToQueue,
                  onAddToPlaylist: onAddToPlaylist,
                ));
                sections.add(const SizedBox(height: 32));
              }
              if (allSongs.isNotEmpty) {
                sections.add(_SectionTitle('Discover'));
                sections.add(const SizedBox(height: 12));
                sections.add(
                  _DiscoverSongsSection(
                    songs: allSongs,
                    currentMediaId: currentMediaId,
                    isPlaying: isPlaying,
                    onPlay: _playSong,
                    onAddToQueue: _addToQueue,
                    onAddToPlaylist: onAddToPlaylist,
                  ),
                );
                sections.add(const SizedBox(height: 32));
              }
              for (final e in genreSections.entries) {
                if (e.value.isEmpty) continue;
                sections.add(_SectionTitle(e.key));
                sections.add(const SizedBox(height: 12));
                sections.add(_HorizontalSongStrip(
                  songs: e.value,
                  currentMediaId: currentMediaId,
                  isPlaying: isPlaying,
                  onPlay: _playSong,
                  onAddToQueue: _addToQueue,
                  onAddToPlaylist: onAddToPlaylist,
                ));
                sections.add(const SizedBox(height: 32));
              }
              sections.add(const SizedBox(height: 32));
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

// ── Skeleton loading screen ────────────────────────────────────────────────
class _HomeSkeletonView extends StatefulWidget {
  const _HomeSkeletonView();

  @override
  State<_HomeSkeletonView> createState() => _HomeSkeletonViewState();
}

class _HomeSkeletonViewState extends State<_HomeSkeletonView>
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

  Widget _box(double w, double h, {double r = 8}) =>
      Container(width: w, height: h, decoration: _shimmer(radius: r));

  Widget _gridRow(double cardW, double cardH) => Row(
        children: [
          _box(cardW, cardH, r: 12),
          const SizedBox(width: 10),
          _box(cardW, cardH, r: 12),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          // ── Welcome ────────────────────────────────────────────────
          _box(180, 28, r: 6),
          const SizedBox(height: 10),
          _box(230, 15, r: 5),
          const SizedBox(height: 36),

          // ── Suggested for you ──────────────────────────────────────
          _box(170, 20, r: 5),
          const SizedBox(height: 14),
          SizedBox(
            height: 215,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: 4,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(140, 140, r: 12),
                    const SizedBox(height: 10),
                    _box(110, 13, r: 4),
                    const SizedBox(height: 6),
                    _box(75, 11, r: 4),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),

          // ── Discover ───────────────────────────────────────────────
          _box(100, 20, r: 5),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 10.0;
              final cardW = (constraints.maxWidth - spacing) / 2;
              final cardH = cardW + 46.0;
              return Column(
                children: [
                  _gridRow(cardW, cardH),
                  const SizedBox(height: 10),
                  _gridRow(cardW, cardH),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // ── Dot indicator placeholder ──────────────────────────────
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == 0 ? 20 : 6,
                  height: 6,
                  decoration: _shimmer(radius: 999),
                ),
              ),
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

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/logo.png',
              width: 56,
              height: 56,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good evening',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Find something to listen to',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
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
      padding: const EdgeInsets.only(left: 0, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
      ),
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
      height: 215,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        clipBehavior: Clip.none,
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

class _DiscoverSongsSection extends StatefulWidget {
  final List<Song> songs;
  final String? currentMediaId;
  final bool isPlaying;
  final void Function(Song) onPlay;
  final void Function(Song) onAddToQueue;
  final void Function(Song)? onAddToPlaylist;

  const _DiscoverSongsSection({
    required this.songs,
    required this.currentMediaId,
    required this.isPlaying,
    required this.onPlay,
    required this.onAddToQueue,
    this.onAddToPlaylist,
  });

  @override
  State<_DiscoverSongsSection> createState() => _DiscoverSongsSectionState();
}

class _DiscoverSongsSectionState extends State<_DiscoverSongsSection> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) return const SizedBox.shrink();

    // Fixed 2×2 grid, 3 pages of 4 songs each = 12 songs total
    const crossAxisCount = 2;
    const rowCount = 2;
    const pageSize = crossAxisCount * rowCount; // 4
    const totalPages = 3;
    const spacing = 10.0;
    const dotsHeight = 28.0;
    // Extra vertical space for title + artist text below the square image
    const textAreaHeight = 46.0; // 8 gap + ~16 title + 3 gap + ~16 artist + 3 buffer

    // Take at most totalPages * pageSize songs, pad if needed
    final source = widget.songs.take(totalPages * pageSize).toList();

    final chunks = <List<Song>>[];
    for (var i = 0; i < totalPages; i++) {
      final start = i * pageSize;
      if (start >= source.length) {
        final padded = List<Song>.generate(
          pageSize,
          (j) => source[(start + j) % source.length],
        );
        chunks.add(padded);
      } else {
        final end = (start + pageSize).clamp(0, source.length);
        chunks.add(source.sublist(start, end));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Card width = half of available width minus the one inter-column gap
        final cardWidth = (constraints.maxWidth - spacing) / crossAxisCount;
        // Card height = square image + text area below
        final cardHeight = cardWidth + textAreaHeight;
        final aspectRatio = cardWidth / cardHeight;

        final totalHeight =
            rowCount * cardHeight + (rowCount - 1) * spacing + dotsHeight + 12;

        return SizedBox(
          height: totalHeight,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: chunks.length,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, pageIndex) {
                    final pageSongs = chunks[pageIndex];
                    return GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        childAspectRatio: aspectRatio,
                      ),
                      itemCount: pageSongs.length,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final song = pageSongs[index];
                        final isCurrentlyPlaying =
                            widget.currentMediaId != null &&
                                widget.currentMediaId == song.s3Url;
                        return _DiscoverSongCard(
                          song: song,
                          isCurrentlyPlaying: isCurrentlyPlaying,
                          isPlaying: isCurrentlyPlaying && widget.isPlaying,
                          onTap: () => widget.onPlay(song),
                          onAddToQueue: () => widget.onAddToQueue(song),
                          onAddToPlaylist: widget.onAddToPlaylist != null
                              ? () => widget.onAddToPlaylist!(song)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  chunks.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: _currentPage == index
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DiscoverSongCard extends StatelessWidget {
  final Song song;
  final bool isCurrentlyPlaying;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onAddToQueue;
  final VoidCallback? onAddToPlaylist;

  const _DiscoverSongCard({
    required this.song,
    required this.isCurrentlyPlaying,
    required this.isPlaying,
    required this.onTap,
    required this.onAddToQueue,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  song.coverUrl != null && song.coverUrl!.isNotEmpty
                      ? Image.network(
                          song.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                  if (isCurrentlyPlaying)
                    Container(
                      color: Colors.black38,
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            song.title.isNotEmpty ? song.title : 'Unknown',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            song.artist.isNotEmpty ? song.artist : 'Unknown artist',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1E293B),
      child: const Center(
        child: Icon(Icons.music_note, color: Color(0xFF64748B), size: 32),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: song.coverUrl != null && song.coverUrl!.isNotEmpty
                          ? Image.network(
                              song.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(context),
                            )
                          : _buildPlaceholder(context),
                    ),
                    if (isCurrentlyPlaying)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                song.title.isNotEmpty ? song.title : 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                song.artist.isNotEmpty ? song.artist : 'Unknown artist',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: const Color(0xFF1E293B),
      child: const Icon(Icons.music_note, size: 48, color: Color(0xFF64748B)),
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
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: song.coverUrl != null && song.coverUrl!.isNotEmpty
              ? Image.network(
                  song.coverUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color: isCurrentlyPlaying ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Colors.grey[800],
                    child: Icon(
                      isCurrentlyPlaying ? Icons.graphic_eq : Icons.music_note,
                      color: isCurrentlyPlaying ? Theme.of(context).colorScheme.primary : Colors.grey,
                      size: 28,
                    ),
                  ),
                )
              : Container(
                  width: 56,
                  height: 56,
                  color: isCurrentlyPlaying ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Colors.grey[800],
                  child: Icon(
                    isCurrentlyPlaying ? Icons.graphic_eq : Icons.music_note,
                    color: isCurrentlyPlaying ? Theme.of(context).colorScheme.primary : Colors.grey,
                    size: 28,
                  ),
                ),
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
            context.go('/library?create=1');
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
