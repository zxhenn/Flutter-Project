import 'package:flutter/material.dart';
// import '/addition/top_header.dart'; // Assuming this is your custom top header

class BadgeScreen extends StatelessWidget {
  const BadgeScreen({super.key});

  // Data for badges and power-ups (can be moved to a separate file or fetched)
  static const List<Map<String, String>> _badgesData = [
    {'imagePath': 'assets/badges/grandmaster.png', 'label': 'Grandmaster'},
    {'imagePath': 'assets/badges/diamond.png', 'label': 'Diamond'},
    {'imagePath': 'assets/badges/emerald.png', 'label': 'Emerald'},
    {'imagePath': 'assets/badges/gold.png', 'label': 'Gold'},
    {'imagePath': 'assets/badges/silver.png', 'label': 'Silver'}, // Changed Iron to Silver for consistency
    {'imagePath': 'assets/badges/bronze.png', 'label': 'Bronze'},
    // Add more badges if you have them
  ];

  static const List<Map<String, String>> _powerUpsData = [
    {
      'imagePath': 'assets/boosts/cardio_charge.png',
      'title': 'Cardio Charge',
      'description': 'Boosts points for completed Cardiovascular habits by +50% when active.',
      'color': 'Color(0xFFE0F2F1)', // Example: Light Teal
    },
    {
      'imagePath': 'assets/boosts/iron_boost.png',
      'title': 'Iron Boost',
      'description': 'Enhances Strength Training habits, granting +50% extra points when active.',
      'color': 'Color(0xFFFFF3E0)', // Example: Light Orange/Amber
    },
    {
      'imagePath': 'assets/boosts/focus_boost.png',
      'title': 'Focus Boost',
      'description': 'Grants +50% extra points for any completed custom-defined habit when active.',
      'color': 'Color(0xFFE3F2FD)', // Example: Light Blue
    },
  ];


  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blue[700], size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        title: Text(
          "Collectibles",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Your Badges', Icons.shield_outlined),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _badgesData.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final badge = _badgesData[index];
                    return _BadgeTile(
                      imagePath: badge['imagePath']!,
                      label: badge['label']!,
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Available Power-Ups', Icons.flash_on_outlined),
              ..._powerUpsData.map((powerUp) {
                Color cardColor = Colors.teal.shade50;
                if (powerUp['color'] == 'Color(0xFFFFF3E0)') cardColor = const Color(0xFFFFF3E0);
                if (powerUp['color'] == 'Color(0xFFE3F2FD)') cardColor = const Color(0xFFE3F2FD);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PowerUpCard(
                    imagePath: powerUp['imagePath']!,
                    title: powerUp['title']!,
                    description: powerUp['description']!,
                    cardColor: cardColor,
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
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

  const _BadgeTile({required this.imagePath, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset(
            imagePath,
            height: 60,
            width: 60,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.star, size: 40, color: Colors.blue[700]);
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PowerUpCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String description;
  final Color cardColor;

  const _PowerUpCard({
    required this.imagePath,
    required this.title,
    required this.description,
    this.cardColor = const Color(0xFFE0F2F1),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              imagePath,
              height: 48,
              width: 48,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.bolt, size: 32, color: Colors.orange[700]);
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}