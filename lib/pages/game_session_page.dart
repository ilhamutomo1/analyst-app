import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:takraw_analyst/data/database/database_helper.dart';
import 'package:takraw_analyst/pages/result_page.dart';
import 'package:takraw_analyst/widgets/scoreboard/scoreboard.dart';
import 'package:takraw_analyst/widgets/shapes/half_circle.dart';

class GameSessionPage extends StatefulWidget {
  final String teamName;
  final String opponentTeam; // Nama tim lawan
  final List<Map<String, dynamic>> players;

  Map<String, Map<int, Map<String, dynamic>>> ballPositionsByCategory = {};
  List<Map<String, dynamic>> playerDetails = [];

  GameSessionPage({
    required this.teamName,
    required this.opponentTeam,
    required this.players,
  });

  @override
  _GameSessionPageState createState() => _GameSessionPageState();
}

class _DrawingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Color> colors;
  final List<Offset> currentStroke;
  final Color currentColor;

  _DrawingPainter({
    required this.strokes,
    required this.colors,
    required this.currentStroke,
    required this.currentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // 1) gambar semua stroke yang sudah selesai
    for (int i = 0; i < strokes.length; i++) {
      paint.color = colors[i];
      final path = Path()..addPolygon(strokes[i], false);
      canvas.drawPath(path, paint);
    }

    // 2) gambar stroke yang sedang berproses
    paint.color = currentColor;
    final path = Path()..addPolygon(currentStroke, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter old) => true;
}

class _GameSessionPageState extends State<GameSessionPage> {
  final GlobalKey _gameAreaKey = GlobalKey();
  String teamName = "Loading...";
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final CenterOverlayHalfCirclePainter topHalfCirclePainter =
      CenterOverlayHalfCirclePainter(color: Colors.white, isTop: true);
  final CenterOverlayHalfCirclePainter bottomHalfCirclePainter =
      CenterOverlayHalfCirclePainter(color: Colors.white, isTop: false);

  late List<Offset> playerPositions;
  Offset ballOffset = Offset(100, 100); // Default initial position
  bool isTimerRunning = false;
  bool showCategoryCards = true;
  bool isSetFinished = false;
  bool isGameFinished = false;
  int secondsElapsed = 0;
  Timer? timer;
  List<Map<String, dynamic>> scoreHistory = [];
  Function?
      updateDialogState; // Variabel global (misal, di dalam state _ResultPageState)
  bool _isProcessingUndo = false;

  List<List<Offset>> _strokes = [];
  List<Color> _strokeColors = [];
  // Coretan yang sedang berjalan
  List<Offset> _currentStroke = [];
  // Apakah sedang dalam mode menggambar?
  bool _isDrawingMode = false;

  bool get canProceedNextSet {
    // Jika kedua tim mencapai minimal 14, artinya dalam kondisi deuce.
    if (teamScore >= 14 && opponentScore >= 14) {
      // Pada deuce, tombol aktif jika salah satu tim mencapai 17 atau lebih,
      // tanpa memeriksa selisih.
      return (teamScore >= 17 || opponentScore >= 17);
    } else {
      // Pada kondisi normal, tombol aktif jika salah satu tim mencapai 15,
      // tanpa memeriksa selisih.
      return (teamScore >= 15 || opponentScore >= 15);
    }
  }

  Map<String, Map<String, int>> defaultLocalScores = {
    "SERVE": {"ACE": 0, "IN": 0, "ERROR": 0},
    "FIRSTBALL": {"SUCCESS": 0, "ERROR": 0},
    "FREEBALL": {"ACE": 0, "IN": 0, "ERROR": 0},
    "FEEDING": {"SUCCESS": 0, "FAILED": 0, "ERROR": 0},
    "STRIKE": {"ACE": 0, "IN": 0, "ERROR": 0},
    "BLOCKING": {"SUCCESS": 0, "ERROR": 0},
  };

  Map<String, Map<String, int>> localScores = {
    "SERVE": {"ACE": 0, "IN": 0, "ERROR": 0},
    "FIRSTBALL": {"SUCCESS": 0, "ERROR": 0},
    "FREEBALL": {"ACE": 0, "IN": 0, "ERROR": 0},
    "FEEDING": {"SUCCESS": 0, "FAILED": 0, "ERROR": 0},
    "STRIKE": {"ACE": 0, "IN": 0, "ERROR": 0},
    "BLOCKING": {"SUCCESS": 0, "ERROR": 0},
  };

  Map<String, Map<String, int>> deepCopyScores(
      Map<String, Map<String, int>> original) {
    return original.map((cat, subMap) =>
        MapEntry(cat, subMap.map((sub, value) => MapEntry(sub, value))));
  }

  // Simpan localScores per player, kunci: playerId.
  Map<int, Map<String, Map<String, int>>> playerLocalScores = {};
  Map<int, Map<int, int>> playerBallLocalScores = {};

  // Scores for team and opponent
  int currentSet = 0; // Set pertama dimulai dari 0
  int teamScore = 0;
  int opponentScore = 0;
  int teamSet = 0;
  int opponentSet = 0;
  int _teamSet = 0;
  int _opponentSet = 0;

  String? pendingSetWinner;
  List<Map<String, dynamic>> setHistory = [];
  int? lastBallPosition;

  final List<Color> _availableColors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.orange,
  ];

  final List<String> _colorNames = [
    '',
    '',
    '',
    '',
  ];

// Indeks warna sekarang
  int _colorIndex = 0;

// Getter untuk warna saat ini
  Color get _currentColor => _availableColors[_colorIndex];

  bool get _isSetOver {
    // Deuce: Jika kedua tim 15, maka siapa yang capai 17 duluan menang
    if ((teamScore == 17 && opponentScore >= 15) ||
        (opponentScore == 17 && teamScore >= 15)) {
      return true;
    }

    // Tanpa deuce: jika salah satu tim capai 15 dan selisih ≥ 2
    if ((teamScore >= 15 || opponentScore >= 15) &&
        (teamScore - opponentScore).abs() >= 2 &&
        (teamScore <= 15 && opponentScore <= 15)) {
      return true;
    }

    return false;
  }

  Map<String, Map<String, int>> convertScoreMap(dynamic scores) {
    if (scores == null) return <String, Map<String, int>>{};
    if (scores is Map) {
      return scores.map((key, value) {
        if (value is Map) {
          return MapEntry(
            key.toString(),
            value.map((k, v) => MapEntry(
                  k.toString(),
                  v is int ? v : int.tryParse(v.toString()) ?? 0,
                )),
          );
        }
        return MapEntry(key.toString(), <String, int>{});
      });
    }
    return <String, Map<String, int>>{};
  }

  @override
  void initState() {
    super.initState();
    _loadTeamName();
    playerPositions = List.generate(widget.players.length, (_) => Offset(0, 0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePositions();
      _updateScoreboardFromDatabase();
      _loadGameSessionState();
    });
  }

  void _onPanStart(DragStartDetails details) {
    final box = _gameAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    setState(() => _currentStroke = [local]);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = _gameAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    setState(() => _currentStroke.add(local));
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _strokes.add(_currentStroke);
      _strokeColors.add(_currentColor); // ← simpan warna untuk stroke ini
      _currentStroke = [];
    });
  }

  void _changeStrokeColor() {
    setState(() {
      _colorIndex = (_colorIndex + 1) % _availableColors.length;

      // Paksa repaint walaupun belum ada coretan
      if (_isDrawingMode && _currentStroke.isEmpty) {
        _currentStroke = [Offset.zero];
        _currentStroke = [];
      }
    });
  }

  Future<void> _loadGameSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentSet = prefs.getInt('currentSet') ?? 0;
      teamScore = prefs.getInt('teamScore') ?? 0;
      opponentScore = prefs.getInt('opponentScore') ?? 0;
      teamSet = prefs.getInt('teamSet') ?? 0;
      opponentSet = prefs.getInt('opponentSet') ?? 0;
      // Untuk setHistory, Anda bisa menyimpannya sebagai JSON string jika diperlukan.
      // Misalnya:
      // String? historyJson = prefs.getString('setHistory');
      // setHistory = historyJson != null ? jsonDecode(historyJson) : [];
    });
  }

  Future<void> _loadTeamName() async {
    String? name = await dbHelper.getTeamName();
    setState(() {
      teamName = name ?? "Unknown Team";
    });
  }

  Future<int?> _showBallPositionDialog(
    BuildContext context,
    int playerId,
    String categorySelected,
    String subCategorySelected,
  ) async {
    // Inisialisasi skor lokal untuk pemain jika belum ada.
    if (!playerLocalScores.containsKey(playerId)) {
      playerLocalScores[playerId] = {
        for (String cat in ["SERVE", "FREEBALL", "STRIKE"])
          cat: {for (int i = 0; i < 9; i++) i.toString(): 0}
      };
    }
    // Ambil referensi langsung ke skor lokal untuk kategori yang dipilih.
    Map<String, int> ballStats =
        playerLocalScores[playerId]![categorySelected]!;

    return showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Simpan callback agar bisa dipakai di luar builder jika diperlukan.
            updateDialogState = setStateDialog;
            return AlertDialog(
              content: Container(
                width: 800,
                height: 350,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/court10.png"),
                    fit: BoxFit.fill,
                  ),
                ),
                child: Row(
                  children: [
                    // Left side: Header untuk info posisi bola.
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: EdgeInsets.all(16),
                        alignment: Alignment.center,
                        child: Text(
                          "STATISTIK LOKASI:\n${categorySelected.toUpperCase()} - ${subCategorySelected.toUpperCase()}",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    // Right side: Grid 3x3 yang menampilkan skor lokal.
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Container(
                          width: 350,
                          height: 350,
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 1.13,
                              mainAxisSpacing: 3,
                              crossAxisSpacing: 3,
                            ),
                            itemCount: 9,
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              int count = ballStats[index.toString()] ?? 0;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.vibrate();
                                  setStateDialog(() {
                                    ballStats[index.toString()] = count + 1;
                                  });
                                  // Simpan cell terakhir yang ditekan.
                                  lastBallPosition = index;
                                  Navigator.of(context).pop(index);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.transparent),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "$count",
                                      style: TextStyle(fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Reset referensi callback ketika dialog tertutup.
      updateDialogState = null;
    });
  }

  // Fungsi untuk memperbarui skor dari database dan memeriksa kembali kondisi kemenangan.
  Future<void> _updateScoreboardFromDatabase() async {
    int newTeamScore = 0;
    int newOpponentScore = 0;

    for (var player in widget.players) {
      final int playerId = int.tryParse(player['id'].toString()) ?? 0;
      List<Map<String, dynamic>> rows =
          await DatabaseHelper.instance.getScoresByPlayer(playerId, currentSet);
      for (var row in rows) {
        String subcat = row['subcategory'].toString().toUpperCase();
        int score = row['score'] is int
            ? row['score']
            : int.tryParse(row['score'].toString()) ?? 0;
        if (subcat == "ACE" || subcat == "OPPONENT_MISTAKE") {
          newTeamScore += score;
        } else if (subcat == "ERROR") {
          newOpponentScore += score;
        }
      }
    }

    setState(() {
      teamScore = newTeamScore;
      opponentScore = newOpponentScore;
    });

    String? currentWinner;
    if (teamScore >= 14 && opponentScore >= 14) {
      if (teamScore == 17 && opponentScore < 17) {
        currentWinner = 'team';
      } else if (opponentScore == 17 && teamScore < 17) {
        currentWinner = 'opponent';
      }
    } else {
      if (teamScore >= 15 && (teamScore - opponentScore) >= 2) {
        currentWinner = 'team';
      } else if (opponentScore >= 15 && (opponentScore - teamScore) >= 2) {
        currentWinner = 'opponent';
      }
    }

    if (isSetFinished && currentWinner == null) {
      setState(() {
        isSetFinished = false;
        if (setHistory.isNotEmpty) {
          setHistory.removeLast();
        }
        pendingSetWinner = null;
      });
    } else if (!isSetFinished && currentWinner != null) {
      setState(() {
        isSetFinished = true;
        pendingSetWinner = currentWinner;
      });
    }
  }

  Future<void> _handleUndo(int playerId, String category, String sub) async {
    // Ambil skor terakhir untuk player berdasarkan kategori dan subkategori
    List<Map<String, dynamic>> rows =
        await DatabaseHelper.instance.getScoresByPlayer(playerId, currentSet);
    // Filter hanya skor dengan setNumber == currentSet
    rows = rows.where((row) => row['setNumber'] == currentSet).toList();
    if (rows.isNotEmpty) {
      // Undo skor terakhir hanya untuk set yang sedang berjalan.
      await DatabaseHelper.instance.undoLastScore(playerId, category, sub);
      // Update localScores dan UI
      setState(() {
        // Kurangi skor, dengan default 1 jika nilai null.
        localScores[category]?[sub] = ((localScores[category]?[sub] ?? 1) - 1);
        // Ambil nilai saat ini, jika null, gunakan 0.
        int currentScore = localScores[category]?[sub] ?? 0;
        if (currentScore < 0) {
          localScores[category]?[sub] = 0;
        }
      });
      _updateScoreboardFromDatabase();
    }
  }

// Fungsi untuk menangani undo pada skor.

// Fungsi untuk memeriksa kondisi kemenangan set.
  void _checkSetWin() {
    int maxScore = 15;
    bool isDeuce = (teamScore >= 14 && opponentScore >= 14);
    if (isDeuce) {
      maxScore = 17;
    }

    // Clamp nilai skor agar tidak melebihi batas.
    if (teamScore > maxScore) teamScore = maxScore;
    if (opponentScore > maxScore) opponentScore = maxScore;

    String? winner;
    if (isDeuce) {
      // Dalam kondisi deuce, jika salah satu tim mencapai 17 (atau lebih) dan lawan belum mencapai 17, maka dia menang.
      if (teamScore >= 17 && opponentScore < 17) {
        winner = 'team';
      } else if (opponentScore >= 17 && teamScore < 17) {
        winner = 'opponent';
      }
    } else {
      // Kondisi normal: minimal 15 dengan selisih minimal 2.
      if (teamScore >= 15 && (teamScore - opponentScore) >= 2) {
        winner = 'team';
      } else if (opponentScore >= 15 && (opponentScore - teamScore) >= 2) {
        winner = 'opponent';
      }
    }

    // Pastikan hanya satu pemenang yang ditetapkan.
    setState(() {
      pendingSetWinner = winner;
    });
  }

// Fungsi untuk menyelesaikan set.
  void _finishSet({required String winner}) {
    setState(() {
      // Tambahkan poin set ke pemenang
      if (winner == 'team') {
        teamSet++;
      } else {
        opponentSet++;
      }
      // Simpan data set ke history jika diperlukan
      setHistory.add({
        "set": currentSet,
        "teamScore": teamScore,
        "opponentScore": opponentScore,
        "winner": winner,
      });
      // Tandai set sebagai selesai, sehingga penambahan poin baru tidak akan diterima.
      isSetFinished = true;
      // Jangan naikkan currentSet atau reset skor di sini.
    });
  }

  void _checkGameFinished() {
    if ((teamSet > 1 || opponentSet > 1) ||
        (currentSet == 3 && isSetFinished)) {
      setState(() {
        isGameFinished = true;
      });
    }
  }

  void _addPoint(String subcategory, int points) {
    if (!isSetFinished) {
      setState(() {
        if (subcategory.toUpperCase() == "ACE") {
          teamScore += points;
        } else if (subcategory.toUpperCase() == "ERROR") {
          opponentScore += points;
        }
      });
      _checkSetWin();
    }
  }

  void _calculateSetWins() {
    int teamSetCount = 0;
    int opponentSetCount = 0;
    for (var set in setHistory) {
      if (set['winner'] == 'team') {
        teamSetCount++;
      } else if (set['winner'] == 'opponent') {
        opponentSetCount++;
      }
    }
    setState(() {
      _teamSet = teamSetCount;
      _opponentSet = opponentSetCount;
    });
  }

  void _nextSet() {
    setState(() {
      // Jika belum ada pemenang (pendingSetWinner null), beri peringatan dan jangan pindah set.
      if (pendingSetWinner == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Set belum selesai, tidak dapat melanjutkan.")),
        );
        return; // keluar tanpa mengubah currentSet atau setHistory
      } else {
        // Jika sudah ada pemenang, update teamSet/opponentSet.
        if (pendingSetWinner == 'team') {
          teamSet++;
        } else {
          opponentSet++;
        }
        // Simpan data set ke history.
        setHistory.add({
          "set": currentSet + 1, // Tampilkan set sebagai currentSet + 1
          "teamScore": teamScore,
          "opponentScore": opponentScore,
          "winner": pendingSetWinner,
        });
        // Naikkan nomor set dan reset skor serta localScores.
        currentSet++;
        teamScore = 0;
        opponentScore = 0;
        isSetFinished = false;
        pendingSetWinner = null;
        playerLocalScores.clear();
        playerBallLocalScores.clear();
      }
    });
    // Setelah set selesai, hitung jumlah set yang dimenangkan dari setHistory.
    _calculateSetWins();
  }

  void _initializePositions() {
    if (_gameAreaKey.currentContext == null) return;
    final RenderBox gameArea =
        _gameAreaKey.currentContext!.findRenderObject() as RenderBox;
    final size = gameArea.size;
    setState(() {
      playerPositions = List.generate(widget.players.length, (index) {
        if (index < 3) {
          // Arrange 3 active players in a triangle facing left:
          // Player 0: Apex (leftmost point)
          // Player 1: Top-right vertex
          // Player 2: Bottom-right vertex
          if (index == 1) {
            return Offset(size.width * 0.15, size.height / 2.50);
          } else if (index == 0) {
            return Offset(size.width * 0.4, size.height * 0.15);
          } else {
            // index == 2
            return Offset(size.width * 0.4, size.height * 1.3);
          }
        } else {
          // For substitute players, position them elsewhere (e.g., at bottom right)
          double subScreenX = MediaQuery.of(context).size.width * 0.75;
          double subScreenY = MediaQuery.of(context).size.height * 0.85;
          final Offset gameAreaGlobalPos = gameArea.localToGlobal(Offset.zero);
          double localX = subScreenX - gameAreaGlobalPos.dx;
          double localY = subScreenY - gameAreaGlobalPos.dy;
          return Offset(localX, localY);
        }
      });
    });
  }

  void _undoLastScore() async {
    // Cek apakah skor masih kosong
    if (teamScore == 0 && opponentScore == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tidak ada skor yang bisa di-undo!")),
      );
      return; // Tidak melakukan undo jika skor masih kosong
    }

    // Cek jika scoreHistory kosong, return langsung
    if (scoreHistory.isEmpty) return;

    // Ambil entri skor terakhir dan hapus dari scoreHistory
    final lastScore = scoreHistory.removeLast();
    final int playerId = lastScore['playerId'];
    final String category = lastScore['category'];
    final String subcategory = lastScore['subcategory'];

    // Berikan getaran sebagai feedback
    HapticFeedback.vibrate();

    // Panggil fungsi undoLastScore di DatabaseHelper untuk menghapus entri skor terakhir
    await DatabaseHelper.instance
        .undoLastScore(playerId, category, subcategory);

    // Perbarui skor berdasarkan kategori dan subkategori yang dihapus
    setState(() {
      if (category == "TEAM" && subcategory == "OPPONENT_MISTAKE") {
        teamScore--; // Kurangi skor tim jika opponent mistake dihapus
      } else if (subcategory.toUpperCase() == "ACE") {
        teamScore--; // Kurangi skor tim jika poin dari 'ACE' dihapus
      } else if (subcategory.toUpperCase() == "ERROR") {
        opponentScore--; // Kurangi skor lawan jika poin dari 'ERROR' dihapus
      }
    });

    // Perbarui tampilan scoreboard dengan data terbaru dari database
    _updateScoreboardFromDatabase();
  }

  /// POP-UP UNTUK SKOR
  /// Accepts 4 parameters: context, playerId, playerName, and playerScores.
  Future<void> _showScorePopup(
    BuildContext context,
    int playerId,
    String playerName,
    Map<String, Map<String, int>>
        playerScores, // data awal skor lokal (boleh kosong)
  ) async {
    // Jika belum ada skor lokal untuk pemain ini di set saat ini, inisialisasi dengan default.
    if (!playerLocalScores.containsKey(playerId)) {
      playerLocalScores[playerId] = deepCopyScores(defaultLocalScores);
    }
    // Gunakan referensi langsung ke skor lokal pemain tersebut (tanpa deep copy lagi)
    Map<String, Map<String, int>> popupLocalScores =
        playerLocalScores[playerId]!;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Center(
                child: Text(
                  playerName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              content: Container(
                width: 800,
                height: 400,
                child: Stack(
                  children: [
                    // Grid kategori dengan padding agar tombol Close tidak menutupi.
                    Positioned.fill(
                      top: 2, // Sisakan ruang untuk judul
                      bottom: 16, // Sisakan ruang untuk tombol Close
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          childAspectRatio: 5,
                          physics: NeverScrollableScrollPhysics(),
                          children: [
                            _categoryCard(
                              dialogContext,
                              "SERVE",
                              ["ACE", "IN", "ERROR"],
                              popupLocalScores,
                              setDialogState,
                              playerId,
                            ),
                            _categoryCard(
                              dialogContext,
                              "FIRSTBALL",
                              ["SUCCESS", "ERROR"],
                              popupLocalScores,
                              setDialogState,
                              playerId,
                            ),
                            _categoryCard(
                              dialogContext,
                              "FREEBALL",
                              ["ACE", "IN", "ERROR"],
                              popupLocalScores,
                              setDialogState,
                              playerId,
                            ),
                            _categoryCard(
                              dialogContext,
                              "FEEDING",
                              ["SUCCESS", "FAILED", "ERROR"],
                              popupLocalScores,
                              setDialogState,
                              playerId,
                            ),
                            _categoryCard(
                              dialogContext,
                              "STRIKE",
                              ["ACE", "IN", "ERROR"],
                              popupLocalScores,
                              setDialogState,
                              playerId,
                            ),
                            _categoryCard(
                              dialogContext,
                              "BLOCKING",
                              ["ACE", "SUCCESS", "ERROR"],
                              popupLocalScores,
                              setDialogState,
                              playerId,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Tombol Close di pojok kanan bawah.
                    Positioned(
                      bottom: -10,
                      right: 0,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                        ),
                        onPressed: () {
                          // Karena popupLocalScores adalah referensi langsung,
                          // tidak perlu update ulang ke playerLocalScores.
                          Navigator.pop(dialogContext);
                        },
                        child: Icon(
                          Icons.close, // The "X" icon
                          size: 24, // Set the icon size as needed
                          color: Colors.white, // Set the icon color
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// CATEGORY CARD with subcategories (updates DB immediately)
  Widget _categoryCard(
    BuildContext dialogContext, // Dialog context
    String category,
    List<String> subCategories,
    Map<String, Map<String, int>>
        localScores, // Local scores for this player and current set
    void Function(void Function()) setDialogState,
    int playerId,
  ) {
    // Ensure the localScores for this category are initialized.
    if (!localScores.containsKey(category)) {
      localScores[category] = {for (var sub in subCategories) sub: 0};
    }

    // Function to provide appropriate haptic feedback based on subcategory
    void provideHapticFeedback(String sub) {
      switch (sub.toUpperCase()) {
        case "ACE":
          HapticFeedback.vibrate(); // Strong feedback for successful point
          break;
        case "IN":
          HapticFeedback.vibrate(); // Medium feedback for successful hit
          break;
        case "SUCCESS":
          HapticFeedback.vibrate(); // Medium feedback for success
          break;
        case "FAILED":
          HapticFeedback.vibrate(); // Light feedback for failed attempt
          break;
        case "ERROR":
          HapticFeedback.vibrate(); // Distinct vibration pattern for errors
          break;
        default:
          HapticFeedback.selectionClick(); // Default feedback
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Category name.
          Text(
            category,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          // Grid of subcategories with score indicator.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: subCategories.map((sub) {
              int score = localScores[category]?[sub] ?? 0;
              return GestureDetector(
                onTap: () async {
                  // Provide haptic feedback first
                  provideHapticFeedback(sub);

                  // Jika set sudah selesai, jangan lakukan apa-apa.
                  if (_isSetOver || isSetFinished) return;

                  if ((category.toUpperCase() == "SERVE" ||
                          category.toUpperCase() == "STRIKE" ||
                          category.toUpperCase() == "FREEBALL") &&
                      (sub.toUpperCase() == "ACE" ||
                          sub.toUpperCase() == "IN")) {
                    setDialogState(() {
                      showCategoryCards = false;
                    });
                    // Pastikan playerId yang berbeda dikirim untuk setiap pemain.
                    int? selectedCell = await _showBallPositionDialog(
                        context, playerId, category, sub.toUpperCase());
                    setDialogState(() {
                      showCategoryCards = true;
                    });
                    if (selectedCell != null) {
                      await DatabaseHelper.instance.addScore(
                        playerId,
                        category,
                        sub,
                        1,
                        setNumber: currentSet,
                        ballPosition: selectedCell,
                      );
                      setState(() {
                        if (sub.toUpperCase() == "ACE") {
                          teamScore++;
                        }
                        scoreHistory.add({
                          "playerId": playerId,
                          "category": category,
                          "subcategory": sub,
                          "ballPosition": selectedCell,
                          "set": currentSet,
                        });
                      });
                      setDialogState(() {
                        // Update skor lokal untuk kategori dan sub kategori.
                        localScores[category]![sub] =
                            (localScores[category]![sub] ?? 0) + 1;
                      });
                    }
                  } else {
                    await DatabaseHelper.instance.addScore(
                      playerId,
                      category,
                      sub,
                      1,
                      setNumber: currentSet,
                    );
                    setState(() {
                      scoreHistory.add({
                        "playerId": playerId,
                        "category": category,
                        "subcategory": sub,
                        "set": currentSet,
                      });
                      if (sub.toUpperCase() == "ACE") {
                        teamScore++;
                      } else if (sub.toUpperCase() == "ERROR") {
                        opponentScore++;
                      }
                    });
                    setDialogState(() {
                      localScores[category]![sub] =
                          (localScores[category]![sub] ?? 0) + 1;
                    });
                  }

                  Navigator.of(dialogContext).pop();
                  _checkSetWin();
                },
                onLongPress: () async {
                  if (_isProcessingUndo) return;
                  _isProcessingUndo = true;
                  try {
                    // Enhanced haptic feedback for undo action
                    HapticFeedback.heavyImpact();
                    Future.delayed(Duration(milliseconds: 100), () {
                      HapticFeedback
                          .vibrate(); // Double feedback for undo action
                    });

                    bool? shouldUndo = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("Undo Score"),
                          content: Text("Undo last score for $sub?"),
                          actions: [
                            TextButton(
                              onPressed: () {
                                HapticFeedback
                                    .selectionClick(); // Feedback for cancel
                                Navigator.pop(context, false);
                              },
                              child: Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () {
                                HapticFeedback
                                    .heavyImpact(); // Strong feedback for confirm undo
                                Navigator.pop(context, true);
                              },
                              child: Text("Undo"),
                            ),
                          ],
                        );
                      },
                    );
                    if (shouldUndo == true && !isSetFinished) {
                      await DatabaseHelper.instance.undoLastScoreForSet(
                        playerId,
                        category,
                        sub,
                        currentSet,
                      );
                      // Update skor lokal untuk kategori/sub.
                      setDialogState(() {
                        int currentScore = localScores[category]?[sub] ?? 0;
                        if (currentScore > 0) {
                          localScores[category]![sub] = currentScore - 1;
                        }
                      });
                      // Update grid di dialog berdasarkan cell terakhir yang disimpan.
                      if (lastBallPosition != null) {
                        setDialogState(() {
                          Map<String, int> ballStats =
                              playerLocalScores[playerId]![category]!;
                          int currentValue =
                              ballStats[lastBallPosition.toString()] ?? 0;
                          if (currentValue > 0) {
                            ballStats[lastBallPosition.toString()] =
                                currentValue - 1;
                          }
                        });
                        // Reset lastBallPosition setelah undo.
                        lastBallPosition = null;
                      }
                      _updateScoreboardFromDatabase();
                    }
                  } finally {
                    _isProcessingUndo = false;
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _subCategoryColor(sub),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$sub: $score",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// SUBCATEGORY GRADIENT
  Color _subCategoryColor(String sub) {
    switch (sub) {
      case "ACE":
        return Color(0xFF419AFF); // Solid color for ACE
      case "IN":
        return Color(0xFFFFF541); // Solid color for IN
      case "SUCCESS":
        return Color(0xFFFFF541); // Solid yellow for SUCCESS
      case "FAILED":
        return Color.fromARGB(255, 255, 40, 40); // Solid yellow for FAILED
      case "ERROR":
        return Color(0xFFFF532C); // Solid color for ERROR
      default:
        return Colors.grey; // Default color
    }
  }

  /// SAVE SCORES TO DATABASE
  Future<void> _savePlayerScores(
    int playerId,
    Map<String, Map<String, int>> scores,
  ) async {
    await DatabaseHelper.instance.deleteScoresByPlayer(playerId);
    scores.forEach((category, subMap) {
      subMap.forEach((sub, score) async {
        if (score > 0) {
          await DatabaseHelper.instance
              .addScore(playerId, category, sub, score, setNumber: currentSet);
        }
      });
    });
  }

  void _undoBallScore(
      int playerId, String categorySelected, String subCategorySelected) {
    // Ambil referensi ballStats dari localScores untuk kategori yang dipilih.
    Map<String, int> ballStats =
        playerLocalScores[playerId]![categorySelected]!;
    // Kita asumsikan bahwa undo akan mengurangi nilai pada cell terakhir yang memiliki nilai > 0.
    // Misalnya, kita mencari cell dengan index tertinggi (dari 0 hingga 8) dengan nilai > 0.
    List<int> cellIndices =
        ballStats.keys.map((k) => int.tryParse(k) ?? 0).toList();
    cellIndices.sort(); // ascending order
    int? targetIndex;
    for (int i = cellIndices.length - 1; i >= 0; i--) {
      int idx = cellIndices[i];
      if ((ballStats[idx.toString()] ?? 0) > 0) {
        targetIndex = idx;
        break;
      }
    }
    if (targetIndex != null) {
      updateDialogState?.call(() {
        ballStats[targetIndex.toString()] =
            ballStats[targetIndex.toString()]! - 1;
      });
    }
  }

  /// TIMER FUNCTION
  void _toggleTimer() {
    if (isTimerRunning) {
      timer?.cancel();
    } else {
      timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          secondsElapsed++;
        });
      });
    }
    setState(() {
      isTimerRunning = !isTimerRunning;
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// BUILD UI
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async =>
          false, // Mencegah navigasi back dengan gesture / tombol sistem
      child: Scaffold(
        body: Stack(
          children: [
            // BACKGROUND
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/mainbg.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            Positioned.fill(
              child: Column(
                children: [
                  Scoreboard(
                    teamName: teamName,
                    teamScore: teamScore,
                    opponentTeamName: widget.opponentTeam,
                    opponentScore: opponentScore,
                    secondsElapsed: secondsElapsed,
                    teamSet: teamSet,
                    opponentSet: opponentSet,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Center(
                      child: Container(
                        key: _gameAreaKey,
                        width: MediaQuery.of(context).size.width * 0.75,
                        height: MediaQuery.of(context).size.height * 0.75,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          border: Border.all(color: Colors.white, width: 6),
                        ),
                        clipBehavior: Clip.none,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final boxWidth = constraints.maxWidth;
                            final boxHeight = constraints.maxHeight;

                            final double circleSize = 35;
                            final double offset =
                                104; // how much to pull each circle inward

                            final halfCircleWidth =
                                boxWidth * 0.15; // or tweak %
                            final halfCircleHeight = halfCircleWidth *
                                (55 / 75); // keep aspect ratio

                            return Stack(
                              children: [
                                // Lingkaran kiri (digeser dikit ke kanan)
                                Positioned(
                                  top: (boxHeight - circleSize) / 2,
                                  left: -circleSize / 2 + offset,
                                  child: Container(
                                    width: circleSize,
                                    height: circleSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.transparent, // transparan bro
                                      border: Border.all(
                                        color: Colors.white, // warna garis
                                        width: 2, // tebel garis
                                      ),
                                    ),
                                  ),
                                ),

// Lingkaran kanan (digeser dikit ke kiri)
                                Positioned(
                                  top: (boxHeight - circleSize) / 2,
                                  right: -circleSize / 2 + offset,
                                  child: Container(
                                    width: circleSize,
                                    height: circleSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.transparent,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),

                                Positioned(
                                  top: -halfCircleHeight / 2,
                                  left: (boxWidth - halfCircleWidth) / 2,
                                  child: SizedBox(
                                    width: halfCircleWidth,
                                    height: halfCircleHeight,
                                    child: CustomPaint(
                                      painter: CenterOverlayHalfCirclePainter(
                                        color: Colors.white,
                                        isTop: true,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -halfCircleHeight / 2,
                                  left: (boxWidth - halfCircleWidth) / 2,
                                  child: SizedBox(
                                    width: halfCircleWidth,
                                    height: halfCircleHeight,
                                    child: CustomPaint(
                                      painter: CenterOverlayHalfCirclePainter(
                                        color: Colors.white,
                                        isTop: false,
                                      ),
                                    ),
                                  ),
                                ),

                                // rest of your widgets like ball, dividing line, and draggable players
                                Positioned(
                                  top: ballOffset.dy,
                                  left: ballOffset.dx,
                                  child: _draggableBall(),
                                ),
                                Positioned(
                                  left: boxWidth / 2 -
                                      3, // for center white line (6 width)
                                  top: 0,
                                  bottom: 0,
                                  child:
                                      Container(width: 4, color: Colors.white),
                                ),
                                for (int i = 0;
                                    i <
                                        (widget.players.length >= 3
                                            ? 3
                                            : widget.players.length);
                                    i++)
                                  _buildDraggablePlayer(i),

                                if (_isDrawingMode)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onPanStart: _onPanStart,
                                      onPanUpdate: _onPanUpdate,
                                      onPanEnd: _onPanEnd,
                                      child: CustomPaint(
                                        key: ValueKey(
                                            _colorIndex), // <--- Ini yang bikin repaint!
                                        painter: _DrawingPainter(
                                          strokes: _strokes,
                                          colors: _strokeColors,
                                          currentStroke: _currentStroke,
                                          currentColor: _currentColor,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 55,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "PEMAIN CADANGAN:",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        ...(widget.players.length > 3
                            ? widget.players
                                .sublist(3)
                                .asMap()
                                .entries
                                .map((entry) {
                                int subIndex = entry.key + 3;
                                var player = entry.value;
                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 5),
                                  child: Draggable<Map<String, dynamic>>(
                                    key: ValueKey("sub_${player['id']}"),
                                    data: {
                                      "player": widget.players[subIndex],
                                      "index": subIndex,
                                    },
                                    feedback: _playerBall(
                                      player['number'].toString(),
                                      player['name'],
                                      convertScoreMap(player['scores']),
                                      int.tryParse(player['id'].toString()) ??
                                          0,
                                      currentSet, // int: current set number from your state
                                      teamSet, // int: team set score from your state
                                      opponentSet, // int: opponent set score from your state
                                      isSetFinished, // boolean flag from your state
                                    ),
                                    childWhenDragging: Container(),
                                    child: _playerBall(
                                      player['number'].toString(),
                                      player['name'],
                                      convertScoreMap(player['scores']),
                                      int.tryParse(player['id'].toString()) ??
                                          0,
                                      currentSet, // int: current set number from your state
                                      teamSet, // int: team set score from your state
                                      opponentSet, // int: opponent set score from your state
                                      isSetFinished,
                                    ),
                                  ),
                                );
                              }).toList()
                            : []),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
            // LEFT BUTTONS (Back, Undo)
            _buildLeftButtons(),
            // RIGHT BUTTONS (Timer, Next Set, Opponent Mistake)
            _buildRightButtons(),
          ],
        ),
      ),
    );
  }

  Widget _teamScore(String team, int score, Color color) {
    return Column(
      children: [
        Text(
          team,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "$score",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _matchTime() {
    return Column(
      children: [
        Text(
          _formatTime(secondsElapsed),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "SET",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _setPointIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _setBall(teamSet, Colors.purple),
        SizedBox(width: 20),
        _setBall(opponentSet, Colors.orange),
      ],
    );
  }

  Widget _setBall(int count, Color color) {
    return Row(
      children: List.generate(count, (index) {
        return Container(
          width: 10,
          height: 10,
          margin: EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  /// RIGHT BUTTONS (Timer, Next Set, Opponent Mistake)
  Widget _buildRightButtons() {
    return Positioned(
      right: 8,
      top: 80,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildUniformButton(
            onPressed: canProceedNextSet
                ? () {
                    HapticFeedback.vibrate();
                    _nextSet();
                  }
                : null,
            text: "Set\nBerikutnya",
            isLarge: true,
          ),
          const SizedBox(height: 8),
          if (currentSet <= 3) const SizedBox(height: 4),
          GestureDetector(
            onLongPress: () async {
              HapticFeedback.vibrate(); // Strong feedback for undo action
              bool? shouldUndo = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Undo Score"),
                    content: const Text(
                        "Apakah Anda yakin ingin meng-undo 'Opponent Mistake'?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Batal"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Undo",
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  );
                },
              );

              if (shouldUndo == true && !isSetFinished) {
                final int defaultPlayerId =
                    int.tryParse(widget.players[0]['id'].toString()) ?? 0;

                await DatabaseHelper.instance.undoLastScoreForSet(
                  defaultPlayerId,
                  "TEAM",
                  "OPPONENT_MISTAKE",
                  currentSet,
                );

                setState(() {
                  if (teamScore > 0) teamScore--;
                  localScores["TEAM"] ??= {"OPPONENT_MISTAKE": 0};
                  localScores["TEAM"]!["OPPONENT_MISTAKE"] =
                      (localScores["TEAM"]!["OPPONENT_MISTAKE"] ?? 1) - 1;
                  if (scoreHistory.isNotEmpty &&
                      scoreHistory.last["subcategory"] == "OPPONENT_MISTAKE") {
                    scoreHistory.removeLast();
                  }
                });
              }
            },
            child: _buildUniformButton(
              onPressed: () async {
                // Add haptic feedback
                HapticFeedback.vibrate();

                // Cegah penambahan skor jika set sudah selesai
                if (widget.players.isNotEmpty &&
                    !isSetFinished &&
                    !_isSetOver) {
                  final int defaultPlayerId =
                      int.tryParse(widget.players[0]['id'].toString()) ?? 0;

                  setState(() {
                    localScores["TEAM"] ??= {"OPPONENT_MISTAKE": 0};
                    localScores["TEAM"]!["OPPONENT_MISTAKE"] =
                        (localScores["TEAM"]!["OPPONENT_MISTAKE"] ?? 0) + 1;
                  });

                  await DatabaseHelper.instance.addScore(
                    defaultPlayerId,
                    "TEAM",
                    "OPPONENT_MISTAKE",
                    1,
                    setNumber: currentSet,
                  );

                  setState(() {
                    teamScore++;
                    scoreHistory.add({
                      "playerId": defaultPlayerId,
                      "category": "TEAM",
                      "subcategory": "OPPONENT_MISTAKE",
                    });
                  });

                  _checkSetWin();
                }
              },
              text: "Opponent\nMistake",
              isLarge: true,
            ),
          ),
          const SizedBox(height: 8),
          _buildUniformButton(
            onPressed: () {
              HapticFeedback.vibrate();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ResultPage(
                    teamName: teamName,
                    opponentTeam: widget.opponentTeam,
                    teamSet: teamSet,
                    opponentSet: opponentSet,
                    setHistory: setHistory,
                    isCurrentResult: true, // ⬅ Tambahkan flag
                    teamScore: teamScore,
                    opponentScore: opponentScore,
                  ),
                ),
              );
            },
            text: "Hasil\nSementara",
            isLarge: true,
          ),
          const SizedBox(height: 8),
          if ((teamSet > 1 || opponentSet > 1) ||
              (currentSet == 3 && isSetFinished))
            _buildUniformButton(
              onPressed: () {
                HapticFeedback.vibrate();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultPage(
                      teamName: teamName,
                      opponentTeam: widget.opponentTeam,
                      teamSet: teamSet,
                      opponentSet: opponentSet,
                      teamScore: teamScore, // 👈 Pass it here
                      opponentScore: opponentScore,
                      setHistory: setHistory,
                    ),
                  ),
                );
              },
              text: "Hasil\nAkhir",
              isLarge: true,
            ),
        ],
      ),
    );
  }

  Widget _buildUniformButton({
    required VoidCallback? onPressed,
    required String text,
    Color backgroundColor = Colors.transparent,
    bool isLarge = false,
  }) {
    return SizedBox(
      width: 94,
      height: isLarge ? 45 : 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: Colors.grey, // Customize border color
              width: 1, // Border width
            ),
          ),
          padding: const EdgeInsets.all(6),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  /// LEFT BUTTONS (Back, Undo)
  /// Tombol Back, Toggle Pen, dan Undo di pojok kiri (dengan layout agak kebawah)
  Widget _buildLeftButtons() {
    return Positioned(
      top: 80, // geser tombol sedikit ke bawah
      left: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // -- Tombol Back --
          ElevatedButton(
            onPressed: () {
              HapticFeedback.vibrate();
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: Text("Konfirmasi"),
                    content: Text("Apakah kamu yakin ingin kembali?\n Data akan direset"),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext)
                              .pop(); // Tutup dialog saja
                        },
                        child: Text("Tidak"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop(); // Tutup dialog dulu
                          await DatabaseHelper.instance.resetScores(); // 🔄 Reset
                          Navigator.pop(context); // Lalu keluar dari halaman
                        },
                        child: Text("Ya"),
                      ),
                    ],
                  );
                },
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.grey, width: 1),
              ),
            ),
            child: const Text("Kembali"),
          ),

          const SizedBox(height: 12),

          // -- Tombol Toggle Drawing Mode --
          IconButton(
            icon: Icon(
              _isDrawingMode ? Icons.edit_off : Icons.edit,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isDrawingMode = !_isDrawingMode;
              });
            },
          ),
          const SizedBox(height: 12),

          // -- Tombol Undo --
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: () {
              if (_isDrawingMode) {
                if (_strokes.isNotEmpty) {
                  setState(() => _strokes.removeLast());
                }
              } else {
                // panggil undo skor di sini, misal:
                // DatabaseHelper.instance.undoLastScoreForSet(...)
              }
            },
          ),
          const SizedBox(height: 12),

          // -- Tombol Pilih Warna --
          PopupMenuButton<int>(
            icon: Icon(Icons.color_lens, color: _availableColors[_colorIndex]),
            onSelected: (idx) {
              setState(() => _colorIndex = idx);
            },
            itemBuilder: (context) {
              return List<PopupMenuEntry<int>>.generate(
                _availableColors.length, // pastikan ini 4
                (i) => PopupMenuItem<int>(
                  value: i,
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: _availableColors[i]),
                      const SizedBox(width: 8),
                      Text(_colorNames[i]), // i aman di 0..3
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Konfirmasi Keluar"),
          content: Text(
              "Apakah Anda yakin ingin keluar? Set saat ini akan direset."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Tutup dialog
              child: Text("Batal"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  currentSet = 0; // Reset currentSet sebelum keluar
                });
                Navigator.of(context).pop(); // Tutup dialog
                Navigator.of(context).pop(); // Kembali ke halaman sebelumnya
              },
              child: Text("Keluar", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _draggableBall() {
    return Draggable(
      data: "ball", // You can pass any data if needed.
      feedback: Opacity(
        opacity: 0.7,
        child: Image.asset(
          'assets/ball.png',
          width: 50,
          height: 50,
        ),
      ),
      childWhenDragging: Container(), // Hide original while dragging.
      onDragEnd: (DraggableDetails details) {
        // Convert the global position to a local position relative to the court.
        final RenderBox box =
            _gameAreaKey.currentContext!.findRenderObject() as RenderBox;
        final Offset localPosition = box.globalToLocal(details.offset);
        setState(() {
          // Update ballOffset so the ball appears in the new location.
          ballOffset = localPosition;
        });
      },
      child: Image.asset(
        'assets/ball.png',
        width: 50,
        height: 50,
      ),
    );
  }

  Widget _buildDraggablePlayer(int index) {
    final int playerId =
        int.tryParse(widget.players[index]['id'].toString()) ?? 0;
    final String playerName = widget.players[index]['name'].toString();
    final String playerNumber = widget.players[index]['number'].toString();
    final Map<String, Map<String, int>> scoresMap =
        convertScoreMap(widget.players[index]['scores']);

    return AnimatedPositioned(
      key: ValueKey("active_${widget.players[index]['id']}"),
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
      left: playerPositions[index].dx,
      top: playerPositions[index].dy,
      child: GestureDetector(
        onTap: () {
          _showScorePopup(context, playerId, playerName, scoresMap);
        },
        child: DragTarget<Map<String, dynamic>>(
          onAccept: (data) {
            int sourceIndex = data[
                "index"]; // index dari pemain yang diseret (bisa dari substitution)
            setState(() {
              // Lakukan swap antara pemain aktif (index) dan pemain dari substitution (sourceIndex)
              var temp = widget.players[index];
              widget.players[index] = widget.players[sourceIndex];
              widget.players[sourceIndex] = temp;
            });

            HapticFeedback.vibrate();
          },
          builder: (context, candidateData, rejectedData) {
            return Draggable<Map<String, dynamic>>(
              key: ValueKey("draggable_active_${widget.players[index]['id']}"),
              data: {
                "player": widget.players[index],
                "index": index,
              },
              feedback: _playerBall(
                playerNumber,
                playerName,
                scoresMap,
                playerId,
                currentSet, // int: current set number from your state
                teamSet, // int: team set score from your state
                opponentSet, // int: opponent set score from your state
                isSetFinished,
              ),
              childWhenDragging: Container(), // kosong agar tidak ada duplikasi
              child: _playerBall(
                playerNumber,
                playerName,
                scoresMap,
                playerId,
                currentSet, // int: current set number from your state
                teamSet, // int: team set score from your state
                opponentSet, // int: opponent set score from your state
                isSetFinished, // boolean flag from your state
              ),
              onDraggableCanceled: (velocity, offset) {
                if (_gameAreaKey.currentContext == null) return;
                final RenderBox gameAreaBox = _gameAreaKey.currentContext!
                    .findRenderObject() as RenderBox;
                final Offset localOffset = gameAreaBox.globalToLocal(offset);
                setState(() {
                  double maxX = gameAreaBox.size.width - 60;
                  double maxY = gameAreaBox.size.height - 60;
                  if (maxX < 0) maxX = 0;
                  if (maxY < 0) maxY = 0;
                  double newX = localOffset.dx.clamp(0, maxX);
                  double newY = localOffset.dy.clamp(0, maxY);
                  playerPositions[index] = Offset(newX, newY);
                });
              },
              onDragCompleted: () {
                // Tidak perlu update posisi, swap sudah dilakukan di onAccept
              },
            );
          },
        ),
      ),
    );
  }

  /// PLAYER BALL (with 4 parameters)
  Widget _playerBall(
      String number,
      String name,
      Map<String, Map<String, int>> playerScores,
      int playerId,
      int currentSet,
      int teamSet,
      int opponentSet,
      bool isSetFinished) {
    // Disable tap if game is finished
    bool canTap = !((teamSet > 1 || opponentSet > 1) ||
        (currentSet == 3 && isSetFinished));

    return GestureDetector(
      onTap: canTap
          ? () {
              HapticFeedback.vibrate();
              _showScorePopup(context, playerId, name, {});
            }
          : null, // Disabled tap when game is finished
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: canTap
              ? Color(0xFF002F42)
              : Color(0xFF002F42), // Solid color for both states
          border: Border.all(
            color: canTap ? Colors.blue : Colors.blueAccent,
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                number,
                style: TextStyle(
                  color: canTap ? Colors.white : Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                name,
                style: TextStyle(
                  color: canTap ? Colors.white : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
