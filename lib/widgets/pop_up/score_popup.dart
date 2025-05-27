import 'package:flutter/material.dart';

class ScorePopup extends StatelessWidget {
  final String playerName;
  final Function(String, String) onScoreSelected;
  final Map<String, Map<String, int>> playerScores;

  ScorePopup({
    required this.playerName,
    required this.onScoreSelected,
    required this.playerScores,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: Colors.white,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8, // Lebih lebar
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Tambahkan Poin untuk $playerName",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Divider(color: Colors.black),
            _buildCategory("Serve", ["Ace", "In", "Error"]),
            _buildCategory("Strike", ["Ace", "In", "Error"]),
            _buildCategory("Freeball", ["Ace", "In", "Error"]),
            _buildCategory("Firstball", ["Success", "Error"]),
            _buildCategory("Feeding", ["Success", "Error"]),
            _buildCategory("Blocking", ["Success", "Error"]),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Tutup"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(String category, List<String> subcategories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(category,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 5),
        Wrap(
          spacing: 10,
          children: subcategories.map((sub) {
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: () => onScoreSelected(category, sub),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(sub, style: TextStyle(color: Colors.white)),
                  SizedBox(width: 5),
                  _scoreIndicator(category, sub),
                ],
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 10),
      ],
    );
  }

  Widget _scoreIndicator(String category, String sub) {
    int score = playerScores[category]?[sub] ?? 0;
    return CircleAvatar(
      radius: 12,
      backgroundColor: Colors.white,
      child: Text(
        "$score",
        style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
      ),
    );
  }
}
