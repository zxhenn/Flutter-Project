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
                icon: Icons.front_hand,
                title: 'Power Fist',
                description: 'Double Lifting Powers X2 on the earning points',
              ),
              const SizedBox(height: 12),
              const _PowerUpCard(
                icon: Icons.flash_on,
                title: 'Electric',
                description: 'Double Running Power X2 on the earning points',
              ),
              const SizedBox(height: 12),
              const _PowerUpCard(
                icon: Icons.auto_awesome,
                title: 'Aura',
                description: '5% Power boost',
              ),
              const SizedBox(height: 12),
              const _PowerUpCard(
                icon: Icons.medication,
                title: 'Tablet',
                description: '10% Medicine boost',
              ),
              const SizedBox(height: 24),
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
  final IconData icon;
  final String title;
  final String description;

  const _PowerUpCard({
    required this.icon,
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
          Icon(icon, size: 32, color: Colors.blueAccent),
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
