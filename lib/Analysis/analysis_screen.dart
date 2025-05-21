import 'package:flutter/material.dart';
import 'weekly_progress_chart.dart';
import 'category_pie_chart.dart';
import 'consistency_summary_card.dart';
import 'achievement_summary_card.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.blue[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              WeeklyProgressChart(
                values: [3.0, 6.0, 4.0, 5.0, 2.0, 7.0, 1.0],
                labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
              ),
              const SizedBox(height: 16),
              const CategoryPieChart(),
              const SizedBox(height: 16),
              const ConsistencySummaryCard(),
              const SizedBox(height: 16),
              const AchievementSummaryCard(),
            ],
          ),

        ),
      ),
    );
  }
}
