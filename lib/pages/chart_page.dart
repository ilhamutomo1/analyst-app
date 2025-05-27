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

class _ChartPageState extends State<ChartPage> with TickerProviderStateMixin {
  bool isLoading = true;
  int selectedSet = -1; // -1 = All Set
  List<Map<String, dynamic>> playerDetails = [];
  List<Map<String, String>> recapData = [];
  Map<int, List<Map<String, String>>> playerRecaps = {};

  // Change from late to nullable with proper initialization
  AnimationController? _fadeAnimationController;
  Animation<double>? _fadeAnimation;

  final List<Color> _chartColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFFEC4899), // Pink
  ];

  final Color _primaryBg = Color(0xFF0F172A);
  final Color _secondaryBg = Color(0xFF1E293B);
  final Color _cardBg = Color(0xFF334155);
  final Color _accentColor = Color(0xFF3B82F6);

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
    _initializeAnimation();
    _loadDataForSet(selectedSet);
  }

  void _initializeAnimation() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController!,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _fadeAnimationController?.dispose();
    super.dispose();
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
    // Safe animation trigger with null check
    _fadeAnimationController?.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: _primaryBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: _accentColor,
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Loading Analytics...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final playerStats = getPlayerStats();
    final categoryTotals = getCategoryTotals();
    final totalPoints = getTotalAcePoints();
    final topPlayer = playerStats.isNotEmpty
        ? playerStats.reduce((a, b) => a['total'] > b['total'] ? a : b)
        : null;

    return Scaffold(
      backgroundColor: _primaryBg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _fadeAnimation != null
            ? FadeTransition(
          opacity: _fadeAnimation!,
          child: _buildBody(totalPoints, playerStats, topPlayer, categoryTotals),
        )
            : _buildBody(totalPoints, playerStats, topPlayer, categoryTotals),
      ),
    );
  }

  Widget _buildBody(int totalPoints, List<Map<String, dynamic>> playerStats,
      Map<String, dynamic>? topPlayer, Map<String, int> categoryTotals) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTeamHeader(),
          SizedBox(height: 24),
          _buildKPISection(totalPoints, playerStats, topPlayer),
          SizedBox(height: 32),
          _buildCategoryChart(categoryTotals),
          SizedBox(height: 32),
          _buildPlayerPerformanceChart(),
          SizedBox(height: 32),
          _buildPlayerDetailsSection(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'Team Analytics',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }


  Widget _buildTeamHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_secondaryBg.withOpacity(0.8), _secondaryBg.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_volleyball, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${widget.teamName} vs ${widget.opponentTeam}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedSet,
                dropdownColor: _secondaryBg,
                style: TextStyle(color: Colors.white, fontSize: 14),
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.white),
                items: [-1, 1, 2].map((s) {
                  final label = s == -1 ? 'All Sets' : 'Set $s';
                  return DropdownMenuItem(
                    value: s,
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    // Safe animation reset with null check
                    _fadeAnimationController?.reset();
                    _loadDataForSet(val);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPISection(int totalPoints, List<Map<String, dynamic>> playerStats, Map<String, dynamic>? topPlayer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Key Performance Indicators', Icons.dashboard),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                'Total Points',
                totalPoints.toString(),
                Icons.sports_volleyball_outlined,
                _chartColors[0],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildKPICard(
                'Active Players',
                playerStats.length.toString(),
                Icons.group,
                _chartColors[1],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                'Top Player',
                topPlayer?['name'] ?? 'N/A',
                Icons.star,
                _chartColors[2],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildKPICard(
                'Highest Score',
                topPlayer?['total']?.toString() ?? '0',
                Icons.trending_up,
                _chartColors[3],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color accentColor) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _secondaryBg,
        borderRadius: BorderRadius.circular(16),

      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(Map<String, int> categoryTotals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Performance by Category', Icons.pie_chart),
        SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _secondaryBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 250,
                child: PieChart(
                  PieChartData(
                    sections: categoryTotals.entries.map((e) {
                      final index = categoryTotals.keys.toList().indexOf(e.key);
                      return PieChartSectionData(
                        value: e.value.toDouble(),
                        title: '${e.key}\n${e.value}',
                        titleStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        color: _chartColors[index % _chartColors.length],
                        radius: 80,
                        titlePositionPercentageOffset: 0.6,
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: categoryTotals.entries.map((e) {
                  final index = categoryTotals.keys.toList().indexOf(e.key);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _chartColors[index % _chartColors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        e.key,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerPerformanceChart() {
    final performances = getPlayerPerformances();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Player Performance Comparison', Icons.bar_chart),
        SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _secondaryBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: buildPerformanceChart(performances),
        ),
      ],
    );
  }

  Widget _buildPlayerDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Detailed Player Statistics', Icons.analytics),
        SizedBox(height: 16),
        ...playerRecaps.entries.map((entry) {
          final p = playerDetails.firstWhere((pd) => pd['id'] == entry.key);
          final stats = entry.value;
          final index = playerRecaps.keys.toList().indexOf(entry.key);

          return Container(
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _secondaryBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                childrenPadding: EdgeInsets.zero,
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _chartColors[index % _chartColors.length].withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      p['playerName'].toString().substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: _chartColors[index % _chartColors.length],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p['playerName'] ?? '-',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '#${p['jerseyNumber'] ?? '00'}', // Default ke '00' jika null
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p['position'] ?? '-', // Default ke '-' jika null
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Container(
                  margin: EdgeInsets.only(top: 4),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Total Points: ${p['points']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                iconColor: Colors.white70,
                collapsedIconColor: Colors.white70,
                children: [
                  Container(
                    margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardBg.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: stats.map((r) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _primaryBg.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['INDICATOR']!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildStatChip('ACE', r['ACE']!, Colors.green),
                                  SizedBox(width: 8),
                                  _buildStatChip('Success', r['IN/SUCCESS']!, Colors.blue),
                                  SizedBox(width: 8),
                                  _buildStatChip('Error', r['ERROR']!, Colors.red),
                                ],
                              ),
                              if (r['%'] != '0%' && r['%'] != '-') ...[
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Success Rate: ${r['%']}',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _accentColor, size: 20),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget buildPerformanceChart(List<Map<String, dynamic>> data) {
    const double fixedMaxY = 100.0;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          maxY: fixedMaxY,
          groupsSpace: 12,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: _primaryBg,
              tooltipRoundedRadius: 8,
              tooltipPadding: EdgeInsets.all(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${data[groupIndex]['playerName']}\n${rod.toY.toStringAsFixed(1)}%',
                  TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                reservedSize: 40,
                getTitlesWidget: (val, _) => Text(
                  '${val.toInt()}%',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < data.length) {
                    return RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        data[idx]['playerName'] as String,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (y) => FlLine(
              color: Colors.white12,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((e) {
            final performance = e.value['performance'] as double;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: performance.clamp(0.0, 100.0),
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: [
                      _chartColors[e.key % _chartColors.length],
                      _chartColors[e.key % _chartColors.length].withOpacity(0.7),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: fixedMaxY,
                    color: Colors.white10,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ========== Data Helpers ===========
  Future<List<Map<String, dynamic>>> fetchPlayerDetailsForMatch() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
    SELECT 
      p.id, 
      p.name        AS playerName,
      p.position    AS position,
      p.number      AS jerseyNumber,
      SUM(CASE WHEN UPPER(s.subcategory) = 'ACE' THEN s.score ELSE 0 END) AS totalPoints,
      MAX(s.ballPosition)                                   AS lastBallPosition
    FROM scores s
    JOIN players p ON s.player_id = p.id
    GROUP BY s.player_id
  ''');
    return rows.map((r) => {
      'id'           : r['id'],
      'playerName'   : r['playerName'],
      'position'     : r['position'],         // posisi
      'jerseyNumber' : r['jerseyNumber'],     // nomor punggung
      'points'       : (r['totalPoints'] ?? 0).toString(),
      'ballLocation' : (r['lastBallPosition'] ?? '-').toString(),
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

  List<Map<String, dynamic>> getPlayerPerformances() {
    final List<Map<String, dynamic>> list = [];

    for (var p in playerDetails) {
      final id = p['id'] as int;
      final name = p['playerName'] as String;
      final recap = playerRecaps[id] ?? [];

      // ubah recap List<Map<String,String>> ke Map<String, Map<String,int>>
      final byCat = <String, Map<String,int>>{};
      for (var row in recap) {
        final cat = row['INDICATOR']!;
        byCat[cat] = {
          'ACE': int.tryParse(row['ACE']!) ?? 0,
          'IN': int.tryParse(row['IN/SUCCESS']!) ?? 0,
          'SUCCESS': int.tryParse(row['IN/SUCCESS']!) ?? 0,
          'ERROR': int.tryParse(row['ERROR']!) ?? 0,
          'FAILED': int.tryParse(row['FAILED'] ?? '0') ?? 0,
        };
      }

      int totalAce = 0, totalSuccess = 0, totalError = 0;
      const mainCats = ["SERVE","STRIKE","FREEBALL","FIRSTBALL","FEEDING","BLOCKING"];
      for (var cat in mainCats) {
        final vals = byCat[cat] ?? {};
        totalAce += vals['ACE'] ?? 0;
        if (["SERVE","STRIKE","FREEBALL"].contains(cat)) {
          totalSuccess += vals['IN'] ?? 0;
        }
        if (["FIRSTBALL","FEEDING","BLOCKING"].contains(cat)) {
          totalSuccess += vals['SUCCESS'] ?? 0;
        }
        totalError += (vals['ERROR'] ?? 0) + (vals['FAILED'] ?? 0);
      }

      final num = totalAce + totalSuccess;
      final den = num + totalError;
      final perf = den > 0 ? (num / den) * 100 : 0.0;

      list.add({
        'playerName': name,
        'performance': perf.toDouble(),
      });
    }

    return list;
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
