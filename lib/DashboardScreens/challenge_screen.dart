import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/addition/top_header.dart';

class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen({super.key});

  Future<void> sendChallenge(String friendId, String friendName, BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['displayName'] ?? 'Anonymous';

    final challengeData = {
      'fromUid': user.uid,
      'fromName': userName,
      'habit': 'Run 5K',
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(friendId)
        .collection('challenges_received')
        .doc(user.uid)
        .set(challengeData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Challenge sent to $friendName')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopHeader(),
            const SizedBox(height: 16),
            const Text('CHALLENGE', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue)),
            const Text('Friends', style: TextStyle(fontSize: 18, color: Colors.blueGrey)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('friends')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No friends to challenge.'));
                  }

                  final friends = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['status']?.toString().toLowerCase() == 'accepted';
                  }).toList();

                  if (friends.isEmpty) {
                    return const Center(child: Text('No accepted friends found.'));
                  }

                  return ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final doc = friends[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final friendId = doc.id;
                      final friendName = data['name'] ?? 'Friend';

                      return ListTile(
                        leading: const Icon(Icons.person, color: Colors.blue),
                        title: Text(friendName),
                        trailing: ElevatedButton(
                          onPressed: () => sendChallenge(friendId, friendName, context),
                          child: const Text('Challenge'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
