import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class WeeklyLogBarChart extends StatelessWidget {
  final Map<String, int> logCounts;

  const WeeklyLogBarChart({super.key, required this.logCounts});

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Weekly Log Count',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ),
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final day = days[index];
              final count = logCounts[day] ?? 0;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('$count', style: const TextStyle(fontSize: 13)),
                    Container(
                      height: (count * 20).toDouble().clamp(0, 160), // max height limit
                      width: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    Text(day, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

