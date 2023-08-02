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
  Future<List<Rank>>? RankList;

  @override
  void initState() {
    super.initState();
    RankList = getRankList() as Future<List<Rank>>?;
  }

  void _removeAllTodos() async {
    final Database database = await widget.database;
    database.rawDelete('delete from ranks');
    setState(() {
      RankList = getRankList();
    });
  }

  Future<List<Rank>> getRankList() async {
    final Database database = await widget.database;
    List<Map<String, dynamic>> maps = await database.rawQuery(
        'select rankNo, rankDate, score from ranks order by score desc');

    return List.generate(maps.length, (i) {
      return Rank(
        rankNo: maps[i]['rankNo'],
        rankDate: maps[i]['rankDate'],
        score: maps[i]['score'],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // return const Text('게임 결과 화면');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rank'),
      ),
      body: Container(
        child: Center(
          child: FutureBuilder(
            builder: (context, snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.none:
                  return const CircularProgressIndicator();
                case ConnectionState.waiting:
                  return const CircularProgressIndicator();
                case ConnectionState.done:
                  if (snapshot.hasData) {
                    return ListView.builder(
                      itemBuilder: (context, index) {
                        Rank rank = (snapshot.data as List<Rank>)[index];
                        return ListTile(
                          subtitle: Container(
                            decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(5)),
                            child: Row(
                              children: [
                                Flexible(
                                  flex: 2,
                                  child: Container(
                                    margin: EdgeInsets.all(10),
                                    padding: EdgeInsets.all(0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        // 좌 - 랭킹
                                        Text(
                                          'Ranking',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.lightBlueAccent,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          (index + 1).toString(),
                                          style: const TextStyle(
                                              fontSize: 35,
                                              color: Colors.yellow,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Flexible(
                                  flex: 5,
                                  child: Container(
                                    margin: EdgeInsets.all(10),
                                    padding: EdgeInsets.all(0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        //우 - 일시, 점수
                                        Text(
                                          rank.rankDate!,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Score : ' + rank.score!.toString(),
                                          style: const TextStyle(
                                              fontSize: 25,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      itemCount: (snapshot.data as List<Rank>).length,
                    );
                  } else {
                    return const Text('No data');
                  }
              }
              return const CircularProgressIndicator();
            },
            future: RankList,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Delete'),
                  content: const Text('Do you want to delete all data?'),
                  actions: <Widget>[
                    TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                        child: const Text('Yes')),
                    TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                        child: const Text('No')),
                  ],
                );
              });
          if (result == true) {
            _removeAllTodos();
          }
        },
        child: const Icon(Icons.remove),
      ),
    );
  }
}
