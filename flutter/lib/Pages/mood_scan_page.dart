import 'package:music_client/core/models/song_playback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_client/audio_service.dart';
import 'package:music_client/core/models/song_model.dart';
import 'package:music_client/core/network/emotion_repository.dart';
import 'package:music_client/core/network/history_repository.dart';
import 'package:music_client/core/providers/auth_provider.dart';

class MoodScanPage extends ConsumerStatefulWidget {
  const MoodScanPage({super.key});

  @override
  ConsumerState<MoodScanPage> createState() => _MoodScanPageState();
}

class _MoodScanPageState extends ConsumerState<MoodScanPage> {
  final EmotionRepository _emotionRepo = EmotionRepository();
  final HistoryRepository _historyRepo = HistoryRepository();
  final ImagePicker _picker = ImagePicker();

  bool _isScanning = false;
  EmotionScanResult? _result;
  String? _error;

  Future<void> _pickAndScan(ImageSource source) async {
    final auth = ref.read(authProvider);
    if (auth.status != AuthStatus.authenticated) {
      if (mounted) context.push('/login');
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() {
        _isScanning = true;
        _error = null;
        _result = null;
      });

      final result = await _emotionRepo.scanMood(picked.path);
      if (mounted) {
        setState(() {
          _result = result;
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isScanning = false;
        });
      }
    }
  }

  void _showSourceSheet() {
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
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text('Choose from gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndScan(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white70),
              title: const Text('Take photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndScan(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playSong(Song song) async {
    if (song.s3Url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Play URL not available for this song')),
      );
      return;
    }

    final handler = AppAudioHandler.instance;
    final mediaItem = song.toMediaItem();
    await handler.playMediaItem(mediaItem);
    try {
      await _historyRepo.recordPlay(song.trackId);
    } catch (_) {}
  }

  IconData _emotionIcon(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Icons.sentiment_very_satisfied;
      case 'sad':
        return Icons.sentiment_dissatisfied;
      case 'angry':
        return Icons.sentiment_very_dissatisfied;
      case 'fear':
        return Icons.sentiment_neutral;
      case 'surprise':
        return Icons.sentiment_satisfied_alt;
      case 'disgust':
        return Icons.mood_bad;
      default:
        return Icons.face;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Mood Scan')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Scan your face to detect your mood and get genre-matched music recommendations.',
            style: TextStyle(color: Colors.grey[400], height: 1.4),
          ),
          const SizedBox(height: 24),
          if (_isScanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyzing your mood...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            )
          else if (_result != null) ...[
            Card(
              color: const Color(0xFF1F2937),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(_emotionIcon(_result!.emotion), size: 64, color: primary),
                    const SizedBox(height: 12),
                    Text(
                      _result!.emotion.toUpperCase(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      '${(_result!.confidence * 100).toStringAsFixed(0)}% primary mood',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    if (_result!.moodMix.length > 1) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Mood mix',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _result!.moodMix
                            .map((m) => Chip(
                                  avatar: Icon(
                                    _emotionIcon(m.emotion),
                                    size: 18,
                                    color: primary,
                                  ),
                                  label: Text(
                                    '${m.emotion} ${(m.weight * 100).toStringAsFixed(0)}%',
                                  ),
                                  backgroundColor: primary.withOpacity(0.12),
                                  labelStyle: TextStyle(color: primary),
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _result!.mappedGenres
                          .map((g) => Chip(
                                label: Text(g),
                                backgroundColor: primary.withOpacity(0.15),
                                labelStyle: TextStyle(color: primary),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Recommended for your mood',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            if (_result!.recommendations.isEmpty)
              Text('No songs found for these genres.', style: TextStyle(color: Colors.grey[500]))
            else
              ..._result!.recommendations.map((song) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: primary.withOpacity(0.2),
                      child: Icon(Icons.music_note, color: primary),
                    ),
                    title: Text(song.title, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      '${song.artist}${song.genre.isNotEmpty ? ' · ${song.genre.join(', ')}' : ''}',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                      onPressed: () => _playSong(song),
                    ),
                  )),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _showSourceSheet,
              child: const Text('Scan again'),
            ),
          ] else ...[
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
                    Icon(Icons.face_retouching_natural, size: 56, color: primary.withOpacity(0.8)),
                    const SizedBox(height: 12),
                    const Text('No scan yet', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showSourceSheet,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Your Mood'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
    );
  }
}
