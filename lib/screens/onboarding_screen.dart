import 'package:flutter/material.dart';
import '../core/database_helper.dart'; // Импортируем базу данных

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _selectedGroup;

  final List<Map<String, String>> _groups = [
    {'id': 'hypertonic', 'title': 'Гипертоник', 'desc': 'Чувствительность к росту давления'},
    {'id': 'hypotonic', 'title': 'Гипотоник', 'desc': 'Реакция на падение давления'},
    {'id': 'joints', 'title': 'Суставы', 'desc': 'Реакция на влажность и холод'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Анкета профиля'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const Text(
              'Выберите вашу группу метеочувствительности:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _groups.length,
                itemBuilder: (context, index) => RadioListTile<String>(
                  title: Text(_groups[index]['title']!),
                  subtitle: Text(_groups[index]['desc']!),
                  value: _groups[index]['id']!,
                  groupValue: _selectedGroup,
                  onChanged: (val) => setState(() => _selectedGroup = val),
                  activeColor: Colors.teal,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                // Делаем функцию асинхронной (async)
                onPressed: _selectedGroup == null 
                    ? null 
                    : () async {
                        // 1. Сохраняем данные в таблицу settings базы данных
                        await DatabaseHelper.instance.updateProfile(
                          _selectedGroup!, 
                          true // Помечаем, что онбординг пройден
                        );

                        // 2. Закрываем экран и возвращаем результат 'true'
                        if (mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Сохранить и начать', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
