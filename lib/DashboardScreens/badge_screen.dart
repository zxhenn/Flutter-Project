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


  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              // fontFamily: 'Montserrat', // Already set in theme likely
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100], // Light background for the whole screen
      appBar: AppBar(
        title: const Text("Collectibles", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, // Or theme.scaffoldBackgroundColor
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.textTheme.titleLarge?.color ?? theme.colorScheme.primary),
        titleTextStyle: TextStyle(color: theme.textTheme.titleLarge?.color ?? theme.colorScheme.primary, fontSize: 20, fontWeight: FontWeight.bold),

      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // If you have a separate TopHeader for this screen (not AppBar)
              // const TopHeader(),
              // const SizedBox(height: 10),

              _buildSectionTitle(context, 'Your Badges', Icons.shield_outlined),
              Card(
                elevation: 3.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12.0,
                      mainAxisSpacing: 12.0,
                      childAspectRatio: 0.85, // Adjust for better image + text fit
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
              ),

              _buildSectionTitle(context, 'Available Power-Ups', Icons.flash_on_outlined),
              ListView.separated(
                itemCount: _powerUpsData.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final powerUp = _powerUpsData[index];
                  // Basic color parsing from string, ideally store Color objects
                  Color cardColor = Colors.teal.shade50; // Default
                  // This is a hacky way to parse color string.
                  // A better way would be to store actual Color objects or use a map.
                  if(powerUp['color'] == 'Color(0xFFFFF3E0)') cardColor = const Color(0xFFFFF3E0);
                  if(powerUp['color'] == 'Color(0xFFE3F2FD)') cardColor = const Color(0xFFE3F2FD);

                  return _PowerUpCard(
                    imagePath: powerUp['imagePath']!,
                    title: powerUp['title']!,
                    description: powerUp['description']!,
                    cardColor: cardColor,
                  );
                },
              ),
              const SizedBox(height: 20), // Bottom padding
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
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center, // Center content within the tile
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0), // Add some padding around the image
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) { // Fallback for missing assets
                return Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey[400]);
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
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
    this.cardColor = const Color(0xFFE0F2F1), // Default light teal
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: cardColor, // Use the passed color
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top
          children: [
            Image.asset(
              imagePath,
              height: 56, // Slightly smaller for better balance
              width: 56,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.broken_image_outlined, size: 56, color: Colors.grey[400]);
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.87), // Darker text on light bg
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}