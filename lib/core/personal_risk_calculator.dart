import 'database_helper.dart';

/// Один образец для обучения
class DiarySample {
  final double pressure;
  final double temperature;
  final int kpIndex;
  final bool isBadDay; // true, если wellbeing <= 4

  DiarySample({
    required this.pressure,
    required this.temperature,
    required this.kpIndex,
    required this.isBadDay,
  });
}

/// Результат персонального прогноза
class PersonalRiskResult {
  final bool isReady;            // Достаточно ли данных
  final int totalSamples;        // Всего очищенных записей
  final bool highRisk;           // Повышенный риск именно для этого пользователя
  final double accuracy;         // Точность на валидации (0..1)
  final String mainTrigger;      // Главный фактор (давление/Kp/температура)
  final String recommendation;   // Совет

  PersonalRiskResult({
    required this.isReady,
    required this.totalSamples,
    required this.highRisk,
    required this.accuracy,
    required this.mainTrigger,
    required this.recommendation,
  });

  factory PersonalRiskResult.notReady(int samples) {
    return PersonalRiskResult(
      isReady: false,
      totalSamples: samples,
      highRisk: false,
      accuracy: 0,
      mainTrigger: '',
      recommendation: 'Нужно минимум 7 записей дневника для персонализации. Сейчас: $samples.',
    );
  }
}

class PersonalRiskCalculator {
  static const int minSamples = 7;
  static const int badWellbeingLimit = 4; // wellbeing <= 4 — плохой день

  /// Главный метод: обучить модель и сделать прогноз
  static Future<PersonalRiskResult> calculate({
    required double currentPressure,
    required int currentKp,
    required double currentTempDelta,
  }) async {
    final db = DatabaseHelper.instance;

    // 1. Загружаем все записи дневника с погодой
    final List<DiarySample> allSamples = await _loadSamples(db);

    // 2. Очистка уже внутри _loadSamples
    if (allSamples.length < minSamples) {
      return PersonalRiskResult.notReady(allSamples.length);
    }

    // 3. Сортируем (уже отсортированы по timestamp из БД)
    // Делим: 70% обучение, 30% валидация
    final split = (allSamples.length * 0.7).round().clamp(4, allSamples.length - 1);
    final train = allSamples.sublist(0, split);
    final validation = allSamples.sublist(split);

    // 4. Обучаем модель
    final model = _trainModel(train);

    // 5. Валидация
    double accuracy = _validate(model, validation);

    // 6. Предсказание для текущей погоды
    final currentFeatures = _extractFeatures(currentPressure, currentKp, currentTempDelta);
    final isHighRisk = _predict(model, currentFeatures);

    // 7. Определяем главный триггер
    String mainTrigger = _getMainTrigger(model);

    // 8. Формируем рекомендацию
    String recommendation;
    if (isHighRisk) {
      recommendation = 'Ваш персональный риск выше среднего. '
          'Главный триггер: $mainTrigger. '
          'Точность прогноза: ${(accuracy * 100).round()}%.';
    } else {
      recommendation = 'Персональный риск в норме. '
          'Модель обучена на ${allSamples.length} записях. '
          'Точность: ${(accuracy * 100).round()}%.';
    }

    return PersonalRiskResult(
      isReady: true,
      totalSamples: allSamples.length,
      highRisk: isHighRisk,
      accuracy: accuracy,
      mainTrigger: mainTrigger,
      recommendation: recommendation,
    );
  }

  /// Загрузка и очистка данных из БД
  static Future<List<DiarySample>> _loadSamples(DatabaseHelper db) async {
    final dbInstance = await db.database;
    final List<Map<String, dynamic>> rows = await dbInstance.rawQuery('''
      SELECT 
        h.wellbeing,
        h.sleep_quality,
        w.pressure,
        w.temperature,
        w.kp_index
      FROM health_logs h
      INNER JOIN weather_history w ON h.weather_id = w.id
      ORDER BY h.timestamp ASC
    ''');

    final List<DiarySample> samples = [];

    for (final row in rows) {
      final wellbeing = row['wellbeing'] as int;
      final pressure = (row['pressure'] as num).toDouble();
      final temperature = (row['temperature'] as num).toDouble();
      final kpIndex = row['kp_index'] as int;

      // Очистка
      if (wellbeing < 1 || wellbeing > 10) continue;
      if (pressure <= 0) continue;

      samples.add(DiarySample(
        pressure: pressure,
        temperature: temperature,
        kpIndex: kpIndex,
        isBadDay: wellbeing <= badWellbeingLimit,
      ));
    }

    return samples;
  }

  /// Извлечение признаков из текущих показателей
  static List<double> _extractFeatures(double pressure, int kp, double tempDelta) {
    return [
      pressure,
      tempDelta.abs(),
      kp.toDouble(),
    ];
  }

  /// Модель: средние значения признаков для плохих и обычных дней
  static _PersonalModel _trainModel(List<DiarySample> train) {
    final badDays = train.where((s) => s.isBadDay).toList();
    final goodDays = train.where((s) => !s.isBadDay).toList();

    // Средние для плохих дней
    double badPressureAvg = badDays.isEmpty ? 750 : badDays.map((s) => s.pressure).reduce((a, b) => a + b) / badDays.length;
    double badTempAvg = badDays.isEmpty ? 0 : badDays.map((s) => s.temperature.abs()).reduce((a, b) => a + b) / badDays.length;
    double badKpAvg = badDays.isEmpty ? 2 : badDays.map((s) => s.kpIndex.toDouble()).reduce((a, b) => a + b) / badDays.length;

    // Средние для обычных дней
    double goodPressureAvg = goodDays.isEmpty ? 750 : goodDays.map((s) => s.pressure).reduce((a, b) => a + b) / goodDays.length;
    double goodTempAvg = goodDays.isEmpty ? 0 : goodDays.map((s) => s.temperature.abs()).reduce((a, b) => a + b) / goodDays.length;
    double goodKpAvg = goodDays.isEmpty ? 2 : goodDays.map((s) => s.kpIndex.toDouble()).reduce((a, b) => a + b) / goodDays.length;

    // Веса = разница между плохими и обычными днями
    double pressureWeight = (badPressureAvg - goodPressureAvg).abs() / 50;
    double tempWeight = (badTempAvg - goodTempAvg).abs() / 5;
    double kpWeight = (badKpAvg - goodKpAvg).abs() / 2;

    return _PersonalModel(
      badPressureAvg: badPressureAvg,
      badTempAvg: badTempAvg,
      badKpAvg: badKpAvg,
      pressureWeight: pressureWeight.clamp(0, 1),
      tempWeight: tempWeight.clamp(0, 1),
      kpWeight: kpWeight.clamp(0, 1),
    );
  }

  /// Предсказание: плохой день или нет
  static bool _predict(_PersonalModel model, List<double> features) {
    double pressure = features[0];
    double tempDelta = features[1];
    double kp = features[2];

    double riskScore = 0;

    // Чем ближе давление к «плохому» среднему, тем выше риск
    double pressureDiff = (pressure - model.badPressureAvg).abs();
    if (pressureDiff < 15) riskScore += model.pressureWeight;

    // Чем ближе температура к «плохому» среднему
    double tempDiff = (tempDelta - model.badTempAvg).abs();
    if (tempDiff < 5) riskScore += model.tempWeight;

    // Чем ближе Kp к «плохому» среднему
    double kpDiff = (kp - model.badKpAvg).abs();
    if (kpDiff < 1.5) riskScore += model.kpWeight;

    return riskScore >= 0.5;
  }

  /// Валидация: считаем accuracy
  static double _validate(_PersonalModel model, List<DiarySample> validation) {
    if (validation.isEmpty) return 0;

    int correct = 0;
    for (final sample in validation) {
      final features = _extractFeatures(sample.pressure, sample.kpIndex, sample.temperature);
      final prediction = _predict(model, features);
      if (prediction == sample.isBadDay) {
        correct++;
      }
    }

    return correct / validation.length;
  }

  /// Определение главного триггера
  static String _getMainTrigger(_PersonalModel model) {
    if (model.pressureWeight >= model.tempWeight && model.pressureWeight >= model.kpWeight) {
      return 'атмосферное давление';
    } else if (model.tempWeight >= model.kpWeight) {
      return 'перепады температуры';
    } else {
      return 'геомагнитная активность (Kp-индекс)';
    }
  }
}

/// Внутренняя модель с весами
class _PersonalModel {
  final double badPressureAvg;
  final double badTempAvg;
  final double badKpAvg;
  final double pressureWeight;
  final double tempWeight;
  final double kpWeight;

  _PersonalModel({
    required this.badPressureAvg,
    required this.badTempAvg,
    required this.badKpAvg,
    required this.pressureWeight,
    required this.tempWeight,
    required this.kpWeight,
  });
}