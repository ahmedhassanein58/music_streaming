import 'package:flutter/material.dart';

class Player extends StatefulWidget {
  Player({Key? key, required this.song}) : super(key: key);
  final dynamic song;
  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
