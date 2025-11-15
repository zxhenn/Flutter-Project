import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/utils/pointing_system.dart';

// --- IMPORTANT: Ensure you have your Habit model definition ---
// If it's not in a separate file, you might have it directly in
// analysis_screen.dart or another shared location.
// For this example, I'll assume it's defined as we discussed earlier.
// If it's defined elsewhere, adjust the import.
//
// class Habit { ... } // (Your Habit model definition)
// import 'path/to/your/habit_model.dart'; // Or wherever it is

// If your Habit class is indeed the one from the file context, we can use that.
// (The one provided in the context is a good example)

class ViewProfileScreen extends StatefulWidget {
  final String userId; // The ID of the friend whose profile is being viewed

  const ViewProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _profileFuture;
  late Future<DocumentSnapshot<Map<String, dynamic>>> _userFuture;

  @override
  void initState() {
    super.initState();
    // Fetch from '/Profiles/{userId}' (for name, email, photoUrl)
    _profileFuture = FirebaseFirestore.instance
        .collection('Profiles')
        .doc(widget.userId)
        .get() as Future<DocumentSnapshot<Map<String, dynamic>>>;

    // Fetch from '/users/{userId}' (for points, rank, bio, and potentially base for habits subcollection)
    _userFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get() as Future<DocumentSnapshot<Map<String, dynamic>>>;
  }

  String _getString(Map<String, dynamic>? data, String key, [String defaultValue = 'N/A']) {
    return data?[key] as String? ?? defaultValue;
  }

  int _getInt(Map<String, dynamic>? data, String key, [int defaultValue = 0]) {
    return data?[key] as int? ?? defaultValue;
  }

  // --- Reusable UI Builders ---
  // You might extract these into a shared utility file if used in many places.

  Widget _buildProfileHeader(
      BuildContext context, {
        required String name,
        required String email,
        required String photoUrl,
        required String? rank,
        required int? points,
        required bool isLoadingStats,
      }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue.shade50,
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Icon(Icons.person, size: 50, color: Colors.blue[700])
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          if (isLoadingStats)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2.0),
            )
          else if (points != null && rank != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        rank,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '$points pts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Text(
              'Stats not available',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey[900],
        ),
      ),
    );
  }

  Widget _buildHabitListSection({
    required String title,
    required Stream<QuerySnapshot<Map<String, dynamic>>> habitsStream,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: habitsStream,
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
            if (snapshot.hasError) {
              print('Error loading habits for $title: ${snapshot.error}');
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Error loading habits.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No ${title.toLowerCase()}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This user hasn\'t created any ${title.toLowerCase()} yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final habitData = doc.data();
                final type = _getString(habitData, 'type', 'Habit');
                final unit = _getString(habitData, 'unit', '');
                final isCompleted = habitData['isComplete'] ?? false;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check_circle : Icons.timer,
                          color: isCompleted ? Colors.green[700] : Colors.blue[700],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[900],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              unit,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              const Text(
                                'Complete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[900]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (profileSnapshot.hasError || !profileSnapshot.data!.exists) {
            return Center(
              child: Text(
                'Could not load profile.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          final profileData = profileSnapshot.data!.data();
          final String displayName = _getString(profileData, 'Name', 'User');
          final String email = _getString(profileData, 'Email');
          final String photoUrl = _getString(profileData, 'photoUrl', '');

          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: _userFuture,
            builder: (context, userSnapshot) {
              String? rank;
              int? points;
              String? bio;
              bool isLoadingStats = true;

              if (userSnapshot.connectionState == ConnectionState.done) {
                isLoadingStats = false;
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data();
                  points = (_getInt(userData, 'strengthPoints', 0)) +
                      (_getInt(userData, 'cardioPoints', 0)) +
                      (_getInt(userData, 'miscPoints', 0));
                  rank = PointingSystem.getRankFromPoints(points ?? 0);
                  bio = _getString(userData, 'bio', '');
                } else {
                  points = 0;
                  rank = PointingSystem.getRankFromPoints(0);
                }
              }

              // Stream for active habits
              final Stream<QuerySnapshot<Map<String, dynamic>>> activeHabitsStream =
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .collection('habits')
                  .where('isComplete', isEqualTo: false)
                  .snapshots();

              // Stream for completed habits
              final Stream<QuerySnapshot<Map<String, dynamic>>> completedHabitsStream =
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .collection('habits')
                  .where('isComplete', isEqualTo: true)
                  .snapshots();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Profile Header
                    _buildProfileHeader(
                      context,
                      name: displayName,
                      email: email,
                      photoUrl: photoUrl,
                      rank: rank,
                      points: points,
                      isLoadingStats: isLoadingStats,
                    ),
                    const SizedBox(height: 24),

                    // Bio Section
                    if (bio != null && bio.isNotEmpty) ...[
                      _buildSectionTitle('About Me'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                bio,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Active Habits Section
                    _buildHabitListSection(
                      title: 'Active Habits',
                      habitsStream: activeHabitsStream,
                    ),
                    const SizedBox(height: 24),

                    // Completed Habits Section
                    _buildHabitListSection(
                      title: 'Completed Habits',
                      habitsStream: completedHabitsStream,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}