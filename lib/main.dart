import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_client/Pages/home.dart';
import 'package:music_client/Pages/player.dart';
import 'package:music_client/Pages/search/search_page.dart';
import 'package:music_client/Pages/library/library_page.dart';
import 'package:music_client/audio_service.dart';

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(title: 'Echo Nova'),
    ),
    GoRoute(
      path: '/player',
      builder: (context, state) => const Player(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchPage(),
    ),
    GoRoute(
      path: '/library',
      builder: (context, state) => const LibraryPage(),
    ),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppAudioHandler.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Echo Nova',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      routerConfig: _router,
    );
  }
}

