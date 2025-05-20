import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class ChallengeLoggerPage extends StatefulWidget {
  final String friendId;
  final String friendName;

  const ChallengeLoggerPage({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<ChallengeLoggerPage> createState() => _ChallengeLoggerPageState();
}

class _ChallengeLoggerPageState extends State<ChallengeLoggerPage> {
  final _formKey = GlobalKey<FormState>();
  String selectedType = 'Running';
  int minTarget = 1;
  int maxTarget = 5;
  int duration = 7;

  final List<String> habitTypes = [
    'Running',
    'Yoga',
    'Weightlifting',
    'Meditation',
    'Cycling',
  ];

  bool loading = false;

  void submitChallenge() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final user = FirebaseAuth.instance.currentUser!;
    final challengeId = const Uuid().v4();

    final data = {
      'id': challengeId,
      'senderId': user.uid,
      'receiverId': widget.friendId,
      'senderName': user.displayName ?? 'You',
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

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('challenges')
          .doc(challengeId)
          .set(data);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.friendId)
          .collection('challenges')
          .doc(challengeId)
          .set(data);

      if (context.mounted) {
        Navigator.pop(context);
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

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set Challenge")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                items: habitTypes
                    .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => selectedType = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Habit Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: minTarget.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Min Target',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                      value == null || value.isEmpty ? 'Enter min' : null,
                      onChanged: (val) => minTarget = int.tryParse(val) ?? 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: maxTarget.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Max Target',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                      value == null || value.isEmpty ? 'Enter max' : null,
                      onChanged: (val) => maxTarget = int.tryParse(val) ?? 5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: duration.toString(),
                decoration: const InputDecoration(
                  labelText: 'Duration (Days)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                value == null || value.isEmpty ? 'Enter duration' : null,
                onChanged: (val) => duration = int.tryParse(val) ?? 7,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: submitChallenge,
                icon: const Icon(Icons.send),
                label: const Text("Send Challenge"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  backgroundColor: Colors.blueAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
