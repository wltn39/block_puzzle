import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'rank.dart';

class RankListApp extends StatefulWidget {
  final Future<Database> database;
  RankListApp(this.database);

  @override
  State<RankListApp> createState() => _RankListAppState();
}

class _RankListAppState extends State<RankListApp> {
  @override
  Widget build(BuildContext context) {
    return const Text('게임 결과 화면');
  }
}
