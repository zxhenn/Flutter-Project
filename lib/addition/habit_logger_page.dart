import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HabitLoggerPage extends StatefulWidget {
  final String habitId;
  final Map<String, dynamic> habitData;

  const HabitLoggerPage({
    super.key,
    required this.habitId,
    required this.habitData,
  });

  @override
  State<HabitLoggerPage> createState() => _HabitLoggerPageState();
}

class _HabitLoggerPageState extends State<HabitLoggerPage> {
  late int todayProgress;
  late int todayExcess;
  late int target;
  late int daysCompleted;
  late int durationDays;
  late DateTime lastCompleted;
  late String frequency;
  bool isComplete = false;

  @override
  void initState() {
    super.initState();
    todayProgress = widget.habitData['todayProgress'] ?? 0;
    todayExcess = widget.habitData['todayExcess'] ?? 0;
    target = widget.habitData['targetMin'] ?? 1;
    daysCompleted = widget.habitData['daysCompleted'] ?? 0;
    durationDays = widget.habitData['durationDays'] ?? 1;
    frequency = widget.habitData['frequency'] ?? 'daily';
    lastCompleted = (widget.habitData['lastCompleted'] as Timestamp?)?.toDate() ?? DateTime(2000);
    isComplete = _checkIsCompleteForPeriod();
  }

  bool _checkIsCompleteForPeriod() {
    final now = DateTime.now();
    final diff = now.difference(lastCompleted);
    if (frequency == 'daily') {
      return diff.inHours < 24;
    } else if (frequency == 'weekly') {
      return diff.inHours < 168;
    }
    return false;
  }

  Future<void> _incrementProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ You already completed for this period.')),
      );
      return;
    }

    setState(() {
      todayProgress += 1;
      if (todayProgress >= target) {
        isComplete = true;
        daysCompleted += 1;
        lastCompleted = DateTime.now();
      }
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('habits')
        .doc(widget.habitId)
        .update({
      'todayProgress': todayProgress,
      'todayExcess': todayExcess,
      'daysCompleted': daysCompleted,
      'lastCompleted': Timestamp.fromDate(lastCompleted),
    });
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.habitData['type'] ?? 'Habit';
    final unit = widget.habitData['unit'] ?? 'units';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Progress'),
        backgroundColor: Colors.blue[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$type ($unit)',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (todayProgress / target).clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.grey[300],
              color: isComplete ? Colors.green : Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(height: 12),
            Text(
              '$todayProgress / $target completed',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '$daysCompleted / $durationDays done',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text('Frequency: ${frequency[0].toUpperCase()}${frequency.substring(1)}'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _incrementProgress,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                backgroundColor: Colors.blue[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('+1', style: TextStyle(fontSize: 24, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            if (isComplete)
              const Text(
                '✅ You reached your target for this period!',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
