import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'EditProfileScreen.dart';
import '/utils/pointing_system.dart';
import '/Analysis/analysis_screen.dart';
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _displayName = '';
  String _email = '';
  int _points = 0;
  String _rank = 'Bronze';

  @override
  void initState() {
    super.initState();
    _loadProfileInfo();
  }

  Future<void> _loadProfileInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profileDoc = await FirebaseFirestore.instance
        .collection('Profiles')
        .doc(user.uid)
        .get();

    final name = profileDoc.data()?['Name'] ?? 'User';
    final email = user.email ?? '';
    final habitsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('habits')
        .get();

    int totalPoints = 0;

    for (var doc in habitsSnapshot.docs) {
      final habitData = doc.data();
      if (habitData.containsKey('points')) {
        totalPoints += (habitData['points'] as num).toInt();
      }
    }

    final rank = PointingSystem.getRankFromPoints(totalPoints);



    setState(() {
      _displayName = name;
      _email = email;
      _points = totalPoints;
      _rank = rank;
    });


  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final providerId = user?.providerData.first.providerId;

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
                  fontFamily: 'Montserrat',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 24),

              // ✅ Profile Card
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
                          _displayName,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // 🏅 Rank Badge Image
                            Image.asset(
                              'assets/badges/${_rank.toLowerCase()}.png',
                              height: 30,
                              width: 50,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.emoji_events, size: 24, color: Colors.grey);
                              },
                            ),
                            const SizedBox(width: 1),

                            // 🔠 Rank Text
                            Text(
                              _rank,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(width: 16),

                            const Icon(Icons.leaderboard, size: 18, color: Colors.deepPurple),
                            const SizedBox(width: 4),

                            // 🧮 Points
                            Text(
                              'Points: $_points',
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 16,
                              ),
                            ),
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalysisScreen()),
                  );
                },
              ),

              _settingsButton(
                icon: Icons.info_outline,
                label: 'About',
                onTap: () {
                  Navigator.pushNamed(context, '/welcome');
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
  }

  Widget _settingsButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
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
                fontFamily: 'Montserrat',
                fontSize: 20,
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
