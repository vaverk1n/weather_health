import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:geolocator/geolocator.dart';
import 'database_helper.dart';

class WeatherApiService {
  static const String _baseUrl = "https://api.open-meteo.com/v1/forecast";

  // Основной метод: текущая погода + прогноз на сегодня
  static Future<void> fetchAndSaveWeather() async {
    try {
      double lat = 55.75;
      double lon = 37.61;

      try {
        Position position = await _determinePosition();
        lat = position.latitude;
        lon = position.longitude;
      } catch (e) {
        debugPrint("Используем координаты Москвы: $e");
      }

      // Запрашиваем: текущие данные + почасовой прогноз
      final url = Uri.parse(
        "$_baseUrl?latitude=$lat&longitude=$lon"
        "&current=temperature_2m,surface_pressure"
        "&hourly=temperature_2m,surface_pressure"
        "&timezone=auto"
      );

      debugPrint("Запрос к API: $url");

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // --- ТЕКУЩИЕ ДАННЫЕ ---
        final current = data['current'];
        double pressHpa = (current['surface_pressure'] ?? 1013.25).toDouble();
        double pressMmHg = pressHpa * 0.750062;
        double currentTemp = (current['temperature_2m'] ?? 20.0).toDouble();
        int kpIndex = 1; // Kp-индекс пока заглушка

        // Рассчитываем deltaT (разница текущей и средней за день)
        final hourly = data['hourly'];
        List<dynamic> hourlyTemps = hourly['temperature_2m'];
        double avgTemp = hourlyTemps.take(24).reduce((a, b) => a + b) / 24;
        double deltaT = currentTemp - avgTemp;

        // Сохраняем текущую погоду в БД
        await DatabaseHelper.instance.saveWeather(pressMmHg, kpIndex, deltaT);

        // --- ПРОГНОЗ НА СЕГОДНЯ (ПОЧАСОВОЙ) ---
        List<dynamic> hourlyPressures = hourly['surface_pressure'];
        List<FlSpot> forecastPoints = [];

        // Берём 7 точек с 06:00 до 18:00 с шагом 2 часа
        for (int h = 6; h <= 18; h += 2) {
          double tempAtHour = (hourlyTemps[h] ?? currentTemp).toDouble();
          double pressAtHour = (hourlyPressures[h] ?? pressHpa).toDouble() * 0.750062;

          // Рассчитываем уровень стресса для этой точки
          double stressLevel = _calculateStressLevel(
            pressure: pressAtHour,
            kpIndex: kpIndex,
            tempDelta: tempAtHour - avgTemp,
          );

          int index = ((h - 6) / 2).round();
          forecastPoints.add(FlSpot(index.toDouble(), stressLevel));
        }

        // Сохраняем прогноз в БД
        await DatabaseHelper.instance.saveForecastPoints(forecastPoints);

        debugPrint("API Успех: $pressMmHg мм рт.ст., Kp: $kpIndex, DeltaT: ${deltaT.toStringAsFixed(1)}°");
        debugPrint("Прогноз сохранён: ${forecastPoints.length} точек");
      } else {
        debugPrint("Ошибка API: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Критическая ошибка WeatherApiService: $e");
    }
  }

  // Расчёт уровня стресса для одной точки прогноза (0–10)
  static double _calculateStressLevel({
    required double pressure,
    required int kpIndex,
    required double tempDelta,
  }) {
    double stress = 2.0; // Базовый уровень

    // Фактор давления (чем дальше от нормы 750, тем выше стресс)
    double pressureDeviation = (pressure - 750).abs();
    if (pressureDeviation > 20) {
      stress += 4.0;
    } else if (pressureDeviation > 10) {
      stress += 2.5;
    } else if (pressureDeviation > 5) {
      stress += 1.0;
    }

    // Фактор Kp-индекса
    if (kpIndex >= 6) {
      stress += 3.0;
    } else if (kpIndex >= 4) {
      stress += 1.5;
    }

    // Фактор перепада температуры
    double absDelta = tempDelta.abs();
    if (absDelta >= 15) {
      stress += 2.5;
    } else if (absDelta >= 7) {
      stress += 1.5;
    } else if (absDelta >= 3) {
      stress += 0.5;
    }

    return stress.clamp(0.0, 10.0);
  }

  static Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('GPS выключен');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Доступ запрещен');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 5),
    );
  }
}