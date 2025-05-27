import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
// If pointing_system.dart is in lib/utils:
import '../utils/pointing_system.dart'; // Make sure this path is correct

// Habit model
class Habit {
  final String id;
  final String name;
  final String? description;
  final Timestamp? startDate;
  // final Timestamp? actualCompletionDate; // Optional: If you explicitly set this upon completion
  final String? type;
  final int? durationDays;
  final int? daysCompleted;

  Habit({
    required this.id,
    required this.name,
    this.description,
    this.startDate,
    // this.actualCompletionDate,
    this.type,
    this.durationDays,
    this.daysCompleted,
  });

  factory Habit.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Habit(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Habit',
      description: data['description'],
      startDate: data['startDate'] as Timestamp?,
      // actualCompletionDate: data['actualCompletionDate'] as Timestamp?,
      type: data['type'],
      durationDays: data['durationDays'] as int?,
      daysCompleted: data['daysCompleted'] as int?,
    );
  }

  // Helper to determine if a habit is completed based on your logic
  bool get isCompleted {
    if (durationDays == null || daysCompleted == null) {
      return false; // Not enough information to determine completion
    }
    if (durationDays == 0 && daysCompleted! >= 0) return true; // 0-day habits are complete if daysCompleted is not null
    return daysCompleted! >= durationDays!;
  }
}

class ViewProfileScreen extends StatefulWidget {
  final String userId; // The ID of the user whose profile is being viewed

  const ViewProfileScreen({super.key, required this.userId});

  static Route route({required String userId}) {
    return MaterialPageRoute(
      builder: (_) => ViewProfileScreen(userId: userId),
      settings: const RouteSettings(name: '/view_profile'),
    );
  }

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  // Reference to the 'Profiles' collection for basic info (name, email, photoUrl)
  // This assumes 'Profiles/{userId}' holds this basic info.
  // If all info is in 'users/{userId}', you might only need _userRef.
  late DocumentReference _profileRef;

  // Reference to the 'users' collection document for detailed info (bio, points, and habits subcollection)
  late DocumentReference _userRef;

  @override
  void initState() {
    super.initState();
    // Initialize Firestore references based on the userId of the profile being viewed
    _profileRef = FirebaseFirestore.instance.collection('Profiles').doc(widget.userId);
    _userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);

    print("ViewProfileScreen: Viewing profile for userId: ${widget.userId}");
    print("ViewProfileScreen: Path to user document: users/${widget.userId}");
    print("ViewProfileScreen: Path to habits subcollection: users/${widget.userId}/habits");
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent[700], // Theme color
          fontFamily: 'Montserrat',
        ),
      ),
    );
  }

  // Helper for displaying "No habits" messages
  Widget _buildNoHabitsMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600], fontSize: 15),
      ),
    );
  }

  // Widget to display a list of habits (the "mini dashboard" style)
  Widget _buildMiniHabitListView(List<Habit> habits, bool isCompletedList) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        String? dateInfo;
        String progressInfo = "";

        if (isCompletedList) {
          dateInfo = "Achieved: ${habit.durationDays ?? 'N/A'} days goal";
          // If you had an actualCompletionDate field and it was populated:
          // if (habit.actualCompletionDate != null) {
          //   dateInfo = 'Completed: ${DateFormat.yMMMd().format(habit.actualCompletionDate!.toDate())}';
          // }
        } else { // Active habits
          if (habit.startDate != null) {
            dateInfo = 'Started: ${DateFormat.yMMMd().format(habit.startDate!.toDate())}';
          }
          if (habit.durationDays != null && habit.durationDays! > 0) {
            double percentage = (habit.daysCompleted ?? 0).toDouble() / habit.durationDays!.toDouble();
            progressInfo = "Progress: ${habit.daysCompleted ?? 0}/${habit.durationDays} (${(percentage * 100).toStringAsFixed(0)}%)";
          } else if (habit.durationDays == 0) {
            progressInfo = "Goal: 0 days (Instantly achieved)";
          } else {
            progressInfo = "Progress: ${habit.daysCompleted ?? 0} days (Duration not set)";
          }
        }

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            leading: Icon(
              isCompletedList ? Icons.check_circle_outline_rounded : Icons.directions_run_rounded,
              color: isCompletedList ? Colors.green.shade600 : Colors.blue.shade700,
              size: 28,
            ),
            title: Text(
              habit.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15.5,
                fontFamily: 'Montserrat',
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (habit.description != null && habit.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3.0),
                    child: Text(
                      habit.description!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (dateInfo != null && dateInfo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      dateInfo,
                      style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: Colors.grey[600]),
                    ),
                  ),
                if (!isCompletedList && progressInfo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      progressInfo,
                      style: TextStyle(fontSize: 12.5, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Main content builder for the profile information
 // From 'users/{userId}' document (for bio, points)
// (Assuming the code above this point is the same as the last complete version you received)
// ... (imports, Habit class, ViewProfileScreen StatefulWidget, _ViewProfileScreenState initState, _buildSectionTitle, _buildNoHabitsMessage, _buildMiniHabitListView) ...

  // Main content builder for the profile information
  Widget _buildProfileContent(
      BuildContext context,
      String name,
      String email,
      String? photoUrl,
      Map<String, dynamic>? userDetailData, // Parameter for user details
      Widget? userDetailLoadingIndicator  // Parameter for the loading indicator
      ) {
  String bio = "This user hasn't shared a bio yet.";
  int points = 0;
  String rank = "Beginner"; // Default rank

  if (userDetailData != null) {
  bio = userDetailData['bio'] as String? ?? "This user hasn't shared a bio yet.";
  // Assuming points are stored as individual fields in userDetailData
  points = (userDetailData['strengthPoints'] as int? ?? 0) +
  (userDetailData['cardioPoints'] as int? ?? 0) +
  (userDetailData['miscPoints'] as int? ?? 0);
  rank = PointingSystem.getRankFromPoints(points); // Ensure PointingSystem is correctly imported and implemented
  }

  return SingleChildScrollView(
  padding: const EdgeInsets.only(bottom: 30), // Padding at the bottom for scrollability
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: <Widget>[
  // Profile Header Card
  Container(
  margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
  padding: const EdgeInsets.all(20.0),
  decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
  BoxShadow(
  color: Colors.grey.withOpacity(0.2),
  spreadRadius: 2,
  blurRadius: 8,
  offset: const Offset(0, 4),
  ),
  ],
  ),
  child: Row(
  children: [
  CircleAvatar(
  radius: 40,
  backgroundColor: Colors.blue.shade100,
  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
  ? NetworkImage(photoUrl)
      : null,
  child: photoUrl == null || photoUrl.isEmpty
  ? Icon(Icons.person, size: 48, color: Colors.blue.shade700)
      : null,
  ),
  const SizedBox(width: 20),
  Expanded(
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  Text(
  name,
  style: const TextStyle(
  fontFamily: 'Montserrat',
  fontSize: 22,
  fontWeight: FontWeight.bold,
  ),
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  ),
  const SizedBox(height: 6),
  Text(
  email,
  style: TextStyle(
  fontFamily: 'Montserrat',
  fontSize: 14,
  color: Colors.grey[600],
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  ),
  const SizedBox(height: 12),
  // Rank and Points - Shown if userDetailData is loaded or if there's no loading indicator for it
  if (userDetailData != null || userDetailLoadingIndicator == null)
  Row(
  children: [
  // Ensure you have these badge images in assets/badges/
  Image.asset(
  'assets/badges/${rank.toLowerCase()}.png',
  height: 50,
  width: 40,
  errorBuilder: (context, error, stackTrace) {
  return Icon(Icons.shield_outlined, size: 30, color: Colors.grey[400]); // Fallback
  },
  ),
  const SizedBox(width: 8),
  Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  Text(
  rank,
  style: const TextStyle(
  fontFamily: 'Montserrat',
  fontSize: 17,
  fontWeight: FontWeight.bold,
  ),
  ),
  Text(
  '$points Points',
  style: TextStyle(
  fontFamily: 'Montserrat',
  fontSize: 13,
  color: Colors.grey[700],
  ),
  ),
  ],
  ),
  ],
  ),
  // Show loading indicator for points/rank if userDetailData is still loading
  if (userDetailLoadingIndicator != null && userDetailData == null)
  Padding(
  padding: const EdgeInsets.only(top: 8.0),
  child: userDetailLoadingIndicator,
  ),
  ],
  ),
  ),
  ],
  ),
  ),

  // Bio Section
  if (userDetailData != null || userDetailLoadingIndicator == null) // Show if data loaded or not loading details
  Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  child: Card(
  elevation: 1.5,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  child: Padding(
  padding: const EdgeInsets.all(16.0),
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  Text(
  "About ${name.split(" ")[0]}", // "About [FirstName]"
  style: TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.bold,
  color: Colors.blueAccent[700],
  fontFamily: 'Montserrat',
  ),
  ),
  const SizedBox(height: 10),
  Text(
  bio,
  style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.4),
  ),
  ],
  ),
  ),
  ),
  ),
  if (userDetailLoadingIndicator != null && userDetailData == null) // Loading for bio
  Padding(
  padding: const EdgeInsets.all(16.0),
  child: userDetailLoadingIndicator,
  ),


  // Habits Section (Active and Completed)
  // StreamBuilder for ALL habits of the VIEWED USER from 'users/{userId}/habits'
  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
  stream: _userRef.collection('habits') // Query the 'habits' subcollection of the specific user
      .orderBy('startDate', descending: true) // Example: order by start date
      .snapshots(),
  builder: (context, habitSnapshot) {
  if (habitSnapshot.hasError) {
  print("Error loading habits for ${widget.userId}: ${habitSnapshot.error}");
  return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  child: Text('Error loading habits.', style: const TextStyle(color: Colors.red)),
  );
  }
  if (habitSnapshot.connectionState == ConnectionState.waiting) {
  return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)));
  }
  if (!habitSnapshot.hasData || habitSnapshot.data!.docs.isEmpty) {
  return _buildNoHabitsMessage('This user is not tracking any habits yet.');
  }

  final allHabits = habitSnapshot.data!.docs.map((doc) => Habit.fromFirestore(doc)).toList();

  final activeHabits = allHabits.where((habit) => !habit.isCompleted).toList();
  final completedHabits = allHabits.where((habit) => habit.isCompleted).toList();

  return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  _buildSectionTitle('Active Habits (${activeHabits.length})'),
  activeHabits.isEmpty
  ? _buildNoHabitsMessage('No active habits being tracked by this user.')
      : _buildMiniHabitListView(activeHabits, false),

  _buildSectionTitle('Completed Habits (${completedHabits.length})'),
// (Code before this line is assumed to be the same as the previous correct segment)
_buildSectionTitle('Completed Habits (${completedHabits.length})'),
  completedHabits.isEmpty
  ? _buildNoHabitsMessage('This user has not completed any habits yet.')
      : _buildMiniHabitListView(completedHabits, true),
  ],
  );
  },
  ),
  ],
  ),
  );
  }

  @override
  Widget build(BuildContext context) {
  // This uses a nested StreamBuilder approach:
  // 1. Outer StreamBuilder for 'Profiles/{userId}' (name, email, photoUrl).
  // 2. Inner StreamBuilder for 'users/{userId}' (bio, points - which also contains habits subcollection).
  // This is because these might be two separate documents. If all info is in 'users/{userId}',
  // you could simplify to a single StreamBuilder.

  return Scaffold(
  appBar: AppBar(
  title: const Text(
  'User Profile',
  style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
  ),
  backgroundColor: Colors.blueAccent[700], // Example AppBar color
  elevation: 2,
  ),
  body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
  stream: _profileRef.snapshots() as Stream<DocumentSnapshot<Map<String, dynamic>>>,
  builder: (context, profileSnapshot) {
  if (profileSnapshot.hasError) {
  print("Error loading profile data for ${widget.userId} from 'Profiles': ${profileSnapshot.error}");
  return Center(child: Text('Error loading profile: ${profileSnapshot.error}', style: const TextStyle(color: Colors.red)));
  }
  if (profileSnapshot.connectionState == ConnectionState.waiting) {
  return const Center(child: CircularProgressIndicator());
  }
  if (!profileSnapshot.hasData || !profileSnapshot.data!.exists) {
  print("Profile document not found for ${widget.userId} in 'Profiles'");
  return const Center(child: Text('User profile not found.'));
  }

  // Basic profile data from 'Profiles' collection
  final profileData = profileSnapshot.data!.data();
  final String name = profileData?['displayName'] as String? ?? profileData?['name'] as String? ?? 'N/A';
  final String email = profileData?['email'] as String? ?? 'No email provided';
  final String? photoUrl = profileData?['photoURL'] as String?;

  // Now, StreamBuilder for 'users/{userId}' document (bio, points)
  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
  stream: _userRef.snapshots() as Stream<DocumentSnapshot<Map<String, dynamic>>>,
  builder: (context, userDetailSnapshot) {
  Widget? userDetailLoadingIndicator;
  Map<String, dynamic>? userDetailData;

  if (userDetailSnapshot.connectionState == ConnectionState.waiting && !userDetailSnapshot.hasData) {
  // Only show top-level loading for details if profile data is already loaded
  // and details are still coming.
  if(profileSnapshot.hasData) {
  userDetailLoadingIndicator = const Padding(
  padding: EdgeInsets.symmetric(vertical: 8.0),
  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
  );
  }
  }
  if (userDetailSnapshot.hasError) {
  print("Error loading user details for ${widget.userId} from 'users': ${userDetailSnapshot.error}");
  // You might choose to show the profile with an error message for details,
  // or handle it more gracefully. For now, we'll allow content to build.
  }
  if (userDetailSnapshot.hasData && userDetailSnapshot.data!.exists) {
  userDetailData = userDetailSnapshot.data!.data();
  } else if (userDetailSnapshot.hasData && !userDetailSnapshot.data!.exists) {
  print("User details document not found for ${widget.userId} in 'users'. Bio/Points might be missing.");
  // User document in 'users' collection doesn't exist, proceed with default/empty values.
  }

  return _buildProfileContent(
  context,
  name,
  email,
  photoUrl,
  userDetailData,
  userDetailLoadingIndicator,
  );
  },
  );
  },
  ),
  );
  }
}
