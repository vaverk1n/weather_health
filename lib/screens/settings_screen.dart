import 'package:flutter/material.dart';
import '../core/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Настройки (в идеале должны загружаться из БД)
  bool _notifyMagnetic = true;
  bool _notifyPressure = true;

  // Метод для имитации получения пуш-уведомления (Тестирование п. 3.1)
  void _testNotification() {
    // Получаем список советов вместо одной строки
    final advices = NotificationService.getSmartAdvices(
      pressure: _notifyPressure ? 730 : 760, 
      kpIndex: _notifyMagnetic ? 6 : 2, 
      tempDelta: 0,
      userGroup: 'hypertonic', // Заглушка для теста
    );

    // Берем текст из первого совета в списке
    String message = advices.isNotEmpty 
        ? advices.first.text 
        : "Уведомления для выбранных категорий отключены.";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Тестовое уведомление: $message'),
        backgroundColor: Colors.indigo,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки уведомлений')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Типы уведомлений:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text('Магнитные бури'),
            value: _notifyMagnetic,
            onChanged: (val) => setState(() => _notifyMagnetic = val),
            secondary: const Icon(Icons.wb_sunny, color: Colors.orange),
          ),
          SwitchListTile(
            title: const Text('Давление'),
            value: _notifyPressure,
            onChanged: (val) => setState(() => _notifyPressure = val),
            secondary: const Icon(Icons.speed, color: Colors.blue),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: _testNotification,
              icon: const Icon(Icons.notification_important),
              label: const Text('Проверить уведомления'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                foregroundColor: Colors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              '* В данной версии настройки сохраняются в рамках текущей сессии.',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          )
        ],
      ),
    );
  }
}
