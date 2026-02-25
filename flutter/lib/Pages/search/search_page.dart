import 'package:flutter/material.dart';
import 'package:music_client/Pages/home.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        centerTitle: true,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Search coming soon'),
      ),
      bottomNavigationBar: const MainBottomNavigationBar(),
    );
  }
}

