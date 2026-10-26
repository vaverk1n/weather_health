import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class StressChart extends StatelessWidget {
  final List<FlSpot> points;
  final List<int> userLogIndices;

  const StressChart({
    super.key, 
    required this.points, 
    this.userLogIndices = const []
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 10,
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: _bottomTitles,
                reservedSize: 30,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              barWidth: 4,
              isStrokeCapRound: true,
              // УСТАНОВЛЕН фиксированный зеленый цвет линии
              color: Colors.greenAccent, 
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  bool isUserEntry = userLogIndices.contains(spot.x.toInt());
                  return FlDotCirclePainter(
                    radius: isUserEntry ? 6 : 0, 
                    color: Colors.white,
                    strokeWidth: 3,
                    strokeColor: Colors.blueGrey,
                  );
                },
              ),
              // УСТАНОВЛЕНА фиксированная зеленая заливка
              belowBarData: BarAreaData(
                show: true,
                color: Colors.greenAccent.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomTitles(double value, TitleMeta meta) {
    const style = TextStyle(color: Colors.grey, fontSize: 10);
    String text;
    switch (value.toInt()) {
      case 0: text = '06:00'; break;
      case 3: text = '12:00'; break;
      case 6: text = '18:00'; break;
      default: return const SizedBox();
    }
    return SideTitleWidget(axisSide: meta.axisSide, space: 8, child: Text(text, style: style));
  }
}
