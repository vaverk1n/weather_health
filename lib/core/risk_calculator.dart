import 'package:flutter/material.dart';

enum RiskLevel { low, medium, high }

class RiskCalculator {
  static RiskLevel calculate(double pressure, int kp, double deltaT) {

    bool pressureAnomaly = pressure < 738 || pressure > 758;
    bool kpAnomaly = kp >= 4;
    bool tempAnomaly = deltaT.abs() >= 15;
    int totalFactors = (pressureAnomaly ? 1 : 0) + 
                       (kpAnomaly ? 1 : 0) + 
                       (tempAnomaly ? 1 : 0);

    
    // Красный (Опасно): сочетание НЕСКОЛЬКИХ факторов (2 или 3)
    if (totalFactors >= 2) {
      return RiskLevel.high;
    }

    // Оранжевый (Внимание): отклонение только ОДНОГО любого фактора
    if (totalFactors == 1) {
      return RiskLevel.medium;
    }

    // Зеленый (Норма): все факторы в пределах допустимых значений (0 факторов)
    return RiskLevel.low;
  }

  static Color getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.high: return Colors.red;
      case RiskLevel.medium: return Colors.orange;
      case RiskLevel.low: return Colors.green;
    }
  }
}
