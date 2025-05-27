import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/rewards/powerup_manager.dart';

class TopHeader extends StatelessWidget {
  final VoidCallback? onAddTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  final String? powerupAssetPath;
  final List<String> notifications;

  const TopHeader({
    super.key,
    this.onAddTap,
    this.onProfileTap,
    this.onNotificationTap,
    this.notifications = const [],
    this.powerupAssetPath,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;
    final screenWidth = mediaQuery.size.width;

    // Calculate dynamic padding based on status bar height
    final topPadding = statusBarHeight + 10.0; // Minimum 10px below status bar
    final bottomPadding = 16.0;
    final horizontalPadding = screenWidth * 0.04; // 4% of screen width

    return Container(
      width: double.infinity,
      color: Colors.blueAccent,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bottomPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate responsive sizes based on available width
          final avatarSize = constraints.maxWidth * 0.12; // 12% of header width
          final iconSize = constraints.maxWidth * 0.08; // 8% of header width
          // You might want a specific height for your header image, or make it responsive
          final headerImageHeight = constraints.maxWidth * 0.1; // Example: 10% of header width
          final titleSize = constraints.maxWidth * 0.06; // 6% of header width

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Profile Menu
              PopupMenuButton<String>(
                onSelected: (value) async {
                  // ... your existing onSelected logic
                  if (value == 'logout') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/login', (_) => false);
                      }
                    }
                  } else if (value == 'settings') {
                    Navigator.pushNamed(context, '/settings_page');
                  } else if (value == 'about') {
                    Navigator.pushNamed(context, '/welcome');
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'settings', child: Text('Settings')),
                  const PopupMenuItem(value: 'about', child: Text('About Us')),
                  const PopupMenuItem(value: 'logout', child: Text('Logout')),
                ],
                child: CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundColor: Colors.white,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? Text(
                    'S', // Consider a more generic initial or icon
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: titleSize, // Use a responsive size
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                    ),
                  )
                      : null,
                ),
              ),

              // App Title with Icon (Rectangular Image Container)
              Expanded( // Use Expanded to allow the Row to take available space
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, // Center the icon and title
                  children: [
                    Container(
                      width: 160, // Adjust width as needed, make it responsive
                      height: 58, // Use the responsive height
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/app_icon3.png'),
                          fit: BoxFit.fitWidth, // Image will be as wide as the container, height adjusts
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.02),

                  ],
                ),
              ),


              // Power-up Icon
              FutureBuilder<Map<String, dynamic>?>(
                future: PowerupManager.getTodayPowerup(),
                builder: (context, snapshot) {
                  final powerup = snapshot.data;
                  final assetPath = powerup != null
                      ? getPowerupAssetPath(powerup['name'])
                      : null;

                  return Tooltip(
                    message: powerup != null
                        ? "Today's Power-up: ${powerup['name']}"
                        : 'No power-up',
                    child: assetPath != null
                        ? Image.asset(
                      assetPath,
                      width: iconSize,
                      height: iconSize,
                    )
                        : Icon(
                      Icons.flash_on,
                      size: iconSize,
                      color: Colors.blueAccent, // Changed for better visibility if no image
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String? getPowerupAssetPath(String name) {
    // ... your existing getPowerupAssetPath logic
    switch (name.toLowerCase()) {
      case 'cardio charge':
        return 'assets/boosts/cardio_charge.png';
      case 'iron boost':
        return 'assets/boosts/iron_boost.png';
      case 'focus boost':
        return 'assets/boosts/focus_boost.png';
      default:
        return null;
    }
  }
}