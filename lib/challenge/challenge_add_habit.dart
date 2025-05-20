import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'challenge_logger_page.dart';

class ChallengeAddHabitPage extends StatefulWidget {
  final String friendId;
  final String friendName;

  const ChallengeAddHabitPage({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<ChallengeAddHabitPage> createState() => _ChallengeAddHabitPageState();
}

class _ChallengeAddHabitPageState extends State<ChallengeAddHabitPage> {
  final _formKey = GlobalKey<FormState>();
  String selectedType = 'Running';
  int minTarget = 1;
  int maxTarget = 5;
  int duration = 7;

  final List<String> habitTypes = [
    'Running',
    'Yoga',
    'Weightlifting',
    'Cycling',
    'Meditation',
  ];

  Future<String?> submitChallenge() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final challengeId = FirebaseFirestore.instance.collection('challenges').doc().id;
    final challengeRef = FirebaseFirestore.instance.collection('challenges').doc(challengeId);

    final challengeData = {
      'senderId': currentUser.uid,
      'receiverId': widget.friendId,
      'senderName': currentUser.displayName ?? 'You',
      'receiverName': widget.friendName,
      'habitType': selectedType,
      'targetMin': minTarget,
      'targetMax': maxTarget,
      'durationDays': duration,
      'status': 'pending',
      'createdAt': Timestamp.now(),
      'senderProgress': 0,
      'receiverProgress': 0,
    };

    print('DEBUG - challengeData: $challengeData');
    print("Auth UID: ${FirebaseAuth.instance.currentUser?.uid}");
    print("Sender in challengeData: ${challengeData['senderId']}");

    try {
      await challengeRef.set(challengeData);
      return challengeId;
    } catch (e) {
      print('ERROR SUBMITTING CHALLENGE: $e');
      return null;
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6EC), // soft beige
      appBar: AppBar(
        backgroundColor: Colors.orangeAccent,
        title: const Text(
          "Set Challenge Habit",
          style: TextStyle(fontFamily: 'Montserrat'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                "Challenge Against",
                style: TextStyle(fontSize: 14, fontFamily: 'Montserrat'),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(widget.friendName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Montserrat')),
              ),
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: InputDecoration(
                  labelText: 'Habit Type',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: habitTypes
                    .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type, style: const TextStyle(fontFamily: 'Montserrat')),
                ))
                    .toList(),
                onChanged: (val) => setState(() => selectedType = val ?? selectedType),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: minTarget.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Min Target',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) => minTarget = int.tryParse(val) ?? 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: maxTarget.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Max Target',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) => maxTarget = int.tryParse(val) ?? 5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              TextFormField(
                initialValue: duration.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Duration (days)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) => duration = int.tryParse(val) ?? 7,
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text(
                  "Send Challenge",
                  style: TextStyle(fontFamily: 'Montserrat'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    final challengeId = await submitChallenge();
                    if (challengeId != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Challenge sent!")),
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChallengeLoggerPage(challengeId: challengeId),
                        ),
                      );

                    }
                  }

              )
            ],
          ),
        ),
      ),
    );
  }
}
