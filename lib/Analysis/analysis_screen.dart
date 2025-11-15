import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // For potential date formatting if needed
// import '../addition/top_header.dart'; // Assuming this is your custom top header

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  String? selectedHabitId;
  Map<String, dynamic>? selectedHabitData; // Can be null if no habit selected
  List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  List<double> logCounts = List.filled(7, 0.0); // Use double for FlChart
  int daysLogged = 0;
  int daysPassed = 0;
  List<Map<String, dynamic>> allHabits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchHabits();
  }

  Future<void> fetchHabits() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('habits')
      // .orderBy('createdAt', descending: true) // Optional: order habits
          .get();

      if (!mounted) return;

      final fetchedHabits = snap.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      setState(() {
        allHabits = fetchedHabits;
        if (allHabits.isNotEmpty) {
          selectedHabitId = allHabits.first['id']; // Default to first habit
          updateSelectedHabitData();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error fetching habits: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching habits: ${e.toString()}")),
      );
    }
  }

  void updateSelectedHabitData() {
    if (selectedHabitId == null || allHabits.isEmpty) {
      setState(() {
        selectedHabitData = null;
        logCounts = List.filled(7, 0.0);
        daysLogged = 0;
        daysPassed = 0;
      });
      return;
    }

    final habit = allHabits.firstWhere((h) => h['id'] == selectedHabitId, orElse: () => {});
    if (habit.isEmpty) {
      setState(() {
        selectedHabitData = null;
        logCounts = List.filled(7, 0.0);
        daysLogged = 0;
        daysPassed = 0;
      });
      return;
    }

    setState(() {
      selectedHabitData = habit;
      daysLogged = (habit['daysLogged'] ?? 0) as int;
      // Ensure 'createdAt' exists and is a Timestamp before calculating daysPassed
      final createdAtTimestamp = habit['createdAt'] as Timestamp?;
      if (createdAtTimestamp != null) {
        daysPassed = DateTime.now().difference(createdAtTimestamp.toDate()).inDays + 1;
        // If you store 'daysPassed' in Firestore and it's reliable, use that instead:
        // daysPassed = (habit['daysPassed'] ?? 0) as int;
      } else {
        daysPassed = 0; // Or handle as appropriate if createdAt is missing
      }
      generateWeeklyLogCounts();
    });
  }

  void generateWeeklyLogCounts() {
    if (selectedHabitData == null) {
      setState(() => logCounts = List.filled(7, 0.0));
      return;
    }
    final logs = selectedHabitData!['logDates'] as List<dynamic>? ?? [];
    List<double> counts = List.filled(7, 0.0);
    for (var ts in logs) {
      if (ts is Timestamp) {
        final dt = ts.toDate();
        // DateTime.weekday: Monday is 1 and Sunday is 7
        int weekdayIndex = dt.weekday - 1; // Monday = 0, Sunday = 6
        counts[weekdayIndex] += 1.0;
      }
    }
    if (mounted) setState(() => logCounts = counts);
  }

  Widget _buildSectionCard({required String title, required Widget child, IconData? titleIcon, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (titleIcon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(titleIcon, color: Colors.blue[700], size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildWeeklyLogBarChart(ThemeData theme) {
    double maxY = logCounts.isEmpty ? 5 : (logCounts.reduce((a, b) => a > b ? a : b) + 2);
    if (maxY < 5) maxY = 5;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blue[700]!.withOpacity(0.9),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String weekDay = weekDays[group.x.toInt()];
              return BarTooltipItem(
                '$weekDay\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                children: <TextSpan>[
                  TextSpan(
                    text: (rod.toY - rod.fromY).toInt().toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: ' logs', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= weekDays.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    weekDays[index],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY ~/ 5 > 0 ? (maxY ~/ 5).toDouble() : 1,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == meta.max) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY ~/ 5 > 0 ? (maxY ~/ 5).toDouble() : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
          },
        ),
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: logCounts[i],
                width: 20,
                color: Colors.blue[700],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
            ],
            showingTooltipIndicators: [],
          );
        }),
      ),
    );
  }

  Widget _buildStatsDisplay() {
    double consistency = (daysPassed > 0 && daysLogged > 0) ? (daysLogged / daysPassed * 100) : 0.0;
    Color consistencyColor = Colors.grey;
    if (consistency >= 75) consistencyColor = Colors.green;
    else if (consistency >= 50) consistencyColor = Colors.orange;
    else if (consistency > 0) consistencyColor = Colors.red;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.event_available, color: Colors.blue[700], size: 28),
                    const SizedBox(height: 8),
                    Text(
                      daysLogged.toString(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Days Logged",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.timelapse, color: Colors.green[700], size: 28),
                    const SizedBox(height: 8),
                    Text(
                      daysPassed.toString(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Days Passed",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (selectedHabitData != null) ...[
          const SizedBox(height: 24),
          Text(
            "Consistency",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: CircularProgressIndicator(
                  value: consistency / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(consistencyColor),
                ),
              ),
              Column(
                children: [
                  Text(
                    "${consistency.toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: consistencyColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedHabitData!['type'] ?? 'Habit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.grey[50],
          elevation: 0,
          title: Text(
            "Analysis",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (allHabits.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.grey[50],
          elevation: 0,
          title: Text(
            "Analysis",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "No Habits Found",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Start by adding some habits to analyze!",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        title: Text(
          "Habit Analysis",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Habit Selector
              _buildSectionCard(
                title: "Select Habit",
                titleIcon: Icons.analytics_outlined,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedHabitId,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  hint: const Text("Select a habit to analyze"),
                  items: allHabits.map((habit) {
                    return DropdownMenuItem<String>(
                      value: habit['id'] as String,
                      child: Text(
                        (habit['name'] ?? habit['type'] ?? 'Unnamed Habit') as String,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      setState(() => selectedHabitId = id);
                      updateSelectedHabitData();
                    }
                  },
                ),
              ),

              if (selectedHabitId != null && selectedHabitData != null) ...[
                _buildSectionCard(
                  title: "Weekly Log Count",
                  titleIcon: Icons.bar_chart,
                  child: AspectRatio(
                    aspectRatio: 1.6,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0, right: 8.0),
                      child: _buildWeeklyLogBarChart(theme),
                    ),
                  ),
                ),
                _buildSectionCard(
                  title: "Habit Statistics",
                  titleIcon: Icons.trending_up,
                  child: _buildStatsDisplay(),
                ),
              ] else if (selectedHabitId != null && selectedHabitData == null) ...[
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "Selected habit data not found.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}