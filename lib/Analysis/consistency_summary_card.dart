import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConsistencySummaryCard extends StatelessWidget {
  final String userId;
  const ConsistencySummaryCard({super.key, required this.userId});

  Future<Map<String, int>> _fetchConsistencyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'daysLogged': 0, 'daysPassed': 0};

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('habits')
        .get();

    int totalLogged = 0;
    int totalPassed = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      totalLogged += (data['daysLogged'] ?? 0) as int;
      totalPassed += (data['daysPassed'] ?? 0) as int;
    }

    return {'daysLogged': totalLogged, 'daysPassed': totalPassed};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _fetchConsistencyData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final logged = snapshot.data?['daysLogged'] ?? 0;
        final passed = snapshot.data?['daysPassed'] ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal[50],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Consistency Insights',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.calendar_today, size: 28, color: Colors.indigo),
                      const SizedBox(height: 6),
                      Text('$passed',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text('Existing Days to Log'),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 28, color: Colors.green),
                      const SizedBox(height: 6),
                      Text('$logged',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text('Days logged'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
