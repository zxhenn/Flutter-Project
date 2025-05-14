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
    final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    final currentUserName = currentUserDoc.data()?['displayName'] ?? 'You';
    final currentUserCategoryPoints = currentUserDoc.data()?['categoryPoints'] ?? {};
    final currentUserPoints = (currentUserCategoryPoints as Map<String, dynamic>)
        .values
        .fold(0, (sum, val) => sum + (val is int ? val : 0));

    List<Map<String, dynamic>> allUsers = [];

    if (filter == 'Friends') {
      allUsers.add({
        'uid': currentUserId,
        'name': currentUserName,
        'points': currentUserPoints,
      });

      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .get();

      for (final friendDoc in friendsSnapshot.docs) {
        final friendId = friendDoc.id;
        final friendUserDoc = await FirebaseFirestore.instance.collection('users').doc(friendId).get();

        if (friendUserDoc.exists) {
          final friendName = friendUserDoc.data()?['displayName'] ?? 'Friend';
          final friendCategoryPoints = friendUserDoc.data()?['categoryPoints'] ?? {};
          final friendPoints = (friendCategoryPoints as Map<String, dynamic>)
              .values
              .fold(0, (sum, val) => sum + (val is int ? val : 0));

          allUsers.add({
            'uid': friendId,
            'name': friendName,
            'points': friendPoints,
          });
        }
      }
    } else if (filter == 'Global') {
      final allUserDocs = await FirebaseFirestore.instance.collection('users').get();

      for (final doc in allUserDocs.docs) {
        final userData = doc.data();
        final name = userData['displayName'] ?? 'User';
        final categoryPoints = userData['categoryPoints'] ?? {};
        final points = (categoryPoints as Map<String, dynamic>)
            .values
            .fold(0, (sum, val) => sum + (val is int ? val : 0));

        allUsers.add({
          'uid': doc.id,
          'name': name,
          'points': points,
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TopHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Leaderboard',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  DropdownButton<String>(
                    value: filter,
                    items: const [
                      DropdownMenuItem(value: 'Friends', child: Text('Friends')),
                      DropdownMenuItem(value: 'Global', child: Text('Global')),
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
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                itemCount: rankedUsers.length,
                itemBuilder: (context, index) {
                  final user = rankedUsers[index];
                  final rank = index + 1;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: rank == 1
                          ? Colors.amber
                          : rank == 2
                          ? Colors.grey
                          : rank == 3
                          ? Colors.brown
                          : Colors.blue,
                      child: Text('$rank', style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(user['name']),
                    trailing: Text('${user['points']} pts', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
