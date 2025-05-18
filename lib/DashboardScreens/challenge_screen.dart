import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final user = FirebaseAuth.instance.currentUser;
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
        .doc(user!.uid)
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
          'name': profileSnap.data()?['name'] ?? 'Unknown',

        });
      }
    }

    setState(() {
      friends = temp;
      loading = false;
    });
  }

  Future<Map<String, dynamic>?> fetchActiveChallenge(String friendId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('challenges')
          .where('status', isEqualTo: 'accepted')
          .where('senderId', whereIn: [user!.uid, friendId])
          .where('receiverId', whereIn: [user!.uid, friendId])
          .get()
          .timeout(const Duration(seconds: 3)); // prevent forever wait

      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
    } catch (e) {
      print("Failed to fetch challenge for $friendId: $e");
    }

    return null;
  }

  Widget buildChallengeCard(Map<String, dynamic> challenge) {
    final isSender = challenge['senderId'] == user!.uid;
    final myName = isSender ? challenge['senderName'] : challenge['receiverName'];
    final friendName = isSender ? challenge['receiverName'] : challenge['senderName'];
    final myProgress = isSender ? challenge['senderProgress'] : challenge['receiverProgress'];
    final friendProgress = isSender ? challenge['receiverProgress'] : challenge['senderProgress'];
    final target = challenge['target'];
    final type = challenge['challengeType'];

    final icon = getChallengeIcon(type);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text("$myName VS $friendName", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 8),
              Text('$type  $myProgress/$target'),
            ],
          ),
          LinearProgressIndicator(value: myProgress / target),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 8),
              Text('$type  $friendProgress/$target'),
            ],
          ),
          LinearProgressIndicator(value: friendProgress / target),
        ],
      ),
    );
  }

  IconData getChallengeIcon(String type) {
    switch (type) {
      case 'Running':
        return Icons.directions_run;
      case 'Lifting':
        return Icons.fitness_center;
      case 'Yoga':
        return Icons.self_improvement;
      default:
        return Icons.star;
    }
  }

  void sendChallenge(String friendId, String friendName) async {
    await FirebaseFirestore.instance.collection('challenges').add({
      'senderId': user!.uid,
      'receiverId': friendId,
      'senderName': user!.displayName ?? 'You',
      'receiverName': friendName,
      'challengeType': 'Running', // change as needed
      'target': 7,
      'status': 'pending',
      'senderProgress': 0,
      'receiverProgress': 0,
      'createdAt': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Challenge Sent')));
  }

  Widget buildFriendCard(Map<String, dynamic> friend) {
    Future<Map<String, dynamic>?> fetchPendingChallenge(String friendId) async {
      final query = await FirebaseFirestore.instance
          .collection('challenges')
          .where('status', isEqualTo: 'pending')
          .where('receiverId', isEqualTo: user!.uid)
          .where('senderId', isEqualTo: friendId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return {
          'id': query.docs.first.id,
          ...query.docs.first.data(),
        };
      }
      return null;
    }
    FutureBuilder(
      future: fetchPendingChallenge(friend['uid']),
      builder: (context, pendingSnapshot) {
        if (pendingSnapshot.connectionState != ConnectionState.done) {
          return const CircularProgressIndicator();
        }

        final pending = pendingSnapshot.data;

        if (pending != null) {
          return Column(
            children: [
              const Text("Challenge Request"),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('challenges')
                          .doc(pending['id'])
                          .update({'status': 'accepted'});
                    },
                    child: const Text("Accept"),
                  ),
                  TextButton(
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('challenges')
                          .doc(pending['id'])
                          .update({'status': 'rejected'});
                    },
                    child: const Text("Decline"),
                  ),
                ],
              )
            ],
          );
        }

        return const SizedBox.shrink(); // no pending, no accepted
      },
    );

    return FutureBuilder(

      future: fetchActiveChallenge(friend['uid']),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final challenge = snapshot.data;


        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.person, size: 30),
                  const SizedBox(width: 10),
                  Text(friend['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              challenge != null
                  ? buildChallengeCard(challenge)
                  : Column(
                children: [
                  Row(
                    children: const [
                      Icon(Icons.fitness_center),
                      SizedBox(width: 6),
                      Text("No challenge yet"),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => sendChallenge(friend['uid'], friend['name']),
                    child: Column(
                      children: const [
                        Icon(Icons.sports_kabaddi, color: Colors.red, size: 32),
                        Text("Challenge friend", style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        );
      },

    );

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Challenge Friends")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: friends.length,
        itemBuilder: (context, index) => buildFriendCard(friends[index]),
      ),
    );
  }
}
