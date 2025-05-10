// Enhanced Habit Logger Page with Strict Consistency Point System + Final Points Logic
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vibration/vibration.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'awesome_notifications.dart';

class HabitLoggerPage extends StatefulWidget {
  final String habitId;
  final Map<String, dynamic> habitData;

  const HabitLoggerPage({super.key, required this.habitId, required this.habitData});

  @override
  State<HabitLoggerPage> createState() => _HabitLoggerPageState();
}

class _HabitLoggerPageState extends State<HabitLoggerPage> {
  bool isLoading = false;
  int currentProgress = 0;
  int todayExcess = 0;
  bool isDoneForToday = false;
  Timer? timer;
  bool isTimerRunning = false;
  String timerMode = 'auto';
  Duration elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    currentProgress = widget.habitData['todayProgress'] ?? 0;
    todayExcess = widget.habitData['todayExcess'] ?? 0;
    timerMode = widget.habitData['timerMode'] ?? 'auto';
    int targetMin = widget.habitData['targetMin'] ?? 0;
    isDoneForToday = currentProgress >= targetMin;
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> logProgress(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('habits')
        .doc(widget.habitId);

    final docSnap = await docRef.get();
    final data = docSnap.data();
    if (data == null) return;

    int targetMax = data['targetMax'] ?? 1;
    int targetMin = data['targetMin'] ?? 1;
    int updated = currentProgress + amount;
    int excess = 0;

    if (updated > targetMax) {
      excess = updated - targetMax;
      if (timerMode == 'auto') {
        updated = targetMax;
      }
    }

    int daysCompleted = data['daysCompleted'] ?? 0;
    final lastLogged = data['lastLogged'] ?? '';
    final String todayKey = DateTime.now().toIso8601String().split('T').first;

    final Timestamp? createdAt = data['createdAt'];
    final DateTime startDate = createdAt?.toDate() ?? DateTime.now();
    final int daysSinceStart = DateTime.now().difference(startDate).inDays + 1;
    final int durationDays = data['durationDays'] ?? 30;
    bool isHabitDone = daysCompleted >= durationDays;

    final Map<String, dynamic> updates = {
      'todayProgress': updated,
      'todayExcess': todayExcess + excess,
    };

    bool isFirstTimeToday = lastLogged != todayKey;
    bool metMinimumToday = updated >= targetMin;

    if (isFirstTimeToday && metMinimumToday) {
      daysCompleted += 1;
      updates['daysCompleted'] = daysCompleted;
      updates['lastLogged'] = todayKey;
    }

    final double consistency = daysSinceStart > 0
        ? (daysCompleted / daysSinceStart * 100).clamp(0, 100)
        : 0;
    updates['consistencyPercent'] = consistency;

    // Final points calculation if habit completed and not yet stored
    if (daysCompleted == durationDays && !(data.containsKey('pointsClaimed'))) {
      final int finalPoints = ((daysCompleted / daysSinceStart) * 10 * durationDays).floor();

      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userSnap = await userDocRef.get();
      final Map<String, dynamic> userData = userSnap.data() ?? {};
      final dynamic raw = userData['categoryPoints'];
      final Map<String, dynamic> categoryPoints =
      raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : {};

      final String category = data['category'] ?? 'General';

      categoryPoints[category] = (categoryPoints[category] ?? 0) + finalPoints;

      await userDocRef.set({
        'categoryPoints': categoryPoints
      }, SetOptions(merge: true));

      await docRef.update({'pointsClaimed': true}); // Prevent future re-adding
    }

    await docRef.update(updates);

    setState(() {
      currentProgress = updated;
      todayExcess += excess;
      isDoneForToday = currentProgress >= targetMin;
    });

    if (currentProgress >= targetMin && isFirstTimeToday) {
      _showPrompt("✅ Minimum goal reached today!");
      NotificationService.showInstantNotification("✅ Minimum Reached!", "You hit your goal today.");
      if (await Vibration.hasVibrator() ?? false) Vibration.vibrate();
    } else if (updated == targetMax && timerMode == 'auto') {
      _showPrompt("⏱ Maximum reached!");
      NotificationService.showInstantNotification("⏱ Max Time Hit", "Great job hitting your limit.");
      if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 1000);
      stopTimer();
    } else if (updated > targetMax && timerMode == 'manual') {
      _showPrompt("🔥 Beyond maximum! Awesome work!");
      NotificationService.showInstantNotification("🔥 Beyond Max!", "You exceeded your goal.");
    }
  }

  void startTimer() {
    if (isTimerRunning) return;
    setState(() {
      isTimerRunning = true;
      elapsed = Duration.zero;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        elapsed += const Duration(seconds: 1);
      });
      if (elapsed.inSeconds % 60 == 0) {
        logProgress(1);
      }
    });
  }

  void stopTimer() {
    timer?.cancel();
    setState(() => isTimerRunning = false);
  }

  void _showPrompt(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blueAccent),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Widget buildTimerControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: isTimerRunning
              ? [
            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Stop Timer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(220, 48),
              ),
              onPressed: stopTimer,
            )
          ]
              : [
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Timer'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(150, 48)),
              onPressed: startTimer,
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Stop Timer'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(150, 48)),
              onPressed: stopTimer,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Elapsed Time: ${_formatDuration(elapsed)}'),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Timer Mode: '),
            DropdownButton<String>(
              value: timerMode,
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('Auto Stop')),
                DropdownMenuItem(value: 'manual', child: Text('Manual Stop')),
              ],
              onChanged: (value) async {
                if (value == null) return;
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                setState(() => timerMode = value);
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('habits')
                    .doc(widget.habitId)
                    .update({'timerMode': value});
              },
            )
          ],
        ),
      ],
    );
  }

  Widget buildQuickLogButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Log:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            ElevatedButton(onPressed: () => logProgress(1), child: const Text('+1')),
            ElevatedButton(onPressed: () => logProgress(5), child: const Text('+5')),
            ElevatedButton(onPressed: () => logProgress(10), child: const Text('+10')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
              onPressed: () => showDialog(
                context: context,
                builder: (context) {
                  final controller = TextEditingController();
                  return AlertDialog(
                    title: const Text('Custom Input'),
                    content: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Enter value'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final amount = int.tryParse(controller.text);
                          if (amount != null) {
                            Navigator.pop(context);
                            logProgress(amount);
                          }
                        },
                        child: const Text('Log'),
                      ),
                    ],
                  );
                },
              ),
              child: const Text('Custom'),
            )
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.habitData['type'] ?? 'Habit';
    final unit = widget.habitData['unit'] ?? '';
    final frequency = widget.habitData['frequency'] ?? '';
    final target = widget.habitData['targetMax'] ?? 1;

    return Scaffold(
      appBar: AppBar(title: Text('$type ($unit)')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Frequency: $frequency', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Text('Progress Today: $currentProgress / $target', style: const TextStyle(fontSize: 16)),
            if (isDoneForToday)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '🎉 You\'re done for today. Great job!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
            if (todayExcess > 0)
              Text('Excess: +$todayExcess', style: const TextStyle(color: Colors.orange)),
            const SizedBox(height: 24),
            if (unit == 'Minutes')
              buildTimerControls()
            else if (unit == 'Reps' || unit == 'Sessions')
              buildQuickLogButtons()
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Advanced tracker coming soon (GPS/Timer)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
