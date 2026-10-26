import 'package:flutter/material.dart';
import '../core/database_helper.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  double _wellbeing = 5.0;
  double _sleepQuality = 5.0;
  
  final List<String> _selectedSymptoms = [];

  Color _getPastelColor(double value) {
    if (value > 7) return const Color(0xFFB8E1C4);
    if (value > 4) return const Color(0xFFFFE5B4);
    return const Color(0xFFF4C2C2);
  }

  final List<String> _symptomsList = [
    'Головная боль',
    'Головокружение',
    'Сонливость',
    'Боль в суставах',
    'Шум в ушах',
    'Тревога'
  ];

  bool _isSaving = false;

  Future<void> _saveHealthLog() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final db = DatabaseHelper.instance;
      
      final lastWeather = await db.getLastWeather();
      
      int weatherId;
      if (lastWeather != null) {
        weatherId = lastWeather['id'];
      } else {
        weatherId = await db.saveWeather(760.0, 2, 0.0);
      }

      await db.saveHealthLog(
        wellbeing: _wellbeing.round(),
        sleepQuality: _sleepQuality.round(),
        symptoms: _selectedSymptoms,
        weatherId: weatherId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Состояние зафиксировано'),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Дневник состояния'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildSectionTitle('Общее самочувствие'),
            const SizedBox(height: 10),
            
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getPastelColor(_wellbeing),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _wellbeing.round().toString(),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
              ),
            ),
            Slider(
              value: _wellbeing,
              min: 1, max: 10, divisions: 9,
              activeColor: _getPastelColor(_wellbeing),
              inactiveColor: Colors.black12,
              onChanged: (val) => setState(() => _wellbeing = val),
            ),

            const SizedBox(height: 30),
            _buildSectionTitle('Качество сна'),
            Slider(
              value: _sleepQuality,
              min: 1, max: 10, divisions: 9,
              activeColor: const Color(0xFFD1D0F9),
              onChanged: (val) => setState(() => _sleepQuality = val),
            ),

            const SizedBox(height: 30),
            _buildSectionTitle('Конкретные симптомы'),
            const SizedBox(height: 10),
            
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _symptomsList.map((symptom) {
                final isSelected = _selectedSymptoms.contains(symptom);
                return FilterChip(
                  label: Text(symptom),
                  selected: isSelected,
                  selectedColor: const Color(0xFFE0E0E0),
                  checkmarkColor: Colors.teal,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedSymptoms.add(symptom);
                      } else {
                        _selectedSymptoms.remove(symptom);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveHealthLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  side: const BorderSide(color: Colors.black12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_isSaving ? 'Сохранение...' : 'Зафиксировать состояние'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54),
    );
  }
}