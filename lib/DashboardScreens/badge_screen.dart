// badge_screen.dart
import 'package:flutter/material.dart';
import '/addition/top_header.dart';

class BadgeScreen extends StatelessWidget {
  const BadgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TopHeader(),
              const SizedBox(height: 20),

              const Center(
                child: Text(
                  'BADGES',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.shade300, blurRadius: 8, offset: const Offset(0, 4))
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    _BadgeTile('assets/badges/grandmaster.png', 'Grandmaster'),
                    _BadgeTile('assets/badges/diamond.png', 'Diamond'),
                    _BadgeTile('assets/badges/emerald.png', 'Emerald'),
                    _BadgeTile('assets/badges/gold.png', 'Gold'),
                    _BadgeTile('assets/badges/silver.png', 'Iron'),
                    _BadgeTile('assets/badges/bronze.png', 'Bronze'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Center(
                child: Text(
                  'Power Ups',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 16),

              const _PowerUpCard(
                imagePath: 'assets/boosts/cardio_charge.png',
                title: 'Cardio Charge',
                description: 'This power-up gives you +50% extra points for completed Cardiovascular habits.',
              ),
              const SizedBox(height: 12),
              const _PowerUpCard(
                imagePath: 'assets/boosts/iron_boost.png',
                title: 'Iron Boost',
                description: 'This power-up boosts your Strength Training habit by granting +50% extra points.',
              ),
              const SizedBox(height: 12),
              const _PowerUpCard(
                imagePath: 'assets/boosts/focus_boost.png',
                title: 'Focus Boost',
                description: 'This power-up grants +50% extra points for any completed custom habit.',
              ),


            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final String imagePath;
  final String label;

  const _BadgeTile(this.imagePath, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _PowerUpCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String description;

  const _PowerUpCard({
    required this.imagePath,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade300, blurRadius: 6, offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Image.asset(imagePath, height: 64, width: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

