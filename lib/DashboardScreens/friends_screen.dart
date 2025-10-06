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

    // Widget for the search bar UI
    Widget _buildSearchBarInput() {
      // Renamed to avoid confusion with a method that returns a larger section
      return Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 12.0),
        child: TextField(
          controller: _searchController,
          // autofocus: false, // Keep autofocus false
          decoration: InputDecoration(
            hintText: 'Search & add users by name or email...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.0),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey[200],
            contentPadding:
            const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                // _onSearchChanged will be triggered by listener, clearing results
              },
            )
                : null,
          ),
        ),
      );
    }

    // Widget for displaying search results
    Widget _buildSearchResultsContent() {
      if (_isSearching) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_searchResults.isEmpty && _searchQuery.isNotEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No users found for your search.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Montserrat', fontSize: 16),
            ),
          ),
        );
      }
      if (_searchQuery.isEmpty) return const SizedBox.shrink();

      return ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final userDoc = _searchResults[index]; // This is a DocumentSnapshot from 'Profiles'
          final userData = userDoc.data() as Map<String, dynamic>;
          final name = userData['Name'] ?? 'N/A';
          final email = userData['Email'] ?? 'N/A';
          final userId = userDoc.id; // Get the UID of the searched user

          return FutureBuilder<int>(
            future: PointingSystem.getTotalPoints(userId),
            // Fetch total points for this user
            builder: (context, snapshot) {
              String rankDisplay = 'Loading rank...';
              Color rankColor = Colors.grey;

              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasError) {
                  rankDisplay = 'Error fetching rank';
                  debugPrint(
                      "Error fetching points for $userId: ${snapshot.error}");
                } else if (snapshot.hasData) {
                  final points = snapshot.data!;
                  final rank = PointingSystem.getRankFromPoints(points);
                  rankDisplay = 'Rank: $rank ($points pts)';
                  // You can add colors based on rank here if you want
                  // Example:
                  // if (rank == 'Grandmaster') rankColor = Colors.purple;
                  // else if (rank == 'Master') rankColor = Colors.amber;
                } else {
                  rankDisplay = 'Rank: Bronze (0 pts)'; // Default if no data
                }
              }

              return Card(
                margin: const EdgeInsets.symmetric(
                    vertical: 4.0, horizontal: 8.0),
                child: ListTile(
                  title: Text(name, style: const TextStyle(
                      fontFamily: 'Montserrat', fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email,
                          style: const TextStyle(fontFamily: 'Montserrat')),
                      const SizedBox(height: 4),
                      Text(
                        rankDisplay,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          color: rankColor, // Apply color if you set it
                          fontWeight: snapshot.connectionState ==
                              ConnectionState.done && snapshot.hasData
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Add'),
                    onPressed: () => _sendFriendRequest(userDoc),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    // New: Widget for the static part: Title, Toggle, SearchBar
    Widget _buildFixedHeaderAndSearch() {
      return Column(
        mainAxisSize: MainAxisSize.min, // Takes minimum vertical space
        children: [
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
            title: const Text('Receive Friend Requests?',
                style: TextStyle(fontFamily: 'Montserrat')),
            value: receiveRequests,
            onChanged: _toggleReceiveRequests,
          ),
          _buildSearchBarInput(), // Call to the TextField widget
          const Divider(thickness: 1),
        ],
      );
    }


    // Modified: Widget for the scrollable friend requests and friends list
    Widget _buildFriendListsSection() {
      final user = FirebaseAuth.instance.currentUser;
      // User null check already happens in main build, but good for safety
      if (user == null) return const Center(child: Text('Not signed in'));

      final requestRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friend_requests');
      final friendsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friends');

      return SingleChildScrollView( // Makes this section scrollable
        child: Padding( // Added padding for visual separation if needed
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // Important for Column in SingleChildScrollView
            children: [
              Container(
                color: Colors.blueAccent,
                width: double.infinity,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    textAlign: TextAlign.center,
                    'Friend Requests',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 22,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 180,
                child: StreamBuilder<QuerySnapshot>(
                  stream: requestRef.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: Text(
                            'No friend requests.',
                            style: TextStyle(fontFamily: 'Montserrat'),
                          ),
                        ),
                      );
                    }
                    final requests = snapshot.data!.docs;
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
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
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8,
                              vertical: 4),
                          child: Container(
                            width: 200,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  fromName,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Montserrat'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(fromEmail,
                                    style: const TextStyle(
                                        fontSize: 14, fontFamily: 'Montserrat'),
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment
                                      .spaceEvenly,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check,
                                          color: Colors.green),
                                      tooltip: 'Accept Request',
                                      onPressed: () async {
                                        final current = FirebaseAuth.instance
                                            .currentUser;
                                        if (current == null) return;
                                        final currentUid = current.uid;

                                        String currentUserName = current
                                            .displayName ?? 'Anonymous';
                                        String currentUserEmail = current
                                            .email ?? '';
                                        final currentUserProfile = await FirebaseFirestore
                                            .instance
                                            .collection('Profiles')
                                            .doc(currentUid)
                                            .get();
                                        if (currentUserProfile.exists) {
                                          currentUserName = currentUserProfile
                                              .data()?['Name'] ??
                                              currentUserName;
                                          currentUserEmail = currentUserProfile
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
                                          'addedAt': FieldValue
                                              .serverTimestamp(),
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
                                          'addedAt': FieldValue
                                              .serverTimestamp(),
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
                                        ScaffoldMessenger
                                            .of(context)
                                            .showSnackBar(SnackBar(
                                            content: Text(
                                                'You and $fromName are now friends!')),);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.close, color: Colors.red),
                                      tooltip: 'Decline Request',
                                      onPressed: () async {
                                        final current = FirebaseAuth.instance
                                            .currentUser;
                                        if (current == null) return;
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(
                                            current.uid)
                                            .collection(
                                            'friend_requests')
                                            .doc(fromUid)
                                            .delete();
                                        if (!mounted) return;
                                        ScaffoldMessenger
                                            .of(context)
                                            .showSnackBar(const SnackBar(
                                            content: Text(
                                                'Friend request removed.')),);
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
              Container(
                color: Colors.blueAccent,
                width: double.infinity,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    textAlign: TextAlign.center,
                    'Your Friends',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 22,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: friendsRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding( // Give some space for indicator
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: 20.0, horizontal: 16.0),
                      child: Center(
                        child: Text(
                          "You haven't added any friends yet.\nUse the search bar above to find users.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w400,
                              fontSize: 16),
                        ),
                      ),
                    );
                  }
                  final friends = snapshot.data!.docs;
                  return ListView.builder(
                    shrinkWrap: true,
                    // Crucial for ListView in Column in SingleChildScrollView
                    physics: const NeverScrollableScrollPhysics(),
                    // Crucial
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final data = friends[index].data() as Map<String,
                          dynamic>;
                      final friendId = data['uid'] ?? '';
                      final friendEmail = data['email'] ?? '';
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection(
                            'Profiles').doc(friendId).get(),
                        builder: (context, profileSnapshot) {
                          String friendName = data['name'] ?? 'Friend';
                          if (profileSnapshot.connectionState ==
                              ConnectionState.done && profileSnapshot.hasData &&
                              profileSnapshot.data!.exists) {
                            final profileData = profileSnapshot.data!
                                .data() as Map<String, dynamic>;
                            friendName = profileData['Name'] ?? friendName;
                          }
                          return ListTile(
                            title: Text(friendName, style: const TextStyle(
                                fontFamily: 'Montserrat')),
                            subtitle: Text(friendEmail, style: const TextStyle(
                                fontFamily: 'Montserrat')),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'unfriend') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) =>
                                        AlertDialog(
                                          title: const Text('Unfriend'),
                                          content: Text(
                                              'Do you really want to unfriend $friendName?'),
                                          actionsPadding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 16, vertical: 12),
                                          actionsAlignment: MainAxisAlignment
                                              .spaceBetween,
                                          actions: [
                                            TextButton(onPressed: () =>
                                                Navigator.pop(context, false),
                                                style: TextButton.styleFrom(
                                                    backgroundColor: Colors.grey
                                                        .shade300),
                                                child: const Text('No',
                                                    style: TextStyle(
                                                        color: Colors.black87,
                                                        fontSize: 16))),
                                            TextButton(onPressed: () =>
                                                Navigator.pop(context, true),
                                                style: TextButton.styleFrom(
                                                    backgroundColor: Colors
                                                        .red),
                                                child: const Text(
                                                    'Yes, Unfriend',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16))),
                                          ],
                                        ),
                                  );
                                  if (confirm == true) {
                                    final currentUser = FirebaseAuth.instance
                                        .currentUser;
                                    if (currentUser == null) return;
                                    final currentId = currentUser.uid;
                                    await FirebaseFirestore.instance.collection(
                                        'users').doc(currentId).collection(
                                        'friends').doc(friendId).delete();
                                    await FirebaseFirestore.instance.collection(
                                        'users').doc(friendId).collection(
                                        'friends').doc(currentId).delete();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(
                                            'You unfriended $friendName')));
                                  }
                                } else if (value == 'view') {
                                  Navigator.pushNamed(context, '/view_profile',
                                      arguments: {'userId': friendId});
                                }
                              },
                              itemBuilder: (context) =>
                              [
                                const PopupMenuItem(
                                    value: 'view', child: Text('View Profile')),
                                const PopupMenuItem(
                                    value: 'unfriend', child: Text('Unfriend')),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              // Add some space at the bottom for better scrolling
            ],
          ),
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return const Center(
            child: Text('Not signed in. Please sign in to view friends.'));
      }

      // Get MediaQuery data ONCE, ideally before keyboard affects it significantly
      // However, build can be called multiple times.
      // The resizeToAvoidBottomInset: false is the primary guard.
      final MediaQueryData mediaQuery = MediaQuery.of(context);
      final double bottomInset = mediaQuery.viewInsets
          .bottom; // Keyboard height

      return Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false, // CRUCIAL: Keep this
        body: Column(
          children: [
            // Section 1: TopHeader (assumes it handles its own status bar padding)
            TopHeader(
              onProfileTap: () => Navigator.pushNamed(context, '/profile'),
              onNotificationTap: () =>
                  Navigator.pushNamed(context, '/notifications'),
            ),

            // Section 2: Fixed search area
            _buildFixedHeaderAndSearch(),

            // Section 3: Dynamic content (lists or search results)
            // This Expanded widget will take the remaining space.
            // Its child will be laid out respecting the keyboard inset because
            // we are NOT removing the viewInsets for THIS child directly anymore
            // with MediaQuery.removePadding. Instead, the SingleChildScrollView
            // or ListView within the children should handle scrolling.
            Expanded(
              child: _searchQuery
                  .trim()
                  .isEmpty
                  ? _buildFriendListsSection() // This is already a SingleChildScrollView
                  : _buildSearchResultsContent(), // This is a ListView
            ),

            // If you want to ensure the content doesn't go under a translucent keyboard,
            // you could add a SizedBox here that accounts for the keyboard height.
            // This is usually only needed if resizeToAvoidBottomInset is true,
            // or if you have specific UI elements at the very bottom that are not part of a scroll view.
            // if (bottomInset > 0 && _searchController.hasFocus) // Only if keyboard is visible and search has focus
            //   SizedBox(height: bottomInset),
          ],
        ),
      );
    }
  }