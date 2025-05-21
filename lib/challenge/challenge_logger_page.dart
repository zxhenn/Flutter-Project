import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/addition/gps_running_tracker.dart';
import '/addition/minutes_timer_page.dart';
import '/addition/session_timer_page.dart';

class ChallengeLoggerPage extends StatefulWidget {
  final String challengeId;

  const ChallengeLoggerPage({
    super.key,
    required this.challengeId,
  });

  @override
  State<ChallengeLoggerPage> createState() => _ChallengeLoggerPageState();
}

class _ChallengeLoggerPageState extends State<ChallengeLoggerPage> {
  late String currentUserId;
  late dynamic todayProgress;
  late dynamic targetMin;
  late dynamic targetMax;
  late String type;
  late String unit;
  bool isComplete = false;
  bool loading = true;
  Map<String, dynamic>? challengeData;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser!.uid;
    loadChallenge();
  }

  /// Loads the challenge document and sets user-specific progress data
  Future<void> loadChallenge() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('challenges')
        .doc(widget.challengeId)
        .get();


    if (doc.exists) {
      final data = doc.data()!;
      final isSender = currentUserId == data['senderId'];

      setState(() {
        challengeData = data;
        todayProgress = data[isSender ? 'senderProgress' : 'receiverProgress'] ?? 0;
        targetMin = data['targetMin'];
        targetMax = data['targetMax'];
        type = data['habitType'];
        unit = type == 'Running'
            ? 'km'
            : type == 'Meditation' || type == 'Cycling'
            ? 'minutes'
            : 'sessions';
        isComplete = todayProgress >= targetMax;
        loading = false;
      });
    }
  }

  /// Starts the appropriate tracking screen
  void launchTracker() {
    if (type == 'Running') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GPSRunningTrackerPage(
            habitId: widget.challengeId,
            target: targetMax.toDouble(),
            unit: unit,
          ),
        ),
      ).then((_) => loadChallenge());
    } else if (type == 'Meditation' || type == 'Cycling') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MinutesTimerPage(
            habitId: widget.challengeId,
            targetMin: targetMin,
            targetMax: targetMax,

          ),
        ),
      ).then((_) => loadChallenge());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionTimerPage(
            habitId: widget.challengeId,
            targetMin: targetMin,
            targetMax: targetMax,
          ),
        ),
      ).then((_) => loadChallenge());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading || challengeData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final isSender = challengeData!['senderId'] == currentUserId;
    return Scaffold(
      appBar: AppBar(title: const Text('Challenge Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text('Habit: $type', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
        Text("Your Progress: $todayProgress $unit",
            style: const TextStyle(fontSize: 16),
      ),
        LinearProgressIndicator(
          value: (todayProgress / targetMax).clamp(0.0, 1.0),
          minHeight: 10,
        ),
            const SizedBox(height: 20),
            Text(
              "Your Friend's Progress: ${challengeData![isSender ? 'receiverProgress' : 'senderProgress']} $unit",
              style: const TextStyle(fontSize: 16),
            ),
            LinearProgressIndicator(
              value: (challengeData![isSender ? 'receiverProgress' : 'senderProgress'] / targetMax).clamp(0.0, 1.0),
              minHeight: 10,
              color: Colors.grey, // optional different color
            ),


            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(isComplete ? "Completed!" : "Track Now"),
              onPressed: isComplete ? null : launchTracker,
            ),
          ],
          
        ),
      ),
    );
  }
}
