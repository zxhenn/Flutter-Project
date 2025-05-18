import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '/utils/pointing_system.dart'; // update path accordingly

class ChallengeLoggerPage extends StatefulWidget {
  final String challengeId;
  final Map<String, dynamic> habitData;
  final Map<String, dynamic> challengeData;

  const ChallengeLoggerPage({
    super.key,
    required this.challengeId,
    required this.habitData,
    required this.challengeData,
  });

  @override
  State<ChallengeLoggerPage> createState() => _ChallengeLoggerPageState();
}

class _ChallengeLoggerPageState extends State<ChallengeLoggerPage> {
  final user = FirebaseAuth.instance.currentUser!;
  late DocumentReference myHabitRef;
  late String opponentId;
  bool isComplete = false;

  @override
  void initState() {
    super.initState();
    myHabitRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('challengeHabits')
        .doc(widget.challengeId);

    opponentId = widget.challengeData['senderId'] == user.uid
        ? widget.challengeData['receiverId']
        : widget.challengeData['senderId'];
  }

  Future<void> updateProgress() async {
    final snap = await myHabitRef.get();
    final data = snap.data() as Map<String, dynamic>?;

    if (data == null) return;

    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastTracked = data['lastTracked'] ?? '';
    int daysLogged = data['daysLogged'] ?? 0;
    int duration = widget.habitData['durationDays'] ?? 7;

    if (lastTracked != today) {
      daysLogged += 1;
    }

    final createdAt = (data['createdAt'] as Timestamp).toDate();
    final daysPassed = DateTime.now().difference(createdAt).inDays + 1;
    final consistencyRatio = daysLogged / daysPassed;

    await myHabitRef.update({
      'todayProgress': FieldValue.increment(1),
      'daysLogged': daysLogged,
      'lastTracked': today,
      'consistencyRatio': consistencyRatio,
    });

    // Check if challenge is over
    if (daysPassed >= duration) {
      await checkWinnerAndReward();
    }
  }

  Future<void> checkWinnerAndReward() async {
    final mySnap = await myHabitRef.get();
    final opponentRef = FirebaseFirestore.instance
        .collection('users')
        .doc(opponentId)
        .collection('challengeHabits')
        .doc(widget.challengeId);

    final opponentSnap = await opponentRef.get();

    if (!mySnap.exists || !opponentSnap.exists) return;

    final myRatio = (mySnap['consistencyRatio'] ?? 0).toDouble();
    final opponentRatio = (opponentSnap['consistencyRatio'] ?? 0).toDouble();

    if (myRatio > opponentRatio) {
      await PointingSystem.rewardHonorPoints(user.uid, 10); // winner reward
    } else if (opponentRatio > myRatio) {
      // no action, loser
    } else {
      // draw — optional logic
    }

    setState(() {
      isComplete = true;
    });
  }

  void handleTrack() async {
    await updateProgress();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Progress tracked!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isComplete) {
      return Scaffold(
        appBar: AppBar(title: const Text("Challenge Complete")),
        body: const Center(child: Text("This challenge is complete.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Track Challenge Habit")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.habitData['type'] ?? 'Challenge Habit'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: handleTrack,
              child: const Text("Track Progress"),
            ),
          ],
        ),
      ),
    );
  }
}
