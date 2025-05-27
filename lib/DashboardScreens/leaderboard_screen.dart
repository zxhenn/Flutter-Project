import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/addition/top_header.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> rankedUsers = [];
  bool isLoading = true;
  String filter = 'Friends';

  @override
  void initState() {
    super.initState();
    fetchLeaderboard();
  }

  Future<void> fetchLeaderboard() async {
    setState(() => isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentUserId = user.uid;
    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    final profileDoc = await FirebaseFirestore.instance
        .collection('Profiles')
        .doc(currentUserId)
        .get();

    final currentUserName = currentUserDoc.data()?['displayName'] ?? 'You';
    final photoUrl = profileDoc.data()?['photoUrl'] ?? '';
    final currentUserData = currentUserDoc.data() ?? {};
    final currentUserPoints = (currentUserData['strengthPoints'] ?? 0)
        + (currentUserData['cardioPoints'] ?? 0)
        + (currentUserData['miscPoints'] ?? 0);


    List<Map<String, dynamic>> allUsers = [];

    if (filter == 'Friends') {
      allUsers.add({
        'uid': currentUserId,
        'name': currentUserName,
        'points': currentUserPoints,
        'photoUrl': photoUrl,
      });

      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .get();

      for (final friendDoc in friendsSnapshot.docs) {
        final friendId = friendDoc.id;
        final friendUserDoc = await FirebaseFirestore.instance.collection(
            'users').doc(friendId).get();
        final friendProfileDoc = await FirebaseFirestore.instance.collection(
            'Profiles').doc(friendId).get();

        if (friendUserDoc.exists) {
          final friendName =
              friendProfileDoc.data()?['Name'] ?? // 👈 comes from profile setup
                  friendUserDoc
                      .data()?['displayName'] ?? // fallback to Google name
                  'Friend';

          final data = friendUserDoc.data() ?? {};
          final friendPoints = (data['strengthPoints'] ?? 0) +
              (data['cardioPoints'] ?? 0) +
              (data['miscPoints'] ?? 0);
          final friendPhotoUrl = friendProfileDoc.data()?['photoUrl'] ?? '';

          allUsers.add({
            'uid': friendId,
            'name': friendName,
            'points': friendPoints,
            'photoUrl': friendPhotoUrl,
          });
        }
      }
    } else if (filter == 'Global') {
      final allUserDocs = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (final doc in allUserDocs.docs) {
        final userData = doc.data();
        final profileDoc = await FirebaseFirestore.instance.collection(
            'Profiles').doc(doc.id).get();

        final name = profileDoc.data()?['Name'] ??
            userData['displayName'] ??
            'User';

        final points = (userData['strengthPoints'] ?? 0) +
            (userData['cardioPoints'] ?? 0) +
            (userData['miscPoints'] ?? 0);

        final photoUrl = profileDoc.data()?['photoUrl'] ?? '';

        allUsers.add({
          'uid': doc.id,
          'name': name,
          'points': points,
          'photoUrl': photoUrl,
        });
      }
    }

    allUsers.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

    setState(() {
      rankedUsers = allUsers;
      isLoading = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header with built-in status bar handling
          const TopHeader(),

          // Main content with bottom-only SafeArea
          Expanded(
            child: SafeArea(
              top: false, // Disable top padding since header handles it
              bottom: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and filter dropdown
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Leaderboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        DropdownButton<String>(
                          value: filter,
                          underline: Container(),
                          // Remove default underline
                          borderRadius: BorderRadius.circular(12),
                          items: const [
                            DropdownMenuItem(
                              value: 'Friends',
                              child: Text(
                                'Friends',
                                style: TextStyle(fontFamily: 'Montserrat'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Global',
                              child: Text(
                                'Global',
                                style: TextStyle(fontFamily: 'Montserrat'),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => filter = value);
                              fetchLeaderboard();
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  // Leaderboard list
                  Expanded(
                    child: isLoading
                        ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blue,
                      ),
                    )
                        : _buildLeaderboardList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rankedUsers.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = rankedUsers[index];
        final rank = index + 1;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rank indicator
                Container(
                  width: 32,
                  alignment: Alignment.center,
                  child: Text(
                    rank == 1 ? '🥇' :
                    rank == 2 ? '🥈' :
                    rank == 3 ? '🥉' : '$rank',
                    style: TextStyle(
                      fontSize: rank <= 3 ? 20 : 16,
                      color: rank > 3 ? Colors.blue : Colors.amber[700],
                    ),
                  ),
                ),

                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundImage: user['photoUrl']?.isNotEmpty == true
                      ? NetworkImage(user['photoUrl'])
                      : const AssetImage('assets/images/default_avatar.png')
                  as ImageProvider,
                ),
              ],
            ),
            title: Text(
              user['name'] ?? 'Anonymous',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Text(
              '${user['points']} pts',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        );
      },
    );
  }
}
