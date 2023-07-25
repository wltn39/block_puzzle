import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'rankList.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'rank.dart';
import 'package:just_audio/just_audio.dart'; // 소리 mp3
import 'package:fluttertoast/fluttertoast.dart'; // 팝업 메시지 토스트
import 'package:fading_image_button/fading_image_button.dart'; // 이미지 버튼
import 'package:vibration/vibration.dart'; // 진동
import 'package:url_launcher/url_launcher.dart'; // 웹페이 열기에 사용
import 'package:intl/intl.dart'; // 달력

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
  State<DatabaseApp> createState() => _DatabaseApp();
}

class _DatabaseApp extends State<DatabaseApp> {
  @override
  void dispose() {
    _player.stop();
    _playerLoop.stop();
    _player.dispose();
    _playerLoop.dispose();

    super.dispose();
  }

  bool? v_flagButtonPlay = true;

  // 변수설정
  String v_image_volume = 'asset/images/volumeOn.png';
  bool v_volume = true;

  @override
  Widget build(BuildContext context) {
    // return const Text('테트리스 메인 화면');
    //   return ElevatedButton(
    //       onPressed: () {
    //         Navigator.of(context).pushNamed('/rankList');
    //       },
    //       child: const Text(
    //         'Rank',
    //         style: TextStyle(color: Colors.white, fontSize: 13),
    //       ));
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Block Puzzle',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          ElevatedButton(
            child: Image.asset(
              'asset/images/lock.png',
              height: 30,
              width: 25,
            ),
            onPressed: () async {
              if (v_flagButtonPlay == false) {
                flutter_toast(1, 'Not executed!');
              } else {
                const url = 'https://velog.io/@wltn39';
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
          ),
          ElevatedButton(
            child: Image.asset(
              'asset/images/playstore.png',
              height: 22,
              width: 25,
            ),
            onPressed: () async {
              if (v_flagButtonPlay == false) {
                flutter_toast(1, 'Not executed!');
              } else {
                const url =
                    'https://play.google.com/store/apps/details?id=com.gpldy.block_puzzle';
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
          ),
          ElevatedButton(
            child: Image.asset(
              'v_image_volume',
              height: 22,
              width: 25,
            ),
            onPressed: () {
              if (v_volume == true) {
                v_image_volume = 'asset/images/volumeOff.png';
                v_volume = false;
                if (v_flagButtonPlay == false) {
                  _playerLoop.pause();
                }
              } else {
                v_image_volume = 'asset/images/volumeOn.png';
                v_volume = true;
                if (v_flagButtonPlay == false) {
                  _playerLoop.play();
                }
              }
              setState(() {});
            },
          ),
        ],
      ),
      body: Container(),
    );
  }

  void flutter_toast(_toasttime, _toastMsg) {
    Fluttertoast.showToast(
        msg: _toastMsg,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: _toasttime,
        backgroundColor: Colors.limeAccent,
        textColor: Colors.black87,
        fontSize: 18.0);
  }

  final _player = AudioPlayer();
  Future audioPlayer(parm_mp3) async {
    await _player.setAsset(parm_mp3);
    _player.play();
  }

  final _playerLoop = AudioPlayer(); // 백그라운드 반복
  Future audioPlayerLoop(parm_mp3) async {
    await _playerLoop.setLoopMode(LoopMode.one); // 반복 설정
    await _playerLoop.setAsset(parm_mp3);
    _playerLoop.play();
  }
}
