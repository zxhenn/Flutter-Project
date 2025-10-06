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

  Widget _buildSectionCard({required String title, required Widget child, EdgeInsets? padding}) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyLogBarChart(ThemeData theme) {
    double maxY = logCounts.isEmpty ? 5 : (logCounts.reduce((a, b) => a > b ? a : b) + 2);
    if (maxY < 5) maxY = 5; // Ensure a minimum height for the y-axis

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String weekDay = weekDays[group.x.toInt()];
              return BarTooltipItem(
                '$weekDay\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                children: <TextSpan>[
                  TextSpan(
                    text: (rod.toY - rod.fromY).toInt().toString(),
                    style: TextStyle(
                      color: theme.colorScheme.surface, // Or Colors.yellow
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const TextSpan(text: ' logs', style: TextStyle(color: Colors.white, fontSize: 12)),
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
                  child: Text(weekDays[index], style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: maxY ~/ 5 > 0 ? (maxY ~/ 5).toDouble() : 1, // Dynamic interval
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == meta.max) return const SizedBox.shrink(); // Avoid clutter at edges
                return Text(value.toInt().toString(), style: TextStyle(fontSize: 10, color: Colors.grey[600]));
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
            return FlLine(color: Colors.grey.shade300, strokeWidth: 0.5);
          },
        ),
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                  toY: logCounts[i],
                  width: 18,
                  color: theme.colorScheme.primary.withOpacity(0.8),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.0)
              ),
            ],
            showingTooltipIndicators: [],
          );
        }),
      ),
    );
  }

  Widget _buildStatsDisplay(ThemeData theme) {
    double consistency = (daysPassed > 0 && daysLogged > 0) ? (daysLogged / daysPassed * 100) : 0.0;
    Color consistencyColor = Colors.grey;
    if (consistency >= 75) consistencyColor = Colors.green;
    else if (consistency >= 50) consistencyColor = Colors.orange;
    else if (consistency > 0) consistencyColor = Colors.red;


    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(theme, "Days Logged", daysLogged.toString(), Icons.event_available_outlined),
            _buildStatItem(theme, "Days Passed", daysPassed.toString(), Icons.timelapse_outlined),
          ],
        ),
        const SizedBox(height: 20),
        if(selectedHabitData != null) ...[
          Text("Consistency", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 100, width: 100,
                child: CircularProgressIndicator(
                  value: consistency / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(consistencyColor),
                ),
              ),
              Text("${consistency.toStringAsFixed(0)}%", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: consistencyColor)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selectedHabitData!['type'] ?? 'Habit Analysis',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ]
      ],
    );
  }

  Widget _buildStatItem(ThemeData theme, String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: theme.colorScheme.secondary),
        const SizedBox(height: 6),
        Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Analysis"), elevation: 0, backgroundColor: Colors.transparent),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (allHabits.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Analysis"), elevation: 0, backgroundColor: Colors.transparent),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "No habits found to analyze.\nStart by adding some habits!",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100], // Light background for the whole screen
      appBar: AppBar(
        title: const Text("Habit Analysis", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
        titleTextStyle: TextStyle(color: theme.textTheme.titleLarge?.color, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SafeArea(
        child: SingleChildScrollView( // Make the whole screen scrollable
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Potentially your TopHeader here if it's different from AppBar
              // const TopHeader(),
              // const SizedBox(height: 16),

              _buildSectionCard(
                title: "Habit Selector",
                padding: const EdgeInsets.symmetric(horizontal:16, vertical: 12),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedHabitId,
                  decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
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
                  child: AspectRatio(
                    aspectRatio: 1.6, // Adjusted for potentially taller chart due to y-axis labels
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0, right: 8.0), // Padding for chart
                      child: _buildWeeklyLogBarChart(theme),
                    ),
                  ),
                ),
                _buildSectionCard(
                  title: "Habit Statistics",
                  child: _buildStatsDisplay(theme),
                ),
              ] else if (selectedHabitId != null && selectedHabitData == null) ...[
                // This case might occur if a selected habit was deleted or data is inconsistent
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: Text("Selected habit data not found.")),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}