import 'package:flutter/material.dart';

class Scoreboard extends StatelessWidget {
  final String teamName;
  final String opponentTeamName;
  final int teamScore;
  final int opponentScore;
  final int secondsElapsed;
  final int teamSet;
  final int opponentSet;

  const Scoreboard({
    Key? key,
    required this.teamName,
    required this.teamScore,
    required this.opponentTeamName,
    required this.opponentScore,
    required this.secondsElapsed,
    required this.teamSet,
    required this.opponentSet,
  }) : super(key: key);

  Widget _teamScoreWidget(String team, int score, Color color) {
    return Column(
      children: [
        Text(
          team,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white, // Change to any color you like
              width: 1, // Border width
            ),
          ),
          child: Text(
            "$score",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: 2,
        height: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.white30),
        ),
      ),
    );
  }

  Widget _setPointIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _setBall(teamSet, const Color(0xFF002F42)),
        const SizedBox(width: 20),
        const Text(
          "SET",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 20),
        _setBall(opponentSet, const Color(0xFFFF532C)),
      ],
    );
  }

  Widget _setBall(int count, Color color) {
    return Row(
      children: List.generate(count, (index) {
        return Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey, // Menambahkan border berwarna grey
              width: 1, // Lebar border
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Team & Score Row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _teamScoreWidget(teamName, teamScore, const Color(0xFF002F42)),
                _divider(),
                _setPointIndicator(), // ← dipindah ke sini
                _divider(),
                _teamScoreWidget(
                    opponentTeamName, opponentScore, const Color(0xFFFF532C)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
