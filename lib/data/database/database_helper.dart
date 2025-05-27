import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Get the database instance.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('players.db');
    return _database!;
  }

  /// Initialize the database with the provided file path.
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5, // Increase version for migration if needed.
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// Create the initial tables: players and scores.
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE players (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        position TEXT,
        number TEXT,
        teamName TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        player_id INTEGER,
        category TEXT,
        subcategory TEXT,
        score INTEGER,
        setNumber INTEGER DEFAULT 0,
        ballPosition INTEGER,
        FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE
      )
    ''');

    // Create match_history table for saving match result.
    await db.execute('''
  CREATE TABLE match_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    matchId INTEGER,
    teamName TEXT,
    opponentTeam TEXT,
    filePath TEXT,
    timestamp INTEGER
  )
''');
  }

  /// Upgrade the database if an older version is used.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db
          .execute('ALTER TABLE scores ADD COLUMN setNumber INTEGER DEFAULT 0');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE scores ADD COLUMN ballPosition INTEGER');
    }
    // Misalnya, jika match_history ditambahkan di versi 6:
    if (oldVersion < 6) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS match_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        matchId INTEGER,
        teamName TEXT,
        opponentTeam TEXT,
        filePath TEXT,
        timestamp INTEGER
      )
    ''');
    }
  }

  Future<void> undoLastScoreForSet(
      int playerId, String category, String subcategory, int setNumber) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'scores',
      where:
          'player_id = ? AND category = ? AND subcategory = ? AND setNumber = ?',
      whereArgs: [playerId, category, subcategory, setNumber],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      int scoreId = result.first['id'];
      await db.delete('scores', where: 'id = ?', whereArgs: [scoreId]);
    }
  }

  // ==================== Player Functions ====================

  Future<int> addPlayer(
      String name, String position, String number, String teamName) async {
    final db = await database;
    return await db.insert('players', {
      'name': name,
      'position': position,
      'number': number,
      'teamName': teamName,
    });
  }

  Future<List<Map<String, dynamic>>> getPlayers() async {
    final db = await database;
    return await db.query('players'); // Ensure the 'id' field is included.
  }

  Future<int> updatePlayer({
    required int id,
    required String name,
    required String position,
    required String number,
    required String teamName,
  }) async {
    final db = await database;
    return await db.update(
      'players',
      {
        'name': name,
        'position': position,
        'number': number,
        'teamName': teamName,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> resetPlayers() async {
    final db = await database;
    await db.delete('players');
  }

  // ==================== Score Functions ====================

  /// Add a score entry for a given player.
  Future<int> addScore(
    int playerId,
    String category,
    String subcategory,
    int score, {
    required int setNumber,
    int? ballPosition,
  }) async {
    final db = await database;
    return await db.insert('scores', {
      'player_id': playerId,
      'category': category,
      'subcategory': subcategory,
      'score': score,
      'setNumber': setNumber,
      'ballPosition': ballPosition,
    });
  }

  /// Get all scores for a specific player.
  Future<List<Map<String, dynamic>>> getScoresByPlayer(
      int playerId, int setNumber) async {
    final db = await database;
    return await db.query(
      'scores',
      where: 'player_id = ? AND setNumber = ?',
      // Jika currentSet = 0 (Set 1), maka filter dengan setNumber = 1.
      whereArgs: [playerId, setNumber],
      orderBy: 'id ASC',
    );
  }

  /// Delete all scores for a specific player.
  Future<void> deleteScoresByPlayer(int playerId) async {
    final db = await database;
    await db.delete('scores', where: 'player_id = ?', whereArgs: [playerId]);
  }

  /// Undo the last score entry for a given player, category, and subcategory.
  Future<void> undoLastScore(
      int playerId, String category, String subcategory) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'scores',
      where: 'player_id = ? AND category = ? AND subcategory = ?',
      whereArgs: [playerId, category, subcategory],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      int scoreId = result.first['id'];
      await db.delete('scores', where: 'id = ?', whereArgs: [scoreId]);
    }
  }

  /// Delete all scores.
  Future<void> resetScores() async {
    final db = await database;
    await db.delete('scores');
  }

  /// Get all scores for a specific set.
  Future<List<Map<String, dynamic>>> getScoresBySet(int setNumber) async {
    final db = await database;
    return await db.query(
      'scores',
      where: 'setNumber = ?',
      whereArgs: [setNumber],
      orderBy: 'id ASC',
    );
  }

  /// Get the team name (unique) from players.
  Future<String?> getTeamName() async {
    final db = await database;
    final List<Map<String, dynamic>> result =
        await db.rawQuery("SELECT DISTINCT teamName FROM players LIMIT 1");
    if (result.isNotEmpty && result.first['teamName'] != null) {
      return result.first['teamName'] as String;
    }
    return null;
  }

  // ==================== Match History Functions ====================

  /// Save match history (to be used after a match is finished).
  Future<int> saveMatchHistory({
    required int matchId,
    required String teamName,
    required String opponentTeam,
    required String filePath,
    // Optionally, you could add a timestamp here:
    // required int timestamp,
  }) async {
    final db = await database;
    return await db.insert('match_history', {
      'matchId': matchId,
      'teamName': teamName,
      'opponentTeam': opponentTeam,
      'filePath': filePath,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ==================== Utility Functions ====================

  /// Convert a dynamic score structure to a typed Map<String, Map<String, int>>.
  Map<String, Map<String, int>> convertScoreMap(dynamic score) {
    if (score == null) return <String, Map<String, int>>{};
    if (score is Map<String, Map<String, int>>) return score;
    if (score is Map) {
      return score.map((key, value) {
        return MapEntry(
          key.toString(),
          (value is Map) ? value.cast<String, int>() : <String, int>{},
        );
      });
    }
    return <String, Map<String, int>>{};
  }
}
