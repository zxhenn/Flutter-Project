import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'EditProfileScreen.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final providerId = user?.providerData.first.providerId;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Profiles').doc(user?.uid).get(),
      builder: (context, snapshot) {
        String displayName = 'User';
        if (snapshot.hasData && snapshot.data!.exists) {
          displayName = snapshot.data!.get('Name') ?? 'User';
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'User Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profile Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage: user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : null,
                          child: user?.photoURL == null
                              ? const Icon(Icons.person, size: 36, color: Colors.blue)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Row(
                              children: [
                                Icon(Icons.emoji_events, size: 18, color: Colors.deepPurple),
                                SizedBox(width: 4),
                                Text('Rank'),
                                SizedBox(width: 16),
                                Icon(Icons.leaderboard, size: 18, color: Colors.deepPurple),
                                SizedBox(width: 4),
                                Text('Points: 598'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(Icons.flash_on, color: Colors.blue),
                                SizedBox(width: 6),
                                Text('Power Ups', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  _settingsButton(
                    icon: Icons.person,
                    label: 'Edit Profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      );
                    },
                  ),
                  _settingsButton(
                    icon: Icons.lock,
                    label: 'Change Password',
                    onTap: providerId == 'password'
                        ? () async {
                      final email = FirebaseAuth.instance.currentUser?.email;
                      if (email != null) {
                        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password reset email sent')),
                        );
                      }
                    }
                        : null,
                  ),
                  _settingsButton(
                    icon: Icons.newspaper,
                    label: 'Analysis',
                    onTap: () {},
                  ),
                  _settingsButton(
                    icon: Icons.info_outline,
                    label: 'About',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Gamified Productivity App',
                        applicationVersion: '1.0.0',
                        children: [const Text('Designed for awesome productivity!')],
                      );
                    },
                  ),
                  _settingsButton(
                    icon: Icons.logout,
                    label: 'Log out',
                    onTap: () async {
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
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _settingsButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap, // allow null
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade300 : Colors.teal.shade50,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.blue),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: onTap == null ? Colors.grey : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
