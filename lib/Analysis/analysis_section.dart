import 'package:flutter/material.dart';
import 'weekly_progress_chart.dart';
import '/Analysis/category_pie_chart.dart';
import '/Analysis/consistency_summary_card.dart';
import '/Analysis/achievement_summary_card.dart';

class AnalysisSection extends StatefulWidget {
  const AnalysisSection({super.key});

  @override
  State<AnalysisSection> createState() => _AnalysisSectionState();
}

class _AnalysisSectionState extends State<AnalysisSection> {
  String _range = 'Last 7 Days';

  final Map<String, List<double>> mockProgress = {
    'Today': [2],
    'Last 7 Days': [2, 4, 6, 3, 5, 7, 2],
    'This Month': List.generate(30, (i) => (i % 7 + 1).toDouble()),
  };

  final Map<String, List<String>> mockLabels = {
    'Today': ['Now'],
    'Last 7 Days': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    'This Month': List.generate(30, (i) => '${i + 1}'),
  };

  @override
  Widget build(BuildContext context) {
    final values = mockProgress[_range]!;
    final labels = mockLabels[_range]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analysis',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Track your progress over time and analyze your performance based on selected ranges.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 20),

        // Progress Over Time
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal[50],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Progress Over Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _range,
                    items: ['Today', 'Last 7 Days', 'This Month']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (value) => setState(() => _range = value!),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              WeeklyProgressChart(values: values, labels: labels),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.bar_chart),
                label: const Text('Generate Report'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Category Breakdown
        const CategoryPieChart(),
        const SizedBox(height: 20),

        // Consistency
        const ConsistencySummaryCard(),
        const SizedBox(height: 20),

        // Achievements
        const AchievementSummaryCard(),
      ],
    );
  }
}
