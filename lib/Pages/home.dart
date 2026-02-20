import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:music_client/Pages/player.dart';
import 'package:music_client/audio_service.dart';
import 'package:audio_service/audio_service.dart';

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
    // Reset state only on manual retry/refresh, but here we can just update
    // If called from init, isLoading is already true.
    // If called from retry, we might want to set loading.
    
    try {
      final letters = 'abcdefghiklmnopqrstuvwxyz';
      final currentChoice = letters[Random().nextInt(letters.length)];

      final url = Uri.parse('https://api.deezer.com/search?q=$currentChoice');
      final res = await http.get(url).timeout(const Duration(seconds: 10));

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
        _handleError();
      }
    } catch (e) {
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
      
      await handler.playMediaItem(mediaItem);
      
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const Player()),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        elevation: 0,
      ),
      body: _buildBody()
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
            style: TextStyle(color: Colors.grey[600]),
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
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Failed to load songs',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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
          Icon(Icons.music_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No songs found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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

  const SongTile({super.key, required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song['artist']?['name'] ?? 'Unknown Artist',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.play_circle_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
        onTap: onTap,
      ),
    );
  }
}
