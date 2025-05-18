import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TopHeader extends StatelessWidget {
  final VoidCallback? onAddTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  const TopHeader({
    super.key,
    this.onAddTap,
    this.onProfileTap,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Profile Menu with Dropdown
                PopupMenuButton<String>(
                  onSelected: (value) async {
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
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                        }
                      }
                    } else if (value == 'settings') {
                      Navigator.pushNamed(context, '/settings_page');
                    } else if (value == 'about') {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Gamified Productivity App',
                        applicationVersion: '1.0.0',
                        children: [
                          const Text('Built with ❤️ using Flutter. Stay productive!'),
                        ],
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'settings', child: Text('Settings')),
                    const PopupMenuItem(value: 'about', child: Text('About Us')),
                    const PopupMenuItem(value: 'logout', child: Text('Logout')),
                  ],
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue[100],
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? const Icon(Icons.person, size: 28, color: Colors.blue)
                        : null,
                  ),
                ),

                // App Title
                const Text(
                  'GAMIFIED\nPRODUCTIVITY APP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    height: 1.2,
                    letterSpacing: 0.8,
                  ),
                ),

                // Notification Bell (placeholder)
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notifications coming soon!')),
                    );
                  },
                  child: Stack(
                    children: [
                      const Icon(Icons.notifications, size: 32, color: Colors.blue),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider line
          const Divider(
            thickness: 1.2,
            color: Colors.grey,
            height: 0,
          ),
        ],
      ),
    );
  }
}
