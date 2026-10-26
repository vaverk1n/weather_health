class WeatherAdvice {
  final String category;
  final String text;

  WeatherAdvice({required this.category, required this.text});
}

class NotificationService {
  static List<WeatherAdvice> getSmartAdvices({
    required double pressure,
    required int kpIndex,
    required double tempDelta,
    required String userGroup,
  }) {
    // Синхронизация с RiskCalculator: определяем выход за рамки нормы
    bool isPressureBad = pressure < 752 || pressure > 765;
    bool isKpBad = kpIndex > 4;
    bool isTempBad = tempDelta.abs() >= 7;

    // Считаем количество активных аномалий
    int anomaliesCount = (isPressureBad ? 1 : 0) + (isKpBad ? 1 : 0) + (isTempBad ? 1 : 0);

    // Выбор набора советов в зависимости от группы пользователя
    switch (userGroup) {
      case 'hypertonic':
        return _getHypertonicAdvices(anomaliesCount, isPressureBad, isKpBad, isTempBad);
      case 'hypotonic':
        return _getHypotonicAdvices(anomaliesCount, isPressureBad, isKpBad, isTempBad);
      case 'joints':
        return _getJointsAdvices(anomaliesCount, isPressureBad, isKpBad, isTempBad);
      default:
        return [WeatherAdvice(category: "Инфо", text: "Настройте профиль для получения точных рекомендаций.")];
    }
  }

  // --- РЕКОМЕНДАЦИИ ДЛЯ ГИПЕРТОНИКОВ ---
  static List<WeatherAdvice> _getHypertonicAdvices(int count, bool p, bool kp, bool t) {
    String activity = count == 0 ? "Нормальные кардио-нагрузки." : "Ограничьте кардио, замените его на мягкую растяжку.";
    String sleep = (p || kp) ? "Риск нарушения сна. Рекомендуется сон не менее 8 часов, исключите гаджеты за час до сна." : "Стандартный режим сна (7-8 часов).";
    String home = t ? "Контролируйте влажность (40-60%) и температуру в спальне." : "Регулярное проветривание помещения.";

    if (count >= 2) {
      activity = "Максимальный физический покой. Избегайте резких движений и наклонов.";
      sleep = "Обязательный отдых. Используйте высокую подушку для разгрузки сосудов головы.";
      home = "Обеспечьте тишину, затемнение комнаты и приток прохладного воздуха.";
    }

    return [
      WeatherAdvice(category: "Физическая активность", text: activity),
      WeatherAdvice(category: "Режим сна", text: sleep),
      WeatherAdvice(category: "Бытовые советы", text: home),
    ];
  }

  // --- РЕКОМЕНДАЦИИ ДЛЯ ГИПОТОНИКОВ ---
  static List<WeatherAdvice> _getHypotonicAdvices(int count, bool p, bool kp, bool t) {
    String activity = count == 0 ? "Активные прогулки для поддержания тонуса сосудов." : "Снизьте интенсивность, замените бег на плавную разминку.";
    String sleep = p ? "Возможна сильная сонливость. Допустим короткий дневной сон (20 мин) для восстановления." : "Сон не менее 8-9 часов.";
    String home = count >= 1 ? "Обеспечьте постоянный доступ кислорода, чаще проветривайте." : "Плановое проветривание комнаты.";

    if (count >= 2) {
      activity = "Избегайте резкого подъема с кровати. Минимум физической активности.";
      sleep = "Полноценный покой. При слабости не ограничивайте время сна.";
      home = "Проветривание в режиме микроциркуляции, не допускайте духоты.";
    }

    return [
      WeatherAdvice(category: "Физическая активность", text: activity),
      WeatherAdvice(category: "Режим сна", text: sleep),
      WeatherAdvice(category: "Бытовые советы", text: home),
    ];
  }

  // --- РЕКОМЕНДАЦИИ ДЛЯ МЕТЕОБОЛЕЙ (СУСТАВЫ) ---
  static List<WeatherAdvice> _getJointsAdvices(int count, bool p, bool kp, bool t) {
    String activity = count == 0 ? "Утренняя гимнастика и легкий фитнес." : "Минимизируйте нагрузку на суставы, только растяжка в тепле.";
    String sleep = t ? "Используйте согревающие одеяла. Поза во сне должна быть максимально расслабленной." : "Качественный сон на ортопедическом матрасе.";
    String home = (t || p) ? "Избегайте сырости и сквозняков, используйте сухое тепло для проблемных зон." : "Проветривание без резкого охлаждения воздуха.";

    if (count >= 2) {
      activity = "Обеспечьте суставам максимальный покой и тепло.";
      sleep = "Длительный отдых в максимально комфортном температурном режиме.";
      home = "Поддерживайте стабильную температуру в помещении, исключите холодный воздух.";
    }

    return [
      WeatherAdvice(category: "Физическая активность", text: activity),
      WeatherAdvice(category: "Режим сна", text: sleep),
      WeatherAdvice(category: "Бытовые советы", text: home),
    ];
  }
}
