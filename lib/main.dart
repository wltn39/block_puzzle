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

  // 모든 Flag 설정
  bool? v_flagButtonPlay = true;

  // 변수설정
  String v_image_volume = 'asset/images/volumeOn.png';
  bool v_volume = true;

  // 모든 배열 설정, 판배열 = v_listBox, 배열 (20행*10열*특성 5)
  // 특성 1,2,3,rgb, 특성4 이동 on,off 1,0, 특성5 고정 on off 1,0
  final v_listBox = List.generate(
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
                          ],
                        ),
                      ),
                    ),
                    // body 상단 우측
                    Expanded(
                      flex: 6,
                      child: Container(
                          child: Column(children: [
                        // body 상단 우측 Next1
                        Expanded(
                          flex: 6,
                          child: Container(
                            color: Colors.red,
                          ),
                        ),
                        Expanded(
                          flex: 6,
                          child: Container(
                            color: Colors.blueAccent,
                          ),
                        ),
                        // body 상단 우측 레벨, 점수
                        Expanded(
                          flex: 8,
                          child: Container(
                            color: Colors.white,
                          ),
                        ),
                        // 상단 우측 빈칸
                        Expanded(
                          flex: 1,
                          child: Container(
                            color: Colors.green,
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
                        color: Colors.pink,
                      ),
                    ),
                    // body 하단 우측 3개 버튼
                    Expanded(
                      flex: 6,
                      child: Container(
                        color: Colors.amber,
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
}
