import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../addition/top_header.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  String? selectedHabitId;
  Map<String, dynamic> selectedHabitData = {};
  List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  List<int> logCounts = List.filled(7, 0);
  int daysLogged = 0;
  int daysPassed = 0;
  List<Map<String, dynamic>> allHabits = [];

  @override
  void initState() {
    super.initState();
    fetchHabits();
  }

  Future<void> fetchHabits() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('habits')
        .get();

    setState(() {
      allHabits = snap.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
      if (allHabits.isNotEmpty) {
        selectedHabitId = allHabits.first['id'];
        updateSelectedHabitData();
      }
    });
  }

  void updateSelectedHabitData() {
    final habit = allHabits.firstWhere((h) => h['id'] == selectedHabitId);
    setState(() {
      selectedHabitData = habit;
      daysLogged = habit['daysLogged'] ?? 0;
      daysPassed = habit['daysPassed'] ?? 0;
    });
    generateWeeklyLogCounts();
  }

  void generateWeeklyLogCounts() {
    final logs = selectedHabitData['logDates'] ?? [];
    List<int> counts = List.filled(7, 0);
    for (var ts in logs) {
      final dt = (ts as Timestamp).toDate();
      final weekday = dt.weekday % 7; // Monday=1, Sunday=7 → index 0-6
      counts[weekday == 7 ? 6 : weekday - 1] += 1;
    }
    setState(() => logCounts = counts);
  }

  Widget buildWeeklyLogBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= weekDays.length) return const SizedBox.shrink();
                return Column(
                  children: [
                    Text(logCounts[index].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(weekDays[index], style: const TextStyle(fontSize: 10)),
                  ],
                );
              },
              reservedSize: 42,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(toY: logCounts[i].toDouble(), width: 16, color: Colors.blue),
            ],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const TopHeader_analysis(),
              const SizedBox(height: 16),
              const Text("Weekly Log Count", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Montserrat', color: Colors.blueAccent)),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 1.8,
                child: buildWeeklyLogBarChart(),
              ),
              const SizedBox(height: 24),
              DropdownButton<String>(
                isExpanded: true,
                value: selectedHabitId,
                hint: const Text("Select a habit"),
                items: allHabits.map((habit) {
                  return DropdownMenuItem<String>(
                    value: habit['id'],
                    child: Text(habit['type'] ?? 'Habit'),
                  );
                }).toList(),

                onChanged: (id) {
                  setState(() => selectedHabitId = id);
                  updateSelectedHabitData();
                },
              ),
              const SizedBox(height: 16),
              if (selectedHabitId != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Days Passed: $daysPassed", style: const TextStyle(fontSize: 16)),
                    Text("Days Logged: $daysLogged", style: const TextStyle(fontSize: 16)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
