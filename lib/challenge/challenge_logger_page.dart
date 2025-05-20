import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


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
  Map<String, dynamic>? challengeData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadChallenge();
  }

  Future<void> loadChallenge() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId)
          .get();

      if (doc.exists) {
        setState(() {
          challengeData = doc.data();
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      print('Failed to fetch challenge: $e');
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Challenge Details")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : challengeData == null
          ? const Center(child: Text("Challenge not found."))
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Challenger: ${challengeData!['senderName']}"),
            Text("Opponent: ${challengeData!['receiverName']}"),
            const SizedBox(height: 12),
            Text("Habit Type: ${challengeData!['habitType']}"),
            Text("Target: ${challengeData!['targetMin']} - ${challengeData!['targetMax']}"),
            Text("Duration: ${challengeData!['durationDays']} days"),
            const SizedBox(height: 24),
            Text("Sender Progress: ${challengeData!['senderProgress']}"),
            Text("Receiver Progress: ${challengeData!['receiverProgress']}"),
          ],
        ),
      ),
    );
  }
}
