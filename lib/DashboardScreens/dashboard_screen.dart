import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_screen.dart';
import 'challenge_screen.dart';
import 'leaderboard_screen.dart';
import 'badge_screen.dart';
import '/addition/habit_logger_page.dart';
import '/addition/top_header.dart';
import '/addition/bottom_navbar.dart';
import 'friends_screen.dart';
import '/Settings/settings_page.dart';
import '/utils/pointing_system.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardHomeContent(),
    const ChallengeScreen(),
    const FriendsScreen(),
    const AddScreen(),
    const LeaderboardScreen(),
    const BadgeScreen(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class DashboardHomeContent extends StatefulWidget {
  const DashboardHomeContent({super.key});

  @override
  State<DashboardHomeContent> createState() => _DashboardHomeContentState();
}

class _DashboardHomeContentState extends State<DashboardHomeContent> {
  Map<String, dynamic> categoryPoints = {};

  @override
  void initState() {
    super.initState();
    _loadCategoryPoints();
  }

  Future<void> _loadCategoryPoints() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    setState(() {
      categoryPoints = Map<String, dynamic>.from(data['categoryPoints'] ?? {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("You must be logged in."));
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TopHeader(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('Your Habits',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('habits')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'You haven’t set up your habit to track.',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Setup Now',
                              style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ],
                    ),
                  );
                }

                final habits = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: habits.length,
                  itemBuilder: (context, index) {
                    final doc = habits[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final String type = data['type'] ?? 'Habit';
                    final String unit = data['unit'] ?? '';
                    final String frequency = data['frequency'] ?? 'Daily';
                    final int targetMin = data['targetMin'] ?? 0;
                    final int targetMax = data['targetMax'] ?? 0;
                    final int durationDays = data['durationDays'] ?? 1;
                    final int daysCompleted = data['daysCompleted'] ?? 0;
                    final String category = data['category'] ?? 'General';

                    final bool isHabitDone = daysCompleted >= durationDays;
                    final String progressLabel = isHabitDone ? 'Completed' : 'Ongoing';

                    final int categoryScore = categoryPoints[category] ?? 0;

                    final Timestamp? createdAt = data['createdAt'];
                    final DateTime startDate = createdAt?.toDate() ?? DateTime.now();
                    final int daysSinceStart = DateTime.now().difference(startDate).inDays + 1;
                    final double consistencyRatio = PointingSystem.calculateConsistencyRatio(daysCompleted, daysSinceStart);

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HabitLoggerPage(
                              habitId: doc.id,
                              habitData: data,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal[50],
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade300,
                              blurRadius: 6,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$type - $unit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Frequency: $frequency', style: const TextStyle(fontSize: 14, color: Colors.blue)),
                            Text('Minimum of $targetMin $unit'),
                            Text('Maximum of $targetMax $unit'),
                            Text('Days: $daysCompleted / $durationDays'),
                            Text('Completed: $daysCompleted / $durationDays'),
                            Text('Progress: $progressLabel', style: TextStyle(color: isHabitDone ? Colors.green : Colors.orange)),

                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: (daysCompleted / durationDays).clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor: Colors.grey[300],
                                color: isHabitDone ? Colors.green : Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Tooltip(
                                  message: 'Consistency is your streak compared to how long this habit has existed. Higher is better!',
                                  child: const Icon(Icons.info_outline, size: 18, color: Colors.indigo),
                                ),
                                const SizedBox(width: 6),
                                const Text('Consistency', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: consistencyRatio,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade300,
                                color: consistencyRatio >= 0.9
                                    ? Colors.green
                                    : consistencyRatio >= 0.6
                                    ? Colors.orange
                                    : Colors.red,
                              ),
                            ),
                            Text('${(consistencyRatio * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: consistencyRatio >= 0.9
                                        ? Colors.green
                                        : consistencyRatio >= 0.6
                                        ? Colors.orange
                                        : Colors.red)),
                            const SizedBox(height: 10),
                            Text('🏆 $category Points: $categoryScore', style: const TextStyle(color: Colors.deepPurple)),

                            Align(
                              alignment: Alignment.centerRight,
                              child: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'delete') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Habit?'),
                                        content: const Text('Are you sure you want to delete this habit?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user.uid)
                                          .collection('habits')
                                          .doc(doc.id)
                                          .delete();

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Habit deleted')),
                                        );
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
