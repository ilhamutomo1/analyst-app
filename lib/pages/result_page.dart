import 'package:flutter/material.dart';
import 'package:takraw_analyst/data/database/database_helper.dart';
import 'package:takraw_analyst/pages/chart_page.dart';
import 'package:takraw_analyst/widgets/result.dart';
import 'package:fl_chart/fl_chart.dart';

class ResultPage extends StatefulWidget {
  final String teamName;
  final String opponentTeam;
  final int teamScore;
  final int teamSet;
  final int opponentSet;
  final int opponentScore;
  final bool isCurrentResult; // Tambahkan ini
  final List<Map<String, dynamic>> setHistory;

  const ResultPage({
    Key? key,
    required this.teamName,
    required this.opponentTeam,
    required this.teamScore,
    required this.teamSet,
    required this.opponentSet,
    required this.opponentScore,
    required this.setHistory,
    this.isCurrentResult = false,
  }) : super(key: key);

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage>
    with SingleTickerProviderStateMixin {
  int _teamScoreTotal = 0;
  int _opponentScoreTotal = 0;
  int _teamSet = 0;
  int _opponentSet = 0;
  int _selectedTabIndex = 0; // 0 = Table, 1 = Chart

  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> setHistory = []; // Menyimpan data tiap set

  int? _selectedPlayerId;
  String _selectedCategory = "SERVE";

  Map<String, Map<int, Map<String, dynamic>>> ballPositionsByCategory = {};
  List<Map<String, dynamic>> playerDetails = [];

  late bool isCurrentResult;

  // Hanya gunakan satu variabel
  int? _selectedSet = -1; // Gunakan -1 sebagai pengganti "ALL SET"
  final List<int> _setOptions = [
    -1,
    0,
    1,
    2
  ]; // Pastikan semua nilai bertipe int

  int calculateTeamSetWins(List<Map<String, dynamic>> history) {
    int count = 0;
    for (var set in history) {
      if (set['winner'] == 'team') count++;
    }
    return count;
  }

  int calculateOpponentSetWins(List<Map<String, dynamic>> history) {
    int count = 0;
    for (var set in history) {
      if (set['winner'] == 'opponent') count++;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    isCurrentResult = widget.isCurrentResult;
  }

  Future<void> _loadExportData() async {
    ballPositionsByCategory = {
      "SERVE": await _fetchBallPositionDataForCategory("SERVE"),
      "STRIKE": await _fetchBallPositionDataForCategory("STRIKE"),
      "FREEBALL": await _fetchBallPositionDataForCategory("FREEBALL"),
      // Tambahkan kategori lain jika perlu.
    };

    playerDetails = await fetchPlayerDetailsForMatch();

    setState(() {});
  }

  Future<void> _fetchInitialData() async {
    final db = await DatabaseHelper.instance.database;

    // Ambil seluruh data skor dengan join ke tabel players (jika diperlukan untuk menampilkan skor total).
    final List<Map<String, dynamic>> allScores = await db.rawQuery('''
    SELECT s.*, p.name as playerName 
    FROM scores s
    JOIN players p ON s.player_id = p.id
  ''');

    int teamScoreTotal = 0;
    int opponentScoreTotal = 0;
    for (var row in allScores) {
      String sub = (row['subcategory'] ?? "").toString().toUpperCase();
      int score = row['score'] is int
          ? row['score']
          : int.tryParse(row['score'].toString()) ?? 0;
      // "ACE" dan "OPPONENT_MISTAKE" menambah poin tim; "ERROR" menambah poin lawan.
      if (sub == "ACE" || sub == "OPPONENT_MISTAKE") {
        teamScoreTotal += score;
      } else if (sub == "ERROR") {
        opponentScoreTotal += score;
      }
    }

    // Ambil data pemain
    final List<Map<String, dynamic>> playersData = await db.query('players');

    setState(() {
      _teamScoreTotal = teamScoreTotal;
      _opponentScoreTotal = opponentScoreTotal;
      _players = playersData;
    });

    // Hitung set wins berdasarkan data yang sudah dikirim (widget.setHistory)
    setState(() {
      _teamSet = calculateTeamSetWins(widget.setHistory);
      _opponentSet = calculateOpponentSetWins(widget.setHistory);
    });
  }

  /// Fungsi mengambil data recap berdasarkan kategori dan subkategori.
  Future<List<Map<String, String>>> _fetchRecapData() async {
    final db = await DatabaseHelper.instance.database;
    String query = '''
  SELECT category, UPPER(subcategory) as subcat, SUM(score) as total
  FROM scores
  ''';
    List<dynamic> args = [];
    bool whereAdded = false;

    if (_selectedSet != -1) {
      query += ' WHERE setNumber = ?';
      args.add(_selectedSet);
      whereAdded = true;
    }

    if (_selectedPlayerId != null) {
      query += whereAdded ? ' AND player_id = ?' : ' WHERE player_id = ?';
      args.add(_selectedPlayerId);
    }

    query += ' GROUP BY category, UPPER(subcategory)';
    final List<Map<String, dynamic>> rows = await db.rawQuery(query, args);
    print("Rows from recap query: $rows");

    Map<String, Map<String, int>> recap = {
      "SERVE": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "STRIKE": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "FREEBALL": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "FIRSTBALL": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "FEEDING": {"SUCCESS": 0, "FAILED": 0, "ERROR": 0},
      "BLOCKING": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "TEAM": {"OPPONENT_MISTAKE": 0},
    };

    for (var row in rows) {
      String cat = row['category']?.toString().toUpperCase() ?? "";
      String subcat = row['subcat']?.toString() ?? "";
      int total = int.tryParse((row['total'] ?? 0).toString()) ?? 0;
      if (recap.containsKey(cat)) {
        recap[cat]![subcat] = total;
      } else {
        recap[cat] = {subcat: total};
      }
    }

    List<String> indicators = [
      "SERVE",
      "STRIKE",
      "FREEBALL",
      "FIRSTBALL",
      "FEEDING",
      "BLOCKING",
      // Menjaga urutan lainnya
    ];

    List<Map<String, String>> recapData = [];

    for (String ind in indicators) {
      String aceStr = "";
      String inSuccessStr = "";
      String failedStr = "";
      String errorStr = "";
      String percent = "0%";

      if (ind == "OPPONENT MISTAKE") {
        inSuccessStr = (recap["TEAM"]?["OPPONENT_MISTAKE"] ?? 0).toString();
        percent = "-";
      } else if (ind == "FEEDING") {
        int success = recap[ind]?["SUCCESS"] ?? 0;
        int failed = recap[ind]?["FAILED"] ?? 0;
        int error = recap[ind]?["ERROR"] ?? 0;

        int sum = success + failed + error;
        if (sum > 0) {
          double pct = (success / sum) * 100;
          percent = pct.toStringAsFixed(1) + "%";
        }

        inSuccessStr = success.toString();
        failedStr = failed.toString();
        errorStr = error.toString();
      } else {
        int ace = recap[ind]?["ACE"] ?? 0;
        int inVal = recap[ind]?["IN"] ?? 0;
        int success = recap[ind]?["SUCCESS"] ?? 0;
        int error = recap[ind]?["ERROR"] ?? 0;

        int inSuccess = inVal + success;
        int sum = ace + inSuccess + error;

        if (sum > 0) {
          double pct = ((ace + inSuccess) / sum) * 100;
          percent = pct.toStringAsFixed(1) + "%";
        }

        aceStr = ace.toString();
        inSuccessStr = inSuccess.toString();
        errorStr = error.toString();
      }

      recapData.add({
        "INDICATOR": ind,
        "ACE": aceStr,
        "IN/SUCCESS": inSuccessStr,
        "FAILED": failedStr,
        "ERROR": errorStr,
        "%": percent,
      });
    }

    // Hitung PERFORMANCE dengan benar
    int totalAce = 0;
    int totalSuccess = 0;
    int totalError = 0;

    List<String> mainCategories = [
      "SERVE",
      "STRIKE",
      "FREEBALL",
      "FIRSTBALL",
      "FEEDING",
      "BLOCKING"
    ];

    for (String cat in mainCategories) {
      totalAce += recap[cat]?["ACE"] ?? 0;

      int error = recap[cat]?["ERROR"] ?? 0;
      int failed =
          recap[cat]?["FAILED"] ?? 0; // hanya FEEDING yang punya FAILED
      totalError += error + failed;

      // Tambahkan IN untuk kategori offensive
      if (["SERVE", "STRIKE", "FREEBALL"].contains(cat)) {
        totalSuccess += recap[cat]?["IN"] ?? 0;
      }

      // Tambahkan SUCCESS untuk kategori defensive
      if (["FIRSTBALL", "FEEDING", "BLOCKING"].contains(cat)) {
        totalSuccess += recap[cat]?["SUCCESS"] ?? 0;
      }
    }

    int numerator = totalAce + totalSuccess;
    int denominator = numerator + totalError;
    double performance = 0.0;
    if (denominator > 0) {
      performance = (numerator / denominator) * 100;
    }

    String formattedPerformance = performance.toStringAsFixed(2) + "%";

    // Tambahkan baris PERFORMANCE
    recapData.add({
      "INDICATOR": "PERFORMANCE",
      "ACE": "",
      "IN/SUCCESS": "",
      "ERROR": "",
      "%": formattedPerformance,
    });

    // Tambahkan baris OPPOENT MISTAKE setelah PERFORMANCE
    int totalOppMistake = _selectedPlayerId != null
        ? 0
        : (recap["TEAM"]?["OPPONENT_MISTAKE"] ?? 0);
    recapData.add({
      "INDICATOR": "OPPONENT MISTAKE",
      "ACE": "",
      "IN/SUCCESS": totalOppMistake.toString(),
      "ERROR": "",
      "%": "-",
    });

    return recapData;
  }

  Future<Map<int, Map<String, dynamic>>> _fetchBallPositionDataForCategory(
    String category, {
    int? playerId,
    int? setNumber,
  }) async {
    final db = await DatabaseHelper.instance.database;
    String query = '''
    SELECT ballPosition, SUM(score) as total
    FROM scores
    WHERE ballPosition IS NOT NULL AND UPPER(category) = ?
  ''';
    List<dynamic> args = [category.toUpperCase()];
    if (playerId != null) {
      query += ' AND player_id = ?';
      args.add(playerId);
    }
    if (setNumber != null) {
      query += ' AND setNumber = ?';
      args.add(setNumber);
    }
    query += ' GROUP BY ballPosition';
    final rows = await db.rawQuery(query, args);

    Map<int, int> ballCounts = {};
    int sumAll = 0;
    for (var row in rows) {
      int pos = int.tryParse((row['ballPosition']?.toString() ?? '0')) ?? 0;
      int total = row['total'] is num
          ? (row['total'] as num).toInt()
          : int.tryParse(row['total']?.toString() ?? '0') ?? 0;
      ballCounts[pos] = total;
      sumAll += total;
    }

    Map<int, Map<String, dynamic>> result = {};
    for (int i = 0; i < 9; i++) {
      int attempts = ballCounts[i] ?? 0;
      double pct = sumAll > 0 ? (attempts / sumAll) * 100 : 0.0;
      result[i] = {"percentage": pct, "attempts": attempts};
    }
    return result;
  }

  Map<String, Map<String, Map<String, dynamic>>> convertBallPositions(
      Map<String, Map<int, Map<String, dynamic>>> original) {
    return original.map((outerKey, innerMap) {
      final convertedInnerMap =
          innerMap.map((int key, Map<String, dynamic> value) {
        return MapEntry(key.toString(), value);
      });
      return MapEntry(outerKey, convertedInnerMap);
    });
  }

  Future<Map<int, Map<String, int>>> _fetchBallPositionAceInDataForCategory(
    String category,
    int? playerId, {
    int? setNumber,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // Pastikan subcategory dalam kondisi uppercase agar konsisten
    String query = '''
    SELECT ballPosition, UPPER(subcategory) AS subcat, COALESCE(SUM(score), 0) AS total
    FROM scores
    WHERE ballPosition IS NOT NULL AND UPPER(category) = ?
  ''';

    List<dynamic> args = [category.toUpperCase()];

    if (playerId != null) {
      query += ' AND player_id = ?';
      args.add(playerId);
    }

    if (setNumber != null) {
      query += ' AND setNumber = ?';
      args.add(setNumber);
    }

    query += ' GROUP BY ballPosition, UPPER(subcategory)';

    final rows = await db.rawQuery(query, args);

    // Inisialisasi data dengan nilai default 0 untuk semua posisi (0-8)
    Map<int, Map<String, int>> data = {
      for (int i = 0; i < 9; i++) i: {"ACE": 0, "IN": 0}
    };

    // Iterasi hasil query dan masukkan ke dalam map
    for (var row in rows) {
      int pos = int.tryParse(row['ballPosition']?.toString() ?? '-1') ?? -1;
      String subcat = row['subcat']?.toString() ?? "";
      int total = (row['total'] is num) ? (row['total'] as num).toInt() : 0;

      // Validasi posisi agar hanya antara 0-8
      if (pos >= 0 && pos < 9) {
        if (subcat == "ACE" || subcat == "IN") {
          data[pos]![subcat] = total;
        }
      }
    }

    return data;
  }

  Future<List<Map<String, dynamic>>> fetchPlayerDetailsForMatch() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
    SELECT p.name as playerName, SUM(s.score) as totalPoints,
           MAX(s.ballPosition) as lastBallPosition
    FROM scores s
    JOIN players p ON s.player_id = p.id
    GROUP BY s.player_id
  ''');
    return rows.map((row) {
      return {
        "playerName": row["playerName"] ?? "",
        "points": row["totalPoints"]?.toString() ?? "0",
        "ballLocation": row["lastBallPosition"]?.toString() ?? "-"
      };
    }).toList();
  }

  Future<Map<int, int>> _fetchSetScoresForTeam(String teamName) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
    SELECT s.setNumber, SUM(s.score) as total
    FROM scores s
    WHERE s.player_id IN (
      SELECT id FROM players WHERE teamName = ?
    )
    AND (UPPER(s.subcategory) = 'ACE' OR UPPER(s.subcategory) = 'OPPONENT_MISTAKE')
    GROUP BY s.setNumber
  ''', [teamName]);
    Map<int, int> setScores = {};
    for (var row in rows) {
      int setNum = row['setNumber'] is int
          ? row['setNumber']
          : int.tryParse(row['setNumber'].toString()) ?? 0;
      int total = row['total'] is int
          ? row['total']
          : int.tryParse(row['total'].toString()) ?? 0;
      setScores[setNum] = total;
    }
    return setScores;
  }

  Future<Map<int, Map<String, dynamic>>> _accumulateAllSetBallPositionData(
      String category) async {
    // Inisialisasi total percobaan tiap cell (0-8)
    Map<int, int> totalCounts = {for (int i = 0; i < 9; i++) i: 0};

    // Misal, set yang ada adalah 1, 2, dan 3.
    for (int setNum = 0; setNum <= 2; setNum++) {
      Map<int, Map<String, dynamic>> setData =
          await _fetchBallPositionDataForCategory(
        category,
        setNumber: setNum,
      );
      for (int i = 0; i < 9; i++) {
        int attempts = (setData[i]?["attempts"] ?? 0) is num
            ? (setData[i]?["attempts"] as num).toInt()
            : 0;
        totalCounts[i] = totalCounts[i]! + attempts;
      }
    }

    int sumAll = totalCounts.values.fold(0, (prev, element) => prev + element);
    Map<int, Map<String, dynamic>> result = {};
    for (int i = 0; i < 9; i++) {
      int attempts = totalCounts[i]!;
      double pct = sumAll > 0 ? (attempts / sumAll) * 100 : 0.0;
      result[i] = {"percentage": pct, "attempts": attempts};
    }
    return result;
  }

// Fungsi untuk mengambil total skor per set untuk lawan (dengan kondisi ERROR)
  Future<Map<int, int>> _fetchSetScoresForOpponent(String teamName) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
    SELECT s.setNumber, SUM(s.score) as total
    FROM scores s
    WHERE s.player_id IN (
      SELECT id FROM players WHERE teamName = ?
    )
    AND UPPER(s.subcategory) = 'ERROR'
    GROUP BY s.setNumber
  ''', [teamName]);
    Map<int, int> setScores = {};
    for (var row in rows) {
      int setNum = row['setNumber'] is int
          ? row['setNumber']
          : int.tryParse(row['setNumber'].toString()) ?? 0;
      int total = row['total'] is int
          ? row['total']
          : int.tryParse(row['total'].toString()) ?? 0;
      setScores[setNum] = total;
    }
    return setScores;
  }

  // Contoh metode untuk mengambil recap data berdasarkan set.
  // Jika setNumber == 0, artinya ALL SET; jika tidak, filter berdasarkan set.
  Future<List<Map<String, String>>> _fetchRecapDataForSet(
      dynamic selectedOption) async {
    final db = await DatabaseHelper.instance.database;
    String query;
    List<dynamic> args = [];

    if (selectedOption is String && selectedOption == -1) {
      // Akumulasi data dari set 0, 1, dan 2
      query = '''
      SELECT category, UPPER(subcategory) as subcat, SUM(score) as total
      FROM scores
      WHERE setNumber IN (0, 1, 2)
      GROUP BY category, UPPER(subcategory)
    ''';
    } else if (selectedOption is int) {
      // Untuk set individual, gunakan setNumber sesuai (currentSet sudah 0 untuk set pertama)
      query = '''
      SELECT category, UPPER(subcategory) as subcat, SUM(score) as total
      FROM scores
      WHERE setNumber = ?
      GROUP BY category, UPPER(subcategory)
    ''';
      args.add(selectedOption);
    } else {
      // Default, ambil semua
      query = '''
      SELECT category, UPPER(subcategory) as subcat, SUM(score) as total
      FROM scores
      GROUP BY category, UPPER(subcategory)
    ''';
    }

    final List<Map<String, dynamic>> rows = await db.rawQuery(query, args);

    // Parsing hasil query menjadi format recapData
    Map<String, Map<String, int>> recap = {
      "SERVE": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "STRIKE": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "FREEBALL": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "FIRSTBALL": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "FEEDING": {"SUCCESS": 0, "FAILED": 0, "ERROR": 0},
      "BLOCKING": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "TEAM": {"OPPONENT_MISTAKE": 0},
    };

    for (var row in rows) {
      String cat = row['category']?.toString().toUpperCase() ?? "";
      String subcat = row['subcat']?.toString() ?? "";
      int total = int.tryParse((row['total'] ?? 0).toString()) ?? 0;
      if (recap.containsKey(cat)) {
        recap[cat]![subcat] = total;
      } else {
        recap[cat] = {subcat: total};
      }
    }

    List<Map<String, String>> recapData = [];
    List<String> indicators = [
      "SERVE",
      "STRIKE",
      "FREEBALL",
      "FIRSTBALL",
      "FEEDING",
      "BLOCKING",
      "OPPONENT MISTAKE"
    ];

    for (String ind in indicators) {
      String aceStr = "";
      String inSuccessStr = "";
      String failedStr = "";
      String errorStr = "";
      String percent = "0%";

      if (ind == "OPPONENT MISTAKE") {
        inSuccessStr = (recap["TEAM"]?["OPPONENT_MISTAKE"] ?? 0).toString();
        percent = "-";
      } else if (ind == "FEEDING") {
        int success = recap[ind]?["SUCCESS"] ?? 0;
        int failed = recap[ind]?["FAILED"] ?? 0;
        int error = recap[ind]?["ERROR"] ?? 0;

        int sum = success + failed + error;
        if (sum > 0) {
          double pct = (success / sum) * 100;
          percent = pct.toStringAsFixed(1) + "%";
        }

        inSuccessStr = success.toString();
        failedStr = failed.toString();
        errorStr = error.toString();
      } else {
        int ace = recap[ind]?["ACE"] ?? 0;
        int inVal = recap[ind]?["IN"] ?? 0;
        int success = recap[ind]?["SUCCESS"] ?? 0;
        int error = recap[ind]?["ERROR"] ?? 0;

        int inSuccess = inVal + success;
        int sum = ace + inSuccess + error;

        if (sum > 0) {
          double pct = ((ace + inSuccess) / sum) * 100;
          percent = pct.toStringAsFixed(1) + "%";
        }

        aceStr = ace.toString();
        inSuccessStr = inSuccess.toString();
        errorStr = error.toString();
      }

      recapData.add({
        "INDICATOR": ind,
        "ACE": aceStr,
        "IN/SUCCESS": inSuccessStr,
        "FAILED": failedStr,
        "ERROR": errorStr,
        "%": percent,
      });
    }

    return recapData;
  }

// Contoh fungsi untuk mengambil data ball position tim per set.
// Fungsi ini harus mengembalikan data dalam bentuk List<List<String>> untuk ditampilkan di tabel.
// Misalnya, setiap baris adalah list: ["SERVE: 50%", "FREEBALL: 40%", "STRIKE: 60%"]
  Future<List<List<String>>> _fetchTeamBallPositionDataForSet(
      int setNumber) async {
    // Anda bisa menggunakan fungsi _fetchBallPositionDataForCategory untuk tiap kategori.
    // Berikut contoh implementasi minimal (sesuaikan dengan data asli):
    List<List<String>> tableData = [];
    List<String> categories = ["SERVE", "FREEBALL", "STRIKE"];
    for (String cat in categories) {
      Map<int, Map<String, dynamic>> data =
          await _fetchBallPositionDataForCategory(cat, setNumber: setNumber);
      // Misalnya, hitung total percobaan untuk kategori tersebut
      int totalAttempts = 0;
      data.forEach((key, value) {
        totalAttempts += value["attempts"] as int;
      });
      // Hitung rata-rata persen untuk kategori (ini hanya contoh)
      double avgPct = 0;
      if (totalAttempts > 0) {
        double sumPct = 0;
        data.forEach((key, value) {
          sumPct += value["percentage"] as double;
        });
        avgPct = sumPct / data.length;
      }
      tableData.add(["$cat: ${avgPct.toStringAsFixed(1)}%"]);
    }
    return tableData;
  }

// Contoh fungsi untuk mengambil data recap pemain per set.
  Future<List<Map<String, String>>> _fetchPlayerRecapData(
      {required int playerId, required int setNumber}) async {
    // Implementasikan query serupa dengan _fetchRecapDataForSet dengan tambahan filter player_id.
    final db = await DatabaseHelper.instance.database;
    String query = '''
    SELECT category, UPPER(subcategory) as subcat, SUM(score) as total
    FROM scores
    WHERE player_id = ?
  ''';
    List<dynamic> args = [playerId];
    if (setNumber != 0) {
      query += ' AND setNumber = ?';
      args.add(setNumber);
    }
    query += ' GROUP BY category, UPPER(subcategory)';
    final List<Map<String, dynamic>> rows = await db.rawQuery(query, args);

    Map<String, Map<String, int>> recap = {
      "SERVE": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "STRIKE": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "FREEBALL": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "FIRSTBALL": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "FEEDING": {"SUCCESS": 0, "FAILED": 0, "ERROR": 0},
      "BLOCKING": {"ACE": 0, "IN": 0, "SUCCESS": 0, "ERROR": 0},
      "TEAM": {"OPPONENT_MISTAKE": 0},
    };

    for (var row in rows) {
      String cat = row['category']?.toString().toUpperCase() ?? "";
      String subcat = row['subcat']?.toString() ?? "";
      int total = int.tryParse((row['total'] ?? 0).toString()) ?? 0;
      if (recap.containsKey(cat)) {
        recap[cat]![subcat] = total;
      } else {
        recap[cat] = {subcat: total};
      }
    }
    List<Map<String, String>> recapData = [];
    List<String> indicators = [
      "SERVE",
      "STRIKE",
      "FREEBALL",
      "FIRSTBALL",
      "FEEDING",
      "BLOCKING",
      "OPPONENT MISTAKE"
    ];

    for (String ind in indicators) {
      String aceStr = "";
      String inSuccessStr = "";
      String failedStr = "";
      String errorStr = "";
      String percent = "0%";

      if (ind == "OPPONENT MISTAKE") {
        inSuccessStr = (recap["TEAM"]?["OPPONENT_MISTAKE"] ?? 0).toString();
        percent = "-";
      } else if (ind == "FEEDING") {
        int success = recap[ind]?["SUCCESS"] ?? 0;
        int failed = recap[ind]?["FAILED"] ?? 0;
        int error = recap[ind]?["ERROR"] ?? 0;

        int sum = success + failed + error;
        if (sum > 0) {
          double pct = (success / sum) * 100;
          percent = pct.toStringAsFixed(1) + "%";
        }

        inSuccessStr = success.toString();
        failedStr = failed.toString();
        errorStr = error.toString();
      } else {
        int ace = recap[ind]?["ACE"] ?? 0;
        int inVal = recap[ind]?["IN"] ?? 0;
        int success = recap[ind]?["SUCCESS"] ?? 0;
        int error = recap[ind]?["ERROR"] ?? 0;

        int inSuccess = inVal + success;
        int sum = ace + inSuccess + error;

        if (sum > 0) {
          double pct = ((ace + inSuccess) / sum) * 100;
          percent = pct.toStringAsFixed(1) + "%";
        }

        aceStr = ace.toString();
        inSuccessStr = inSuccess.toString();
        errorStr = error.toString();
      }

      recapData.add({
        "INDICATOR": ind,
        "ACE": aceStr,
        "IN/SUCCESS": inSuccessStr,
        "FAILED": failedStr,
        "ERROR": errorStr,
        "%": percent,
      });
    }

    return recapData;
  }

// Contoh fungsi untuk mengambil data ball position pemain per set.
// Format pengembalian disesuaikan dengan fungsi _fetchTeamBallPositionDataForSet.
  Future<List<List<String>>> _fetchPlayerBallPositionData(
      {required int playerId, required int setNumber}) async {
    // Implementasikan logika serupa dengan _fetchBallPositionDataForCategory
    // dengan filter berdasarkan playerId.
    // Berikut contoh minimal:
    List<List<String>> tableData = [];
    List<String> categories = ["SERVE", "FREEBALL", "STRIKE"];
    for (String cat in categories) {
      Map<int, Map<String, dynamic>> data =
          await _fetchBallPositionDataForCategory(
        cat,
        playerId: playerId,
        setNumber: setNumber,
      );
      int totalAttempts = 0;
      data.forEach((key, value) {
        totalAttempts += value["attempts"] as int;
      });
      double avgPct = 0;
      if (totalAttempts > 0) {
        double sumPct = 0;
        data.forEach((key, value) {
          sumPct += value["percentage"] as double;
        });
        avgPct = sumPct / data.length;
      }
      tableData.add(["$cat: ${avgPct.toStringAsFixed(1)}%"]);
    }
    return tableData;
  }

  // Metode untuk export PDF yang menggabungkan semua data di atas.
  Future<void> _exportPdf() async {
    // Ambil data recap tim per set (0: ALL SET, 1: SET 1, dst.)
    Map<int, List<Map<String, String>>> teamRecapData = {};
    for (int setNum = 0; setNum <= 2; setNum++) {
      teamRecapData[setNum] = await _fetchRecapDataForSet(setNum);
    }

    // Ambil data ball position tim per set per kategori.
    // Dalam metode _exportPdf() pada _ResultPageState
    Map<int, Map<String, Map<int, Map<String, dynamic>>>> teamBallPositionData =
        {};
    List<String> categories = ["SERVE", "FREEBALL", "STRIKE"];
    for (int setNum = 0; setNum <= 2; setNum++) {
      Map<String, Map<int, Map<String, dynamic>>> catData = {};
      for (String cat in categories) {
        // Gunakan fungsi _accumulateTeamBallPositionDataForSet untuk mendapatkan data akumulasi tim
        catData[cat] =
            await _accumulateTeamBallPositionDataForSet(cat, setNumber: setNum);
      }
      teamBallPositionData[setNum] = catData;
    }

    // Ambil data pemain dari _players.
    Map<int, Map<int, List<Map<String, String>>>> playerRecapData = {};
    Map<int, Map<int, Map<String, Map<int, Map<String, dynamic>>>>>
        playerBallPositionData = {};
    for (var p in _players) {
      int playerId = p["id"];
      Map<int, List<Map<String, String>>> recapBySet = {};
      Map<int, Map<String, Map<int, Map<String, dynamic>>>> ballPosBySet = {};
      for (int setNum = 0; setNum <= 2; setNum++) {
        recapBySet[setNum] =
            await _fetchPlayerRecapData(playerId: playerId, setNumber: setNum);
        Map<String, Map<int, Map<String, dynamic>>> catData = {};
        for (String cat in categories) {
          catData[cat] = await _fetchBallPositionDataForCategory(cat,
              playerId: playerId, setNumber: setNum);
        }
        ballPosBySet[setNum] = catData;
      }
      playerRecapData[playerId] = recapBySet;
      playerBallPositionData[playerId] = ballPosBySet;
    }
    List<int> playerIds = _players.map((p) => p["id"] as int).toList();

    // Pastikan juga Anda mengambil data detail pemain jika diperlukan (misalnya, untuk nama & skor)
    // Misalnya, jika fetchPlayerDetailsForMatch() mengembalikan data yang sama dengan _players, Anda bisa mengirimkan _players.
    await generateCompletePdf(
      teamName: widget.teamName,
      opponentTeam: widget.opponentTeam,
      teamSet: _teamSet,
      opponentSet: _opponentSet,
      setHistory: widget.setHistory,
      teamRecapData: teamRecapData,
      teamBallPositionData: teamBallPositionData,
      playerRecapData: playerRecapData,
      playerBallPositionData: playerBallPositionData,
      players: _players, // Mengirimkan data _players sebagai parameter
      playerDetails: await fetchPlayerDetailsForMatch(),
      playerIds: playerIds,
    );
  }

  Future<Map<int, Map<String, dynamic>>> _accumulateTeamBallPositionDataForSet(
    String category, {
    int? setNumber,
  }) async {
    // Inisialisasi map untuk menyimpan total percobaan untuk tiap cell (0-8)
    Map<int, int> totalCounts = {for (int i = 0; i < 9; i++) i: 0};

    // Ambil data ball position untuk setiap pemain dan akumulasi
    for (var player in _players) {
      int playerId = player["id"];
      // Ambil data ball position untuk pemain tersebut berdasarkan kategori dan setNumber.
      Map<int, Map<String, dynamic>> playerData =
          await _fetchBallPositionDataForCategory(
        category,
        playerId: playerId,
        setNumber: setNumber,
      );
      for (int i = 0; i < 9; i++) {
        // Casting nilai attempts ke int agar dapat dijumlahkan
        int attempts = (playerData[i]?["attempts"] ?? 0) is num
            ? (playerData[i]?["attempts"] as num).toInt()
            : 0;
        totalCounts[i] = totalCounts[i]! + attempts;
      }
    }

    // Hitung total seluruh percobaan
    int sumAll = totalCounts.values.fold(0, (prev, element) => prev + element);

    // Buat struktur data dengan persentase dan total percobaan per cell
    Map<int, Map<String, dynamic>> result = {};
    for (int i = 0; i < 9; i++) {
      int attempts = totalCounts[i]!;
      double pct = 0.0;
      if (sumAll > 0) {
        pct = (attempts / sumAll) * 100;
      }
      result[i] = {
        "percentage": pct,
        "attempts": attempts,
      };
    }
    return result;
  }

  /// Fungsi untuk mengambil persentase lokasi bola berdasarkan kategori (dan filter pemain jika ada).
  Widget _buildBallPositionTableAceIn() {
    return FutureBuilder<Map<int, Map<String, int>>>(
      future: _fetchBallPositionAceInDataForCategory(
        _selectedCategory,
        _selectedPlayerId,
        setNumber: _selectedSet == -1 ? null : _selectedSet,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: 320,
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        Map<int, Map<String, int>> ballData = snapshot.data ?? {};

        // Hitung total nilai ACE dan IN dari semua cell
        int totalAce = 0;
        int totalIn = 0;
        ballData.forEach((index, data) {
          totalAce += data["ACE"] ?? 0;
          totalIn += data["IN"] ?? 0;
        });
        int grandTotal = totalAce + totalIn;

        return Container(
          width: 320,
          height: 150,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/court1.png"),
              fit: BoxFit.fill,
            ),
          ),
          child: Table(
            defaultColumnWidth: FixedColumnWidth(40),
            border: TableBorder.all(color: Colors.transparent),
            children: List.generate(3, (rowIndex) {
              return TableRow(
                children: List.generate(3, (colIndex) {
                  int index = rowIndex * 3 + colIndex;
                  int ace = ballData[index]?["ACE"] ?? 0;
                  int inVal = ballData[index]?["IN"] ?? 0;
                  int cellTotal = ace + inVal;
                  double percentage =
                      grandTotal > 0 ? (cellTotal / grandTotal) * 100 : 0.0;
                  return Container(
                    height: 50,
                    alignment: Alignment.center,
                    color: Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Baris untuk persentase
                        Text(
                          "${percentage.toStringAsFixed(1)}%",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Baris untuk angka ACE/IN
                        Text(
                          "(ACE: $ace/ IN: $inVal)",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            }),
          ),
        );
      },
    );
  }

  /// Dropdown untuk memilih kategori (SERVE, STRIKE, FREEBALL).
  Widget _buildCategoryTabs() {
    List<String> categories = ["SERVE", "STRIKE", "FREEBALL"];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: categories.map((cat) {
        bool isSelected = (_selectedCategory.toUpperCase() == cat);
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategory = cat;
              // Jika kategori berubah, Anda dapat mereset filter pemain (jika diperlukan)
              _selectedPlayerId = null;
            });
          },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 12),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Color(0xFF002F42)
                  : Color.fromARGB(
                      255, 136, 136, 136), //  // Solid color for both states
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: Colors.grey, width: 1) // Border only when selected
                  : null,
            ),
            child: Text(
              cat,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Widget untuk menampilkan grid lokasi bola dalam format tabel 3x3.
  Widget _buildBallPositionTable() {
    return FutureBuilder<Map<int, Map<String, int>>>(
      future: _fetchBallPositionAceInDataForCategory(
        _selectedCategory,
        _selectedPlayerId,
        // Jika _selectedSet == -1, artinya ALL SET, sehingga tidak difilter berdasarkan set.
        // Jika tidak, gunakan nilai _selectedSet (misalnya, 0 untuk set pertama, dst.)
        setNumber: _selectedSet == -1 ? null : _selectedSet,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: 320,
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Dapatkan data, jika tidak ada gunakan map kosong.
        Map<int, Map<String, int>> ballData = snapshot.data ?? {};

        // Hitung total seluruh nilai untuk kategori "ACE" dan "IN"
        int totalAce = 0;
        int totalIn = 0;
        ballData.forEach((index, data) {
          totalAce += data["ACE"] ?? 0;
          totalIn += data["IN"] ?? 0;
        });
        int grandTotal = totalAce + totalIn;

        return Container(
          width: 320,
          height: 150,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/court1.png"),
              fit: BoxFit.fill,
            ),
          ),
          child: Table(
            defaultColumnWidth: FixedColumnWidth(40),
            border: TableBorder.all(color: Colors.transparent),
            children: List.generate(3, (rowIndex) {
              return TableRow(
                children: List.generate(3, (colIndex) {
                  int index = rowIndex * 3 + colIndex;
                  // Ambil nilai ACE dan IN pada cell, jika tidak ada gunakan 0.
                  int ace = ballData[index]?["ACE"] ?? 0;
                  int inVal = ballData[index]?["IN"] ?? 0;
                  int cellTotal = ace + inVal;

                  // Hitung persentase kontribusi cell terhadap total (jika total > 0)
                  double percentage =
                      grandTotal > 0 ? (cellTotal / grandTotal) * 100 : 0;

                  // Format label untuk cell, misalnya "45.0%\n(3/2)"
                  String label =
                      "${percentage.toStringAsFixed(1)}%\n($ace/$inVal)";

                  return Container(
                    height: 50,
                    alignment: Alignment.center,
                    color: Colors.transparent,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        );
      },
    );
  }

  /// Widget untuk menampilkan row pemain (player ball) di bawah tabel lokasi bola.
  Widget _buildPlayersRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _players.map((p) {
        int playerId = p["id"];
        bool isSelected = _selectedPlayerId == playerId;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPlayerId = isSelected ? null : playerId;
            });
          },
          child: Container(
            width: 50, // Keep this the same size for circular shape
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle, // Set shape to circle
              color: isSelected
                  ? Color(0xFF002F42)
                  : Color.fromARGB(
                      255, 136, 136, 136), // Solid color for both states
              border: isSelected
                  ? Border.all(
                      color: Colors.grey, width: 1) // Border only when selected
                  : null,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    p["number"]?.toString() ?? "", // Player number
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    p["name"] ?? "", // Player name
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis, // Prevents overflow
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Area kanan: Menampilkan header recap, tabel recap data, dan tombol navigasi.
  Widget _buildRightArea() {
    return Padding(
      padding: EdgeInsets.only(left: 8), // adjust value as needed
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecapHeader(),
          SizedBox(height: 4),
          SizedBox(height: 4),
          Expanded(child: _buildRecapTable()),
          // _buildButtonRow(),
        ],
      ),
    );
  }

  Widget _buildSetTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // SET TABS
        Row(
          children: _setOptions.map((option) {
            bool isSelected = (option == _selectedSet);
            String label = (option == -1) ? "ALL SET" : "SET ${option + 1}";

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSet = option;
                });
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 4),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Color(0xFF002F42)
                      : Color.fromARGB(255, 136, 136, 136),
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: Colors.grey, width: 1)
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Header recap.
  Widget _buildRecapHeader() {
    String label;
    if (_selectedSet == -1) {
      label = "ALL SET";
    } else {
      label = "SET ${(_selectedSet ?? 0) + 1}";
    }

    String playerInfo = "";
    if (_selectedPlayerId != null) {
      final found = _players.firstWhere(
        (p) => p["id"] == _selectedPlayerId,
        orElse: () => {},
      );
      if (found.isNotEmpty) {
        String playerNumber = found["number"]?.toString() ?? "";
        String playerName = found["name"] ?? "";
        playerInfo = " | $playerName - #$playerNumber";
      }
    }

    return Text(
      "RECAP DATA : $label$playerInfo",
      style: TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Tabel recap data dengan struktur: INDICATOR, ACE, IN/SUCCESS, ERROR, %
  Widget _buildRecapTable() {
    return FutureBuilder<List<Map<String, String>>>(
      future: _fetchRecapData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child:
                Text("Tidak ada data", style: TextStyle(color: Colors.white)),
          );
        }

        final data = snapshot.data!;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: DataTable(
              dataRowHeight: 27,
              headingRowHeight: 36,
              columnSpacing: 12,
              headingRowColor:
                  MaterialStateProperty.all(Colors.blueGrey.shade700),
              border: TableBorder(
                horizontalInside: BorderSide(width: 0.5, color: Colors.white30),
                verticalInside: BorderSide(width: 0.5, color: Colors.white30),
              ),
              columns: [
                DataColumn(
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "INDICATOR",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                DataColumn(label: _tableHeader("ACE")),
                DataColumn(label: _tableHeader("IN/\nSUCCESS")),
                DataColumn(label: _tableHeader("FAILED")),
                DataColumn(label: _tableHeader("ERROR")),
                DataColumn(label: _tableHeader("%")),
              ],
              rows: data.map((row) {
                bool isPerformanceRow = row["INDICATOR"] == "PERFORMANCE";

                return DataRow(cells: [
                  DataCell(
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        row["INDICATOR"] ?? "",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  DataCell(_tableCell(row["ACE"] ?? "")),
                  DataCell(_tableCell(row["IN/SUCCESS"] ?? "")),
                  DataCell(_tableCell(row["FAILED"] ?? "")),
                  DataCell(_tableCell(row["ERROR"] ?? "")),
                  DataCell(
                    isPerformanceRow
                        ? Text(
                            row["%"] ?? "",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : _tableCell(row["%"] ?? ""),
                  ),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _tableHeader(String title) {
    return Center(
      // Ensures vertical and horizontal centering
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _tableCell(String value) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  //Untuk table Score bagian atas
  Widget _buildTableScore() {
    return SizedBox(
      height: 80, // Bisa sesuaikan kalau mau lebih tinggi
      child: Row(
        children: [
          // Tombol BACK di kiri (ikon panah saja)
          Container(
            width: 60,
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.arrow_back),
              color: Colors.white,
              style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.all<Color>(Colors.transparent),
              ),
            ),
          ),

          SizedBox(width: 16),

          // Tabel skor di tengah
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 0.0),
              child: Container(
                alignment: Alignment.center,
                child: Table(
                  border: TableBorder.all(color: Colors.white70, width: 0.8),
                  defaultColumnWidth: FixedColumnWidth(50),
                  children: [
                    // Baris untuk tim
                    TableRow(
                      decoration: BoxDecoration(color: Colors.transparent),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(1),
                          child: Center(
                            child: Text(
                              widget.teamName,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(1),
                          child: Center(
                            child: Text(
                              "${widget.teamSet}",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        // Loop untuk skor per set
                        for (int i = 0; i < widget.setHistory.length; i++)
                          Padding(
                            padding: EdgeInsets.all(1),
                            child: Center(
                              child: Text(
                                widget.setHistory[i]['teamScore'].toString(),
                                style:
                                TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                        // Tambahkan skor current jika sedang currentResult
                        if (widget.isCurrentResult)
                          Padding(
                            padding: EdgeInsets.all(1),
                            child: Center(
                              child: Text(
                                widget.teamScore.toString(),
                                style:
                                TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Baris untuk lawan
                    TableRow(
                      decoration: BoxDecoration(color: Colors.transparent),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(1),
                          child: Center(
                            child: Text(
                              widget.opponentTeam,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(1),
                          child: Center(
                            child: Text(
                              "${widget.opponentSet}",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        for (int i = 0; i < widget.setHistory.length; i++)
                          Padding(
                            padding: EdgeInsets.all(1),
                            child: Center(
                              child: Text(
                                widget.setHistory[i]['opponentScore'].toString(),
                                style:
                                TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                        if (widget.isCurrentResult)
                          Padding(
                            padding: EdgeInsets.all(1),
                            child: Center(
                              child: Text(
                                widget.opponentScore.toString(),
                                style:
                                TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/bgresult.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Layout utama kamu
              Container(
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    _buildTableScore(),
                    SizedBox(height: 2),
                    _buildSetTabs(),
                    SizedBox(height: 18),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCategoryTabs(),
                                SizedBox(height: 8),
                                Center(child: _buildBallPositionTableAceIn()),
                                SizedBox(height: 8),
                                _buildPlayersRow(),
                              ],
                            ),
                          ),
                          Container(width: 2, color: Colors.white30),
                          Expanded(child: _buildRecapTable()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tombol-tombol di pojok kanan bawah (floating)
              Positioned(
                right: 8,
                top: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final data = await _fetchRecapData();
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ChartPage(
                                  teamName: widget.teamName,        // <-- tambahkan ini
                                  opponentTeam: widget.opponentTeam, // <-- dan ini
                                  setHistory: widget.setHistory,     // <-- serta ini
                                )),
                              );
                            }
                          },
                          icon: const Icon(Icons.bar_chart, color: Colors.white, size: 14),
                          label: const Text("Chart", style: TextStyle(color: Colors.white, fontSize: 10)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            minimumSize: const Size(90, 30),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          ),
                        ),
                        SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _exportPdf();
                          },
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 14),
                          label: const Text("Export", style: TextStyle(color: Colors.white, fontSize: 10)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(90, 30),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return AlertDialog(
                              title: const Text("Konfirmasi"),
                              content: const Text("Apakah Anda ingin menyimpan pertandingan dan kembali ke menu utama?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text("Batal"),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(dialogContext);
                                    await DatabaseHelper.instance.resetScores();
                                    await DatabaseHelper.instance.resetPlayers();
                                    Navigator.pushNamed(context, '/');
                                  },
                                  child: const Text("Ya", style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.home, color: Colors.white, size: 14),
                      label: const Text("Main Menu", style: TextStyle(color: Colors.white, fontSize: 10)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        minimumSize: const Size(90, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
