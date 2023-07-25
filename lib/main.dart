import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'rankList.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp]); // 세로고정
    Future<Database> database = initDatabase();

    return MaterialApp(
      title: 'Block Puzzle',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routes: {'/rankList': (context) => RankListApp(database)},
      home: Container(color: Colors.black, child: DatabaseApp(database)),
    );
  }

  Future<Database> initDatabase() async {
    return openDatabase(
      join(await getDatabasesPath(), 'block_puzzle_database.db'),
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE ranks(rankNo INTEGER PRIMARY KEY AUTOINCREMENT, "
          "rankDate TEXT, score INTEGER)",
        );
      },
      version: 1,
    );
  }
}

class DatabaseApp extends StatefulWidget {
  final Future<Database> db;
  DatabaseApp(this.db);

  @override
  State<DatabaseApp> createState() => _DatabaseAppState();
}

class _DatabaseAppState extends State<DatabaseApp> {
  @override
  Widget build(BuildContext context) {
    // return const Text('테트리스 메인 화면');
    return ElevatedButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/rankList');
        },
        child: const Text(
          'Rank',
          style: TextStyle(color: Colors.white, fontSize: 13),
        ));
  }
}
