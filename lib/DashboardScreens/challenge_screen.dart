import 'package:flutter/material.dart';
import '/addition/top_header.dart';

class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const TopHeader(),
              const SizedBox(height: 16),

              const Text(
                'CHALLENGE',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const Text(
                'Friends',
                style: TextStyle(fontSize: 18, color: Colors.blueGrey),
              ),
              const SizedBox(height: 24),

              // Example challenge: Current user vs Friend
              _challengeGroup(
                currentUserName: 'Joven Sacay',
                currentUserHabit: 'Run 10K',
                currentUserProgress: '3/7',
                friendName: 'Ian Aquino',
                friendHabit: 'Run 10K',
                friendProgress: '2/7',
              ),

              const SizedBox(height: 20),

              _challengeCard(
                name: 'Denmark Vergara',
                habit: 'Lift Weight',
                progress: '4/7',
              ),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Challenge friend logic coming soon')),
                  );
                },
                child: Column(
                  children: [
                    const Icon(Icons.sports_kabaddi, size: 40, color: Colors.red),
                    const SizedBox(height: 6),
                    Text(
                      'Challenge friend',
                      style: TextStyle(fontSize: 16, color: Colors.red.shade400, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _challengeGroup({
    required String currentUserName,
    required String currentUserHabit,
    required String currentUserProgress,
    required String friendName,
    required String friendHabit,
    required String friendProgress,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100,
            blurRadius: 4,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _challengeUserRow(friendName, Icons.person, friendHabit, friendProgress),
          const SizedBox(height: 12),
          const Text('VS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _challengeUserRow(currentUserName, Icons.person_outline, currentUserHabit, currentUserProgress),
        ],
      ),
    );
  }

  Widget _challengeUserRow(String name, IconData icon, String habit, String progress) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.teal[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(name),
              const SizedBox(width: 8),
              const Icon(Icons.military_tech, size: 18),
              const SizedBox(width: 4),
              const Text('Points: 0'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 4,
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.fitness_center, size: 28, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text('$habit\n$progress', style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _challengeCard({
    required String name,
    required String habit,
    required String progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100,
            blurRadius: 4,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 20),
                const SizedBox(width: 8),
                Text(name),
                const SizedBox(width: 8),
                const Icon(Icons.military_tech, size: 18),
                const SizedBox(width: 4),
                const Text('Points: 0'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.fitness_center, size: 28, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('$habit\n$progress', style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
  