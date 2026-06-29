import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/audio_service.dart';
import 'package:music_client/core/models/song_model.dart';
import 'package:music_client/core/models/song_playback.dart';
import 'package:music_client/core/network/history_repository.dart';
import 'package:music_client/core/network/identify_repository.dart';
import 'package:music_client/core/network/song_repository.dart';
import 'package:music_client/core/providers/auth_provider.dart';

class IdentifySongPage extends ConsumerStatefulWidget {
  const IdentifySongPage({super.key});

  @override
  ConsumerState<IdentifySongPage> createState() => _IdentifySongPageState();
}

class _IdentifySongPageState extends ConsumerState<IdentifySongPage> {
  final IdentifyRepository _identifyRepo = IdentifyRepository();
  final SongRepository _songRepo = SongRepository();
  final HistoryRepository _historyRepo = HistoryRepository();

  bool _listening = false;
  bool _notFound = false;
  Song? _foundSong;

  Future<void> _startIdentify() async {
    setState(() {
      _listening = true;
      _notFound = false;
      _foundSong = null;
    });

    try {
      final result = await _identifyRepo.identify();
      if (!mounted) return;

      if (result == null) {
        setState(() {
          _listening = false;
          _notFound = true;
        });
        return;
      }

      final response = await _songRepo.list(search: result.title, pageSize: 5);
      if (!mounted) return;

      final match = response.items.isNotEmpty ? response.items.first : null;
      setState(() {
        _listening = false;
        if (match != null) {
          _foundSong = match;
        } else {
          _notFound = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _listening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _playSong(Song song) async {
    if (song.s3Url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Play URL not available for this song'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final handler = AppAudioHandler.instance;
      await handler.playMediaItem(song.toMediaItem());
      final auth = ref.read(authProvider);
      if (auth.status == AuthStatus.authenticated) {
        try {
          await _historyRepo.recordPlay(song.trackId);
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _listening = false;
      _notFound = false;
      _foundSong = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Identify a Song')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Tap the mic to listen and identify a song. If we have it in our catalog, you can play it right away.',
            style: TextStyle(color: Colors.grey[400], height: 1.4),
          ),
          const SizedBox(height: 32),
          if (_listening)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: primary),
                    const SizedBox(height: 16),
                    const Text('Listening...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            )
          else if (_foundSong != null) ...[
            Card(
              color: const Color(0xFF1F2937),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: primary.withValues(alpha: 0.2),
                  child: Icon(Icons.music_note, color: primary),
                ),
                title: Text(
                  _foundSong!.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _foundSong!.artist,
                  style: TextStyle(color: Colors.grey[500]),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
                  onPressed: () => _playSong(_foundSong!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _reset,
              child: const Text('Identify again'),
            ),
          ] else if (_notFound) ...[
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_off, size: 56, color: Colors.grey[600]),
                    const SizedBox(height: 12),
                    const Text(
                      'Song not found',
                      style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This track is not in our catalog yet.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _reset,
              child: const Text('Try again'),
            ),
          ] else ...[
            Center(
              child: Material(
                color: primary.withValues(alpha: 0.15),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _startIdentify,
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: Icon(Icons.mic, size: 56, color: primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('Tap to identify', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ],
      ),
    );
  }
}
