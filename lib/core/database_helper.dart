import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:fl_chart/fl_chart.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('meteo_data.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const floatType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY CHECK (id = 0), 
        user_group TEXT NOT NULL,
        is_onboarded INTEGER NOT NULL
      )
    ''');

    await db.insert('settings', {'id': 0, 'user_group': 'general', 'is_onboarded': 0});

    await db.execute('''
      CREATE TABLE weather_history (
        id $idType,
        pressure $floatType,
        kp_index $intType,
        temperature $floatType,
        timestamp $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE health_logs (
        id $idType,
        wellbeing $intType,
        sleep_quality $intType,
        symptoms $textType,
        weather_id $intType,
        timestamp $textType,
        FOREIGN KEY (weather_id) REFERENCES weather_history (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE forecast_points (
        id $idType,
        hour_index $intType,
        stress_level $floatType,
        date $textType
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS forecast_points (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          hour_index INTEGER NOT NULL,
          stress_level REAL NOT NULL,
          date TEXT NOT NULL
        )
      ''');
    }
  }

  // --- НАСТРОЙКИ ---

  Future<Map<String, dynamic>> getSettings() async {
    final db = await instance.database;
    final res = await db.query('settings', where: 'id = 0');
    return res.first;
  }

  Future<void> updateProfile(String group, bool onboarded) async {
    final db = await instance.database;
    await db.update('settings', {'user_group': group, 'is_onboarded': onboarded ? 1 : 0}, where: 'id = 0');
  }

  // --- ПОГОДА ---

  Future<Map<String, dynamic>?> getLastWeather() async {
    final db = await instance.database;
    final res = await db.query('weather_history', orderBy: 'timestamp DESC', limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<int> saveWeather(double press, int kp, double temp) async {
    final db = await instance.database;
    return await db.insert('weather_history', {
      'pressure': press,
      'kp_index': kp,
      'temperature': temp,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // --- ДНЕВНИК ---

  Future<int> saveHealthLog({
    required int wellbeing,
    required int sleepQuality,
    required List<String> symptoms,
    required int weatherId,
  }) async {
    final db = await instance.database;
    return await db.insert('health_logs', {
      'wellbeing': wellbeing,
      'sleep_quality': sleepQuality,
      'symptoms': symptoms.join(','),
      'weather_id': weatherId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // --- ТОЧКИ ДЛЯ ГРАФИКА ИСТОРИИ ---
  // X = время записи (06:00 → 0, 08:00 → 1, ..., 18:00 → 6)
  // Y = инвертированное самочувствие (10 - wellbeing), чтобы выше = хуже

  Future<List<FlSpot>> getStressData() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT wellbeing, timestamp FROM health_logs '
      'WHERE timestamp LIKE ? '
      'ORDER BY timestamp ASC',
      ['$today%']
    );

    if (maps.isEmpty) {
      return [];
    }

    return maps.map((m) {
      final ts = DateTime.parse(m['timestamp']);
      final hour = ts.hour + ts.minute / 60.0;
      final x = (hour - 6) / 2.0;
      final y = 10 - (m['wellbeing'] as int).toDouble();
      return FlSpot(x, y);
    }).toList();
  }

  // --- ИНДЕКСЫ ЗАПИСЕЙ ДЛЯ ПОДСВЕТКИ ТОЧЕК ---

  Future<List<int>> getUserLogIndices() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT timestamp FROM health_logs WHERE timestamp LIKE ? ORDER BY timestamp ASC',
      ['$today%']
    );

    if (maps.isEmpty) return [];

    return maps.map((m) {
      final ts = DateTime.parse(m['timestamp']);
      final hour = ts.hour;
      return ((hour - 6) / 2).round().clamp(0, 6);
    }).toList();
  }

  // --- ПРОГНОЗ ---

  Future<void> saveForecastPoints(List<FlSpot> points) async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    await db.delete('forecast_points', where: 'date = ?', whereArgs: [today]);

    for (int i = 0; i < points.length; i++) {
      await db.insert('forecast_points', {
        'hour_index': i,
        'stress_level': points[i].y,
        'date': today,
      });
    }
  }

  Future<List<FlSpot>> getForecastPoints() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final List<Map<String, dynamic>> maps = await db.query(
      'forecast_points',
      where: 'date = ?',
      whereArgs: [today],
      orderBy: 'hour_index ASC',
    );

    if (maps.isEmpty) {
      return [
        const FlSpot(0, 2.1), const FlSpot(1, 2.3), const FlSpot(2, 2.0),
        const FlSpot(3, 2.8), const FlSpot(4, 2.5),
        const FlSpot(5, 2.2), const FlSpot(6, 2.0),
      ];
    }

    return maps.map((m) => FlSpot(
      (m['hour_index'] as int).toDouble(),
      (m['stress_level'] as num).toDouble(),
    )).toList();
  }
}