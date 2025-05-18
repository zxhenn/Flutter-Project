import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/utils/pointing_system.dart'; // Adjust import
import '/addition/top_header.dart';


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
      final friendId = doc.id;

      final profileSnap = await FirebaseFirestore.instance
          .collection('Profiles')
          .doc(friendId)
          .get();

      final profileData = profileSnap.data();

      final points = await PointingSystem.getTotalPoints(friendId);
      final rank = PointingSystem.getRankFromPoints(points);

      temp.add({
        'uid': friendId,
        'name': profileData?['name'] ?? 'Unknown',
        'points': points,
        'rank': rank,
      });
    }

    setState(() {
      friends = temp;
      loading = false;
    });
  }

  Future<Map<String, dynamic>?> getChallenge(String friendId) async {
    final challengeSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('challenges')
        .where('receiverId', isEqualTo: friendId)
        .where('status', whereIn: ['accepted', 'pending'])
        .get();

    if (challengeSnap.docs.isEmpty) {
      return null;
    }

    return {
      'id': challengeSnap.docs.first.id,
      ...challengeSnap.docs.first.data(),
    };
  }

  void openAddScreenForChallenge(Map<String, dynamic> friend) {
    // Navigate to add_screen.dart in challenge mode
    Navigator.pushNamed(context, '/add', arguments: {
      'challengeMode': true,
      'friendId': friend['uid'],
      'friendName': friend['name']
    });
  }

  void acceptChallenge(String challengeId, String friendId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('challenges')
        .doc(challengeId)
        .update({'status': 'accepted'});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(friendId)
        .collection('challenges')
        .doc(challengeId)
        .update({'status': 'accepted'});

    setState(() {}); // Refresh UI
  }

  void declineChallenge(String challengeId, String friendId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('challenges')
        .doc(challengeId)
        .update({'status': 'rejected'});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(friendId)
        .collection('challenges')
        .doc(challengeId)
        .update({'status': 'rejected'});

    setState(() {}); // Refresh UI
  }

  Widget buildFriendCard(Map<String, dynamic> friend) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: getChallenge(friend['uid']),
      builder: (context, snapshot) {
        final challenge = snapshot.data;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(friend['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("${friend['points']} pts • Rank: ${friend['rank']}"),
              const SizedBox(height: 8),
              if (challenge == null)
                GestureDetector(
                  onTap: () => openAddScreenForChallenge(friend),
                  child: Column(
                    children: const [
                      Icon(Icons.sports_kabaddi, size: 30, color: Colors.red),
                      Text("Challenge friend", style: TextStyle(color: Colors.red)),
                    ],
                  ),
                )
              else if (challenge['status'] == 'pending' && challenge['receiverId'] == user.uid)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${friend['name']} challenged you!", style: const TextStyle(color: Colors.orange)),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => acceptChallenge(challenge['id'], friend['uid']),
                          child: const Text("Accept"),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () => declineChallenge(challenge['id'], friend['uid']),
                          child: const Text("Decline"),
                        ),
                      ],
                    )
                  ],
                )
              else if (challenge['status'] == 'accepted')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Challenge: ${challenge['challengeType']}"),
                      Text("Target: ${challenge['target']}"),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/challengeLogger',
                            arguments: {
                              'challengeId': challenge['id'],
                              'challengeData': challenge,
                            },
                          );
                        },
                        child: const Text("Track Challenge"),
                      ),
                    ],
                  )
                else
                  const Text("No challenge yet")
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const TopHeader(), // your existing top header layout

                const SizedBox(height: 8),
                const Text(
                  "Challenge Friends",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Divider(thickness: 1),

                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : friends.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "🥺 You have no friends to challenge...",
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Montserrat',
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/friends_screen',
                              arguments: {'triggerAdd': true},
                            );
                          },
                          child: const Text(
                            "Add one now!",
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) =>
                        buildFriendCard(friends[index]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


}
