import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/addition/top_header.dart';
import '/addition/awesome_notifications.dart';
import '/utils/pointing_system.dart';
class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  List<Map<String, dynamic>> friends = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchFriends();
  }

  Future<void> fetchFriends() async {
    final friendsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .get();

    List<Map<String, dynamic>> temp = [];

    for (var doc in friendsSnap.docs) {
      final profileSnap = await FirebaseFirestore.instance
          .collection('Profiles')
          .doc(doc.id)
          .get();

      if (profileSnap.exists) {
        // ✅ Now fetch /users/{id} for points and rank
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .get();

        final userData = userSnap.data() ?? {};
        final int totalPoints = (userData['strengthPoints'] ?? 0) +
            (userData['cardioPoints'] ?? 0) +
            (userData['miscPoints'] ?? 0);

        String _getRankFromPoints(int points) {
          if (points >= 4000) return 'Grandmaster';
          if (points >= 1000) return 'Master';
          if (points >= 500) return 'Diamond';
          if (points >= 200) return 'Platinum';
          if (points >= 100) return 'Gold';
          if (points >= 50) return 'Silver';
          return 'Bronze';
        }

        final String rank = _getRankFromPoints(totalPoints);

        temp.add({
          'uid': doc.id,
          'name': profileSnap['Name'] ?? 'Unknown',
          'rank': rank,
          'points': totalPoints,
        });
      }
    }


    setState(() {
      friends = temp;
      loading = false;
    });
  }

  Future<Map<String, dynamic>?> getChallengeWithFriend(String friendId) async {
    final myChallengesSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('challenges')
        .get();

    for (var doc in myChallengesSnap.docs) {
      final data = doc.data();
      if ((data['senderId'] == user.uid && data['receiverId'] == friendId) ||
          (data['senderId'] == friendId && data['receiverId'] == user.uid)) {
        return data;
      }
    }

    return null;
  }


  Widget buildFriendCard(Map<String, dynamic> friend) {
    return FutureBuilder(
      future: getChallengeWithFriend(friend['uid']),
      builder: (context, snapshot) {
        final challenge = snapshot.data;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(friend['name'],

                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat')),
              const SizedBox(height: 4),
              Row(
                children: [
                  // 🏅 Badge
                  Image.asset(
                    'assets/badges/${friend['rank']
                        .toString()
                        .toLowerCase()}.png',
                    height: 40,
                    width: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                          Icons.emoji_events, size: 30, color: Colors.grey);
                    },
                  ),
                  // 🔠 Rank & Points
                  Text(
                    '${friend['rank']} • ${friend['points']} pts',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),


              if (challenge == null) ...[
                const SizedBox(height: 8),
                const Text("Challenge this friend to a habit fight?",
                    style: TextStyle(fontFamily: 'Montserrat')),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/challengeAddHabit',
                      arguments: {
                        'friendId': friend['uid'],
                        'friendName': friend['name'],
                      },
                    );
                  },
                  icon: SizedBox(
                    height: 24,
                    width: 24,
                    child: Image.asset('assets/images/sword.png'),
                  ),
                  label: const Text(
                    "Start Challenge",
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),

              ]

              else
                if (challenge['status'] == 'pending' &&
                    challenge['senderId'] == user.uid) ...[
                  const SizedBox(height: 8),
                  const Text("Waiting for them to accept the challenge.",
                      style: TextStyle(fontFamily: 'Montserrat')),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final challengeId = challenge['id'];

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('challenges')
                          .doc(challengeId)
                          .delete();

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(challenge['receiverId'])
                          .collection('challenges')
                          .doc(challengeId)
                          .delete();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Challenge cancelled.")),
                        );
                      }
                      final isSender = challenge['senderId'] == user.uid;
                      final progress = challenge[isSender
                          ? 'senderProgress'
                          : 'receiverProgress'];
                      final targetMax = challenge['targetMax'];
                      final percent = (progress / targetMax * 100)
                          .clamp(0, 100)
                          .toStringAsFixed(0);

                      setState(() {});
                    },
                    child: const Text(
                      "Waiting for Response. \n Wanna back down?",
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ]
                else
                  if (challenge['status'] == 'pending' &&
                      challenge['receiverId'] == user.uid) ...[
                    const SizedBox(height: 8),
                    const Text("This user has challenged you to a habit fight.",
                        style: TextStyle(fontFamily: 'Montserrat')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => acceptChallenge(challenge),
                          child: const Text("Accept",
                              style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => viewChallenge(challenge),
                          child: const Text("View Habit",
                              style: TextStyle(fontFamily: 'Montserrat')),
                        ),
                      ],
                    )
                  ]

                  else
                    if (challenge['status'] == 'accepted') ...[
                      const SizedBox(height: 2),
                      const Text("Challenge is Active!",
                          style: TextStyle(fontFamily: 'Montserrat',
                              color: Colors.green,
                              fontWeight: FontWeight.w300)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/challengeLogger',
                                  arguments: {'challengeData': challenge},
                                );
                              },
                              child: const Text(
                                "Track Challenge",
                                style: TextStyle(fontFamily: 'Montserrat',
                                    color: Colors.white,
                                    fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final currentUser = FirebaseAuth.instance
                                    .currentUser;
                                if (currentUser == null) return;

                                final String challengeId = challenge['id'];
                                final bool isSender = currentUser.uid ==
                                    challenge['senderId'];
                                final String opponentId = isSender
                                    ? challenge['receiverId']
                                    : challenge['senderId'];

                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUser.uid)
                                    .collection('challenges')
                                    .doc(challengeId)
                                    .update({
                                  'status': 'cancel_requested',
                                  'cancelRequestedBy': currentUser.uid,
                                  'cancelRequestedTo': opponentId,
                                });

                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(opponentId)
                                    .collection('challenges')
                                    .doc(challengeId)
                                    .update({
                                  'status': 'cancel_requested',
                                  'cancelRequestedBy': currentUser.uid,
                                  'cancelRequestedTo': opponentId,
                                });

                                NotificationService.showInstantNotification(
                                  "Challenge Update",
                                  "${currentUser.displayName ??
                                      'A user'} wants to cancel the challenge.",
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text(
                                        "Cancellation request sent.")),
                                  );
                                }

                                setState(() {});
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                backgroundColor: Colors.redAccent,
                              ),
                              child: const Text(
                                "Cancel Challenge?",
                                style: TextStyle(fontFamily: 'Montserrat',
                                    fontSize: 13,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),

                    ]

                    else
                      if (challenge['status'] == 'cancel_requested') ...[
                        const SizedBox(height: 8),
                        if (challenge['cancelRequestedBy'] == user.uid) ...[
                          const Text(
                            "Waiting for them to confirm cancellation...",
                            style: TextStyle(fontFamily: 'Montserrat'),
                          ),
                        ] else
                          if (challenge['cancelRequestedTo'] == user.uid) ...[
                            const Text(
                              "Your opponent wants to cancel this challenge.",
                              style: TextStyle(fontFamily: 'Montserrat'),
                            ),
                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        acceptCancellation(challenge),
                                    child: const Text(
                                      "Accept Cancel",
                                      style: TextStyle(fontFamily: 'Montserrat',
                                          color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Colors.greenAccent),
                                      foregroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      backgroundColor: Colors.greenAccent,
                                    ),
                                    onPressed: () =>
                                        declineCancellation(challenge),
                                    child: const Text(
                                      "Decline",
                                      style: TextStyle(fontFamily: 'Montserrat',
                                          fontSize: 13,
                                          color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          ],
                      ]


            ],
          ),
        );
      },
    );
  }

  void acceptCancellation(Map<String, dynamic> challenge) async {
    final id = challenge['id'];
    final senderId = challenge['senderId'];
    final receiverId = challenge['receiverId'];

    await FirebaseFirestore.instance
        .collection('users')
        .doc(senderId)
        .collection('challenges')
        .doc(id)
        .delete();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(receiverId)
        .collection('challenges')
        .doc(id)
        .delete();

    NotificationService.showInstantNotification(
      "Challenge Cancelled",
      "Both users agreed to cancel the challenge.",
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Challenge cancelled.")),
      );
      setState(() {});
    }
  }

  void declineCancellation(Map<String, dynamic> challenge) async {
    final id = challenge['id'];
    final senderId = challenge['senderId'];
    final receiverId = challenge['receiverId'];

    await FirebaseFirestore.instance
        .collection('users')
        .doc(senderId)
        .collection('challenges')
        .doc(id)
        .update({
      'status': 'accepted',
      'cancelRequestedBy': FieldValue.delete(),
      'cancelRequestedTo': FieldValue.delete()
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(receiverId)
        .collection('challenges')
        .doc(id)
        .update({
      'status': 'accepted',
      'cancelRequestedBy': FieldValue.delete(),
      'cancelRequestedTo': FieldValue.delete()
    });

    NotificationService.showInstantNotification(
      "Challenge Continued",
      "Your opponent declined the cancel request.",
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cancel declined. Challenge continues.")),
      );
      setState(() {});
    }
  }

  void acceptChallenge(Map<String, dynamic> challenge) async {
    final challengeId = challenge['id'];

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('challenges')
        .doc(challengeId)
        .update({'status': 'accepted'});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(challenge['senderId'])
        .collection('challenges')
        .doc(challengeId)
        .update({'status': 'accepted'});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Challenge accepted!")),
      );
    }

    setState(() {});
  }

  void viewChallenge(Map<String, dynamic> challenge) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Challenge Details",
              style: TextStyle(fontFamily: 'Montserrat')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Type: ${challenge['habitType']}",
                  style: const TextStyle(fontFamily: 'Montserrat')),
              Text("Duration: ${challenge['durationDays']} days",
                  style: const TextStyle(fontFamily: 'Montserrat')),
              Text(
                  "Target: ${challenge['targetMin']} - ${challenge['targetMax']}",
                  style: const TextStyle(fontFamily: 'Montserrat')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close",
                  style: TextStyle(fontFamily: 'Montserrat')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // TopHeader now handles its own top padding for status bar
          const TopHeader(),

          // Main content area with SafeArea for bottom only
          Expanded(
            child: SafeArea(
              top: false, // Disable top SafeArea since header handles it
              bottom: true,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        "Challenge Friends",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                          color: Colors.black,
                        ),
                      ),
                      const Divider(thickness: 1),
                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : friends.isEmpty
                            ? _buildEmptyState()
                            : _buildFriendsList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// Extracted widget methods for better readability
  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "🥺 You have no friends to challenge...",
          style: TextStyle(fontSize: 16, fontFamily: 'Montserrat'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/friends_screen'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          child: const Text(
            "Add One Now",
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: friends.length,
      itemBuilder: (context, index) => buildFriendCard(friends[index]),
    );
  }
}