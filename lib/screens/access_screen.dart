import 'package:flutter/material.dart';

class AccessScreen {
  static void showDisclaimer(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("⚠️Важное уведомление"),
        content: const Text(
          "Приложение «МетеоЗащита» предоставляет справочную информацию. "
          "Наши советы не являются врачебным назначением. "
          "При плохом самочувствии обязательно обратитесь к специалисту.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Я ПОНИМАЮ"),
          ),
        ],
      ),
    );
  }
}
