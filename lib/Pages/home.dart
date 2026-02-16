import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:music_client/Pages/player.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key, required this.title});
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
    final letters = 'abcdefghiklmnopqrstuvwxyz';
    final currentChoice = letters[Random().nextInt(letters.length)];

    final client = http.Client();
    final url = Uri.parse('https://api.deezer.com/search?q=$currentChoice');
    final res = await client.get(url);
    // int counter = 0;

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        songs = data['data'].take(20).toList();
        isLoading = false;
        isError = false;
      });
    } else {
      setState(() {
        isError = true;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: isLoading
          ? Center(child:CircularProgressIndicator())
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    child: Image.network(songs[index]['album']['cover_small']),
                  ),
                  title: Text(songs[index]['title']),
                  subtitle: Text("Album: ${songs[index]['album']['title']}"),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Player(song: songs[index]),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
