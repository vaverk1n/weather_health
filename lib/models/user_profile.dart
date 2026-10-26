enum UserGroup { hypotonic, hypertonic, joints, general }

class UserProfile {
  final UserGroup group;
  final List<String> chronicSymptoms;

  UserProfile({
    required this.group,
    this.chronicSymptoms = const [],
  });

  // Логика динамического контента (п. 4.3)
  String getRecommendation() {
    switch (group) {
      case UserGroup.hypertonic:
        return "Рекомендуется ограничить соль и контролировать давление.";
      case UserGroup.hypotonic:
        return "Рекомендуется тонизирующий чай и легкая физическая активность.";
      case UserGroup.joints:
        return "Держите суставы в тепле и избегайте переохлаждения.";
      case UserGroup.general:
        return "Следите за режимом сна и водным балансом.";
    }
  }
}
