import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:takraw_analyst/data/database/database_helper.dart';

// Fungsi _fetchPlayerRecapData yang telah diperbarui:
Future<List<Map<String, String>>> _fetchPlayerRecapData({
  required int playerId,
  required int setNumber,
}) async {
  final db = await DatabaseHelper.instance.database;
  String query = '''
    SELECT category, UPPER(subcategory) as subcat, COALESCE(SUM(score), 0) as total
    FROM scores
    WHERE player_id = ? AND setNumber = ?
    GROUP BY category, UPPER(subcategory)
  ''';
  List<dynamic> args = [playerId, setNumber];
  final List<Map<String, dynamic>> rows = await db.rawQuery(query, args);
  print("Recap rows for player $playerId, set $setNumber: $rows");

  // Inisialisasi default recap
  Map<String, Map<String, int>> recap = {
    "SERVE": {"ACE": 0, "IN": 0, "FAILED": 0, "ERROR": 0},
    "STRIKE": {"ACE": 0, "IN": 0, "FAILED": 0, "ERROR": 0},
    "FREEBALL": {"ACE": 0, "IN": 0, "FAILED": 0, "ERROR": 0},
    "FIRSTBALL": {"SUCCESS": 0, "FAILED": 0, "ERROR": 0},
    "FEEDING": {"SUCCESS": 0, "FAILED": 0, "ERROR": 0},
    "BLOCKING": {"ACE": 0, "SUCCESS": 0, "FAILED": 0, "ERROR": 0},
    "OPPONENT MISTAKE": {"": 0},
  };

  for (var row in rows) {
    String cat = row['category']?.toString().toUpperCase() ?? "";
    // Ubah nama subkategori sesuai kategori:
    String subcat = row['subcat']?.toString().toUpperCase() ?? "";
    if (cat == "SERVE" || cat == "FREEBALL" || cat == "STRIKE") {
      // Untuk kategori ini, gunakan field IN
      if (subcat == "IN/SUCCESS" || subcat == "IN") {
        subcat = "IN";
      } else if (subcat == "FAILED") {
        subcat = "FAILED";
      }
    } else if (cat == "FEEDING" || cat == "FIRSTBALL" || cat == "BLOCKING") {
      // Untuk kategori ini, gunakan field SUCCESS
      if (subcat == "IN" || subcat == "IN/SUCCESS") {
        subcat = "SUCCESS";
      } else if (subcat == "FAILED") {
        subcat = "FAILED";
      }
    }
    int total = int.tryParse(row['total']?.toString() ?? '0') ?? 0;
    if (recap.containsKey(cat)) {
      recap[cat]![subcat] = total;
    } else {
      recap[cat] = {subcat: total};
    }
  }

  // Daftar indikator yang ingin ditampilkan
  List<String> indicators = [
    "SERVE",
    "STRIKE",
    "FREEBALL",
    "FIRSTBALL",
    "FEEDING",
    "BLOCKING",
    "OPPONENT MISTAKE"
  ];

  List<Map<String, String>> recapData = [];
  for (String ind in indicators) {
    int ace = 0, inSuccess = 0, failed = 0, error = 0;
    // Untuk kategori SERVE, STRIKE, FREEBALL gunakan key "IN"
    if (ind == "SERVE" || ind == "STRIKE" || ind == "FREEBALL") {
      ace = recap[ind]?["ACE"] ?? 0;
      inSuccess = recap[ind]?["IN"] ?? 0;
      failed = recap[ind]?["FAILED"] ?? 0;
      error = recap[ind]?["ERROR"] ?? 0;
    }
    // Untuk kategori FEEDING, FIRSTBALL, BLOCKING gunakan key "SUCCESS"
    else if (ind == "FIRSTBALL" || ind == "FEEDING" || ind == "BLOCKING") {
      ace = recap[ind]?["ACE"] ?? 0;
      inSuccess = recap[ind]?["SUCCESS"] ?? 0;
      failed = recap[ind]?["FAILED"] ?? 0;
      error = recap[ind]?["ERROR"] ?? 0;
    }
    // OPPONENT MISTAKE
    else if (ind == "OPPONENT MISTAKE") {
      // Misalnya gunakan field dari TEAM jika diperlukan
      inSuccess = recap["OPPONENT MISTAKE"]?[""] ?? 0;
    }
    int sum = ace + inSuccess + failed + error;
    String percent = "0%";
    if (ind != "OPPONENT MISTAKE" && sum > 0) {
      double pct = ((ace + inSuccess) / sum) * 100;
      percent = pct.toStringAsFixed(1) + "%";
    } else if (ind == "OPPONENT MISTAKE") {
      percent = "-";
    }
    // Untuk tampilan, gunakan label yang sesuai
    String aceStr = (ind == "OPPONENT MISTAKE") ? "" : ace.toString();
    String inSuccessStr = inSuccess.toString();
    String failedStr = (ind == "OPPONENT MISTAKE")
        ? ""
        : (failed == 0 ? "" : failed.toString());
    String errorStr = (ind == "OPPONENT MISTAKE") ? "" : error.toString();

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

/// Recap Data ALL SET untuk pemain (akumulasi dari set individual).
List<Map<String, String>> generatePlayerAllSetRecap(
    Map<int, List<Map<String, String>>> playerRecapData) {
  Map<String, Map<String, int>> accum = {
    "SERVE": {"ACE": 0, "IN": 0, "FAILED": 0, "ERROR": 0},
    "STRIKE": {"ACE": 0, "IN": 0, "FAILED": 0, "ERROR": 0},
    "FREEBALL": {"ACE": 0, "IN": 0, "FAILED": 0, "ERROR": 0},
    "FIRSTBALL": {"SUCCESS": 0, "FAILED": 0, "ERROR": 0},
    "FEEDING": {"SUCCESS": 0, "FAILED": 0, "ERROR": 0},
    "BLOCKING": {"ACE": 0, "SUCCESS": 0, "FAILED": 0, "ERROR": 0},
    "OPPONENT MISTAKE": {"": 0},
  };

  List<String> indicators = [
    "SERVE",
    "STRIKE",
    "FREEBALL",
    "FIRSTBALL",
    "FEEDING",
    "BLOCKING",
    "OPPONENT MISTAKE"
  ];

  for (int key in playerRecapData.keys) {
    if (key == -1) continue;
    List<Map<String, String>> setData = playerRecapData[key] ?? [];
    for (var row in setData) {
      String indicator = row["INDICATOR"] ?? "";
      if (indicator.isEmpty || !accum.containsKey(indicator)) continue;
      if (indicator == "SERVE" ||
          indicator == "STRIKE" ||
          indicator == "FREEBALL") {
        int ace = int.tryParse(row["ACE"] ?? "0") ?? 0;
        int inVal = int.tryParse(row["IN/SUCCESS"] ?? "0") ?? 0;
        int failed = int.tryParse(row["FAILED"] ?? "0") ?? 0;
        int error = int.tryParse(row["ERROR"] ?? "0") ?? 0;
        accum[indicator]!["ACE"] = (accum[indicator]!["ACE"] ?? 0) + ace;
        accum[indicator]!["IN"] = (accum[indicator]!["IN"] ?? 0) + inVal;
        accum[indicator]!["FAILED"] =
            (accum[indicator]!["FAILED"] ?? 0) + failed;
        accum[indicator]!["ERROR"] = (accum[indicator]!["ERROR"] ?? 0) + error;
      } else if (indicator == "FIRSTBALL" ||
          indicator == "FEEDING" ||
          indicator == "BLOCKING") {
        int ace = int.tryParse(row["ACE"] ?? "0") ?? 0;
        int success = int.tryParse(row["IN/SUCCESS"] ?? "0") ?? 0;
        int failed = int.tryParse(row["FAILED"] ?? "0") ?? 0;
        int error = int.tryParse(row["ERROR"] ?? "0") ?? 0;
        accum[indicator]!["ACE"] = (accum[indicator]!["ACE"] ?? 0) + ace;
        accum[indicator]!["SUCCESS"] =
            (accum[indicator]!["SUCCESS"] ?? 0) + success;
        accum[indicator]!["FAILED"] =
            (accum[indicator]!["FAILED"] ?? 0) + failed;
        accum[indicator]!["ERROR"] = (accum[indicator]!["ERROR"] ?? 0) + error;
      } else if (indicator == "OPPONENT MISTAKE") {
        int value = int.tryParse(row["IN/SUCCESS"] ?? "0") ?? 0;
        accum[indicator]![""] = (accum[indicator]![""] ?? 0) + value;
      }
    }
  }

  List<Map<String, String>> allSetRecapList = [];
  for (String ind in indicators) {
    int ace = 0;
    int inOrSuccess = 0;
    int failed = 0;
    int error = 0;
    if (ind == "SERVE" ||
        ind == "STRIKE" ||
        ind == "FREEBALL" ||
        ind == "BLOCKING") {
      ace = accum[ind]?["ACE"] ?? 0;
      inOrSuccess = (accum[ind]?["IN"] ?? 0) + (accum[ind]?["SUCCESS"] ?? 0);
      failed = accum[ind]?["FAILED"] ?? 0;
      error = accum[ind]?["ERROR"] ?? 0;
    } else if (ind == "FIRSTBALL" || ind == "FEEDING") {
      inOrSuccess = accum[ind]?["SUCCESS"] ?? 0;
      failed = accum[ind]?["FAILED"] ?? 0;
      error = accum[ind]?["ERROR"] ?? 0;
    } else if (ind == "OPPONENT MISTAKE") {
      inOrSuccess = accum[ind]?[""] ?? 0;
    }
    int sum = ace + inOrSuccess + failed + error;
    String percent = "0%";
    if (ind != "OPPONENT MISTAKE" && sum > 0) {
      double pct = ((ace + inOrSuccess) / sum) * 100;
      percent = pct.toStringAsFixed(1) + "%";
    } else if (ind == "OPPONENT MISTAKE") {
      percent = "-";
    }
    String aceStr = (ind == "OPPONENT MISTAKE") ? "" : ace.toString();
    String inSuccessStr = inOrSuccess.toString();
    String failedStr = (ind == "OPPONENT MISTAKE")
        ? ""
        : (failed == 0 ? "" : failed.toString());
    String errorStr = (ind == "OPPONENT MISTAKE") ? "" : error.toString();

    allSetRecapList.add({
      "INDICATOR": ind,
      "ACE": aceStr,
      "IN/SUCCESS": inSuccessStr,
      "FAILED": failedStr,
      "ERROR": errorStr,
      "%": percent,
    });
  }
  return allSetRecapList;
}

List<String> _calculatePerformanceRow(List<Map<String, String>> data) {
  int ace = 0;
  int inSuccess = 0;
  int failed = 0;
  int error = 0;

  for (var row in data) {
    final indicator = row["INDICATOR"]?.toUpperCase() ?? "";

    ace += int.tryParse(row["ACE"] ?? "0") ?? 0;
    failed += int.tryParse(row["FAILED"] ?? "0") ?? 0;
    error += int.tryParse(row["ERROR"] ?? "0") ?? 0;

    // IN/SUCCESS hanya dihitung jika bukan OPPONENT MISTAKE
    if (indicator != "OPPONENT MISTAKE") {
      inSuccess += int.tryParse(row["IN/SUCCESS"] ?? "0") ?? 0;
    }
  }

  int total = ace + inSuccess + failed + error;
  double percent = total == 0 ? 0 : ((ace + inSuccess) / total) * 100;

  return [
    "PERFORMANCE",
    ace.toString(),
    inSuccess.toString(),
    failed.toString(),
    error.toString(),
    "${percent.toStringAsFixed(1)}%",
  ];
}

/// =====================
/// Fungsi Data Ball Position
/// =====================

/// Mengambil data ball position per kategori untuk satu set.
Future<Map<int, Map<String, dynamic>>> _getBallPositionDataWithPercentage(
  String category, {
  int? playerId,
  int? setNumber,
}) async {
  // Ambil data ACE dan IN (data dari query yang mengelompokkan berdasarkan subkategori)
  Map<int, Map<String, int>> aceInData =
      await _fetchBallPositionAceInDataForCategory(
    category,
    playerId,
    setNumber: setNumber,
  );

  // Hitung total untuk setiap cell (ACE + IN) dan total keseluruhan
  int grandTotal = 0;
  for (int i = 0; i < 9; i++) {
    int cellTotal = (aceInData[i]?["ACE"] ?? 0) + (aceInData[i]?["IN"] ?? 0);
    grandTotal += cellTotal;
  }

  // Bangun data hasil dengan menambahkan persentase
  Map<int, Map<String, dynamic>> result = {};
  for (int i = 0; i < 9; i++) {
    int cellTotal = (aceInData[i]?["ACE"] ?? 0) + (aceInData[i]?["IN"] ?? 0);
    double percentage = grandTotal > 0 ? (cellTotal / grandTotal) * 100 : 0.0;
    result[i] = {
      "percentage": percentage,
      "ACE": aceInData[i]?["ACE"] ?? 0,
      "IN": aceInData[i]?["IN"] ?? 0,
    };
  }
  return result;
}

// Contoh fungsi _fetchBallPositionAceInDataForCategory (tetap sama seperti sebelumnya)
Future<Map<int, Map<String, int>>> _fetchBallPositionAceInDataForCategory(
  String category,
  int? playerId, {
  int? setNumber,
}) async {
  final db = await DatabaseHelper.instance.database;
  String query = '''
    SELECT ballPosition, UPPER(subcategory) as subcat, COALESCE(SUM(score), 0) as total
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
  Map<int, Map<String, int>> data = {
    for (int i = 0; i < 9; i++) i: {"ACE": 0, "IN": 0}
  };
  for (var row in rows) {
    int pos = int.tryParse(row['ballPosition']?.toString() ?? '0') ?? 0;
    String subcat = (row['subcat']?.toString() ?? "").trim();
    int total = int.tryParse(row['total']?.toString() ?? '0') ?? 0;
    if (pos >= 0 && pos < 9) {
      if (subcat == "ACE") {
        data[pos]!["ACE"] = total;
      } else if (subcat == "IN") {
        data[pos]!["IN"] = total;
      }
    }
  }
  return data;
}

/// =====================
/// Widget Builders untuk PDF
/// =====================

// --- Widget Builder untuk Ball Position Table 3x3 menggunakan data dengan persentase ---
pw.Widget buildBallPositionTable3x3(
    String title, Map<int, Map<String, dynamic>> data) {
  List<pw.TableRow> rows = [];
  for (int rowIndex = 0; rowIndex < 3; rowIndex++) {
    List<pw.Widget> cells = [];
    for (int colIndex = 0; colIndex < 3; colIndex++) {
      int index = rowIndex * 3 + colIndex;
      double percentage = data[index]?["percentage"] ?? 0.0;
      int ace = data[index]?["ACE"] ?? 0;
      int inVal = data[index]?["IN"] ?? 0;
      // Tampilkan persentase di baris pertama dan (ACE/IN) di baris kedua.
      String cellText = "${percentage.toStringAsFixed(1)}%\n($ace/$inVal)";
      cells.add(
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(cellText, style: pw.TextStyle(fontSize: 8)),
        ),
      );
    }
    rows.add(pw.TableRow(children: cells));
  }
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        children: rows,
      ),
    ],
  );
}

/// Membangun Score Table pada PDF.
// Widget Builder untuk Score Table
pw.Widget buildScoreTable(String teamName, String opponentTeam, int teamSet,
    int opponentSet, List<Map<String, dynamic>> setHistory) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Text(
        "$teamName  VS  $opponentTeam",
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.Table.fromTextArray(
        headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        cellStyle: pw.TextStyle(fontSize: 8),
        headers: ['Set', "$teamName", "$opponentTeam"],
        data: setHistory.map((set) {
          return [
            set['set'].toString(),
            set['teamScore'].toString(),
            set['opponentScore'].toString(),
          ];
        }).toList(),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        "Total Set: $teamSet - $opponentSet",
        style: pw.TextStyle(fontSize: 12),
      ),
    ],
  );
}

/// Membangun Recap Table pada PDF.
pw.Widget buildRecapTable(String title, List<Map<String, String>> data) {
  // Konversi data ke List<List<String>> dengan kolom FAILED
  List<List<String>> tableData = data.map((row) {
    return [
      row["INDICATOR"] ?? "-",
      row["ACE"] ?? "0",
      row["IN/SUCCESS"] ?? "0",
      row["FAILED"] ?? "", // Tambahkan kolom FAILED
      row["ERROR"] ?? "0",
      row["%"] ?? "0%",
    ];
  }).toList();

  // Hitung dan tambahkan baris Performance
  List<String> performanceRow = _calculatePerformanceRow(data);
  tableData.add(performanceRow);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Table.fromTextArray(
        headerStyle: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
        cellStyle: pw.TextStyle(fontSize: 6),
        headers: ['INDICATOR', 'ACE', 'IN/SUCCESS', 'FAILED', 'ERROR', '%'],
        data: tableData,
      ),
    ],
  );
}

/// =====================
/// Fungsi Utama: Generate Complete PDF
/// =====================
Future<void> generateCompletePdf({
  required String teamName,
  required String opponentTeam,
  required int teamSet,
  required int opponentSet,
  required List<Map<String, dynamic>> setHistory,
  // teamRecapData: key -1 untuk ALL SET, 0 untuk SET 1, 1 untuk SET 2, 2 untuk SET 3.
  required Map<int, List<Map<String, String>>> teamRecapData,
  required Map<int, Map<String, Map<int, Map<String, dynamic>>>>
      teamBallPositionData,
  required Map<int, Map<int, List<Map<String, String>>>> playerRecapData,
  required Map<int, Map<int, Map<String, Map<int, Map<String, dynamic>>>>>
      playerBallPositionData,
  required List<Map<String, dynamic>> players,
  required List<Map<String, dynamic>> playerDetails,
  required List<int> playerIds,
}) async {
  final pdf = pw.Document();
  // Daftar kategori untuk Ball Position.
  List<String> categories = ["SERVE", "FREEBALL", "STRIKE"];
  // Misalnya, data set tersimpan untuk setNumber: 0,1,2.
  int totalSets = 3;

  // --- Halaman 1: Team Info, Score, dan Recap Table ---
  teamRecapData[-1] = generatePlayerAllSetRecap(teamRecapData);
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            buildScoreTable(
                teamName, opponentTeam, teamSet, opponentSet, setHistory),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                    child: buildRecapTable(
                        "Recap ALL SET", teamRecapData[-1] ?? [])),
                pw.SizedBox(width: 8),
                pw.Expanded(
                    child:
                        buildRecapTable("Recap SET 1", teamRecapData[0] ?? [])),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                    child:
                        buildRecapTable("Recap SET 2", teamRecapData[1] ?? [])),
                pw.SizedBox(width: 8),
                pw.Expanded(
                    child:
                        buildRecapTable("Recap SET 3", teamRecapData[2] ?? [])),
              ],
            ),
          ],
        );
      },
    ),
  );

  // --- Halaman 2: Team Ball Position (Layout: tiap kategori tampil ALL SET & SET 1-3) ---
  List<pw.Widget> teamBallWidgets = [];
  teamBallWidgets.add(
    pw.Text("Team Ball Position",
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
  );
  teamBallWidgets.add(pw.SizedBox(height: 12));
  for (String cat in categories) {
    var allSetData = await _getBallPositionDataWithPercentage(cat);
    var set1Data = await _getBallPositionDataWithPercentage(cat, setNumber: 0);
    var set2Data = await _getBallPositionDataWithPercentage(cat, setNumber: 1);
    var set3Data = await _getBallPositionDataWithPercentage(cat, setNumber: 2);
    teamBallWidgets.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    buildBallPositionTable3x3("$cat - ALL SET", allSetData),
                    pw.SizedBox(height: 8),
                    buildBallPositionTable3x3("$cat - SET 1", set1Data),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    buildBallPositionTable3x3("$cat - SET 2", set2Data),
                    pw.SizedBox(height: 8),
                    buildBallPositionTable3x3("$cat - SET 3", set3Data),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    teamBallWidgets.add(pw.SizedBox(height: 4));
    teamBallWidgets.add(pw.Divider());
    teamBallWidgets.add(pw.SizedBox(height: 4));
  }
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: teamBallWidgets),
    ),
  );

  // --- Halaman 4 dan seterusnya: Data tiap pemain (Recap & Ball Position) ---
  for (int playerId in playerIds) {
    String playerName = players.firstWhere((p) => p["id"] == playerId)["name"];
    // Akumulasi recap untuk pemain: ambil data per set (setNumber: 0,1,2)
    Map<int, List<Map<String, String>>> tempPlayerRecap = {};
    for (int setNum = 0; setNum < totalSets; setNum++) {
      tempPlayerRecap[setNum] =
          await _fetchPlayerRecapData(playerId: playerId, setNumber: setNum);
    }
    tempPlayerRecap[-1] = generatePlayerAllSetRecap(tempPlayerRecap);
    playerRecapData[playerId] = tempPlayerRecap;

    // Halaman Recap Pemain
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('$playerName - Recap Data',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                      child: buildRecapTable("Recap ALL SET",
                          playerRecapData[playerId]?[-1] ?? [])),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                      child: buildRecapTable(
                          "Recap SET 1", playerRecapData[playerId]?[0] ?? [])),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                      child: buildRecapTable(
                          "Recap SET 2", playerRecapData[playerId]?[1] ?? [])),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                      child: buildRecapTable(
                          "Recap SET 3", playerRecapData[playerId]?[2] ?? [])),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Halaman Ball Position Pemain (Layout dua kolom per kategori)
    List<pw.Widget> playerBallWidgets = [];
    playerBallWidgets.add(
      pw.Text('$playerName - Ball Position',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
    );
    playerBallWidgets.add(pw.SizedBox(height: 12));
    for (String cat in categories) {
      var allSetData =
          await _getBallPositionDataWithPercentage(cat, playerId: playerId);
      var set1Data = await _getBallPositionDataWithPercentage(cat,
          playerId: playerId, setNumber: 0);
      var set2Data = await _getBallPositionDataWithPercentage(cat,
          playerId: playerId, setNumber: 1);
      var set3Data = await _getBallPositionDataWithPercentage(cat,
          playerId: playerId, setNumber: 2);
      playerBallWidgets.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      buildBallPositionTable3x3("$cat - ALL SET", allSetData),
                      pw.SizedBox(height: 8),
                      buildBallPositionTable3x3("$cat - SET 1", set1Data),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      buildBallPositionTable3x3("$cat - SET 2", set2Data),
                      pw.SizedBox(height: 8),
                      buildBallPositionTable3x3("$cat - SET 3", set3Data),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      playerBallWidgets.add(pw.SizedBox(height: 4));
      playerBallWidgets.add(pw.Divider());
      playerBallWidgets.add(pw.SizedBox(height: 4));
    }
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: playerBallWidgets),
      ),
    );
  }

  // Simpan PDF dengan nama file yang mencakup team, opponent, dan tanggal (format dd-MM-yyyy)
  final bytes = await pdf.save();
  final now = DateTime.now();
  final formattedDate =
      "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
  final fileName = "${teamName}_vs_${opponentTeam}_$formattedDate.pdf";
  final directory = Platform.isAndroid
      ? Directory('/storage/emulated/0/Download')
      : await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);
  await OpenFile.open(file.path);
}
