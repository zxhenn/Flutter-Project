import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Builder for the profile header (name, photo, rank, points)
  // Similar to how you might display it in settings_page.dart
  Widget _buildProfileHeader(
      BuildContext context, {
        required String name,
        required String email, // Or other secondary info
        required String photoUrl,
        required String? rank,
        required int? points,
        required bool isLoadingStats,
      }) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[300],
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty ? Icon(Icons.person, size: 40, color: Colors.grey[700]) : null,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text( // Display email or another piece of info from 'Profiles'
                    email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  if (isLoadingStats)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0)),
                          SizedBox(width: 8),
                          Text("Loading stats..."),
                        ],
                      ),
                    )
                  else if (points != null && rank != null) ...[
                    Row(
                      children: [
                        Image.asset( // Assuming you have badge assets
                          'assets/badges/${rank.toLowerCase()}.png',
                          height: 40, width: 30,
                          errorBuilder: (context, error, stackTrace) => Icon(Icons.shield_outlined, size: 30, color: Colors.grey[400]),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rank, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text('$points Points', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'Rank and points data not available.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builder for a section title (reusable)
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16.0, 0, 8.0), // Adjusted padding for sections
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // Builder for displaying a list of habits (active or completed)
  // This would be very similar to what your analysis_screen.dart uses.
  // We pass the stream directly to this builder.
  Widget _buildHabitListSection(
      BuildContext context, {
        required String title,
        required Stream<QuerySnapshot<Map<String, dynamic>>> habitsStream,
        // required bool showAsActive, // You might not need this if the stream is already filtered
        // Or use it for subtle UI differences
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, title),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: habitsStream,
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
            if (snapshot.hasError) {
              print('Error loading habits for $title: ${snapshot.error}');
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Error loading habits.'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0),
                child: Center(
                  child: Text(
                    'No ${title.toLowerCase()} found.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            }

            // At this point, you have the habit documents.
            // You need to convert them to Habit objects and display them.
            // This is where your existing logic from analysis_screen.dart for displaying habits comes in.
            // For now, I'll put a placeholder list item.
            // Replace this ListView.builder with your actual habit list widget from analysis_screen.
            // You will likely pass snapshot.data!.docs to it, which will then map them to Habit objects.

            // EXAMPLE: (Replace with your actual habit item widget)
            return ListView.builder(
              shrinkWrap: true, // Important if this ListView is inside a Column/SingleChildScrollView
              physics: const NeverScrollableScrollPhysics(), // Also if nested
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final habitData = doc.data();
                // Assuming your Habit model and its fromFirestore method
                // final Habit habit = Habit.fromFirestore(doc);
                // return YourHabitListItemWidget(habit: habit);

                // Placeholder display:
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                  child: ListTile(
                    leading: Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary), // Example icon
                    title: Text(_getString(habitData, 'name', 'Unnamed Habit')),
                    // subtitle: Text(habit.category ?? ''), // Example
                    // trailing: Text('${habit.progress}/${habit.target}'), // Example
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Title can be dynamic if you want, e.g., "Friend's Profile"
        // or set it after loading the friend's name.
        title: const Text('Profile'),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (profileSnapshot.hasError || !profileSnapshot.data!.exists) {
            return const Center(child: Text('Could not load profile.'));
          }

          final profileData = profileSnapshot.data!.data();
          final String displayName = _getString(profileData, 'Name', 'User');
          final String email = _getString(profileData, 'Email'); // Assuming Email is in Profiles
          final String photoUrl = _getString(profileData, 'photoUrl', '');

          // Update AppBar title once name is loaded (optional)
          // WidgetsBinding.instance.addPostFrameCallback((_) {
          //   if (mounted && ModalRoute.of(context)?.isCurrent ?? false) {
          //     (context as Element).markNeedsBuild(); // Force rebuild for title if it's part of AppBar
          //   }
          // });

          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: _userFuture,
            builder: (context, userSnapshot) {
              String? rank;
              int? points;
              String? bio; // Assuming bio is fetched here
              bool isLoadingStats = true; // For the header part

              if (userSnapshot.connectionState == ConnectionState.done) {
                isLoadingStats = false;
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data();
                  points = (_getInt(userData, 'strengthPoints', 0)) +
                      (_getInt(userData, 'cardioPoints', 0)) +
                      (_getInt(userData, 'miscPoints', 0));
                  rank = _getString(userData, 'rank', 'Beginner');
                  bio = _getString(userData, 'bio', ''); // Fetch bio
                } else {
                  // Handle case where user document might not exist or error
                  print('User details (points/rank/bio) not found or error for ${widget.userId}');
                }
              }
              // If userSnapshot is still waiting, isLoadingStats remains true.

              // Stream for active habits of the friend
              final Stream<QuerySnapshot<Map<String, dynamic>>> activeHabitsStream =
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId) // Use friend's userId
                  .collection('habits')
                  .where('isCompleted', isEqualTo: false)
                  .snapshots();

              // Stream for completed habits of the friend
              final Stream<QuerySnapshot<Map<String, dynamic>>> completedHabitsStream =
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId) // Use friend's userId
                  .collection('habits')
                  .where('isCompleted', isEqualTo: true)
                  .snapshots();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // 1. Profile Header (reusing _buildProfileHeader)
                    _buildProfileHeader(
                      context,
                      name: displayName,
                      email: email,
                      photoUrl: photoUrl,
                      rank: rank,
                      points: points,
                      isLoadingStats: isLoadingStats,
                    ),

                    // 2. Bio Section (Optional, if you fetch and want to display bio)
                    if (bio != null && bio.isNotEmpty) ...[
                      _buildSectionTitle(context, 'About Me'),
                      Card(
                        margin: const EdgeInsets.only(bottom: 24.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            bio,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],

                    // 3. Active Habits Section (reusing _buildHabitListSection)
                    // This is similar to how your analysis_screen.dart would show habits.
                    _buildHabitListSection(
                      context,
                      title: 'Active Habits',
                      habitsStream: activeHabitsStream,
                    ),

                    const SizedBox(height: 24), // Spacing between sections

                    // 4. Completed Habits Section (reusing _buildHabitListSection)
                    _buildHabitListSection(
                      context,
                      title: 'Completed Habits',
                      habitsStream: completedHabitsStream,
                    ),

                    // Add more sections if needed (e.g., stats, mutual friends, etc.)
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