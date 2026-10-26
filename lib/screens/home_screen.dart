import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/risk_calculator.dart';
import '../core/notification_service.dart';
import '../core/database_helper.dart';
import '../core/weather_api_service.dart';
import '../core/personal_risk_calculator.dart';
import 'diary_screen.dart';
import 'settings_screen.dart';
import 'onboarding_screen.dart';
import 'access_screen.dart';
import 'analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double currentPressure = 748.0;
  int currentKp = 2;
  double currentTempDelta = 14.0;
  String currentCity = "Москва";

  bool isProfileFilled = false;
  String userGroup = 'general';

  List<FlSpot> forecastData = [];
  List<FlSpot> historyData = [];

  PersonalRiskResult? _personalRisk;

  @override
  void initState() {
    super.initState();
    _refreshAllDataFromDb();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessScreen.showDisclaimer(context);
    });
  }

  Future<void> _refreshAllDataFromDb() async {
    await WeatherApiService.fetchAndSaveWeather();

    final settings = await DatabaseHelper.instance.getSettings();
    final lastWeather = await DatabaseHelper.instance.getLastWeather();
    final dbHistory = await DatabaseHelper.instance.getStressData();
    final dbForecast = await DatabaseHelper.instance.getForecastPoints();

    if (mounted) {
      setState(() {
        userGroup = settings['user_group'];
        isProfileFilled = settings['is_onboarded'] == 1;

        if (lastWeather != null) {
          currentPressure = (lastWeather['pressure'] as num).toDouble();
          currentKp = lastWeather['kp_index'];
          currentTempDelta = (lastWeather['temperature'] as num).toDouble();
        }

        historyData = dbHistory.isNotEmpty ? dbHistory : [];
        forecastData = dbForecast;
      });

      PersonalRiskCalculator.calculate(
        currentPressure: currentPressure,
        currentKp: currentKp,
        currentTempDelta: currentTempDelta,
      ).then((result) {
        if (mounted) {
          setState(() => _personalRisk = result);
        }
      });
    }
  }

  Future<void> _generateTestData() async {
    final db = DatabaseHelper.instance;

    final testData = [
      {'pressure': 755.0, 'kp': 2, 'temp': 2.0, 'wellbeing': 8, 'sleep': 7, 'symptoms': ['Головная боль']},
      {'pressure': 740.0, 'kp': 5, 'temp': 10.0, 'wellbeing': 3, 'sleep': 4, 'symptoms': ['Головная боль', 'Сонливость']},
      {'pressure': 760.0, 'kp': 1, 'temp': -1.0, 'wellbeing': 9, 'sleep': 8, 'symptoms': []},
      {'pressure': 735.0, 'kp': 6, 'temp': 14.0, 'wellbeing': 2, 'sleep': 3, 'symptoms': ['Головная боль', 'Тревога']},
      {'pressure': 750.0, 'kp': 3, 'temp': 3.0, 'wellbeing': 7, 'sleep': 6, 'symptoms': ['Сонливость']},
      {'pressure': 742.0, 'kp': 4, 'temp': 8.0, 'wellbeing': 4, 'sleep': 5, 'symptoms': ['Боль в суставах', 'Сонливость']},
      {'pressure': 738.0, 'kp': 7, 'temp': 16.0, 'wellbeing': 1, 'sleep': 2, 'symptoms': ['Головная боль', 'Головокружение', 'Тревога']},
    ];

    for (final data in testData) {
      final weatherId = await db.saveWeather(
        data['pressure'] as double,
        data['kp'] as int,
        data['temp'] as double,
      );

      await db.saveHealthLog(
        wellbeing: data['wellbeing'] as int,
        sleepQuality: data['sleep'] as int,
        symptoms: (data['symptoms'] as List).map((e) => e.toString()).toList(),
        weatherId: weatherId,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ Добавлено 7 тестовых записей'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          duration: const Duration(seconds: 2),
        ),
      );
      _refreshAllDataFromDb();
    }
  }

  @override
  Widget build(BuildContext context) {
    final risk = RiskCalculator.calculate(currentPressure, currentKp, currentTempDelta);
    final bool isCritical = risk == RiskLevel.high;

    final advices = NotificationService.getSmartAdvices(
      pressure: currentPressure,
      kpIndex: currentKp,
      tempDelta: currentTempDelta,
      userGroup: userGroup,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.bar_chart_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnalyticsScreen(
                forecastData: forecastData,
                historyData: historyData,
              ),
            ),
          ),
        ),
        title: const Text('МетеоЗащита'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ).then((_) => _refreshAllDataFromDb()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAllDataFromDb,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              if (!isProfileFilled) _buildOnboardingBanner(),
              const SizedBox(height: 10),
              _buildLocationHeader(),
              const SizedBox(height: 20),
              _buildRiskIndicator(risk),
              const SizedBox(height: 30),
              _buildStatsRow(),
              const SizedBox(height: 30),
              if (_personalRisk != null) _buildMLBlock(),
              const SizedBox(height: 20),
              _buildAdvicesList(advices, risk, isCritical),
              const SizedBox(height: 30),
              _buildDiaryButton(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingBanner() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            const Text('Настройте профиль для точных советов'),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                ).then((res) {
                  if (res == true) _refreshAllDataFromDb();
                });
              },
              child: const Text('Пройти анкету'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_on, size: 14, color: Colors.grey),
        const SizedBox(width: 5),
        Text(currentCity, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }

  Widget _buildRiskIndicator(RiskLevel risk) {
    String riskText = risk == RiskLevel.high ? "ВЫСОКИЙ" : risk == RiskLevel.medium ? "СРЕДНИЙ" : "НИЗКИЙ";
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: RiskCalculator.getRiskColor(risk).withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: RiskCalculator.getRiskColor(risk), width: 5),
      ),
      child: Column(
        children: [
          Text(
            riskText,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: RiskCalculator.getRiskColor(risk),
            ),
          ),
          const Text('РИСК', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatTile(Icons.speed, '${currentPressure.round()}', 'мм рт.ст.'),
        _buildStatTile(Icons.language, '$currentKp', 'Kp-индекс'),
        _buildStatTile(
          Icons.thermostat,
          '${currentTempDelta > 0 ? "+" : ""}${currentTempDelta.round()}°',
          'Δ Темп.',
        ),
      ],
    );
  }

  Widget _buildStatTile(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueGrey, size: 20),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMLBlock() {
    final pr = _personalRisk!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pr.highRisk
              ? Colors.red.withValues(alpha: 0.08)
              : Colors.blue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: pr.highRisk
                ? Colors.red.withValues(alpha: 0.2)
                : Colors.blue.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  pr.highRisk ? Icons.warning_amber_rounded : Icons.psychology_outlined,
                  color: pr.highRisk ? Colors.red : Colors.blueGrey,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  pr.highRisk ? 'Ваш персональный риск выше среднего' : 'ML-персонализация',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: pr.highRisk ? Colors.red : Colors.blueGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              pr.recommendation,
              style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvicesList(List<WeatherAdvice> advices, RiskLevel risk, bool isCritical) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: advices.map((advice) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RiskCalculator.getRiskColor(risk).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: RiskCalculator.getRiskColor(risk).withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                advice.category.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isCritical ? Colors.red : Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 6),
              Text(advice.text, style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildDiaryButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DiaryScreen()),
            ).then((_) => _refreshAllDataFromDb()),
            icon: const Icon(Icons.history_edu),
            label: const Text('Заполнить дневник'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _generateTestData,
            icon: const Icon(Icons.science_outlined, size: 18),
            label: const Text('Сгенерировать 7 тестовых записей для ML'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
              foregroundColor: Colors.blueGrey,
              side: const BorderSide(color: Colors.black12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}