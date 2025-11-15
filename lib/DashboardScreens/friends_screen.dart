  import 'dart:async'; // Import for Timer (debouncing)
  import 'package:flutter/material.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import '/addition/top_header.dart';
  import '/utils/pointing_system.dart';
  // import '/Analysis/analysis_screen.dart'; // Unused in this context

  class FriendsScreen extends StatefulWidget {
    const FriendsScreen({super.key});

    @override
    State<FriendsScreen> createState() => _FriendsScreenState();
  }

  class _FriendsScreenState extends State<FriendsScreen> {
    bool receiveRequests = true;
    final TextEditingController _searchController = TextEditingController();
    List<DocumentSnapshot> _searchResults = [];
    bool _isSearching = false;
    String _searchQuery = "";
    Timer? _debounce;

    @override
    void initState() {
      super.initState();
      _loadReceiveToggle();
      _searchController.addListener(_onSearchChanged);
    }

    @override
    void dispose() {
      _searchController.removeListener(_onSearchChanged);
      _searchController.dispose();
      _debounce?.cancel();
      super.dispose();
    }

    void _onSearchChanged() {
      if (!mounted) return;
      // Check if the new query is actually different from the current one
      if (_searchQuery == _searchController.text.trim() &&
          _searchController.text
              .trim()
              .isNotEmpty) {
        // If query is same and not empty, user might be just tapping, do nothing to avoid flicker
        // Or, if you want to force search results to show even on tap, remove this check
      }

      setState(() {
        _searchQuery = _searchController.text.trim();
      });

      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        if (_searchQuery.isNotEmpty) {
          _performSearch(_searchQuery);
        } else {
          setState(() {
            _searchResults.clear();
            _isSearching = false;
          });
        }
      });
    }

    Future<void> _performSearch(String query) async {
      if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isSearching = true;
        });
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
        return;
      }

      final Map<String, DocumentSnapshot> uniqueResults = {};

      try {
        final nameQueryLower = query.toLowerCase();
        QuerySnapshot nameSnapshot = await FirebaseFirestore.instance
            .collection('Profiles')
            .where('NameLower', isGreaterThanOrEqualTo: nameQueryLower)
            .where('NameLower', isLessThanOrEqualTo: '$nameQueryLower\uf8ff')
            .limit(10)
            .get();

        for (var doc in nameSnapshot.docs) {
          if (doc.id != currentUser.uid) {
            uniqueResults[doc.id] = doc;
          }
        }

        // For email, direct prefix might be case-sensitive depending on collation (Firestore default is binary/sensitive)
        // To make email search truly case-insensitive like NameLower, store EmailLower field.
        QuerySnapshot emailSnapshot = await FirebaseFirestore.instance
            .collection('Profiles')
            .where('Email',
            isGreaterThanOrEqualTo: query) // Using original query for case if desired
            .where('Email', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(10)
            .get();

        for (var doc in emailSnapshot.docs) {
          if (doc.id != currentUser.uid) {
            uniqueResults[doc.id] = doc;
          }
        }

        if (!mounted) return;
        setState(() {
          _searchResults = uniqueResults.values.toList();
          _isSearching = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSearching = false;
        });
        debugPrint("Error during search: $e");
      }
    }

    Future<void> _sendFriendRequest(DocumentSnapshot targetUserDoc) async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final targetId = targetUserDoc.id;
      final targetData = targetUserDoc.data() as Map<String, dynamic>?;

      if (targetData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User data not available.')),
          );
        }
        return;
      }

      final targetName = targetData['Name'] ?? 'User';

      if (targetData['receiveRequests'] == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('This user is not accepting friend requests.')),
          );
        }
        return;
      }

      final friendDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .doc(targetId)
          .get();

      if (friendDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('You are already friends with $targetName.')),
          );
        }
        return;
      }

      final requestCheck = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetId)
          .collection('friend_requests')
          .doc(currentUser.uid)
          .get();

      if (requestCheck.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Friend request already sent.')),
          );
        }
        return;
      }

      String currentUserName = currentUser.displayName ?? 'Anonymous';
      String currentUserEmail = currentUser.email ?? '';

      final currentUserProfileDoc = await FirebaseFirestore.instance.collection(
          'Profiles').doc(currentUser.uid).get();
      if (currentUserProfileDoc.exists) {
        final profileData = currentUserProfileDoc.data();
        currentUserName = profileData?['Name'] ?? currentUserName;
        currentUserEmail = profileData?['Email'] ?? currentUserEmail;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetId)
          .collection('friend_requests')
          .doc(currentUser.uid)
          .set({
        'fromUid': currentUser.uid,
        'fromEmail': currentUserEmail,
        'fromName': currentUserName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent to $targetName!')),
        );
      }
    }

    Future<void> _loadReceiveToggle() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final profile =
      await FirebaseFirestore.instance
          .collection('Profiles')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          receiveRequests = profile.data()?['receiveRequests'] ?? true;
        });
      }
    }

    Future<void> _toggleReceiveRequests(bool value) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (mounted) {
        setState(() => receiveRequests = value);
      }
      await FirebaseFirestore.instance.collection('Profiles').doc(user.uid).set(
          {
            'receiveRequests': value,
          }, SetOptions(merge: true));
    }

    Widget _buildSearchBar() {
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
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search users by name or email...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey[600],
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
          ),
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[900],
          ),
        ),
      );
    }

    Widget _buildReceiveRequestsToggle() {
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
        child: SwitchListTile(
          title: Text(
            'Receive Friend Requests',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
          subtitle: Text(
            'Allow others to send you friend requests',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          value: receiveRequests,
          onChanged: _toggleReceiveRequests,
          activeColor: Colors.blue[700],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
      );
    }

    Widget _buildSearchResultsContent() {
      if (_isSearching) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (_searchResults.isEmpty && _searchQuery.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Try a different search term',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      if (_searchQuery.isEmpty) return const SizedBox.shrink();

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final userDoc = _searchResults[index];
          final userData = userDoc.data() as Map<String, dynamic>;
          final name = userData['Name'] ?? 'N/A';
          final email = userData['Email'] ?? 'N/A';
          final photoUrl = userData['photoUrl'];
          final userId = userDoc.id;

          return FutureBuilder<int>(
            future: PointingSystem.getTotalPoints(userId),
            builder: (context, snapshot) {
              String rankDisplay = 'Loading...';
              int points = 0;

              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasError) {
                  rankDisplay = 'Error';
                } else if (snapshot.hasData) {
                  points = snapshot.data!;
                  final rank = PointingSystem.getRankFromPoints(points);
                  rankDisplay = '$rank • $points pts';
                } else {
                  rankDisplay = 'Bronze • 0 pts';
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.blue.shade50,
                        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null || photoUrl.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[900],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
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
                                    rankDisplay,
                                    style: TextStyle(
                                      fontSize: 11,
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
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => _sendFriendRequest(userDoc),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }



    Widget _buildFriendListsSection() {
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

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Settings Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildReceiveRequestsToggle(),
            ),
            const SizedBox(height: 24),
            // Friend Requests Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Friend Requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: StreamBuilder<QuerySnapshot>(
                stream: requestRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_add_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No friend requests',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final requests = snapshot.data!.docs;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final doc = requests[index];
                      final fromUid = doc['fromUid'];
                      final fromName = (doc.data() as Map<String, dynamic>)
                              .containsKey('fromName')
                          ? doc['fromName']
                          : 'Anonymous';
                      final fromEmail = (doc.data() as Map<String, dynamic>)
                              .containsKey('fromEmail')
                          ? doc['fromEmail']
                          : '';

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('Profiles')
                            .doc(fromUid)
                            .get(),
                        builder: (context, profileSnapshot) {
                          String photoUrl = '';
                          if (profileSnapshot.hasData &&
                              profileSnapshot.data!.exists) {
                            final profileData =
                                profileSnapshot.data!.data() as Map<String, dynamic>;
                            photoUrl = profileData['photoUrl'] ?? '';
                          }

                          return Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 12),
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.blue.shade50,
                                    backgroundImage: photoUrl.isNotEmpty
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    child: photoUrl.isEmpty
                                        ? Text(
                                            fromName.isNotEmpty
                                                ? fromName[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 20,
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    fromName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[900],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    fromEmail,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            final current =
                                                FirebaseAuth.instance.currentUser;
                                            if (current == null) return;
                                            final currentUid = current.uid;

                                            String currentUserName =
                                                current.displayName ?? 'Anonymous';
                                            String currentUserEmail =
                                                current.email ?? '';
                                            final currentUserProfile =
                                                await FirebaseFirestore.instance
                                                    .collection('Profiles')
                                                    .doc(currentUid)
                                                    .get();
                                            if (currentUserProfile.exists) {
                                              currentUserName =
                                                  currentUserProfile.data()?['Name'] ??
                                                      currentUserName;
                                              currentUserEmail =
                                                  currentUserProfile
                                                          .data()?['Email'] ??
                                                      currentUserEmail;
                                            }

                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(currentUid)
                                                .collection('friends')
                                                .doc(fromUid)
                                                .set({
                                              'uid': fromUid,
                                              'name': fromName,
                                              'email': fromEmail,
                                              'addedAt':
                                                  FieldValue.serverTimestamp(),
                                            });
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(fromUid)
                                                .collection('friends')
                                                .doc(currentUid)
                                                .set({
                                              'uid': currentUid,
                                              'name': currentUserName,
                                              'email': currentUserEmail,
                                              'addedAt':
                                                  FieldValue.serverTimestamp(),
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
                                                .delete();
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: Text(
                                                  'You and $fromName are now friends!'),
                                            ));
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            minimumSize: const Size(0, 32),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            elevation: 2,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            final current =
                                                FirebaseAuth.instance.currentUser;
                                            if (current == null) return;
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(current.uid)
                                                .collection('friend_requests')
                                                .doc(fromUid)
                                                .delete();
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content:
                                                  Text('Friend request removed.'),
                                            ));
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[600],
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            minimumSize: const Size(0, 32),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            elevation: 2,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
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
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // Friends List Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Your Friends',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: friendsRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 100),
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
                              Icons.people_outline,
                              size: 64,
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No Friends Yet',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use the search bar above to find users',
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
                final friends = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final data = friends[index].data() as Map<String, dynamic>;
                    final friendId = data['uid'] ?? '';
                    final friendEmail = data['email'] ?? '';
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('Profiles')
                          .doc(friendId)
                          .get(),
                      builder: (context, profileSnapshot) {
                        String friendName = data['name'] ?? 'Friend';
                        String photoUrl = '';
                        int totalPoints = 0;
                        String rank = 'Bronze';

                        if (profileSnapshot.connectionState ==
                                ConnectionState.done &&
                            profileSnapshot.hasData &&
                            profileSnapshot.data!.exists) {
                          final profileData = profileSnapshot.data!.data()
                              as Map<String, dynamic>;
                          friendName = profileData['Name'] ?? friendName;
                          photoUrl = profileData['photoUrl'] ?? '';
                        }

                        return FutureBuilder<int>(
                          future: PointingSystem.getTotalPoints(friendId),
                          builder: (context, pointsSnapshot) {
                            if (pointsSnapshot.hasData) {
                              totalPoints = pointsSnapshot.data!;
                              rank = PointingSystem.getRankFromPoints(totalPoints);
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
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
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/view_profile',
                                      arguments: {'userId': friendId},
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: Colors.blue.shade50,
                                          backgroundImage: photoUrl.isNotEmpty
                                              ? NetworkImage(photoUrl)
                                              : null,
                                          child: photoUrl.isEmpty
                                              ? Text(
                                                  friendName.isNotEmpty
                                                      ? friendName[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    color: Colors.blue[700],
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                friendName,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[900],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                friendEmail,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.star,
                                                        size: 12,
                                                        color: Colors.amber),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '$rank • $totalPoints pts',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[700],
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          icon: Icon(
                                            Icons.more_vert,
                                            color: Colors.grey[600],
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'view',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.person_outline,
                                                      size: 20,
                                                      color: Colors.grey[700]),
                                                  const SizedBox(width: 12),
                                                  const Text('View Profile'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'unfriend',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.person_remove,
                                                      size: 20,
                                                      color: Colors.red[600]),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Unfriend',
                                                    style: TextStyle(
                                                      color: Colors.red[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          onSelected: (value) async {
                                            if (value == 'unfriend') {
                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  title: const Text('Unfriend'),
                                                  content: Text(
                                                      'Do you really want to unfriend $friendName?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, false),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, true),
                                                      child: Text(
                                                        'Unfriend',
                                                        style: TextStyle(
                                                          color: Colors.red[600],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                final currentUser =
                                                    FirebaseAuth.instance
                                                        .currentUser;
                                                if (currentUser == null) return;
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
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                  content: Text(
                                                      'You unfriended $friendName'),
                                                ));
                                              }
                                            } else if (value == 'view') {
                                              Navigator.pushNamed(
                                                context,
                                                '/view_profile',
                                                arguments: {'userId': friendId},
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: const Center(
            child: Text('Not signed in. Please sign in to view friends.'),
          ),
        );
      }

      return Scaffold(
        backgroundColor: Colors.grey[50],
        resizeToAvoidBottomInset: false,
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
                              'Friends',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildSearchBar(),
                      ),
                      const SizedBox(height: 20),
                      // Content Section
                      Expanded(
                        child: _searchQuery.trim().isEmpty
                            ? _buildFriendListsSection()
                            : _buildSearchResultsContent(),
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
  }