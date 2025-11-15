import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'EditProfileScreen.dart';
import '/utils/pointing_system.dart';
import '/Analysis/analysis_screen.dart';
import '/DashboardScreens/badge_screen.dart';

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
    loadUserProfile();
    loadUserRank(); // ✅ Add this
  }

  Future<void> loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final doc = await FirebaseFirestore.instance.collection('Profiles').doc(uid).get();

    String name = 'User';
    final data = doc.data();
    if (data != null && data.containsKey('Name')) {
      name = data['Name'];
    }

    setState(() {
      _displayName = name;
      _email = user.email ?? '';
    });
  }

  Future<void> loadUserRank() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;

    final int totalPoints = await PointingSystem.getTotalPoints(uid);
    final rank = PointingSystem.getRankFromPoints(totalPoints);

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'rank': rank,
    }, SetOptions(merge: true));

    setState(() {
      _points = totalPoints;

      _rank = rank;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final providerId = user?.providerData.first.providerId;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
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
                                      : 'U',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/badges/${_rank.toLowerCase()}.png',
                          height: 40,
                          width: 40,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.emoji_events,
                              size: 32,
                              color: Colors.white.withOpacity(0.9),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _rank,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$_points points',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Settings Options
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                children: [
                  _settingsButton(
                    icon: Icons.person_outline,
                    label: 'Edit Profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _settingsButton(
                    icon: Icons.lock_outline,
                    label: 'Change Password',
                    onTap: providerId == 'password'
                        ? () async {
                            final email = FirebaseAuth.instance.currentUser?.email;
                            if (email != null) {
                              await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password reset email sent')),
                                );
                              }
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _settingsButton(
                    icon: Icons.bar_chart_outlined,
                    label: 'Analysis',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AnalysisScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _settingsButton(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Badges & Boosts',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BadgeScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _settingsButton(
                    icon: Icons.info_outline,
                    label: 'About',
                    onTap: () {
                      Navigator.pushNamed(context, '/welcome');
                    },
                  ),
                  const SizedBox(height: 24),
                  _settingsButton(
                    icon: Icons.logout,
                    label: 'Log out',
                    isLogout: true,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                'Logout',
                                style: TextStyle(color: Colors.red[600]),
                              ),
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
          ],
        ),
      ),
    );
  }

  Widget _settingsButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isLogout = false,
  }) {
    final isDisabled = onTap == null;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLogout
                  ? Colors.red.shade200
                  : isDisabled
                      ? Colors.grey.shade300
                      : Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isLogout
                      ? Colors.red.shade50
                      : isDisabled
                          ? Colors.grey.shade100
                          : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isLogout
                      ? Colors.red[600]
                      : isDisabled
                          ? Colors.grey[400]
                          : Colors.blue[700],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isLogout
                        ? Colors.red[600]
                        : isDisabled
                            ? Colors.grey[400]
                            : Colors.grey[900],
                  ),
                ),
              ),
              if (!isDisabled)
                Icon(
                  Icons.chevron_right,
                  color: isLogout ? Colors.red[300] : Colors.grey[400],
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
