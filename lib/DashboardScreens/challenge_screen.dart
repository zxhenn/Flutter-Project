import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      final profileSnap = await FirebaseFirestore.instance
          .collection('Profiles')
          .doc(doc.id)
          .get();

      if (profileSnap.exists) {
        temp.add({
          'uid': doc.id,
          'name': profileSnap['Name'] ?? 'Unknown',
        });
      }
    }

    setState(() {
      friends = temp;
      loading = false;
    });
  }

  Future<Map<String, dynamic>?> getChallengeWithFriend(String friendId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('challenges')
        .where('receiverId', isEqualTo: friendId)
        .get();

    if (snap.docs.isEmpty) {
      final sentSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('challenges')
          .where('senderId', isEqualTo: friendId)
          .get();

      if (sentSnap.docs.isNotEmpty) {
        return sentSnap.docs.first.data();
      }

      return null;
    }

    return snap.docs.first.data();
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
                  icon: const Icon(Icons.sports_kabaddi),
                  label: const Text("Start Challenge",
                      style: TextStyle(
                          fontFamily: 'Montserrat', color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                )
              ]

              else if (challenge['status'] == 'pending' &&
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
                              fontFamily: 'Montserrat', color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
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

              else if (challenge['status'] == 'pending' &&
                    challenge['senderId'] == user.uid) ...[
                  const SizedBox(height: 8),
                  const Text("Waiting for them to accept...",
                      style: TextStyle(fontFamily: 'Montserrat')),
                ]

                else if (challenge['status'] == 'accepted') ...[
                    const SizedBox(height: 8),
                    const Text("Challenge is Active!",
                        style: TextStyle(fontFamily: 'Montserrat')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/challengeLogger',
                          arguments: {
                            'challengeData': challenge,
                          },
                        );
                      },
                      child: const Text("Track Challenge",
                          style: TextStyle(
                              fontFamily: 'Montserrat', color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ],
            ],
          ),
        );
      },
    );
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const TopHeader(), // ✅ added header at the very top
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
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "🥺 You have no friends to challenge...",
                        style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Montserrat'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                              context, '/friends_screen');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
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
                  )
                      : ListView.builder(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16),
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
