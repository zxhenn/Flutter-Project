import 'package:flutter/material.dart';
import '/addition/top_header.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const TopHeader(), // 👈 Add this to actually show the Top Header
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Leaderboard Screen',
                style: TextStyle(fontSize: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


