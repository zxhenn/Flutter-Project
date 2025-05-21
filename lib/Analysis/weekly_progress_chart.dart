import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class WeeklyProgressChart extends StatelessWidget {
  final List<double> values;
  final List<String>? labels;

  const WeeklyProgressChart({
    super.key,
    required this.values,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final barLabels = labels ??
        List.generate(values.length, (i) => 'D${i + 1}'); // fallback dummy labels

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: values.isNotEmpty ? values.reduce(max) + 5 : 10,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                int index = value.toInt();
                if (index >= 0 && index < barLabels.length) {
                  return Text(barLabels[index], style: const TextStyle(fontSize: 12));
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
        ),
        barGroups: values.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value;
          return BarChartGroupData(x: index, barRods: [
            BarChartRodData(
              toY: value,
              color: index.isEven ? Colors.cyan : Colors.blue,
              width: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ]);
        }).toList(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
      ),
    );
  }
}
