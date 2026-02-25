import 'package:flutter/material.dart';
import 'package:music_client/Pages/home.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        centerTitle: true,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Library and collections coming soon'),
      ),
      bottomNavigationBar: const MainBottomNavigationBar(),
    );
  }
}

