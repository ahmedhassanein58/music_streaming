import 'package:flutter/material.dart';
import 'package:music_client/Pages/home.dart';
import 'package:music_client/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await AppAudioHandler.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Echo Nova',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: HomePage(title: 'Echo Nova'),
    );
  }
}

