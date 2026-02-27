import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_client/core/network/auth_interceptor.dart';
import 'package:music_client/Pages/home.dart';
import 'package:music_client/Pages/player.dart';
import 'package:music_client/Pages/search/search_page.dart';
import 'package:music_client/Pages/library/library_page.dart';
import 'package:music_client/Pages/login_page.dart';
import 'package:music_client/Pages/signup.dart';
import 'package:music_client/Pages/profile_page.dart';
import 'package:music_client/audio_service.dart';
import 'package:music_client/core/theme.dart';

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
      builder: (context, state) => LibraryPage(
        showCreateDialog: state.uri.queryParameters['create'] == '1',
      ),
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

  AuthInterceptor.onUnauthorized = () {
    _router.go('/login');
  };

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
      title: 'EchoNova',
      debugShowCheckedModeBanner: false,
      theme: EchoNovaTheme.buildTheme(),
      routerConfig: _router,
    );
  }
}

