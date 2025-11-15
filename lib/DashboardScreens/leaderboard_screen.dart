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
      backgroundColor: Colors.grey[50],
      body: Column(
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
                            'Leaderboard',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          _buildFilterChips(),
                        ],
                      ),
                    ),
                    // Leaderboard list
                    Expanded(
                      child: isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _buildLeaderboardList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterChip('Friends', filter == 'Friends'),
          _buildFilterChip('Global', filter == 'Global'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() => filter = label);
          fetchLeaderboard();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[700] : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardList() {
    if (rankedUsers.isEmpty) {
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
                  Icons.leaderboard_outlined,
                  size: 64,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Rankings Yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                filter == 'Friends'
                    ? 'Add friends to see rankings'
                    : 'Be the first to start competing!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: rankedUsers.length,
      itemBuilder: (context, index) {
        final user = rankedUsers[index];
        final rank = index + 1;
        final isCurrentUser = user['uid'] == currentUserId;
        final isTopThree = rank <= 3;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Rank Badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isTopThree
                        ? _getRankBackgroundColor(rank)
                        : Colors.grey.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isTopThree
                        ? Icon(
                            _getRankIcon(rank),
                            color: _getRankColor(rank),
                            size: 24,
                          )
                        : Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blue.shade50,
                  backgroundImage: user['photoUrl'] != null &&
                          user['photoUrl'].toString().isNotEmpty
                      ? NetworkImage(user['photoUrl'])
                      : null,
                  child: user['photoUrl'] == null ||
                          user['photoUrl'].toString().isEmpty
                      ? Text(
                          (user['name'] ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // Name and Points
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user['name'] ?? 'Anonymous',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[900],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentUser)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[700],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 12, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${user['points']} pts',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
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
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }

  Color _getRankBackgroundColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade50;
      case 2:
        return Colors.grey.shade50;
      case 3:
        return Colors.brown.shade50;
      default:
        return Colors.blue.shade50;
    }
  }

  IconData _getRankIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.looks_one;
      case 2:
        return Icons.looks_two;
      case 3:
        return Icons.looks_3;
      default:
        return Icons.star;
    }
  }
}
