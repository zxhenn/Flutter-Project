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
  import '/rewards/powerup_manager.dart';
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
      const AddScreen(),
      const FriendsScreen(),
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
    String getPowerupAssetPath(String type) {
      switch (type.toLowerCase()) {
        case 'cardio':
        case 'cardio_charge':
          return 'assets/boosts/cardio_charge.png';
        case 'strength':
        case 'iron_boost':
          return 'assets/boosts/iron_boost.png';
        case 'custom':
        case 'focus_boost':
          return 'assets/boosts/focus_boost.png';
        default:
          return 'assets/boosts/default.png';
      }
    }
  
    Map<String, dynamic> categoryPoints = {};
    String _filter = 'All';
    String? powerupAssetPath;
  
    @override
    void initState() {
      super.initState();
  
      PowerupManager.getTodayPowerup().then((powerup) {
        if (powerup != null) {
          setState(() {
            powerupAssetPath = getPowerupAssetPath(powerup['type']);
          });
        }
      });
    }
  
  
    Future<void> _loadCategoryPoints() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !mounted) return;
  
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
  
      setState(() {
        categoryPoints = {
          'Strength Training': data['strengthPoints'] ?? 0,
          'Cardiovascular Fitness': data['cardioPoints'] ?? 0,
          'Custom': data['miscPoints'] ?? 0,
        };
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
  
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TopHeader(),
          Expanded(
            child: SafeArea(
              top: false,
              child: Container(
                color: Colors.grey[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Your Habits',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          // Filter Chip
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: DropdownButton<String>(
                              value: _filter,
                              items: const [
                                DropdownMenuItem(
                                  value: 'All',
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('All'),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Ongoing',
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('Ongoing'),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Completed',
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('Completed'),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _filter = value);
                                }
                              },
                              underline: const SizedBox(),
                              icon: Icon(Icons.filter_list, size: 20, color: Colors.grey[600]),
                              isDense: true,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
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
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.track_changes,
                                        size: 64,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'No Habits Yet',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Start tracking your habits to see them here',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 32),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => const AddScreen()),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[700],
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 32, vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: const Text(
                                        'Create Habit',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => const ChallengeScreen()),
                                        );
                                      },
                                      child: Text(
                                        'Or join a challenge',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final habits = snapshot.data!.docs;

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            itemCount: habits.length,
                            itemBuilder: (context, index) {
                            final doc = habits[index];
                            final data = doc.data() as Map<String, dynamic>;
  
                            final String type = data['type'] ?? 'Habit';
                            final String unit = data['unit'] ?? '';
                            final String frequency = data['frequency'] ?? 'Daily';
                            final double targetMin = data['targetMin'] ?? 0;
                            final double targetMax = (data['targetMax'] ?? 0)
                                .toDouble();
                            final double todayProgress = (data['todayProgress'] ??
                                0).toDouble();
                            final int durationDays = data['durationDays'] ?? 1;
                            final int daysLogged = data['daysLogged'] ?? 0;
                            final String category = data['category'] ?? 'General';
  
                            final bool isHabitDone = daysLogged >= durationDays;
                            final double overallProgressRatio = data['overallProgressRatio'] ??
                                0.0;
                            final String overallProgressLabel = '${(overallProgressRatio *
                                100).toStringAsFixed(1)}%';
  
                            final int categoryScore = categoryPoints[category] ??
                                0;
  
                            final DateTime createdAt = (data['createdAt'] as Timestamp?)
                                ?.toDate() ?? DateTime.now();
                            final int daysPassed = data['daysPassed'] ?? 1;
                            final double consistencyRatio =
                                data['consistencyRatio'] ?? 0.0;
  
                            if (_filter == 'Completed' && !isHabitDone)
                              return const SizedBox.shrink();
                            if (_filter == 'Ongoing' && isHabitDone)
                              return const SizedBox.shrink();
  
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header Section
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isHabitDone
                                            ? Colors.green.shade50
                                            : Colors.blue.shade50,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          topRight: Radius.circular(16),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              getHabitIcon(type),
                                              size: 24,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  type,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey[900],
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '$unit • $frequency',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isHabitDone)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                'Completed',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          PopupMenuButton(
                                            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete, size: 20, color: Colors.red[600]),
                                                    const SizedBox(width: 8),
                                                    Text('Delete', style: TextStyle(color: Colors.red[600])),
                                                  ],
                                                ),
                                                onTap: () async {
                                                  await Future.delayed(Duration.zero);
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      title: const Text('Delete Habit'),
                                                      content: const Text(
                                                          'Are you sure you want to delete this habit?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context, false),
                                                          child: const Text('Cancel'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context, true),
                                                          child: Text(
                                                            'Delete',
                                                            style: TextStyle(color: Colors.red[600]),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true && mounted) {
                                                    await FirebaseFirestore.instance
                                                        .collection('users')
                                                        .doc(FirebaseAuth.instance.currentUser!.uid)
                                                        .collection('habits')
                                                        .doc(doc.id)
                                                        .delete();
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Content Section
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Today's Progress
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Today\'s Progress',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              Text(
                                                '$todayProgress / $targetMax $unit',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[900],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: LinearProgressIndicator(
                                              value: (todayProgress / targetMax).clamp(0.0, 1.0),
                                              minHeight: 10,
                                              backgroundColor: Colors.grey.shade200,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                todayProgress >= targetMin
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                          ),
                                          
                                          const SizedBox(height: 20),
                                          
                                          // Overall Progress
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Overall Progress',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              Text(
                                                overallProgressLabel,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: isHabitDone
                                                      ? Colors.green
                                                      : Colors.orange,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: LinearProgressIndicator(
                                              value: (daysLogged / durationDays).clamp(0.0, 1.0),
                                              minHeight: 10,
                                              backgroundColor: Colors.grey.shade200,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                isHabitDone ? Colors.green : Colors.blue[700]!,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '$daysLogged / $durationDays days',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          
                                          const SizedBox(height: 20),
                                          
                                          // Consistency
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.trending_up, size: 16, color: Colors.grey[700]),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Consistency',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                '${(consistencyRatio * 100).toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: consistencyRatio >= 0.9
                                                      ? Colors.green
                                                      : consistencyRatio >= 0.6
                                                          ? Colors.orange
                                                          : Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: LinearProgressIndicator(
                                              value: consistencyRatio,
                                              minHeight: 8,
                                              backgroundColor: Colors.grey.shade200,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                consistencyRatio >= 0.9
                                                    ? Colors.green
                                                    : consistencyRatio >= 0.6
                                                        ? Colors.orange
                                                        : Colors.red,
                                              ),
                                            ),
                                          ),
                                          
                                          const SizedBox(height: 16),
                                          
                                          // Points
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.star, size: 20, color: Colors.amber),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '$category Points: $categoryScore',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                              ],
                                            ),
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
              ),
            ),
          ),
        ],
      );
    }
  }
