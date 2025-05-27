// habit_logger_page.dart (updated to show total time for session)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'minutes_timer_page.dart';
import 'session_timer_page.dart';
import 'gps_running_tracker.dart';
import 'awesome_notifications.dart';
import '/utils/pointing_system.dart';


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
  late double todayProgress;
  late double targetMin;
  late double targetMax;
  late dynamic habitData;
  late String unit;
  bool isComplete = false;
  int? sessionDuration; // for session time display

  @override
  void initState() {
    super.initState();
    todayProgress = (widget.habitData['todayProgress'] ?? 0).toDouble();
    targetMin = (widget.habitData['targetMin'] ?? 0).toDouble();
    targetMax = (widget.habitData['targetMax'] ?? 0).toDouble();
    unit = widget.habitData['unit'] ?? '';
    isComplete = widget.habitData['isComplete'] ?? false;


    _resetProgressIfNewDay().then((_) {
      setState(() {
        todayProgress = (widget.habitData['todayProgress'] ?? 0).toDouble();
        targetMin = (widget.habitData['targetMin'] ?? 0).toDouble();
        targetMax = (widget.habitData['targetMax'] ?? 0).toDouble();
        unit = widget.habitData['unit'] ?? '';
        isComplete = widget.habitData['isComplete'] ?? false;
      });
    });

  }


  Future<void> _resetProgressIfNewDay() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final habitRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('habits')
        .doc(widget.habitId);

    final habitSnap = await habitRef.get();
    final data = habitSnap.data();
    if (data == null) return;

    final Timestamp? lastUpdated = data['lastUpdated'];
    final int daysLogged = data['daysLogged'] ?? 0;
    final int durationDays = data['durationDays'] ?? 30;
    final DateTime createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final DateTime now = DateTime.now();

    final bool isNewDay = lastUpdated == null ||
        lastUpdated.toDate().year != now.year ||
        lastUpdated.toDate().month != now.month ||
        lastUpdated.toDate().day != now.day;

    if (isNewDay && daysLogged < durationDays) {
      final int daysPassed = now.difference(createdAt).inDays + 1;

      await habitRef.update({
        'todayProgress': 0,
        'loggedToday': false,
        'lastUpdated': Timestamp.fromDate(now),
        'daysPassed': daysPassed,
      });

      setState(() {
        todayProgress = 0.0;
        isComplete = false;
      });
    }
  }



  Future<void> _updateProgress(double value) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print('User is null');
      return;
    }

    // Reference this user's habit document
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('habits')
        .doc(widget.habitId);

    final habitSnap = await docRef.get();
    final habitData = habitSnap.data() ?? {};

    // Fetch essential habit data
    int currentLoggedDays = habitData['daysLogged'] ?? 0;
    Timestamp createdAt = habitData['createdAt'] ?? Timestamp.now();
    int durationDays = habitData['durationDays'] ?? 30;
    String category = habitData['category'] ?? 'Custom';

    // 🔢 Compute how many days have passed since creation
    final int daysPassed = habitData['daysPassed'] ?? 1;


    // 🧠 Calculate adjusted thresholds if unit == Minutes
    final double targetMinAdjusted = unit == 'Minutes' ? targetMin * 60 : targetMin.toDouble();
    final double targetMaxAdjusted = unit == 'Minutes' ? targetMax * 60 : targetMax.toDouble();

    // 🧮 Detect transitions: previously incomplete → now completed
    final double previousProgress = (habitData['todayProgress'] ?? 0).toDouble();
    final bool previouslyCompletedMin = previousProgress >= targetMinAdjusted;
    final bool previouslyCompletedMax = previousProgress >= targetMaxAdjusted;
    final bool nowCompletedMin = value >= targetMinAdjusted;
    final bool nowCompletedMax = value >= targetMaxAdjusted;
// Only mark as loggedToday if max target is reached and not already logged
    if (nowCompletedMax && !(habitData['loggedToday'] ?? false)) {
      await docRef.update({
        'loggedToday': true,
        'lastLogDate': Timestamp.now(),
      });
    }

    // 📈 Increment daysLogged ONCE per newly completed min target
    int updatedDaysLogged = currentLoggedDays;
    if (!previouslyCompletedMin && nowCompletedMin) {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);

      final List existingDates = habitData['logDates'] ?? [];
      final alreadyLoggedToday = existingDates.any((ts) {
        final d = (ts as Timestamp).toDate();
        return d.year == todayMidnight.year &&
            d.month == todayMidnight.month &&
            d.day == todayMidnight.day;
      });

      if (!alreadyLoggedToday) {
        await docRef.update({
          'logDates': FieldValue.arrayUnion([Timestamp.fromDate(now)]),
        });
      }

      updatedDaysLogged += 1;
      await docRef.update({
        'loggedToday': true,
        'lastLogDate': Timestamp.now(),

      });
    }

    // ✅ Pre-calculate these and store for dashboard
    final double consistencyRatio = daysPassed > 0 ? updatedDaysLogged / daysPassed : 0;
    final double overallProgressRatio = durationDays > 0 ? updatedDaysLogged / durationDays : 0;

    // 🔐 Update Firestore
    await docRef.update({
      'todayProgress': value,
      'daysPassed': daysPassed,
      'daysLogged': updatedDaysLogged,
      'consistencyRatio': consistencyRatio,
      'overallProgressRatio': overallProgressRatio,
    });

    // 🎯 Update UI locally
    setState(() {
      todayProgress = value;
      isComplete = nowCompletedMin;
    });

    // 🏅 Award points
    double pointsEarned = 0;

    if (!previouslyCompletedMin && nowCompletedMin) {
      pointsEarned = PointingSystem.calculateEarnedPoints(
        targetMax: targetMax.toDouble(),
        durationDays: durationDays,
        todayProgress: value.toDouble(),
        unit: unit,
      );

      // Check and apply powerup multiplier
      // final today = DateTime.now();
      // final powerupId = "${today.year}-${today.month}-${today.day}";
      //
      // final powerupRef = FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(user.uid)
      //     .collection('powerups')
      //     .doc(powerupId);
      //
      // final powerupDoc = await powerupRef.get();
      // if (powerupDoc.exists) {
      //   final powerupData = powerupDoc.data()!;
      //   if (powerupData['category'] == 'multiplier' &&
      //       !(powerupData['claimed'] ?? false)) {
      //     final multiplier = (powerupData['value'] ?? 1.0) as num;
      //     pointsEarned *= multiplier;
      //     await powerupRef.update({'claimed': true});
      //   }
      // }

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      final categoryPointsField = PointingSystem.getCategoryPointsField(category);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        categoryPointsField: FieldValue.increment(pointsEarned.toInt()),
      }, SetOptions(merge: true));

      await NotificationService.showInstantNotification(
        'Habit Progress 🎯',
        'You earned +${pointsEarned.toInt()} points in $category!\n'
            '${nowCompletedMax ? '✅ Max target hit!' : '👍 Min target reached!'}',
      );
    }

  }





  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }



  @override
  Widget build(BuildContext context) {
    final type = widget.habitData['type'] ?? 'Habit';

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
            Text('$type ($unit)', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (todayProgress / targetMax).clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.grey[300],
              color: isComplete ? Colors.green : Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(height: 12),
            Text(
              unit == 'Minutes'
                  ? _formatDuration(todayProgress.toInt()) + ' / ' + _formatDuration(targetMax.toInt())
                  : '$todayProgress / $targetMax $unit',
              style: const TextStyle(fontSize: 18),
            ),

            if (sessionDuration != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Last session time: ${_formatDuration(sessionDuration!)}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),

            const SizedBox(height: 24),

            if (unit == 'Minutes')
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MinutesTimerPage(
                        habitId: widget.habitId,
                        targetMin: targetMin,
                        targetMax: targetMax,

                      ),
                    ),
                  );
                  if (result != null) {
                    final seconds = result;
                    final minutes = (seconds / 60).toDouble();
                    _updateProgress(todayProgress + minutes); // ✅ send raw seconds

                  }


                },
                child: const Text('Track Minutes'),
              )
            else if (unit == 'Sessions')
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionTimerPage(
                        habitId: widget.habitId,
                        targetMin: targetMin,
                        targetMax: targetMax,

                      ),
                    ),
                  );
                  if (result != null && result is Map) {
                    if (result['sessionCount'] != null) _updateProgress(todayProgress + result['sessionCount']);
                    if (result['duration'] != null) {
                      setState(() => sessionDuration = result['duration']);
                    }
                  }
                },
                child: const Text('Start Session'),
              )
            else if (unit == 'Distance (km)')
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GPSRunningTrackerPage(
                          habitId: widget.habitId,
                          target: targetMax,
                          unit: unit,
                        ),
                      ),
                    );
                    if (result != null) {
                      final seconds = result;
                      _updateProgress(seconds); // ✅ send raw seconds
                    }

                  },
                  child: const Text('Track Now (GPS)'),
                ),

            const SizedBox(height: 24),
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


