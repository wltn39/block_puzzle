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
import 'package:url_launcher/url_launcher.dart'; // 웹페이지 열기에 사용
import 'dart:math'; // Random 사용
import 'dart:async';

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
    _timer.cancel();

    super.dispose();
  }

  // 모든 Flag 설정
  bool? v_flagButtonPlay = true; // 게임시작 버튼
  bool? v_flagButtonStop = false; // 종료 버튼
  bool? v_flagButtonPause = false; // 대기버튼
  bool? v_flagButtonArrow = false; // 이동 버튼
  bool? v_flagNext = true; // 다음 아이템 생성 가능 여부
  bool? v_flagStartGame = true; // 게임시작 여부

  // 변수설정
  String v_image_volume = 'asset/images/volumeOn.png';
  bool v_volume = true;
  int v_level = 0; // 레벨
  int v_score = 0; // 점수

  int v_countItem = 0; // level별 아이템이 생성된 수
  late int i; // 루프용 변수
  late int j;
  late int k;
  late int l;
  late int ii;
  late int jj;
  int v_atr = 5; // list attribute 특성 1,2,3 rgb, 특성 4 on,off 1, 0
  int v_rowBox = 20; // v_listBox의 3차원배열요소수
  int v_colBox = 10;
  int v_rowNext = 4; // v_listN?Box의 3차원배열요소수
  int v_colNext = 4;
  int v_itemNo = 0; // (랜덤수 = v_itemNo)

  late int v_lineNext; // 게임판으로 아이템 가져오기를 할 라인
  late int v_lineMove; // 게임판의 1~20라인 중에 한줄 내리기를 시작할 라인
  late Timer _timer; // 타이머생성
  int v_timeInterval_base = 400;
  int v_timeInterval = 0;

  // 모든 배열 설정
  // 판배열 = v_listBox, 배열 (20행*10열*특성 5)
  // 특성 1,2,3,rgb, 특성4 이동 on,off 1,0, 특성5 고정 on off 1,0
  final v_listBox = List.generate(
      20, (i) => List.generate(10, (j) => List.generate(5, (k) => 0)));

  final v_listN1Box = List.generate(
      4, (i) => List.generate(4, (j) => List.generate(5, (k) => 0)));

  final v_listN2Box = List.generate(
      4, (i) => List.generate(4, (j) => List.generate(5, (k) => 0)));

  final v_listItem = List.generate(
      16,
      (i) => List.generate(
          4, (j) => List.generate(4, (k) => List.generate(5, (l) => 0))));

  final v_listN0Box = List.generate(
      4, (i) => List.generate(4, (j) => List.generate(5, (k) => 0)));

  //이동대상 1,2,3,4
  //배열(4행*3열)==>위치(x,y), 중심까지 거리(z)
  final v_listMove = List.generate(4, (i) => List.generate(3, (j) => 0));

  //이동대상 1,2,3,4
  //배열(4행*2열)==>위치(x,y), 중심까지 거리(z)
  final v_listMoveTarget = List.generate(4, (i) => List.generate(2, (j) => 0));

  //게임판 미러
  final v_listMirrorBox = List.generate(
      20, (i) => List.generate(10, (j) => List.generate(5, (k) => 0)));

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
              v_image_volume,
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
              ;
              setState(() {});
            },
          ),
          ElevatedButton(
              onPressed: () {
                if (v_flagButtonPlay == true) {
                  Navigator.of(context).pushNamed('/rankList');
                } else {
                  flutter_toast(1, 'Not executed!');
                }
              },
              child: const Text(
                'Rank',
                style: TextStyle(color: Colors.white, fontSize: 13),
              )),
        ],
      ),
      body: Container(
        child: Column(
          children: [
            // body 상단
            Expanded(
              flex: 15,
              child: Container(
                // color: Colors.yellow,
                child: Row(
                  children: [
                    // body 상단 좌측 200개 버튼
                    Expanded(
                      flex: 14,
                      child: Container(
                        // color: Colors.yellow,
                        margin: EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.blue,
                            width: 3,
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[0][0][0],
                                            v_listBox[0][0][1],
                                            v_listBox[0][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[0][1][0],
                                            v_listBox[0][1][1],
                                            v_listBox[0][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[0][2][0],
                                            v_listBox[0][2][1],
                                            v_listBox[0][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[0][3][0],
                                            v_listBox[0][3][1],
                                            v_listBox[0][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[0][4][0],
                                            v_listBox[0][4][1],
                                            v_listBox[0][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[0][5][0],
                                            v_listBox[0][5][1],
                                            v_listBox[0][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[0][6][0],
                                            v_listBox[0][6][1],
                                            v_listBox[0][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[0][7][0],
                                            v_listBox[0][7][1],
                                            v_listBox[0][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[0][8][0],
                                            v_listBox[0][8][1],
                                            v_listBox[0][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[0][9][0],
                                            v_listBox[0][9][1],
                                            v_listBox[0][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[1][0][0],
                                            v_listBox[1][0][1],
                                            v_listBox[1][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[1][1][0],
                                            v_listBox[1][1][1],
                                            v_listBox[1][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[1][2][0],
                                            v_listBox[1][2][1],
                                            v_listBox[1][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[1][3][0],
                                            v_listBox[1][3][1],
                                            v_listBox[1][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[1][4][0],
                                            v_listBox[1][4][1],
                                            v_listBox[1][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[1][5][0],
                                            v_listBox[1][5][1],
                                            v_listBox[1][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[1][6][0],
                                            v_listBox[1][6][1],
                                            v_listBox[1][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[1][7][0],
                                            v_listBox[1][7][1],
                                            v_listBox[1][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[1][8][0],
                                            v_listBox[1][8][1],
                                            v_listBox[1][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[1][9][0],
                                            v_listBox[1][9][1],
                                            v_listBox[1][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[2][0][0],
                                            v_listBox[2][0][1],
                                            v_listBox[2][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[2][1][0],
                                            v_listBox[2][1][1],
                                            v_listBox[2][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[2][2][0],
                                            v_listBox[2][2][1],
                                            v_listBox[2][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[2][3][0],
                                            v_listBox[2][3][1],
                                            v_listBox[2][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[2][4][0],
                                            v_listBox[2][4][1],
                                            v_listBox[2][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[2][5][0],
                                            v_listBox[2][5][1],
                                            v_listBox[2][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[2][6][0],
                                            v_listBox[2][6][1],
                                            v_listBox[2][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[2][7][0],
                                            v_listBox[2][7][1],
                                            v_listBox[2][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[2][8][0],
                                            v_listBox[2][8][1],
                                            v_listBox[2][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[2][9][0],
                                            v_listBox[2][9][1],
                                            v_listBox[2][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[3][0][0],
                                            v_listBox[3][0][1],
                                            v_listBox[3][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[3][1][0],
                                            v_listBox[3][1][1],
                                            v_listBox[3][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[3][2][0],
                                            v_listBox[3][2][1],
                                            v_listBox[3][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[3][3][0],
                                            v_listBox[3][3][1],
                                            v_listBox[3][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[3][4][0],
                                            v_listBox[3][4][1],
                                            v_listBox[3][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[3][5][0],
                                            v_listBox[3][5][1],
                                            v_listBox[3][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[3][6][0],
                                            v_listBox[3][6][1],
                                            v_listBox[3][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[3][7][0],
                                            v_listBox[3][7][1],
                                            v_listBox[3][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[3][8][0],
                                            v_listBox[3][8][1],
                                            v_listBox[3][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[3][9][0],
                                            v_listBox[3][9][1],
                                            v_listBox[3][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[4][0][0],
                                            v_listBox[4][0][1],
                                            v_listBox[4][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[4][1][0],
                                            v_listBox[4][1][1],
                                            v_listBox[4][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[4][2][0],
                                            v_listBox[4][2][1],
                                            v_listBox[4][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[4][3][0],
                                            v_listBox[4][3][1],
                                            v_listBox[4][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[4][4][0],
                                            v_listBox[4][4][1],
                                            v_listBox[4][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[4][5][0],
                                            v_listBox[4][5][1],
                                            v_listBox[4][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[4][6][0],
                                            v_listBox[4][6][1],
                                            v_listBox[4][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[4][7][0],
                                            v_listBox[4][7][1],
                                            v_listBox[4][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[4][8][0],
                                            v_listBox[4][8][1],
                                            v_listBox[4][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[4][9][0],
                                            v_listBox[4][9][1],
                                            v_listBox[4][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[5][0][0],
                                            v_listBox[5][0][1],
                                            v_listBox[5][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[5][1][0],
                                            v_listBox[5][1][1],
                                            v_listBox[5][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[5][2][0],
                                            v_listBox[5][2][1],
                                            v_listBox[5][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[5][3][0],
                                            v_listBox[5][3][1],
                                            v_listBox[5][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[5][4][0],
                                            v_listBox[5][4][1],
                                            v_listBox[5][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[5][5][0],
                                            v_listBox[5][5][1],
                                            v_listBox[5][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[5][6][0],
                                            v_listBox[5][6][1],
                                            v_listBox[5][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[5][7][0],
                                            v_listBox[5][7][1],
                                            v_listBox[5][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[5][8][0],
                                            v_listBox[5][8][1],
                                            v_listBox[5][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[5][9][0],
                                            v_listBox[5][9][1],
                                            v_listBox[5][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[6][0][0],
                                            v_listBox[6][0][1],
                                            v_listBox[6][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[6][1][0],
                                            v_listBox[6][1][1],
                                            v_listBox[6][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[6][2][0],
                                            v_listBox[6][2][1],
                                            v_listBox[6][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[6][3][0],
                                            v_listBox[6][3][1],
                                            v_listBox[6][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[6][4][0],
                                            v_listBox[6][4][1],
                                            v_listBox[6][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[6][5][0],
                                            v_listBox[6][5][1],
                                            v_listBox[6][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[6][6][0],
                                            v_listBox[6][6][1],
                                            v_listBox[6][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[6][7][0],
                                            v_listBox[6][7][1],
                                            v_listBox[6][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[6][8][0],
                                            v_listBox[6][8][1],
                                            v_listBox[6][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[6][9][0],
                                            v_listBox[6][9][1],
                                            v_listBox[6][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[7][0][0],
                                            v_listBox[7][0][1],
                                            v_listBox[7][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[7][1][0],
                                            v_listBox[7][1][1],
                                            v_listBox[7][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[7][2][0],
                                            v_listBox[7][2][1],
                                            v_listBox[7][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[7][3][0],
                                            v_listBox[7][3][1],
                                            v_listBox[7][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[7][4][0],
                                            v_listBox[7][4][1],
                                            v_listBox[7][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[7][5][0],
                                            v_listBox[7][5][1],
                                            v_listBox[7][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[7][6][0],
                                            v_listBox[7][6][1],
                                            v_listBox[7][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[7][7][0],
                                            v_listBox[7][7][1],
                                            v_listBox[7][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[7][8][0],
                                            v_listBox[7][8][1],
                                            v_listBox[7][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[7][9][0],
                                            v_listBox[7][9][1],
                                            v_listBox[7][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[8][0][0],
                                            v_listBox[8][0][1],
                                            v_listBox[8][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[8][1][0],
                                            v_listBox[8][1][1],
                                            v_listBox[8][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[8][2][0],
                                            v_listBox[8][2][1],
                                            v_listBox[8][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[8][3][0],
                                            v_listBox[8][3][1],
                                            v_listBox[8][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[8][4][0],
                                            v_listBox[8][4][1],
                                            v_listBox[8][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[8][5][0],
                                            v_listBox[8][5][1],
                                            v_listBox[8][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[8][6][0],
                                            v_listBox[8][6][1],
                                            v_listBox[8][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[8][7][0],
                                            v_listBox[8][7][1],
                                            v_listBox[8][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[8][8][0],
                                            v_listBox[8][8][1],
                                            v_listBox[8][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[8][9][0],
                                            v_listBox[8][9][1],
                                            v_listBox[8][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[9][0][0],
                                            v_listBox[9][0][1],
                                            v_listBox[9][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[9][1][0],
                                            v_listBox[9][1][1],
                                            v_listBox[9][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[9][2][0],
                                            v_listBox[9][2][1],
                                            v_listBox[9][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[9][3][0],
                                            v_listBox[9][3][1],
                                            v_listBox[9][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[9][4][0],
                                            v_listBox[9][4][1],
                                            v_listBox[9][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[9][5][0],
                                            v_listBox[9][5][1],
                                            v_listBox[9][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[9][6][0],
                                            v_listBox[9][6][1],
                                            v_listBox[9][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[9][7][0],
                                            v_listBox[9][7][1],
                                            v_listBox[9][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[9][8][0],
                                            v_listBox[9][8][1],
                                            v_listBox[9][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[9][9][0],
                                            v_listBox[9][9][1],
                                            v_listBox[9][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[10][0][0],
                                            v_listBox[10][0][1],
                                            v_listBox[10][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[10][1][0],
                                            v_listBox[10][1][1],
                                            v_listBox[10][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[10][2][0],
                                            v_listBox[10][2][1],
                                            v_listBox[10][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[10][3][0],
                                            v_listBox[10][3][1],
                                            v_listBox[10][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[10][4][0],
                                            v_listBox[10][4][1],
                                            v_listBox[10][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[10][5][0],
                                            v_listBox[10][5][1],
                                            v_listBox[10][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[10][6][0],
                                            v_listBox[10][6][1],
                                            v_listBox[10][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[10][7][0],
                                            v_listBox[10][7][1],
                                            v_listBox[10][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[10][8][0],
                                            v_listBox[10][8][1],
                                            v_listBox[10][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[10][9][0],
                                            v_listBox[10][9][1],
                                            v_listBox[10][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[11][0][0],
                                            v_listBox[11][0][1],
                                            v_listBox[11][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[11][1][0],
                                            v_listBox[11][1][1],
                                            v_listBox[11][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[11][2][0],
                                            v_listBox[11][2][1],
                                            v_listBox[11][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[11][3][0],
                                            v_listBox[11][3][1],
                                            v_listBox[11][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[11][4][0],
                                            v_listBox[11][4][1],
                                            v_listBox[11][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[11][5][0],
                                            v_listBox[11][5][1],
                                            v_listBox[11][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[11][6][0],
                                            v_listBox[11][6][1],
                                            v_listBox[11][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[11][7][0],
                                            v_listBox[11][7][1],
                                            v_listBox[11][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[11][8][0],
                                            v_listBox[11][8][1],
                                            v_listBox[11][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[11][9][0],
                                            v_listBox[11][9][1],
                                            v_listBox[11][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[12][0][0],
                                            v_listBox[12][0][1],
                                            v_listBox[12][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[12][1][0],
                                            v_listBox[12][1][1],
                                            v_listBox[12][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[12][2][0],
                                            v_listBox[12][2][1],
                                            v_listBox[12][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[12][3][0],
                                            v_listBox[12][3][1],
                                            v_listBox[12][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[12][4][0],
                                            v_listBox[12][4][1],
                                            v_listBox[12][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[12][5][0],
                                            v_listBox[12][5][1],
                                            v_listBox[12][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[12][6][0],
                                            v_listBox[12][6][1],
                                            v_listBox[12][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[12][7][0],
                                            v_listBox[12][7][1],
                                            v_listBox[12][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[12][8][0],
                                            v_listBox[12][8][1],
                                            v_listBox[12][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[12][9][0],
                                            v_listBox[12][9][1],
                                            v_listBox[12][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[13][0][0],
                                            v_listBox[13][0][1],
                                            v_listBox[13][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[13][1][0],
                                            v_listBox[13][1][1],
                                            v_listBox[13][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[13][2][0],
                                            v_listBox[13][2][1],
                                            v_listBox[13][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[13][3][0],
                                            v_listBox[13][3][1],
                                            v_listBox[13][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[13][4][0],
                                            v_listBox[13][4][1],
                                            v_listBox[13][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[13][5][0],
                                            v_listBox[13][5][1],
                                            v_listBox[13][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[13][6][0],
                                            v_listBox[13][6][1],
                                            v_listBox[13][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[13][7][0],
                                            v_listBox[13][7][1],
                                            v_listBox[13][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[13][8][0],
                                            v_listBox[13][8][1],
                                            v_listBox[13][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[13][9][0],
                                            v_listBox[13][9][1],
                                            v_listBox[13][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[14][0][0],
                                            v_listBox[14][0][1],
                                            v_listBox[14][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[14][1][0],
                                            v_listBox[14][1][1],
                                            v_listBox[14][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[14][2][0],
                                            v_listBox[14][2][1],
                                            v_listBox[14][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[14][3][0],
                                            v_listBox[14][3][1],
                                            v_listBox[14][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[14][4][0],
                                            v_listBox[14][4][1],
                                            v_listBox[14][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[14][5][0],
                                            v_listBox[14][5][1],
                                            v_listBox[14][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[14][6][0],
                                            v_listBox[14][6][1],
                                            v_listBox[14][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[14][7][0],
                                            v_listBox[14][7][1],
                                            v_listBox[14][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[14][8][0],
                                            v_listBox[14][8][1],
                                            v_listBox[14][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[14][9][0],
                                            v_listBox[14][9][1],
                                            v_listBox[14][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[15][0][0],
                                            v_listBox[15][0][1],
                                            v_listBox[15][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[15][1][0],
                                            v_listBox[15][1][1],
                                            v_listBox[15][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[15][2][0],
                                            v_listBox[15][2][1],
                                            v_listBox[15][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[15][3][0],
                                            v_listBox[15][3][1],
                                            v_listBox[15][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[15][4][0],
                                            v_listBox[15][4][1],
                                            v_listBox[15][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[15][5][0],
                                            v_listBox[15][5][1],
                                            v_listBox[15][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[15][6][0],
                                            v_listBox[15][6][1],
                                            v_listBox[15][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[15][7][0],
                                            v_listBox[15][7][1],
                                            v_listBox[15][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[15][8][0],
                                            v_listBox[15][8][1],
                                            v_listBox[15][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[15][9][0],
                                            v_listBox[15][9][1],
                                            v_listBox[15][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[16][0][0],
                                            v_listBox[16][0][1],
                                            v_listBox[16][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[16][1][0],
                                            v_listBox[16][1][1],
                                            v_listBox[16][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[16][2][0],
                                            v_listBox[16][2][1],
                                            v_listBox[16][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[16][3][0],
                                            v_listBox[16][3][1],
                                            v_listBox[16][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[16][4][0],
                                            v_listBox[16][4][1],
                                            v_listBox[16][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[16][5][0],
                                            v_listBox[16][5][1],
                                            v_listBox[16][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[16][6][0],
                                            v_listBox[16][6][1],
                                            v_listBox[16][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[16][7][0],
                                            v_listBox[16][7][1],
                                            v_listBox[16][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[16][8][0],
                                            v_listBox[16][8][1],
                                            v_listBox[16][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[16][9][0],
                                            v_listBox[16][9][1],
                                            v_listBox[16][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[17][0][0],
                                            v_listBox[17][0][1],
                                            v_listBox[17][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[17][1][0],
                                            v_listBox[17][1][1],
                                            v_listBox[17][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[17][2][0],
                                            v_listBox[17][2][1],
                                            v_listBox[17][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[17][3][0],
                                            v_listBox[17][3][1],
                                            v_listBox[17][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[17][4][0],
                                            v_listBox[17][4][1],
                                            v_listBox[17][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[17][5][0],
                                            v_listBox[17][5][1],
                                            v_listBox[17][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[17][6][0],
                                            v_listBox[17][6][1],
                                            v_listBox[17][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[17][7][0],
                                            v_listBox[17][7][1],
                                            v_listBox[17][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[17][8][0],
                                            v_listBox[17][8][1],
                                            v_listBox[17][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[17][9][0],
                                            v_listBox[17][9][1],
                                            v_listBox[17][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[18][0][0],
                                            v_listBox[18][0][1],
                                            v_listBox[18][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[18][1][0],
                                            v_listBox[18][1][1],
                                            v_listBox[18][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[18][2][0],
                                            v_listBox[18][2][1],
                                            v_listBox[18][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[18][3][0],
                                            v_listBox[18][3][1],
                                            v_listBox[18][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[18][4][0],
                                            v_listBox[18][4][1],
                                            v_listBox[18][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[18][5][0],
                                            v_listBox[18][5][1],
                                            v_listBox[18][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[18][6][0],
                                            v_listBox[18][6][1],
                                            v_listBox[18][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[18][7][0],
                                            v_listBox[18][7][1],
                                            v_listBox[18][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[18][8][0],
                                            v_listBox[18][8][1],
                                            v_listBox[18][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[18][9][0],
                                            v_listBox[18][9][1],
                                            v_listBox[18][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[19][0][0],
                                            v_listBox[19][0][1],
                                            v_listBox[19][0][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[19][1][0],
                                            v_listBox[19][1][1],
                                            v_listBox[19][1][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[19][2][0],
                                            v_listBox[19][2][1],
                                            v_listBox[19][2][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[19][3][0],
                                            v_listBox[19][3][1],
                                            v_listBox[19][3][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[19][4][0],
                                            v_listBox[19][4][1],
                                            v_listBox[19][4][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[19][5][0],
                                            v_listBox[19][5][1],
                                            v_listBox[19][5][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[19][6][0],
                                            v_listBox[19][6][1],
                                            v_listBox[19][6][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[19][7][0],
                                            v_listBox[19][7][1],
                                            v_listBox[19][7][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[19][8][0],
                                            v_listBox[19][8][1],
                                            v_listBox[19][8][2],
                                            1),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        margin: EdgeInsets.all(1),
                                        color: Color.fromRGBO(
                                            v_listBox[19][9][0],
                                            v_listBox[19][9][1],
                                            v_listBox[19][9][2],
                                            1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // body 상단 우측
                    Expanded(
                      flex: 6,
                      child: Container(
                          // color: Colors.red,
                          child: Column(children: [
                        // body 상단 우측 Next1
                        Expanded(
                          flex: 6,
                          child: Container(
                            // color: Colors.red,
                            child: Column(children: [
                              Expanded(
                                flex: 2,
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(5, 0, 5, 5),
                                  alignment: Alignment.bottomLeft,
                                  child: Text(
                                    'Next 1',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              // body 상단 우측 Next1 16개 박스
                              Expanded(
                                flex: 5,
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(5, 0, 10, 0),
                                  color: Colors.white24,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[0][0][0],
                                                      v_listN1Box[0][0][1],
                                                      v_listN1Box[0][0][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[0][1][0],
                                                      v_listN1Box[0][1][1],
                                                      v_listN1Box[0][1][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[0][2][0],
                                                      v_listN1Box[0][2][1],
                                                      v_listN1Box[0][2][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[0][3][0],
                                                      v_listN1Box[0][3][1],
                                                      v_listN1Box[0][3][2],
                                                      1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[1][0][0],
                                                      v_listN1Box[1][0][1],
                                                      v_listN1Box[1][0][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[1][1][0],
                                                      v_listN1Box[1][1][1],
                                                      v_listN1Box[1][1][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[1][2][0],
                                                      v_listN1Box[1][2][1],
                                                      v_listN1Box[1][2][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[1][3][0],
                                                      v_listN1Box[1][3][1],
                                                      v_listN1Box[1][3][2],
                                                      1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[2][0][0],
                                                      v_listN1Box[2][0][1],
                                                      v_listN1Box[2][0][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[2][1][0],
                                                      v_listN1Box[2][1][1],
                                                      v_listN1Box[2][1][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[2][2][0],
                                                      v_listN1Box[2][2][1],
                                                      v_listN1Box[2][2][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[2][3][0],
                                                      v_listN1Box[2][3][1],
                                                      v_listN1Box[2][3][2],
                                                      1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[3][0][0],
                                                      v_listN1Box[3][0][1],
                                                      v_listN1Box[3][0][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[3][1][0],
                                                      v_listN1Box[3][1][1],
                                                      v_listN1Box[3][1][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[3][2][0],
                                                      v_listN1Box[3][2][1],
                                                      v_listN1Box[3][2][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN1Box[3][3][0],
                                                      v_listN1Box[3][3][1],
                                                      v_listN1Box[3][3][2],
                                                      1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ),

                        Expanded(
                          flex: 6,
                          child: Container(
                            // color: Colors.red,
                            child: Column(children: [
                              Expanded(
                                flex: 2,
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(5, 0, 5, 5),
                                  alignment: Alignment.bottomLeft,
                                  child: Text(
                                    'Next 2',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              // body 상단 우측 Next2 16개 박스
                              Expanded(
                                flex: 5,
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(5, 0, 10, 0),
                                  color: Colors.white24,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[0][0][0],
                                                      v_listN2Box[0][0][1],
                                                      v_listN2Box[0][0][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[0][1][0],
                                                      v_listN2Box[0][1][1],
                                                      v_listN2Box[0][1][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[0][2][0],
                                                      v_listN2Box[0][2][1],
                                                      v_listN2Box[0][2][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[0][3][0],
                                                      v_listN2Box[0][3][1],
                                                      v_listN2Box[0][3][2],
                                                      1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[1][0][0],
                                                      v_listN2Box[1][0][1],
                                                      v_listN2Box[1][0][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[1][1][0],
                                                      v_listN2Box[1][1][1],
                                                      v_listN2Box[1][1][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[1][2][0],
                                                      v_listN2Box[1][2][1],
                                                      v_listN2Box[1][2][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[1][3][0],
                                                      v_listN2Box[1][3][1],
                                                      v_listN2Box[1][3][2],
                                                      1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[2][0][0],
                                                      v_listN2Box[2][0][1],
                                                      v_listN2Box[2][0][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[2][1][0],
                                                      v_listN2Box[2][1][1],
                                                      v_listN2Box[2][1][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[2][2][0],
                                                      v_listN2Box[2][2][1],
                                                      v_listN2Box[2][2][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[2][3][0],
                                                      v_listN2Box[2][3][1],
                                                      v_listN2Box[2][3][2],
                                                      1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[3][0][0],
                                                      v_listN2Box[3][0][1],
                                                      v_listN2Box[3][0][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[3][1][0],
                                                      v_listN2Box[3][1][1],
                                                      v_listN2Box[3][1][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[3][2][0],
                                                      v_listN2Box[3][2][1],
                                                      v_listN2Box[3][2][2],
                                                      1),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  margin: EdgeInsets.all(1),
                                                  color: Color.fromRGBO(
                                                      v_listN2Box[3][3][0],
                                                      v_listN2Box[3][3][1],
                                                      v_listN2Box[3][3][2],
                                                      1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ),
                        // body 상단 우측 레벨, 점수
                        Expanded(
                          flex: 8,
                          child: Container(
                            // color: Colors.white,
                            margin: EdgeInsets.fromLTRB(0, 50, 5, 0),
                            child: Column(children: [
                              Expanded(
                                flex: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          alignment: Alignment.center,
                                          margin:
                                              EdgeInsets.fromLTRB(4, 4, 4, 0),
                                          child: Text(
                                            'Level',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          decoration: BoxDecoration(
                                              color: Colors.yellow),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          alignment: Alignment.center,
                                          margin:
                                              EdgeInsets.fromLTRB(4, 0, 4, 4),
                                          child: Text(
                                            v_level.toString(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 2),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                            alignment: Alignment.center,
                                            margin:
                                                EdgeInsets.fromLTRB(4, 4, 4, 0),
                                            child: Text(
                                              'Score',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                            )),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          alignment: Alignment.center,
                                          margin:
                                              EdgeInsets.fromLTRB(4, 0, 4, 4),
                                          child: Text(v_score.toString(),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              )),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            ]),
                          ),
                        ),
                        // 상단 우측 빈칸
                        Expanded(
                          flex: 1,
                          child: Container(
                              // color: Colors.green,
                              ),
                        ),
                      ])),
                    ),
                  ],
                ),
              ),
            ),

            // body 하단
            Expanded(
              flex: 5,
              child: Container(
                // color: Colors.blue,
                child: Row(
                  children: [
                    // body 하단 좌측 방향키
                    Expanded(
                      flex: 14,
                      child: Container(
                        // color: Colors.pink,
                        margin: EdgeInsets.fromLTRB(15, 5, 0, 15),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // body 하단 좌측 방향키 상단
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Container(),
                                    ),
                                    // body 하단 상단 회전버튼
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        child: FadingImageButton(
                                          onPressed: () => {
                                            if (v_flagButtonArrow == true)
                                              {press_arrow_rotate()}
                                            else
                                              {
                                                flutter_toast(
                                                    0.5, 'Not executed!')
                                              }
                                          },
                                          image: Image.asset(
                                              "asset/images/rotate.png"),
                                          onPressedImage: Image.asset(
                                              "asset/images/rotate_b.png"),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // body 좌측 방향키 버튼
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Row(
                                  children: [
                                    // body 하단 좌측 좌버튼
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        child: FadingImageButton(
                                          onPressed: () => {
                                            if (v_flagButtonArrow == true)
                                              {press_arrow_left()}
                                            else
                                              {
                                                flutter_toast(
                                                    0.5, 'Not executed')
                                              }
                                          },
                                          image: Image.asset(
                                              "asset/images/left.png"),
                                          onPressedImage: Image.asset(
                                              "asset/images/left_b.png"),
                                        ),
                                      ),
                                    ),
                                    // 하단 중앙 하버튼
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        child: FadingImageButton(
                                          onPressed: () => {
                                            if (v_flagButtonArrow == true)
                                              {press_arrow_down()}
                                            else
                                              {
                                                flutter_toast(
                                                    0.5, 'Not executed!')
                                              }
                                          },
                                          image: Image.asset(
                                              "asset/images/down.png"),
                                          onPressedImage: Image.asset(
                                              "asset/images/down_b.png"),
                                        ),
                                      ),
                                    ),
                                    // 하단 우측 우버튼
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        child: FadingImageButton(
                                          onPressed: () => {
                                            if (v_flagButtonArrow == true)
                                              {press_arrow_right()}
                                            else
                                              {
                                                flutter_toast(
                                                    0.5, 'Not executed!')
                                              }
                                          },
                                          image: Image.asset(
                                              "asset/images/right.png"),
                                          onPressedImage: Image.asset(
                                              "asset/images/right_b.png"),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 6,
                      child: Container(
                        // color: Colors.amber,
                        margin: EdgeInsets.fromLTRB(25, 5, 0, 0),
                        child: Column(
                          children: [
                            // body 하단 우측 게임시작버튼
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: FadingImageButton(
                                  onPressed: () => {
                                    if (v_flagButtonPlay == true)
                                      {press_play()}
                                    else
                                      {flutter_toast(1, 'Not executed!')}
                                  },
                                  image: Image.asset("asset/images/play.png"),
                                  onPressedImage:
                                      Image.asset("asset/images/play_b.png"),
                                ),
                              ),
                            ),
                            // body 하단 우측 게임시작버튼
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: FadingImageButton(
                                  onPressed: () => {},
                                  image: Image.asset("asset/images/stop.png"),
                                  onPressedImage:
                                      Image.asset("asset/images/stop_b.png"),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: FadingImageButton(
                                  onPressed: () => {},
                                  image: Image.asset("asset/images/pause.png"),
                                  onPressedImage:
                                      Image.asset("asset/images/pause_b.png"),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 63,
      ),
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

  @override
  void initState() {
    super.initState();

    v_listItem[0][0][0][0] = 4; // 아이템 라인수
    v_listItem[0][0][1][0] = 255;
    v_listItem[0][0][1][1] = 0;
    v_listItem[0][0][1][2] = 0;
    v_listItem[0][0][1][3] = 1;
    v_listItem[0][1][1][0] = 255;
    v_listItem[0][1][1][1] = 0;
    v_listItem[0][1][1][2] = 0;
    v_listItem[0][1][1][3] = 1;
    v_listItem[0][2][1][0] = 255;
    v_listItem[0][2][1][1] = 0;
    v_listItem[0][2][1][2] = 0;
    v_listItem[0][2][1][3] = 1;
    v_listItem[0][3][1][0] = 255;
    v_listItem[0][3][1][1] = 0;
    v_listItem[0][3][1][2] = 0;
    v_listItem[0][3][1][3] = 1;

    v_listItem[1][0][0][0] = 2; // 아이템 라인수
    v_listItem[1][2][0][0] = 255;
    v_listItem[1][2][0][1] = 228;
    v_listItem[1][2][0][2] = 0;
    v_listItem[1][2][0][3] = 1;
    v_listItem[1][2][1][0] = 255;
    v_listItem[1][2][1][1] = 228;
    v_listItem[1][2][1][2] = 0;
    v_listItem[1][2][1][3] = 1;
    v_listItem[1][3][1][0] = 255;
    v_listItem[1][3][1][1] = 228;
    v_listItem[1][3][1][2] = 0;
    v_listItem[1][3][1][3] = 1;
    v_listItem[1][3][2][0] = 255;
    v_listItem[1][3][2][1] = 228;
    v_listItem[1][3][2][2] = 0;
    v_listItem[1][3][2][3] = 1;

    v_listItem[2][0][0][0] = 2; // 아이템 라인수
    v_listItem[2][2][0][0] = 29;
    v_listItem[2][2][0][1] = 219;
    v_listItem[2][2][0][2] = 22;
    v_listItem[2][2][0][3] = 1;
    v_listItem[2][2][1][0] = 29;
    v_listItem[2][2][1][1] = 219;
    v_listItem[2][2][1][2] = 22;
    v_listItem[2][2][1][3] = 1;
    v_listItem[2][2][2][0] = 29;
    v_listItem[2][2][2][1] = 219;
    v_listItem[2][2][2][2] = 22;
    v_listItem[2][2][2][3] = 1;
    v_listItem[2][3][1][0] = 29;
    v_listItem[2][3][1][1] = 219;
    v_listItem[2][3][1][2] = 22;
    v_listItem[2][3][1][3] = 1;

    v_listItem[3][0][0][0] = 3; // 아이템 라인수
    v_listItem[3][1][2][0] = 76;
    v_listItem[3][1][2][1] = 76;
    v_listItem[3][1][2][2] = 76;
    v_listItem[3][1][2][3] = 1;
    v_listItem[3][2][2][0] = 76;
    v_listItem[3][2][2][1] = 76;
    v_listItem[3][2][2][2] = 76;
    v_listItem[3][2][2][3] = 1;
    v_listItem[3][3][1][0] = 76;
    v_listItem[3][3][1][1] = 76;
    v_listItem[3][3][1][2] = 76;
    v_listItem[3][3][1][3] = 1;
    v_listItem[3][3][2][0] = 76;
    v_listItem[3][3][2][1] = 76;
    v_listItem[3][3][2][2] = 76;
    v_listItem[3][3][2][3] = 1;

    v_listItem[4][0][0][0] = 1; // 아이템 라인수
    v_listItem[4][3][0][0] = 171;
    v_listItem[4][3][0][1] = 242;
    v_listItem[4][3][0][2] = 0;
    v_listItem[4][3][0][3] = 1;
    v_listItem[4][3][1][0] = 171;
    v_listItem[4][3][1][1] = 242;
    v_listItem[4][3][1][2] = 0;
    v_listItem[4][3][1][3] = 1;
    v_listItem[4][3][2][0] = 171;
    v_listItem[4][3][2][1] = 242;
    v_listItem[4][3][2][2] = 0;
    v_listItem[4][3][2][3] = 1;
    v_listItem[4][3][3][0] = 171;
    v_listItem[4][3][3][1] = 242;
    v_listItem[4][3][3][2] = 0;
    v_listItem[4][3][3][3] = 1;

    v_listItem[5][0][0][0] = 2; // 아이템 라인수
    v_listItem[5][2][1][0] = 95;
    v_listItem[5][2][1][1] = 0;
    v_listItem[5][2][1][2] = 255;
    v_listItem[5][2][1][3] = 1;
    v_listItem[5][2][2][0] = 95;
    v_listItem[5][2][2][1] = 0;
    v_listItem[5][2][2][2] = 255;
    v_listItem[5][2][2][3] = 1;
    v_listItem[5][3][1][0] = 95;
    v_listItem[5][3][1][1] = 0;
    v_listItem[5][3][1][2] = 255;
    v_listItem[5][3][1][3] = 1;
    v_listItem[5][3][2][0] = 95;
    v_listItem[5][3][2][1] = 0;
    v_listItem[5][3][2][2] = 255;
    v_listItem[5][3][2][3] = 1;

    v_listItem[6][0][0][0] = 3; // 아이템 라인수
    v_listItem[6][1][2][0] = 0;
    v_listItem[6][1][2][1] = 84;
    v_listItem[6][1][2][2] = 255;
    v_listItem[6][1][2][3] = 1;
    v_listItem[6][2][1][0] = 0;
    v_listItem[6][2][1][1] = 84;
    v_listItem[6][2][1][2] = 255;
    v_listItem[6][2][1][3] = 1;
    v_listItem[6][2][2][0] = 0;
    v_listItem[6][2][2][1] = 84;
    v_listItem[6][2][2][2] = 255;
    v_listItem[6][2][2][3] = 1;
    v_listItem[6][3][2][0] = 0;
    v_listItem[6][3][2][1] = 84;
    v_listItem[6][3][2][2] = 255;
    v_listItem[6][3][2][3] = 1;

    v_listItem[7][0][0][0] = 2; // 아이템 라인수
    v_listItem[7][2][1][0] = 255;
    v_listItem[7][2][1][1] = 94;
    v_listItem[7][2][1][2] = 0;
    v_listItem[7][2][1][3] = 1;
    v_listItem[7][2][2][0] = 255;
    v_listItem[7][2][2][1] = 94;
    v_listItem[7][2][2][2] = 0;
    v_listItem[7][2][2][3] = 1;
    v_listItem[7][2][3][0] = 255;
    v_listItem[7][2][3][1] = 94;
    v_listItem[7][2][3][2] = 0;
    v_listItem[7][2][3][3] = 1;
    v_listItem[7][3][1][0] = 255;
    v_listItem[7][3][1][1] = 94;
    v_listItem[7][3][1][2] = 0;
    v_listItem[7][3][1][3] = 1;

    v_listItem[8][0][0][0] = 2; // 아이템 라인수
    v_listItem[8][2][1][0] = 255;
    v_listItem[8][2][1][1] = 187;
    v_listItem[8][2][1][2] = 0;
    v_listItem[8][2][1][3] = 1;
    v_listItem[8][3][0][0] = 255;
    v_listItem[8][3][0][1] = 187;
    v_listItem[8][3][0][2] = 0;
    v_listItem[8][3][0][3] = 1;
    v_listItem[8][3][1][0] = 255;
    v_listItem[8][3][1][1] = 187;
    v_listItem[8][3][1][2] = 0;
    v_listItem[8][3][1][3] = 1;
    v_listItem[8][3][2][0] = 255;
    v_listItem[8][3][2][1] = 187;
    v_listItem[8][3][2][2] = 0;
    v_listItem[8][3][2][3] = 1;

    v_listItem[9][0][0][0] = 2; // 아이템 라인수
    v_listItem[9][2][1][0] = 0;
    v_listItem[9][2][1][1] = 216;
    v_listItem[9][2][1][2] = 255;
    v_listItem[9][2][1][3] = 1;
    v_listItem[9][2][2][0] = 0;
    v_listItem[9][2][2][1] = 216;
    v_listItem[9][2][2][2] = 255;
    v_listItem[9][2][2][3] = 1;
    v_listItem[9][3][0][0] = 0;
    v_listItem[9][3][0][1] = 216;
    v_listItem[9][3][0][2] = 255;
    v_listItem[9][3][0][3] = 1;
    v_listItem[9][3][1][0] = 0;
    v_listItem[9][3][1][1] = 216;
    v_listItem[9][3][1][2] = 255;
    v_listItem[9][3][1][3] = 1;

    v_listItem[10][0][0][0] = 3; // 아이템 라인수
    v_listItem[10][1][1][0] = 200;
    v_listItem[10][1][1][1] = 200;
    v_listItem[10][1][1][2] = 200;
    v_listItem[10][1][1][3] = 1;
    v_listItem[10][2][1][0] = 200;
    v_listItem[10][2][1][1] = 200;
    v_listItem[10][2][1][2] = 200;
    v_listItem[10][2][1][3] = 1;
    v_listItem[10][2][2][0] = 200;
    v_listItem[10][2][2][1] = 200;
    v_listItem[10][2][2][2] = 200;
    v_listItem[10][2][2][3] = 1;
    v_listItem[10][3][1][0] = 200;
    v_listItem[10][3][1][1] = 200;
    v_listItem[10][3][1][2] = 200;
    v_listItem[10][3][1][3] = 1;

    v_listItem[11][0][0][0] = 2; // 아이템 라인수
    v_listItem[11][2][1][0] = 191;
    v_listItem[11][2][1][1] = 33;
    v_listItem[11][2][1][2] = 243;
    v_listItem[11][2][1][3] = 1;
    v_listItem[11][3][1][0] = 191;
    v_listItem[11][3][1][1] = 33;
    v_listItem[11][3][1][2] = 243;
    v_listItem[11][3][1][3] = 1;
    v_listItem[11][3][2][0] = 191;
    v_listItem[11][3][2][1] = 33;
    v_listItem[11][3][2][2] = 243;
    v_listItem[11][3][2][3] = 1;
    v_listItem[11][3][3][0] = 191;
    v_listItem[11][3][3][1] = 33;
    v_listItem[11][3][3][2] = 243;
    v_listItem[11][3][3][3] = 1;

    v_listItem[12][0][0][0] = 2; // 아이템 라인수
    v_listItem[12][2][1][0] = 243;
    v_listItem[12][2][1][1] = 72;
    v_listItem[12][2][1][2] = 33;
    v_listItem[12][2][1][3] = 1;
    v_listItem[12][2][2][0] = 243;
    v_listItem[12][2][2][1] = 72;
    v_listItem[12][2][2][2] = 33;
    v_listItem[12][2][2][3] = 1;
    v_listItem[12][3][1][0] = 243;
    v_listItem[12][3][1][1] = 72;
    v_listItem[12][3][1][2] = 33;
    v_listItem[12][3][1][3] = 1;
    v_listItem[12][3][2][0] = 243;
    v_listItem[12][3][2][1] = 72;
    v_listItem[12][3][2][2] = 33;
    v_listItem[12][3][2][3] = 1;

    v_listItem[13][0][0][0] = 3; // 아이템 라인수
    v_listItem[13][1][1][0] = 33;
    v_listItem[13][1][1][1] = 243;
    v_listItem[13][1][1][2] = 225;
    v_listItem[13][1][1][3] = 1;
    v_listItem[13][2][1][0] = 33;
    v_listItem[13][2][1][1] = 243;
    v_listItem[13][2][1][2] = 225;
    v_listItem[13][2][1][3] = 1;
    v_listItem[13][3][1][0] = 33;
    v_listItem[13][3][1][1] = 243;
    v_listItem[13][3][1][2] = 225;
    v_listItem[13][3][1][3] = 1;
    v_listItem[13][3][2][0] = 33;
    v_listItem[13][3][2][1] = 243;
    v_listItem[13][3][2][2] = 225;
    v_listItem[13][3][2][3] = 1;

    v_listItem[14][0][0][0] = 3; // 아이템 라인수
    v_listItem[14][1][1][0] = 215;
    v_listItem[14][1][1][1] = 243;
    v_listItem[14][1][1][2] = 33;
    v_listItem[14][1][1][3] = 1;
    v_listItem[14][2][1][0] = 215;
    v_listItem[14][2][1][1] = 243;
    v_listItem[14][2][1][2] = 33;
    v_listItem[14][2][1][3] = 1;
    v_listItem[14][2][2][0] = 215;
    v_listItem[14][2][2][1] = 243;
    v_listItem[14][2][2][2] = 33;
    v_listItem[14][2][2][3] = 1;
    v_listItem[14][3][2][0] = 215;
    v_listItem[14][3][2][1] = 243;
    v_listItem[14][3][2][2] = 33;
    v_listItem[14][3][2][3] = 1;

    v_listItem[15][0][0][0] = 3; // 아이템 라인수
    v_listItem[15][1][2][0] = 243;
    v_listItem[15][1][2][1] = 33;
    v_listItem[15][1][2][2] = 239;
    v_listItem[15][1][2][3] = 1;
    v_listItem[15][2][1][0] = 243;
    v_listItem[15][2][1][1] = 33;
    v_listItem[15][2][1][2] = 239;
    v_listItem[15][2][1][3] = 1;
    v_listItem[15][2][2][0] = 243;
    v_listItem[15][2][2][1] = 33;
    v_listItem[15][2][2][2] = 239;
    v_listItem[15][2][2][3] = 1;
    v_listItem[15][3][1][0] = 243;
    v_listItem[15][3][1][1] = 33;
    v_listItem[15][3][1][2] = 239;
    v_listItem[15][3][1][3] = 1;
  }

  void step_initial() {
    v_flagNext = true;
    v_countItem = 0;
    if (v_flagStartGame == true) {
      // 처음 시작했으면
      v_level = 1; // 레벨
      v_score = 0; // 점수란
      v_flagStartGame = false;
    } else {
      v_level++;
    }

    for (i = 0; i < v_rowBox; i++) {
      for (j = 0; j < v_colBox; j++) {
        for (k = 0; k < v_atr; k++) {
          v_listBox[i][j][k] = 0;
        }
      }
    }
  }

  // Next1 생성
  void step_initial_next1() {
    if (v_listN2Box[0][0][0] == 0) {
      // n2 박스에 아이템이 없으면 랜덤하게 아이템을 선택해 n1 박스에 복사
      v_itemNo = Random().nextInt(16); // 랜덤수 = v_itemNo 0~15
      for (i = 0; i < v_rowNext; i++) {
        for (j = 0; j < v_colNext; j++) {
          for (k = 0; k < v_atr; k++) {
            v_listN1Box[i][j][k] = v_listItem[v_itemNo][i][j][k];
          }
        }
      }
    } else {
      // n2 박스에 아이템이 있으면 n2 박스를 n1 박스에 복사
      for (i = 0; i < v_rowNext; i++) {
        for (j = 0; j < v_colNext; j++) {
          for (k = 0; k < v_atr; k++) {
            v_listN2Box[i][j][k] = v_listItem[v_itemNo][i][j][k];
          }
        }
      }
    }
  }

//Next2 생성
  void step_initial_next2() {
    //랜덤하게 아이템을 선택해 n2 박스에 복사
    v_itemNo = Random().nextInt(16); // 랜덤수 = 아이템번호 0~15
    //print(v_itemNo);
    for (i = 0; i < v_rowNext; i++) {
      for (j = 0; j < v_colNext; j++) {
        for (k = 0; k < v_rowNext; k++) {
          v_listN2Box[i][j][k] = v_listItem[v_itemNo][i][j][k];
        }
      }
    }
  }

  //이벤트 - 게임시작 버튼을 누르면
  void press_play() {
    v_flagButtonPlay = false; // false 는 버튼을 못누름
    v_flagButtonStop = true;
    v_flagButtonPause = true;
    v_flagButtonArrow = true;

    step_initial();
    step_initial_next1();
    step_initial_next2();

    setState(() {});

    v_timeInterval = v_timeInterval_base - ((v_level - 1) * 50);
    v_timeInterval < 50 ? 50 : v_timeInterval;
    step_timer();
  }

  void step_get_listN0Box() {
    //4,5,6,7 칸에 고정이 있으면 게임종료
    for (i = 0; i < v_colNext; i++) {
      for (j = 0; j < v_atr; j++) {
        if (v_listBox[0][i + 3][v_atr - 1] == 1) {
          step_end_play();
          return;
        }
      }
    }

    if (v_listN0Box[0][0][0] >= v_lineNext) {
      // n0 라인수가 가져올 라인수보다 작지 않으면 n0의 1 라인을 게임판 4,5,6,7 칸으로 가져옴
      for (i = 0; i < v_colNext; i++) {
        for (j = 0; j < v_atr; j++) {
          v_listBox[0][i + 3][j] = v_listN0Box[v_rowNext - v_lineNext][i][j];
        }
      }
      v_lineNext++;
    }
  }

  //레벨실패
  void step_end_play() {
    _timer.cancel();
    v_flagButtonPlay = true; // false 는 버튼을 못누름
    v_flagButtonStop = false;
    v_flagButtonPause = false;
    v_flagButtonArrow = false;
    _insert();
    flutter_toast(2, 'Game Over!');
    v_flagStartGame = true;
  }

  void _insert() async {
    String _today = DateFormat('yyyy-MM-dd hh:mm:ss').format(DateTime.now());

    final Database database = await widget.db;
    await database.rawUpdate(
        "inset into ranks (rankDate, score) values ('$_today', '$v_score)");
  }

  // 타이머 가동
  void step_timer() {
    _timer = Timer.periodic(Duration(milliseconds: v_timeInterval), (_timer) {
      // 정해진 시간(0.4초)에 한번씩 실행됨
      // step_create_Next(); // n0 생성
      // step_get_listN0Box(); // n0 에 있는 아이템 1줄을 게임판 1번줄 4,5,6,7칸에 옮겨옴

      if (v_flagNext == true) {
        step_create_Next(); // true 면 아이템 생성
        v_flagNext = false; // 아이템 생성은 종료
      } else {
        step_lineDown_listBox(); // 게임판으로 가져온 아이템을 밑으로 한줄 내림
      }
      step_get_listN0Box(); // n0에 있는 아이템을 1줄을 게임판 1번줄 4,5,6,7칸에 옮겨옴
      setState(() {});
      if (v_flagNext == true) step_check_line(); // 체크_줄깨기

      //40개의 아이템이 생성되면 레벨성공
      if (v_countItem > 40) {
        step_end_level();
      }
    });
  }

  //레벨성공
  void step_end_level() {
    _timer.cancel();
    v_flagButtonPlay = true;
    v_flagButtonStop = false;
    v_flagButtonPause = false;
    v_flagButtonArrow = false;
    v_countItem = 0;
    v_score = v_score + 300;
    flutter_toast(2, 'Level Success!');
  }

  // 아이템을 next1 => next0, next2 => next1 로 옮김
  void step_create_Next() {
    //n1박스를 n0 박스에 복사
    for (i = 0; i < v_rowNext; i++) {
      for (j = 0; j < v_colNext; j++) {
        for (k = 0; k < v_atr; k++) {
          v_listN0Box[i][j][k] = v_listN1Box[i][j][k];
        }
      }
    }

    //n2 박스를 n1 박스에 복사
    for (i = 0; i < v_rowNext; i++) {
      for (j = 0; j < v_colNext; j++) {
        for (k = 0; k < v_atr; k++) {
          v_listN1Box[i][j][k] = v_listN2Box[i][j][k];
        }
      }
    }
    step_initial_next2();

    v_lineNext = 1;
    v_lineMove = 1;
    v_countItem++;
    v_score = v_score + 10;
  }

  //box 1줄 내림
  void step_lineDown_listBox() {
    if (v_lineMove >= v_rowBox) {
      step_lineFix_listBox();
      v_flagNext = true;
      return;
    }

    //내릴수 있는지 검토
    for (i = v_lineMove; i > 0; i--) {
      //내릴 줄
      for (j = 0; j < v_colBox; j++) {
        //내릴 칸
        if (v_listBox[i - 1][j][v_atr - 2] == 1 &&
            v_listBox[i - 1][j][v_atr - 1] == 0) {
          if (v_listBox[i][j][v_atr - 1] == 1) {
            //고정되었다면 내리기 종료
            step_lineFix_listBox();
            v_flagNext = true;
            return;
          }
        }
      }
    }
    //내릴수 있다고 검토되었으니 내림
    for (i = v_lineMove; i > 0; i--) {
      //내릴 줄
      for (j = 0; j < v_colBox; j++) {
        //내릴 칸
        if (v_listBox[i - 1][j][v_atr - 2] == 1 &&
            v_listBox[i - 1][j][v_atr - 1] == 0) {
          for (k = 0; k < v_atr; k++) {
            v_listBox[i][j][k] = v_listBox[i - 1][j][k]; // 내릴 칸을 아래칸에 복사
            v_listBox[i - 1][j][k] = 0; // 내린칸 비우기
          }
        }
      }
    }
    v_lineMove++;
  }

  void step_lineFix_listBox() {
    for (i = v_lineMove; i > 0; i--) {
      //내릴 줄
      for (j = 0; j < v_colBox; j++) {
        //내릴 칸
        if (v_listBox[i - 1][j][v_atr - 2] == 1) {
          v_listBox[i - 1][j][v_atr - 1] = 1;
        }
      }
    }
  }

  void press_arrow_down() {
    if (v_lineMove >= v_listN0Box[0][0][0]) {
      //아이템이 게임판에 모두 보이게 되면
      while (v_flagNext == false) {
        step_lineDown_listBox();
      }
      setState(() {});

      step_check_line();
    }
  }

  void press_arrow_right() {
    if (v_lineMove <= v_listN0Box[0][0][0]) {
      // 아이템이 게임판에 모두 안보이면
      return;
    }
    //우로 보낼수 있는지 검토
    for (j = v_colBox - 1; j >= 0; j--) {
      //옮길칸
      for (i = v_lineMove; i > 0; i--) {
        //옮길줄
        if (v_listBox[i - 1][j][v_atr - 2] == 1 && // 이동대상이면서
            v_listBox[i - 1][j][v_atr - 1] == 0) {
          // 고정이 아니면
          if (j == 9) return;
          if (v_listBox[i - 1][j + 1][v_atr - 1] == 1) return;
        }
      }
    }
    //우로 보낼수 있다고 검토되었으니 우로 보냄
    for (j = v_colBox - 1; j >= 0; j--) {
      //옮길 칸
      for (i = v_lineMove; i > 0; i--) {
        //옮길 줄
        if (v_listBox[i - 1][j][v_atr - 2] == 1 && //이동대상이면서
            v_listBox[i - 1][j][v_atr - 1] == 0) {
          // 고정이 아니면
          for (k = 0; k < v_atr; k++) {
            v_listBox[i - 1][j + 1][k] = v_listBox[i - 1][j][k];
            v_listBox[i - 1][j][k] = 0; //옮길칸 비우기
          }
        }
      }
    }
    setState(() {});
  }

  //좌측 방향 버튼을 누르면 왼쪽으로 옮김
  void press_arrow_left() {
    if (v_lineMove <= v_listN0Box[0][0][0]) {
      // 아이템이 게임판에 모두 안보이면
      return;
    }
    //좌로 보낼수 있는지 검토
    for (j = 0; j < v_colBox; j++) {
      //옮길 칸
      for (i = v_lineMove; i > 0; i--) {
        // 옮길 줄
        if (v_listBox[i - 1][j][v_atr - 2] == 1 &&
            v_listBox[i - 1][j][v_atr - 1] == 0) {
          if (j == 0) return;
          if (v_listBox[i - 1][j - 1][v_atr - 1] == 1) return;
        }
      }
    }

    //좌로 보낼수 있다고 검토 되었으니 좌로 보냄
    for (j = 1; j < v_colBox; j++) {
      //옮길 칸
      for (i = v_lineMove; i > 0; i--) {
        //옮길 줄
        if (v_listBox[i - 1][j][v_atr - 2] == 1 &&
            v_listBox[i - 1][j][v_atr - 1] == 0) {
          for (k = 0; k < v_atr; k++) {
            v_listBox[i - 1][j - 1][k] = v_listBox[i - 1][j][k]; //옮길 칸을 좌측칸에 복사
            v_listBox[i - 1][j][k] = 0; // 옮길칸 비우기
          }
        }
      }
    }
    setState(() {});
  }

  //회전을 누르면 시계방향으로 90도 회전
  void press_arrow_rotate() {
    if (v_lineMove <= v_listN0Box[0][0][0])
      //아이템이 게임판에 모두 안보이면
      return;

    // 0.회전대상 위치 구하기
    // 회전대상의 저장위치를 초기화
    for (i = 0; i < v_rowNext; i++) {
      for (j = 0; j < 3; j++) {
        v_listMove[i][j] = 0;
      }
    }

    int _color_R = 0;
    int _color_G = 0;
    int _color_B = 0;
    //회전대상의 위치를 찾아 저장(v_listMove 4개 칸에 저장)
    for (i = v_lineMove; i > 0; i--) {
      //옮길 줄
      for (j = 0; j < v_colBox; j++) {
        //옮길 칸
        if (v_listBox[i - 1][j][v_atr - 2] == 1 &&
            v_listBox[i - 1][j][v_atr - 1] == 0) {
          _color_R = v_listBox[i - 1][j][0];
          _color_G = v_listBox[i - 1][j][1];
          _color_B = v_listBox[i - 1][j][2];
          for (ii = 0; ii < v_rowNext; ii++) {
            //4개중에 빈자리에 넣음
            if (v_listMove[ii][0] + v_listMove[ii][1] == 0) {
              v_listMove[ii][0] = i - 1;
              v_listMove[ii][1] = j - 0;
              break;
            }
          }
        }
      }
    }
    //1.중심점 구하기_center
    num _sum_h = 0;
    num _sum_v = 0;
    num _avr_h = 0; //중심점 수평
    num _avr_v = 0; //중심점 수직
    for (ii = 0; ii < v_rowNext; ii++) {
      _sum_h = _sum_h + v_listMove[ii][0];
      _sum_v = _sum_v + v_listMove[ii][1];
    }
    _avr_h = _sum_h / v_rowNext;
    _avr_v = _sum_v / v_colNext;

    for (ii = 0; ii < v_rowNext; ii++) {
      v_listMove[ii][2] = (((_avr_h - v_listMove[ii][0]).abs() +
                  (_avr_v - v_listMove[ii][1]).abs()) *
              100)
          .toInt(); // as int;
    }

    int _center = 0; // 중심점 0~3
    for (ii = 0; ii < v_rowNext - 1; ii++) {
      if (v_listMove[_center][2] > v_listMove[ii + 1][2]) {
        _center = ii + 1;
      }
      ;
    }
    //2. 이동위치 구하기 (사각형은 회전 제외)
    if (v_listMove[0][2] == v_listMove[1][2] &&
        v_listMove[1][2] == v_listMove[2][2] &&
        v_listMove[2][2] == v_listMove[3][2]) {
      return;
    }
    for (ii = 0; ii < v_rowNext; ii++) {
      if (ii == _center) {
        // 기준점
        v_listMoveTarget[ii][0] = v_listMove[ii][0];
        v_listMoveTarget[ii][1] = v_listMove[ii][1];
      } else if (v_listMove[_center][0] == v_listMove[ii][0]) {
        // 기준점의 좌우에 위치 => 상하로 배치
        // 배치위치(중심i - 중심j + 대상j, 중심j)
        v_listMoveTarget[ii][0] =
            v_listMove[_center][0] - v_listMove[_center][1] + v_listMove[ii][1];
        v_listMoveTarget[ii][1] = v_listMove[_center][1];
      } else if (v_listMove[_center][1] == v_listMove[ii][1]) {
        // 기준점의 상하 => 좌우
        // 배치위치(중심i, 중심j + 중심i - 대상i)
        v_listMoveTarget[ii][0] = v_listMove[_center][0];
        v_listMoveTarget[ii][1] =
            v_listMove[_center][1] + v_listMove[_center][0] - v_listMove[ii][0];
      } else if ((v_listMove[_center][0] > v_listMove[ii][0] &&
              v_listMove[_center][1] > v_listMove[ii][1]) ||
          (v_listMove[_center][0] < v_listMove[ii][0] &&
              v_listMove[_center][1] < v_listMove[ii][1])) {
        // 기준점의 좌상우하 => 우상좌하
        // 배치위치(대상i, 중심j + 중심j - 대상j)
        v_listMoveTarget[ii][0] = v_listMove[ii][0];
        v_listMoveTarget[ii][1] =
            v_listMove[_center][1] + v_listMove[_center][1] - v_listMove[ii][1];
      } else {
        // 기준점의 우상좌하 => 우하좌상
        // 배치위치(중심i + 중심j - 대상i, 대상j)
        v_listMoveTarget[ii][0] =
            v_listMove[_center][0] + v_listMove[_center][0] - v_listMove[ii][0];
        v_listMoveTarget[ii][1] = v_listMove[ii][1];
      }
    }
    // 3. 회전가능 체크
    for (ii = 0; ii < v_rowNext; ii++) {
      if (v_listBox[v_listMoveTarget[ii][0]][v_listMoveTarget[ii][1]][4] == 1) {
        return;
      }
      if (v_listMoveTarget[ii][0] < 0 ||
          v_listMoveTarget[ii][0] > v_rowBox - 1 ||
          v_listMoveTarget[ii][1] < 0 ||
          v_listMoveTarget[ii][1] > v_colBox - 1) {
        return;
      }
    }

    // 4.회전
    // 4 개의 옮길대상 위치를 초기화
    for (ii = 0; ii < v_rowNext; ii++) {
      for (k = 0; k < v_atr; k++) {
        v_listBox[v_listMove[ii][0]][v_listMove[ii][1]][k] = 0;
      }
    }
    // 4개의 옮겨갈 위치에 저장
    for (ii = 0; ii < v_rowNext; ii++) {
      v_listBox[v_listMoveTarget[ii][0]][v_listMoveTarget[ii][1]][0] = _color_R;
      v_listBox[v_listMoveTarget[ii][0]][v_listMoveTarget[ii][1]][1] = _color_G;
      v_listBox[v_listMoveTarget[ii][0]][v_listMoveTarget[ii][1]][2] = _color_B;
      v_listBox[v_listMoveTarget[ii][0]][v_listMoveTarget[ii][1]][3] = 1;
      v_listBox[v_listMoveTarget[ii][0]][v_listMoveTarget[ii][1]][4] = 0;
    }
    setState(() {});

    // 5. 변수값 재설정 (이동시작라인 v_lineMove, 아이템라인수 v_listN0Box[0][0][0])
    switch (v_listN0Box[0][0][0]) {
      case 1:
        v_listN0Box[0][0][0] = 4;
        break;
      case 2:
        v_listN0Box[0][0][0] = 3;
        break;
      case 3:
        v_listN0Box[0][0][0] = 2;
        break;
      case 4:
        v_listN0Box[0][0][0] = 1;
        break;
    }
    for (i = v_rowBox - 1; i > 0; i--) {
      for (j = 0; j < v_colBox; j++) {
        if (v_listBox[i][j][v_atr - 2] == 1 &&
            v_listBox[i][j][v_atr - 1] == 0) {
          v_lineMove = i + 1; // 1~20라인 설정
          return;
        }
      }
    }
  }

  // 줄깨기 체크
  void step_check_line() {
    // 아이템 라인수를 고정대상 체크하여 줄깨기
    int _cnt_checkLine = 0; //깨진줄 수
    for (i = v_lineMove; i > 0; i--) {
      if (i <= v_lineMove - v_listN0Box[0][0][0]) break; // 아이템 라인수를 넘어가면 종료

      int _sum_checkLine = 0;
      for (j = 0; j < v_colBox; j++) {
        _sum_checkLine = _sum_checkLine + v_listBox[i - 1][j][v_atr - 2];
      }
      if (_sum_checkLine == 10) {
        for (j = 0; j < v_colBox; j++) {
          for (k = 0; k < v_colBox; k++) {
            v_listBox[i - 1][j][k] = 0;
          }
        }
        v_score = v_score + 100;
        _cnt_checkLine++;
      }
    }
    setState(() {});
    //깨진줄이 있으면 깨진줄을 채우려 내림
    if (_cnt_checkLine == 0) return; //깨진줄이 없으면 종료
    //v_listBox = v_listMirrorBox; 복사처리
    for (i = 0; i < v_rowBox; i++) {
      for (j = 0; j < v_colBox; j++) {
        for (k = 0; k < v_atr; k++) {
          v_listMirrorBox[i][j][k] = v_listMirrorBox[i][j][k];
        }
      }
    }
    //초기화
    for (i = 0; i < v_rowBox; i++) {
      for (j = 0; j < v_colBox; j++) {
        for (k = 0; k < v_atr; k++) {
          v_listBox[i][j][k] = 0;
        }
      }
    }
    //미러에서 한줄씩 자료가 있으면 게임판으로 복사
    ii = v_rowBox;
    for (i = v_rowBox; i > 0; i--) {
      if (v_listMirrorBox[i - 1][0][v_atr - 2] +
              v_listMirrorBox[i - 1][1][v_atr - 2] +
              v_listMirrorBox[i - 1][2][v_atr - 2] +
              v_listMirrorBox[i - 1][3][v_atr - 2] +
              v_listMirrorBox[i - 1][4][v_atr - 2] +
              v_listMirrorBox[i - 1][5][v_atr - 2] +
              v_listMirrorBox[i - 1][6][v_atr - 2] +
              v_listMirrorBox[i - 1][7][v_atr - 2] +
              v_listMirrorBox[i - 1][8][v_atr - 2] +
              v_listMirrorBox[i - 1][9][v_atr - 2] >
          0) {
        for (j = 0; j < v_colBox; j++) {
          if (v_listMirrorBox[i - 1][j][v_atr - 2] > 0) {
            for (k = 0; k < v_atr; k++) {
              v_listBox[ii - 1][j][k] = v_listMirrorBox[i - 1][j][k];
            }
          }
        }
        setState(() {});
        ii--;
      }
    }
  }
}
