class Team {
  final int id;
  final String name;

  Team({required this.id, required this.name});

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      id: map['id'],
      name: map['name'],
    );
  }
}
