class Rank {
  int? rankNo;
  String? rankDate;
  int? score;

  Rank({this.rankNo, this.rankDate, this.score});

  Map<String, dynamic> toMap() {
    return {
      'rankNo': rankNo,
      'rankDate': rankDate,
      'score': score,
    };
  }
}
