import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    final topPadding = statusBarHeight + 8.0;
    final bottomPadding = 12.0;
    final horizontalPadding = screenWidth * 0.04;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blue[700],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bottomPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with border
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
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
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 12),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 12),
                    const Text(
                      'About Us',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red[600]),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? Text(
                        user?.displayName?.isNotEmpty == true
                            ? user!.displayName![0].toUpperCase()
                            : user?.email?.isNotEmpty == true
                                ? user!.email![0].toUpperCase()
                                : 'S',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),

          // App Logo
          Expanded(
            child: Center(
              child: Container(
                width: 160,
                height: 58,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/app_icon3.png'),
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),
          ),

          // Spacer to balance the layout (same width as avatar)
          SizedBox(width: 44),
        ],
      ),
    );
  }

}