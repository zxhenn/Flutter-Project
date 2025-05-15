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
import '/addition/awesome_notifications.dart';
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool hasPendingRequests = false;
  bool alreadyNotified = false;

  final List<Widget> _screens = [
    const DashboardHomeContent(),
    const ChallengeScreen(),
    const FriendsScreen(),
    const AddScreen(),
    const LeaderboardScreen(),
    const BadgeScreen(),
    const SettingsPage(),
  ];
  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('friend_requests')
          .snapshots()
          .listen((snapshot) {
        final hasRequests = snapshot.docs.isNotEmpty;
        if (mounted) {
          setState(() {
            hasPendingRequests = hasRequests;
          });

          if (hasRequests && !alreadyNotified) {
            showFriendRequestNotification(); // from awesome_notifications.dart
            alreadyNotified = true;
          }

          if (!hasRequests) alreadyNotified = false;
        }
      });
    }
  }

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
        hasPendingRequests: hasPendingRequests,
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
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _loadCategoryPoints();
  }

  Future<void> _loadCategoryPoints() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    setState(() {
      categoryPoints = Map<String, dynamic>.from(data['categoryPoints'] ?? {});
    });
  }

  IconData getHabitIcon(String type) {
    final typeLower = type.toLowerCase();
    if (typeLower.contains('run')) return Icons.directions_run;
    if (typeLower.contains('walk')) return Icons.directions_walk;
    if (typeLower.contains('cycle') || typeLower.contains('bike')) return Icons.pedal_bike;
    if (typeLower.contains('swim')) return Icons.pool;
    if (typeLower.contains('weight') || typeLower.contains('lift')) return Icons.fitness_center;
    if (typeLower.contains('yoga')) return Icons.self_improvement;
    if (typeLower.contains('meditate')) return Icons.spa;
    if (typeLower.contains('sport') || typeLower.contains('ball')) return Icons.sports_soccer;
    if (typeLower.contains('push') || typeLower.contains('squat')) return Icons.accessibility_new;
    return Icons.star_border;
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
            child: Text('Your Habits', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              value: _filter,
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All')),
                DropdownMenuItem(value: 'Ongoing', child: Text('Ongoing')),
                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _filter = value);
                }
              },
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 10),
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
                  return const Center(
                    child: Text('You haven’t set up your habit to track.', style: TextStyle(fontSize: 18)),
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
                    final double targetMax = (data['targetMax'] ?? 0).toDouble();
                    final double todayProgress = (data['todayProgress'] ?? 0).toDouble();
                    final int durationDays = data['durationDays'] ?? 1;
                    final int daysCompleted = data['daysCompleted'] ?? 0;
                    final String category = data['category'] ?? 'General';

                    final bool isHabitDone = daysCompleted >= durationDays;
                    final String progressLabel = isHabitDone ? 'Completed' : 'Ongoing';

                    final int categoryScore = categoryPoints[category] ?? 0;

                    final Timestamp? createdAt = data['createdAt'];
                    final DateTime startDate = createdAt?.toDate() ?? DateTime.now();
                    final int daysSinceStart = DateTime.now().difference(startDate).inDays + 1;
                    final double consistencyRatio =
                    PointingSystem.calculateConsistencyRatio(daysCompleted, daysSinceStart);

                    if (_filter == 'Completed' && !isHabitDone) return const SizedBox.shrink();
                    if (_filter == 'Ongoing' && isHabitDone) return const SizedBox.shrink();

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
                        ).then((_) {
                          _loadCategoryPoints();
                          setState(() {});
                        });
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
                            Row(
                              children: [
                                Icon(getHabitIcon(type), size: 20, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text('$type - $unit',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Frequency: $frequency',
                                style: const TextStyle(fontSize: 14, color: Colors.blue)),
                            Text('Minimum of $targetMin $unit'),
                            Text('Maximum of $targetMax $unit'),
                            Text('Days Passed: $daysSinceStart'),
                            Text('Days Logged: $daysCompleted / $durationDays'),

                            const SizedBox(height: 8),
                            const Text('Progress Today', style: TextStyle(fontWeight: FontWeight.bold)),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: (todayProgress / targetMax).clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade300,
                                color: todayProgress >= targetMin ? Colors.green : Colors.orange,
                              ),
                            ),
                            Text('$todayProgress / $targetMax $unit'),

                            const SizedBox(height: 12),
                            Text('Overall Progress: $progressLabel',
                                style: TextStyle(color: isHabitDone ? Colors.green : Colors.orange)),
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
                                const Icon(Icons.info_outline, size: 18, color: Colors.indigo),
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
                                      : Colors.red,
                                )),
                            const SizedBox(height: 10),
                            Text('🏆 $category Points: $categoryScore',
                                style: const TextStyle(color: Colors.deepPurple)),
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
