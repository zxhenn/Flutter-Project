import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  bool receiveRequests = true;
  bool searchByEmail = false;

  final TextEditingController _searchController = TextEditingController();
  String statusMessage = '';
  Color statusColor = Colors.transparent;
  QueryDocumentSnapshot? matchedProfile;

  @override
  void initState() {
    super.initState();
    _loadRequestPreference();
  }

  Future<void> _loadRequestPreference() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('Profiles').doc(uid).get();
      setState(() {
        receiveRequests = doc.data()?['receiveRequests'] ?? true;
      });
    }
  }

  Future<void> _toggleReceiveRequests(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('Profiles').doc(uid).update({
        'receiveRequests': value,
      });
      setState(() {
        receiveRequests = value;
      });
    }
  }

  void showAddFriendDialog() {
    final currentUser = FirebaseAuth.instance.currentUser;

    bool isSearchingByEmail = false;
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
              final snapshot = await FirebaseFirestore.instance
                  .collection('users')
                  .where(isSearchingByEmail ? 'email' : 'name', isEqualTo: value.trim())
                  .get();

              if (!mounted) return;

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
              if (!mounted) return;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSearchingByEmail
                      ? '🔍 Currently searching by Email'
                      : '🔍 Currently searching by Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: isSearchingByEmail ? 'Enter email here' : 'Enter name here',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                child: const Text('Close', style: TextStyle(color: Colors.blue)),
              ),
              TextButton(
                onPressed: () {
                  isSearchingByEmail = !isSearchingByEmail;
                  _searchController.clear();
                  setStateDialog(() {
                    matchedUser = null;
                    status = '';
                    statusColor = Colors.transparent;
                  });
                },
                child: Text(
                  isSearchingByEmail ? 'Search with Name Instead' : 'Search with Email Instead',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
              TextButton(
                onPressed: matchedUser != null
                    ? () async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(matchedUser!.id)
                      .collection('friend_requests')
                      .doc(currentUser!.uid)
                      .set({
                    'fromUid': currentUser.uid,
                    'fromEmail': currentUser.email,
                    'fromName': currentUser.displayName ?? 'Anonymous',
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
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in.')));
    }

    final userId = user.uid;
    final friendsRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('friends');
    final requestsRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('friend_requests');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: showAddFriendDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text("Receive Friend Requests?"),
            value: receiveRequests,
            onChanged: _toggleReceiveRequests,
          ),
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Friend Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(
            height: 160,
            child: StreamBuilder<QuerySnapshot>(
              stream: requestsRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No friend requests.'));
                }

                final requests = snapshot.data!.docs;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final data = requests[index].data() as Map<String, dynamic>;
                    final fromEmail = data['fromEmail'] ?? 'Unknown';
                    final fromName = data['fromName'] ?? '';

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
                                    await friendsRef.doc(data['fromUid']).set({
                                      'email': fromEmail,
                                      'name': fromName,
                                      'uid': data['fromUid'],
                                    });
                                    await requests[index].reference.delete();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () async {
                                    await requests[index].reference.delete();

                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: friendsRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("You haven't added any friends yet."));
                }

                final friends = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final data = friends[index].data() as Map<String, dynamic>;
                    final email = data['email'] ?? 'Unknown';
                    final name = data['name'] ?? '';

                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(name),
                      subtitle: Text(email),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chat),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Chat placeholder opened')),
                              );
                            },
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'unfriend') {
                                friendsRef.doc(data['uid']).delete();
                              } else if (value == 'report') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Reported user.')),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'unfriend', child: Text('Unfriend')),
                              const PopupMenuItem(value: 'report', child: Text('Report')),
                            ],
                          ),
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
    );
  }
}
