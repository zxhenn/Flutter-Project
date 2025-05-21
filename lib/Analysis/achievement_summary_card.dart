import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AchievementSummaryCard extends StatelessWidget {
  const AchievementSummaryCard({super.key});

  Future<Map<String, dynamic>> _loadAchievements() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('completed_habits')
        .get();

    int totalCompleted = snapshot.docs.length;
    int longestStreak = 0;
    Map<String, int> typeTotals = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final type = data['type'] ?? 'Unknown';
      final logged = (data['daysLogged'] ?? 0).toInt();


      typeTotals[type] = ((typeTotals[type] ?? 0) + logged).toInt();



      // Placeholder for streak logic (not yet tracked)
      if (logged > longestStreak) longestStreak = logged;
    }

    final mostTracked = typeTotals.entries.fold<MapEntry<String, int>>(
      const MapEntry('None', 0),
          (prev, entry) => entry.value > prev.value ? entry : prev,
    );

    return {
      'totalCompleted': totalCompleted,
      'longestStreak': longestStreak,
      'mostTrackedType': mostTracked.key,
      'mostTrackedCount': mostTracked.value,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadAchievements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data ?? {};
        final total = data['totalCompleted'] ?? 0;
        final longestStreak = data['longestStreak'] ?? 0;
        final type = data['mostTrackedType'] ?? 'None';
        final count = data['mostTrackedCount'] ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal[50],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Achievement Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.emoji_events, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Longest streak: $longestStreak days'),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.star, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text('$type logged $count times'),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text('Total habits completed: $total'),
              ]),
            ],
          ),
        );
      },
    );
  }
}
