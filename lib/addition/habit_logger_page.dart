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
  bool isComplete = false;

  @override
  void initState() {
    super.initState();
    todayProgress = widget.habitData['todayProgress'] ?? 0;
    todayExcess = widget.habitData['todayExcess'] ?? 0;
    target = widget.habitData['targetPerDay'] ?? 1;
    isComplete = todayProgress >= target;
  }

  Future<void> _incrementProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (todayProgress < target) {
        todayProgress += 1;
      } else {
        todayExcess += 1;
      }
      isComplete = todayProgress >= target;
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('habits')
        .doc(widget.habitId)
        .update({
      'todayProgress': todayProgress,
      'todayExcess': todayExcess,
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
            if (todayExcess > 0)
              Text(
                '+$todayExcess excess',
                style: const TextStyle(fontSize: 16, color: Colors.orange),
              ),
            const SizedBox(height: 32),
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
                '✅ You reached your target for today!',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
