import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

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
  String selectedUnit = 'Minutes';

  final List<String> habitTypes = [
    'Running',
    'Yoga',
    'Weightlifting',
    'Cycling',
    'Meditation',
  ];
  List<String> getUnitOptionsForType(String type) {
    if (type == 'Running') {
      return ['Distance (km)', 'Minutes', 'Sessions'];
    } else {
      return ['Sessions'];
    }
  }



  /// Sends the challenge to both users' collections
  Future<void> submitChallenge() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
// Prevent duplicates

    final allChallenges = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('challenges')
        .get();

    final hasChallenge = allChallenges.docs.any((doc) {
      final data = doc.data();
      final status = data['status'];
      final idA = data['senderId'];
      final idB = data['receiverId'];
      return (status != 'declined') &&
          ((idA == currentUser.uid && idB == widget.friendId) ||
              (idA == widget.friendId && idB == currentUser.uid));
    });

    if (hasChallenge) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You already have a challenge with this friend.")),
        );
      }
      return;
    }

    final challengeId = const Uuid().v4();



    final challengeData = {
      'id': challengeId,
      'senderId': currentUser.uid,
      'receiverId': widget.friendId,
      'senderName': currentUser.displayName ?? 'You',
      'receiverName': widget.friendName,
      'habitType': selectedType,
      'unit': selectedUnit, // ✅ Save unit here
      'targetMin': minTarget,
      'targetMax': maxTarget,
      'durationDays': duration,
      'status': 'pending',
      'createdAt': Timestamp.now(),
      'senderProgress': 0,
      'receiverProgress': 0,
    };


    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('challenges')
          .doc(challengeId)
          .set(challengeData);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.friendId)
          .collection('challenges')
          .doc(challengeId)
          .set(challengeData);

      if (context.mounted) {
        Navigator.pop(context); // return to challenge_screen.dart
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Challenge sent!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send challenge: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6EC),
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text("Set Challenge Habit",
            style: TextStyle(fontFamily: 'Montserrat', color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text("Challenge Against",
                  style: TextStyle(fontSize: 14, fontFamily: 'Montserrat', fontWeight: FontWeight.w500, color: Colors.red)),
              const SizedBox(height: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
              const SizedBox(height: 26),

              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: InputDecoration(
                  labelText: 'Habit Type',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: habitTypes
                    .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type, style: TextStyle(fontFamily: 'Montserrat')),
                ))
                    .toList(),
                onChanged: (val) {
                  final newType = val ?? selectedType;
                  final newUnitOptions = getUnitOptionsForType(newType);
                  final defaultUnit = newUnitOptions.first;

                  setState(() {
                    selectedType = newType;
                    selectedUnit = defaultUnit; // ✅ reset unit based on selected type
                  });
                },
              ),

              const SizedBox(height: 26),
              DropdownButtonFormField<String>(
                value: selectedUnit,
                decoration: InputDecoration(
                  labelText: 'Unit',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: getUnitOptionsForType(selectedType).map((unit) => DropdownMenuItem(
                  value: unit,
                  child: Text(unit, style: const TextStyle(fontFamily: 'Montserrat')),
                )).toList(),

                onChanged: (val) => setState(() => selectedUnit = val ?? selectedUnit),
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
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) =>
                      minTarget = int.tryParse(val) ?? minTarget,
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
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) =>
                      maxTarget = int.tryParse(val) ?? maxTarget,
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
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) =>
                duration = int.tryParse(val) ?? duration,
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text("Send Challenge",
                    style: TextStyle(fontFamily: 'Montserrat', color: Colors.white, fontWeight: FontWeight.w500)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    submitChallenge();
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
