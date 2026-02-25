import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_client/Pages/home.dart';
import 'package:music_client/Pages/player.dart';
import 'package:music_client/Pages/search/search_page.dart';
import 'package:music_client/Pages/library/library_page.dart';
import 'package:music_client/Pages/login_page.dart';
import 'package:music_client/Pages/signup.dart';
import 'package:music_client/Pages/profile_page.dart';
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
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppAudioHandler.init();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Echo Nova',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF050814),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardColor: const Color(0xFF0C1020),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF111827),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF050814),
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Color(0xFF7C8BA1),
          showUnselectedLabels: true,
          // selectedFontSize: 12,
          // unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      routerConfig: _router,
    );
  }
}

