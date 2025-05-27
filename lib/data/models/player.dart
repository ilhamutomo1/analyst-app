class Player {
  final int? id; // Bisa null untuk pemain baru
  final String name;
  final String position;
  final String number;
  final String teamName;

  Player({
    this.id,
    required this.name,
    required this.position,
    required this.number,
    required this.teamName,
  });

  // Konversi objek Player ke Map untuk database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'number': number,
      'teamName': teamName,
    };
  }

  // Konversi Map dari database menjadi objek Player
  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'],
      name: map['name'],
      position: map['position'],
      number: map['number'],
      teamName: map['teamName'],
    );
  }
}
