import 'package:flutter/material.dart';

class DetailedResultPage extends StatefulWidget {
  final Map<String, dynamic> matchHistory;

  const DetailedResultPage({Key? key, required this.matchHistory})
      : super(key: key);

  @override
  _DetailedResultPageState createState() => _DetailedResultPageState();
}

class _DetailedResultPageState extends State<DetailedResultPage> {
  @override
  Widget build(BuildContext context) {
    // Extract data from matchHistory. Adjust keys as needed.
    final String teamName = widget.matchHistory['teamName'] ?? "Team";
    final String opponentTeam =
        widget.matchHistory['opponentTeam'] ?? "Opponent";
    final int teamSet = widget.matchHistory['teamSet'] ?? 0;
    final int opponentSet = widget.matchHistory['opponentSet'] ?? 0;
    final List<dynamic> setHistory = widget.matchHistory['setHistory'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text("Detailed Result"),
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (similar to your ResultPage header)
            Center(
              child: Text(
                "Match Result",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
            SizedBox(height: 16),
            // Team Names & Overall Set Score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Team: $teamName",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                Text(
                  "Opponent: $opponentTeam",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ],
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                "Set Score: $teamSet - $opponentSet",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
            SizedBox(height: 16),
            // Set History Table
            Text(
              "Set Breakdown",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: Colors.white70, width: 1),
              defaultColumnWidth: FixedColumnWidth(80),
              children: [
                // Table header
                TableRow(
                  decoration: BoxDecoration(color: Colors.blueGrey),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(
                        child: Text("Set",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(
                        child: Text("Team Score",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(
                        child: Text("Opponent Score",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                // Data rows from setHistory.
                ...setHistory.map((set) {
                  return TableRow(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Center(
                          child: Text(
                            set['set'].toString(),
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Center(
                          child: Text(
                            set['teamScore'].toString(),
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Center(
                          child: Text(
                            set['opponentScore'].toString(),
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
            SizedBox(height: 16),
            // Additional details (e.g., player details or ball positions) can be added here.
            Text(
              "Player Details and Ball Positions (if any)",
              style: TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            // You can add more widgets here to show detailed data per player.
          ],
        ),
      ),
    );
  }
}
