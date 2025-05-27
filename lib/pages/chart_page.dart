import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/database/database_helper.dart';

class ChartPage extends StatefulWidget {
  final String teamName;
  final String opponentTeam;
  final List<Map<String, dynamic>> setHistory;

  const ChartPage({
    Key? key,
    required this.teamName,
    required this.opponentTeam,
    required this.setHistory,
  }) : super(key: key);

  @override
  _ChartPageState createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  bool isLoading = true;
  int selectedSet = -1; // -1 = All Set
  List<Map<String, dynamic>> playerDetails = [];
  List<Map<String, String>> recapData = [];
  Map<int, List<Map<String, String>>> playerRecaps = {};

  int getTotalAcePoints() {
    int totalAce = 0;
    for (var r in recapData) {
      totalAce += int.tryParse(r['ACE']!) ?? 0;
    }
    return totalAce;
  }


  @override
  void initState() {
    super.initState();
    _loadDataForSet(selectedSet);
  }

  Future<void> _loadDataForSet(int setNumber) async {
    setState(() => isLoading = true);
    playerDetails = await fetchPlayerDetailsForMatch();
    recapData = await fetchRecapDataForSet(setNumber);
    playerRecaps.clear();
    for (var p in playerDetails) {
      final id = p['id'] as int;
      playerRecaps[id] = await fetchPlayerRecapData(playerId: id, setNumber: setNumber);
    }
    setState(() {
      selectedSet = setNumber;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }
    final playerStats = getPlayerStats();
    final categoryTotals = getCategoryTotals();
    final totalPoints = getTotalAcePoints();
    final topPlayer = playerStats.isNotEmpty
        ? playerStats.reduce((a, b) => a['total'] > b['total'] ? a : b)
        : null;

    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Color(0xFF1E293B),
        title: Text('Analytics', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () {},
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Team & Set selector
              Card(
                color: Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${widget.teamName} vs ${widget.opponentTeam}',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedSet,
                          dropdownColor: Color(0xFF1E293B),
                          style: TextStyle(color: Colors.white),
                          items: [-1, 1, 2].map((s) {
                            final label = s == -1 ? 'All Sets' : 'Set $s';
                            return DropdownMenuItem(value: s, child: Text(label));
                          }).toList(),
                          onChanged: (val) { if (val != null) _loadDataForSet(val); },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // KPI Cards
              Row(children: [
                Expanded(child: _buildKPICard('Total Points', totalPoints.toString(), Icons.sports_volleyball_outlined)),
                SizedBox(width: 12),
                Expanded(child: _buildKPICard('Players', playerStats.length.toString(), Icons.group)),
              ]),
              SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildKPICard('Top Player', topPlayer?['name'] ?? 'N/A', Icons.star)),
                SizedBox(width: 12),
                Expanded(child: _buildKPICard('Top Score', topPlayer?['total']?.toString() ?? '0', Icons.trending_up)),
              ]),
              SizedBox(height: 24),

              // Category Pie Chart
              _buildSectionHeader('Performance by Category', Icons.pie_chart),
              SizedBox(height: 16),
              Card(
                color: Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 200,
                    child: PieChart(PieChartData(
                      sections: categoryTotals.entries.map((e) => PieChartSectionData(
                        value: e.value.toDouble(),
                        title: '${e.key}\n${e.value}',
                        titleStyle: TextStyle(color: Colors.white, fontSize: 12),
                      )).toList(),
                    )),
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Player Details Expandable
              _buildSectionHeader('Player Details', Icons.list),
              SizedBox(height: 8),
              ...playerRecaps.entries.map((entry) {
                final p = playerDetails.firstWhere((pd) => pd['id'] == entry.key);
                final stats = entry.value;
                return Card(
                  color: Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: ExpansionTile(
                    title: Text(p['playerName'], style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('Points: ${p['points']}', style: TextStyle(color: Colors.grey[400])),
                    children: stats.map((r) {
                      return ListTile(
                        title: Text(r['INDICATOR']!, style: TextStyle(color: Colors.white)),
                        subtitle: Text('Ace: ${r['ACE']}  In/Suc: ${r['IN/SUCCESS']}  Err: ${r['ERROR']}  %: ${r['%']}', style: TextStyle(color: Colors.grey[400])),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon) => Card(
    color: Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [Icon(icon, color: Colors.amber), SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12)), Text(value, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))])]),
    ),
  );

  Widget _buildSectionHeader(String title, IconData icon) => Row(children: [Icon(icon, color: Colors.white70), SizedBox(width: 8), Text(title, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]);

  // ========== Data Helpers ===========
  Future<List<Map<String, dynamic>>> fetchPlayerDetailsForMatch() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
    SELECT p.id, p.name AS playerName,
      SUM(CASE WHEN UPPER(s.subcategory) = 'ACE' THEN s.score ELSE 0 END) AS totalPoints,
      MAX(s.ballPosition) AS lastBallPosition
    FROM scores s
    JOIN players p ON s.player_id = p.id
    GROUP BY s.player_id
  ''');
    return rows.map((r) => {
      'id': r['id'],
      'playerName': r['playerName'],
      'points': (r['totalPoints'] ?? 0).toString(),
      'ballLocation': (r['lastBallPosition'] ?? '-').toString(),
    }).toList();
  }


  Future<List<Map<String, String>>> fetchRecapDataForSet(int selectedOption) async {
    final db = await DatabaseHelper.instance.database;
    String query;
    List<dynamic> args = [];
    if (selectedOption == -1) {
      query = '''
        SELECT category, UPPER(subcategory) as subcat, SUM(score) as total
        FROM scores
        WHERE setNumber IN (0,1,2)
        GROUP BY category, UPPER(subcategory)
      ''';
    } else {
      query = '''
        SELECT category, UPPER(subcategory) as subcat, SUM(score) as total
        FROM scores
        WHERE setNumber = ?
        GROUP BY category, UPPER(subcategory)
      ''';
      args.add(selectedOption);
    }
    final rows = await db.rawQuery(query, args);
    final recap = <String, Map<String,int>>{
      'SERVE': {'ACE':0,'IN':0,'SUCCESS':0,'ERROR':0},
      'STRIKE': {'ACE':0,'IN':0,'SUCCESS':0,'ERROR':0},
      'FREEBALL': {'ACE':0,'IN':0,'SUCCESS':0,'ERROR':0},
      'FIRSTBALL': {'ACE':0,'IN':0,'SUCCESS':0,'ERROR':0},
      'FEEDING': {'SUCCESS':0,'FAILED':0,'ERROR':0},
      'BLOCKING': {'ACE':0,'IN':0,'SUCCESS':0,'ERROR':0},
      'TEAM': {'OPPONENT_MISTAKE':0},
    };
    for (var row in rows) {
      final cat = row['category']?.toString().toUpperCase() ?? '';
      final sub = row['subcat']?.toString() ?? '';
      final tot = int.tryParse((row['total'] ?? 0).toString()) ?? 0;
      if (recap.containsKey(cat)) recap[cat]![sub] = tot;
    }
    final indicators = ['SERVE','STRIKE','FREEBALL','FIRSTBALL','FEEDING','BLOCKING','OPPONENT MISTAKE'];
    List<Map<String,String>> data = [];
    for (var ind in indicators) {
      String ace='', ins='', fail='', err='', pct='0%';
      if (ind=='OPPONENT MISTAKE') {
        ins = recap['TEAM']!['OPPONENT_MISTAKE']!.toString(); pct='-';
      } else {
        final aceVal = recap[ind]?['ACE'] ?? 0;
        final inVal = (recap[ind]?['IN'] ?? 0) + (recap[ind]?['SUCCESS'] ?? 0);
        final errVal = recap[ind]?['ERROR'] ?? 0;
        final total = aceVal+inVal+errVal;
        if (total>0) pct = ((aceVal+inVal)/total*100).toStringAsFixed(1)+'%';
        ace=aceVal.toString(); ins=inVal.toString(); err=errVal.toString();
        if (ind=='FEEDING') fail=(recap[ind]?['FAILED']??0).toString();
      }
      data.add({'INDICATOR':ind,'ACE':ace,'IN/SUCCESS':ins,'FAILED':fail,'ERROR':err,'%':pct});
    }
    return data;
  }

  Future<List<Map<String, String>>> fetchPlayerRecapData({required int playerId, required int setNumber}) async {
    final db = await DatabaseHelper.instance.database;
    String query = '''
      SELECT category, UPPER(subcategory) as subcat, SUM(score) as total
      FROM scores
      WHERE player_id = ?${setNumber != -1 ? ' AND setNumber = ?' : ''}
      GROUP BY category, UPPER(subcategory)
    ''';
    final args = [playerId];
    if (setNumber != -1) args.add(setNumber);
    final rows = await db.rawQuery(query, args);
    final recap = <String, Map<String,int>>{
      'SERVE': {'ACE':0,'IN':0,'SUCCESS':0,'ERROR':0},
      'STRIKE': {'ACE':0,'IN':0,'SUCCESS':0,'ERROR':0},
      'FREEBALL': {'ACE':0,'IN':0,'SUCCESS':0,'ERROR':0},
      'FIRSTBALL': {'ACE':0,'IN':0,'SUCCESS':0,'ERROR':0},
      'FEEDING': {'SUCCESS':0,'FAILED':0,'ERROR':0},
      'BLOCKING': {'ACE':0,'IN':0,'SUCCESS':0,'ERROR':0},
      'TEAM': {'OPPONENT_MISTAKE':0},
    };
    for (var row in rows) {
      final cat = row['category']?.toString().toUpperCase() ?? '';
      final sub = row['subcat']?.toString() ?? '';
      final tot = int.tryParse((row['total'] ?? 0).toString()) ?? 0;
      if (recap.containsKey(cat)) recap[cat]![sub] = tot;
      else recap[cat] = {sub: tot};
    }
    final indicators = ['SERVE','STRIKE','FREEBALL','FIRSTBALL','FEEDING','BLOCKING','OPPONENT MISTAKE'];
    List<Map<String,String>> data = [];
    for (var ind in indicators) {
      String ace='', ins='', fail='', err='', pct='0%';
      if (ind=='OPPONENT MISTAKE') {
        ins = recap['TEAM']!['OPPONENT_MISTAKE']!.toString(); pct='-';
      } else {
        final aceVal = recap[ind]?['ACE'] ?? 0;
        final inVal = (recap[ind]?['IN'] ?? 0) + (recap[ind]?['SUCCESS'] ?? 0);
        final errVal = recap[ind]?['ERROR'] ?? 0;
        final total = aceVal+inVal+errVal;
        if (total>0) pct = ((aceVal+inVal)/total*100).toStringAsFixed(1)+'%';
        ace=aceVal.toString(); ins=inVal.toString(); err=errVal.toString();
        if (ind=='FEEDING') fail=(recap[ind]?['FAILED']??0).toString();
      }
      data.add({'INDICATOR':ind,'ACE':ace,'IN/SUCCESS':ins,'FAILED':fail,'ERROR':err,'%':pct});
    }
    return data;
  }

  List<Map<String, dynamic>> getPlayerStats() {
    return playerDetails.map((p) => {
      'id': p['id'],
      'name': p['playerName'],
      'total': int.parse(p['points']),
    }).toList();
  }

  Map<String, int> getCategoryTotals() {
    final Map<String, int> totals = {
      'STRIKE': 0,
      'SERVE': 0,
      'FREEBALL': 0,
      'FIRSTBALL': 0,
      'FEEDING': 0,
      'BLOCKING': 0,
    };

    for (var r in recapData) {
      final ind = r['INDICATOR']!;
      final ace = int.tryParse(r['ACE']!) ?? 0;
      final ins = int.tryParse(r['IN/SUCCESS']!) ?? 0;
      final err = int.tryParse(r['ERROR']!) ?? 0;
      final sum = ace + ins + err;

      if (totals.containsKey(ind)) {
        totals[ind] = totals[ind]! + sum;
      }
    }

    return totals;
  }


  List<Map<String, dynamic>> getPlayerStatsForRadarChart() {
    final colors = [Colors.blue, Colors.green, Colors.red, Colors.orange, Colors.purple, Colors.cyan];
    final stats = <Map<String, dynamic>>[];
    final players = getPlayerStats();
    for (var i = 0; i < players.length; i++) {
      final p = players[i];
      final recap = playerRecaps[p['id']] ?? [];
      int att = 0, svc = 0, def = 0;
      for (var r in recap) {
        final ind = r['INDICATOR']!;
        final ace = int.tryParse(r['ACE']!) ?? 0;
        final ins = int.tryParse(r['IN/SUCCESS']!) ?? 0;
        final err = int.tryParse(r['ERROR']!) ?? 0;
        final sum = ace + ins + err;
        if (['SERVE', 'STRIKE', 'FREEBALL'].contains(ind)) att += sum;
        else if (['FIRSTBALL', 'FEEDING', 'BLOCKING'].contains(ind)) def += sum;
        else if (ind == 'OPPONENT MISTAKE') svc += sum;
      }
      stats.add({
        'name': p['name'],
        'attacks': att,
        'service': svc,
        'defense': def,
        'color': colors[i % colors.length],
      });
    }
    return stats;
  }
}
