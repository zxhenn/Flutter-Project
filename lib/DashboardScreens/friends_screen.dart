import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/addition/top_header.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();

}

class _FriendsScreenState extends State<FriendsScreen> {
  bool receiveRequests = true;
  void showAddFriendDialog(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final TextEditingController _searchController = TextEditingController();
    QueryDocumentSnapshot? matchedUser;
    String status = '';
    Color statusColor = Colors.transparent;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          Future<void> searchUser(String value) async {
            if (value.trim().isEmpty) return;

            setStateDialog(() {
              matchedUser = null;
              status = '';
              statusColor = Colors.transparent;
            });

            try {
              final query = value.trim().toLowerCase();

              QuerySnapshot snapshot = await FirebaseFirestore.instance
                  .collection('Profiles')
                  .where('NameLower', isEqualTo: query)
                  .get();

              if (snapshot.docs.isEmpty) {
                snapshot = await FirebaseFirestore.instance
                    .collection('Profiles')
                    .where('Email', isEqualTo: value.trim())
                    .get();
              }

              if (!context.mounted) return;

              if (snapshot.docs.isEmpty) {
                setStateDialog(() {
                  status = '❌ No user found';
                  statusColor = Colors.red;
                });
              } else {
                final userDoc = snapshot.docs.first;
                if (userDoc.id == currentUser?.uid) {
                  setStateDialog(() {
                    status = '❌ You cannot add yourself';
                    statusColor = Colors.red;
                  });
                } else {
                  setStateDialog(() {
                    matchedUser = userDoc;
                    status = '✅ User found';
                    statusColor = Colors.green;
                  });
                }
              }
            } catch (e) {
              if (!context.mounted) return;
              setStateDialog(() {
                status = '❌ Error occurred';
                statusColor = Colors.red;
              });
            }
          }

          return AlertDialog(
            title: const Text('Add Friend'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter full name or email',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: searchUser,
                ),
                const SizedBox(height: 8),
                Text(status, style: TextStyle(color: statusColor)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: matchedUser != null
                    ? () async {
                  final doc = matchedUser!;
                  final current = FirebaseAuth.instance.currentUser!;
                  final targetId = doc.id;

                  final profileDoc = await FirebaseFirestore.instance
                      .collection('Profiles')
                      .doc(targetId)
                      .get();

                  if (profileDoc.exists &&
                      profileDoc.data()?['receiveRequests'] == false) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('This user is not accepting friend requests.')),
                      );
                    }
                    return;
                  }

                  final requestCheck = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(targetId)
                      .collection('friend_requests')
                      .doc(current.uid)
                      .get();

                  if (requestCheck.exists) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Friend request already sent.')),
                      );
                    }
                    return;
                  }

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(targetId)
                      .collection('friend_requests')
                      .doc(current.uid)
                      .set({
                    'fromUid': current.uid,
                    'fromEmail': current.email,
                    'fromName': current.displayName ?? 'Anonymous',
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Friend request sent!')),
                    );
                  }
                }
                    : null,
                child: Text(
                  'Send Request',
                  style: TextStyle(color: matchedUser != null ? Colors.blue : Colors.grey),
                ),
              ),
            ],
          );
        });
      },
    );
  }


  @override
  void initState() {
    super.initState();
    _loadReceiveToggle();
  }

  Future<void> _loadReceiveToggle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profile = await FirebaseFirestore.instance.collection('Profiles').doc(user.uid).get();
    setState(() {
      receiveRequests = profile.data()?['receiveRequests'] ?? true;
    });
  }

  Future<void> _toggleReceiveRequests(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => receiveRequests = value);

    await FirebaseFirestore.instance.collection('Profiles').doc(user.uid).set({
      'receiveRequests': value,
    }, SetOptions(merge: true));
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in'));

    final requestRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friend_requests');

    final friendsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friends');

    return Scaffold(

      backgroundColor: Colors.white,

      floatingActionButton: SizedBox(
        width: 70,   // ✅ Width of the button
        height: 70,  // ✅ Height of the button
        child: FloatingActionButton(
          onPressed: () => showAddFriendDialog(context),
          backgroundColor: Colors.blueAccent,
          child: const Icon(
            Icons.person_add,
            color: Colors.white,
            size: 36, // ✅ Bigger icon inside
          ),
        ),
      ),


      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                TopHeader(
                  onAddTap: () => showAddFriendDialog(context),
                  onProfileTap: () => Navigator.pushNamed(context, '/profile'),
                  onNotificationTap: () => Navigator.pushNamed(context, '/notifications'),
                ),

                const SizedBox(height: 8),
                const Text(
                  "Friends",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                    color: Colors.black,
                  ),
                ),
                const Divider(thickness: 1),
                SwitchListTile(
                  title: const Text('Receive Friend Requests?'),
                  value: receiveRequests,
                  onChanged: _toggleReceiveRequests,
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Friend Requests', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 22)),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: requestRef.snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No friend requests.'),
                      );
                    }

                    final requests = snapshot.data!.docs;

                    return SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final doc = requests[index];
                          final fromUid = doc['fromUid'];
                          final fromName = doc['fromName'] ?? 'Anonymous';
                          final fromEmail = doc['fromEmail'] ?? '';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(fromName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(fromEmail, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [

                                      IconButton(
                                        icon: const Icon(Icons.check, color: Colors.green),
                                        onPressed: () async {
                                          final current = FirebaseAuth.instance.currentUser;
                                          if (current == null) return;

                                          final currentUid = current.uid;

                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(currentUid)
                                              .collection('friends')
                                              .doc(fromUid)
                                              .set({
                                            'uid': fromUid,
                                            'name': fromName,
                                            'email': fromEmail,
                                            'addedAt': FieldValue.serverTimestamp(),
                                          });

                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(fromUid)
                                              .collection('friends')
                                              .doc(currentUid)
                                              .set({
                                            'uid': currentUid,
                                            'name': current.displayName ?? 'You',
                                            'email': current.email ?? '',
                                            'addedAt': FieldValue.serverTimestamp(),
                                          });

                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(currentUid)
                                              .collection('friend_requests')
                                              .doc(fromUid)
                                              .delete();

                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(fromUid)
                                              .collection('friend_requests')
                                              .doc(currentUid)
                                              .get()
                                              .then((snap) async {
                                            if (snap.exists) {
                                              await snap.reference.delete();
                                            }
                                          });

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('You and $fromName are now friends!')),
                                            );
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        onPressed: () async {
                                          final current = FirebaseAuth.instance.currentUser;
                                          if (current == null) return;

                                          final requestRef = FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(current.uid)
                                              .collection('friend_requests')
                                              .doc(fromUid);

                                          await requestRef.get().then((snap) async {
                                            if (snap.exists) {
                                              await snap.reference.delete();
                                            }
                                          });

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Friend request removed.')),
                                            );
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.person_add),
                                        onPressed: () => showAddFriendDialog(context), // ← won't work here directly
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text("Your Friends", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.blue)),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: friendsRef.snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("You haven't added any friends yet."));
                      }

                      final friends = snapshot.data!.docs;
                      return ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final data = friends[index].data() as Map<String, dynamic>;
                          final friendId = data['uid'] ?? '';
                          final friendName = data['name'] ?? 'Friend';
                          final friendEmail = data['email'] ?? '';

                          return ListTile(
                            title: Text(friendName),
                            subtitle: Text(friendEmail),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'unfriend') {
                                  try {
                                    final currentUser = FirebaseAuth.instance.currentUser;
                                    if (currentUser == null) throw 'Not logged in';

                                    final currentId = currentUser.uid;

                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(currentId)
                                        .collection('friends')
                                        .doc(friendId)
                                        .delete();

                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(friendId)
                                        .collection('friends')
                                        .doc(currentId)
                                        .delete();

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('You unfriended ${data['name'] ?? 'them'}')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Unfriend failed: $e')),
                                      );
                                    }
                                  }
                                }

                                if (value == 'view') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('View Profile coming soon...')),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'view', child: Text('View Profile')),
                                const PopupMenuItem(value: 'unfriend', child: Text('Unfriend')),
                              ],
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
        ),
      ),
    );
  }

}
