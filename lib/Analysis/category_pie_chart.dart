import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CategoryPieChart extends StatelessWidget {
  final String userId;
  const CategoryPieChart({super.key, required this.userId});

  Future<Map<String, double>> _loadCategoryPoints() async {
    final user = FirebaseAuth.instance.currentUser;


    if (user == null) return {};

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data()?['categoryPoints'] as Map<String, dynamic>? ?? {};
    return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.blue, Colors.cyan, Colors.teal, Colors.indigo, Colors.green, Colors.purple];

    return FutureBuilder<Map<String, double>>(
      future: _loadCategoryPoints(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final categoryData = snapshot.data ?? {};
        final entries = categoryData.entries.toList();
        if (entries.isEmpty) {
          return const Text('No category points available.');
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal[50],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sections: List.generate(entries.length, (i) {
                      final e = entries[i];
                      return PieChartSectionData(
                        color: colors[i % colors.length],
                        value: e.value,
                        title: '',
                        radius: 50,
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: List.generate(entries.length, (i) {
                  final e = entries[i];
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 12, height: 12, color: colors[i % colors.length]),
                      const SizedBox(width: 6),
                      Text(e.key),
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
