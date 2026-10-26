import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/stress_chart.dart';
import '../core/database_helper.dart';

class AnalyticsScreen extends StatefulWidget {
  final List<FlSpot> forecastData;
  final List<FlSpot> historyData;

  const AnalyticsScreen({
    super.key,
    required this.forecastData,
    required this.historyData,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<int> _userLogIndices = [];
  String _reminderText = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final db = DatabaseHelper.instance;
    final indices = await db.getUserLogIndices();
    
    if (mounted) {
      setState(() {
        _userLogIndices = indices;
        _reminderText = _buildReminder(indices);
      });
    }
  }

  String _buildReminder(List<int> indices) {
    final now = DateTime.now();
    final hour = now.hour;

    if (indices.isEmpty) {
      if (hour < 12) {
        return "🌅 Доброе утро! Не забудьте отметить своё состояние "
            "сегодня днём и вечером. Регулярные записи помогут выявить "
            "ваши персональные метеотриггеры.";
      } else if (hour < 18) {
        return "☀️ День в разгаре! Самое время отметить текущее "
            "самочувствие. Вечером тоже не забудьте сделать запись — "
            "это важно для точного анализа.";
      } else {
        return "🌙 Вечернее время. Зафиксируйте, как прошёл день. "
            "Завтра продолжим наблюдение за вашим состоянием.";
      }
    }

    // Проверяем, есть ли вечерняя запись (индекс 5 или 6 = 16:00–18:00)
    bool hasEveningRecord = indices.any((idx) => idx >= 5);
    bool hasNoonRecord = indices.any((idx) => idx >= 3 && idx < 5);

    if (hour >= 18 && !hasEveningRecord) {
      return "🌙 День подходит к концу. Не забудьте оценить "
          "своё самочувствие перед сном — вечерние данные особенно "
          "важны для анализа влияния погоды за целый день.";
    } else if (hour >= 18 && hasEveningRecord) {
      return "✅ Спасибо! Данные за сегодня зафиксированы. "
          "Завтра продолжайте отмечать состояние — чем больше записей, "
          "тем точнее персональный прогноз.";
    } else if (hour >= 12 && hour < 18 && !hasNoonRecord) {
      return "📝 Не забудьте отметить самочувствие сейчас и вечером.";
    } else if (hour >= 12 && hour < 18 && hasNoonRecord) {
      return "👍 Дневная запись уже есть. Отметьте также вечернее состояние.";
    } else if (hour < 12) {
      return "☀️ Утренняя запись уже есть. Продолжайте "
          "отмечать состояние днём и вечером.";
    } else {
      return "📝 Продолжайте вести дневник. Регулярные записи "
          "помогут точнее определить ваши метеотриггеры.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Аналитика'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              "ПРОГНОЗ МЕТЕОСТРЕССА",
              "Ожидаемая нагрузка на организм (чем выше — тем хуже)"
            ),
            const SizedBox(height: 15),
            StressChart(
              points: widget.forecastData,
            ),

            const SizedBox(height: 40),

            _buildSectionHeader(
              "ИСТОРИЯ САМОЧУВСТВИЯ",
              "Точки — моменты ваших записей (выше = хуже)"
            ),
            const SizedBox(height: 15),
            if (widget.historyData.isEmpty)
              Container(
                height: 200,
                alignment: Alignment.center,
                child: const Text(
                  "Пока нет записей за сегодня",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              )
            else
              StressChart(
                points: widget.historyData,
                userLogIndices: _userLogIndices,
              ),

            const SizedBox(height: 40),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "📋 НАПОМИНАНИЕ",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _reminderText,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}