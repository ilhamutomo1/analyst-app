class Point {
  int? id;
  int playerId;
  String category;
  String subcategory;
  int points;

  Point(
      {this.id,
      required this.playerId,
      required this.category,
      required this.subcategory,
      required this.points});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'player_id': playerId,
      'category': category,
      'subcategory': subcategory,
      'points': points,
    };
  }

  factory Point.fromMap(Map<String, dynamic> map) {
    return Point(
      id: map['id'],
      playerId: map['player_id'],
      category: map['category'],
      subcategory: map['subcategory'],
      points: map['points'],
    );
  }
}
