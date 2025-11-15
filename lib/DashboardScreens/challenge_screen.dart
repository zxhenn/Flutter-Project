import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/addition/top_header.dart'; // Assuming TopHeader handles its own SafeArea
// import '/addition/awesome_notifications.dart'; // For notifications - uncomment if used
// import '/utils/pointing_system.dart'; // Not directly used in this UI, but good for context

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final User _currentUser = FirebaseAuth.instance.currentUser!;
  List<Map<String, dynamic>> _friends = [];
  bool _isLoadingFriends = true;
  Map<String, Map<String, dynamic>?> _friendChallenges = {}; // Cache challenges
  bool _isLoadingChallenges = false; // Separate loading for challenges

  @override
  void initState() {
    super.initState();
    _fetchFriendsAndTheirChallenges();
  }

  Future<void> _fetchFriendsAndTheirChallenges() async {
    if (!mounted) return;
    setState(() {
      _isLoadingFriends = true;
      _isLoadingChallenges = true;
    });

    final friendsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('friends')
        .get();

    List<Map<String, dynamic>> tempFriends = [];
    List<Future> challengeFetchFutures = [];

    for (var doc in friendsSnap.docs) {
      final profileSnap = await FirebaseFirestore.instance
          .collection('Profiles')
          .doc(doc.id)
          .get();

      if (profileSnap.exists && profileSnap.data() != null) {
        final profileData = profileSnap.data()!;
        final userSnap = await FirebaseFirestore.instance.collection('users').doc(doc.id).get();
        final userData = userSnap.data() ?? {};

        final int sPoints = (userData['strengthPoints'] ?? 0) as int;
        final int cPoints = (userData['cardioPoints'] ?? 0) as int;
        final int mPoints = (userData['miscPoints'] ?? 0) as int;

        final int totalPoints = sPoints + cPoints + mPoints;
        final String rank = _getRankFromPoints(totalPoints);

        tempFriends.add({
          'uid': doc.id,
          'name': profileData['Name'] ?? 'Unknown Friend',
          'rank': rank,
          'points': totalPoints,
          'photoUrl': profileData['photoUrl'],
        });
        challengeFetchFutures.add(_getChallengeWithFriend(doc.id).then((challenge) {
          if (mounted) {
            setState(() {
              _friendChallenges[doc.id] = challenge;
            });
          }
        }));
      }
    }

    if (mounted) {
      setState(() {
        _friends = tempFriends;
        _isLoadingFriends = false;
      });
    }

    await Future.wait(challengeFetchFutures);
    if (mounted) {
      setState(() {
        _isLoadingChallenges = false;
      });
    }
  }

  String _getRankFromPoints(int points) {
    if (points >= 4000) return 'Grandmaster';
    if (points >= 1000) return 'Master';
    if (points >= 500) return 'Diamond';
    if (points >= 200) return 'Emerald';
    if (points >= 100) return 'Gold';
    if (points >= 50) return 'Silver';
    return 'Bronze';
  }

  Future<Map<String, dynamic>?> _getChallengeWithFriend(String friendId) async {
    const List<String> blockingStatuses = [
      'pending',
      'active',
      'cancel_requested',
    ];

    final query1Snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('challenges')
        .where('receiverId', isEqualTo: friendId)
        .where('status', whereIn: blockingStatuses)
        .limit(1)
        .get();

    if (query1Snap.docs.isNotEmpty) {
      final doc = query1Snap.docs.first;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      return {...data, 'id': doc.id}; // Ensure ID is included
    }

    final query2Snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('challenges')
        .where('senderId', isEqualTo: friendId)
        .where('status', whereIn: blockingStatuses)
        .limit(1)
        .get();

    if (query2Snap.docs.isNotEmpty) {
      final doc = query2Snap.docs.first;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      return {...data, 'id': doc.id}; // Ensure ID is included
    }
    return null;
  }

  Widget _buildFriendCard(Map<String, dynamic> friendData) {
    final String friendUid = friendData['uid'];
    final Map<String, dynamic>? challenge = _friendChallenges[friendUid];
    final bool isLoadingThisFriendChallenge = _isLoadingChallenges && !_friendChallenges.containsKey(friendUid);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Friend Info Header
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blue.shade50,
                  backgroundImage: friendData['photoUrl'] != null && friendData['photoUrl'].isNotEmpty
                      ? NetworkImage(friendData['photoUrl'])
                      : null,
                  child: friendData['photoUrl'] == null || friendData['photoUrl'].isEmpty
                      ? Text(
                          friendData['name'] != null && friendData['name'].isNotEmpty
                              ? friendData['name'][0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friendData['name'] ?? 'Friend',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  '${friendData['rank'] ?? 'Bronze'} • ${friendData['points'] ?? 0} pts',
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 16),
            // Challenge Status Section
            if (isLoadingThisFriendChallenge)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  ),
                ),
              )
            else if (challenge == null)
              _buildStartChallengeButton(friendData)
            else
              _buildChallengeStatusSection(challenge, friendData, friendUid),
          ],
        ),
      ),
    );
  }

  Widget _buildStartChallengeButton(Map<String, dynamic> friendData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No active challenge',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/challengeAddHabit',
                arguments: {
                  'friendId': friendData['uid'],
                  'friendName': friendData['name'],
                },
              ).then((_) => _refreshChallengeForFriend(friendData['uid']));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Challenge Friend',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeStatusSection(
      Map<String, dynamic>? challenge, // <<<<< MODIFIED TO BE NULLABLE
      Map<String, dynamic> friendData,
      String friendUid,
      ) {
    if (challenge == null) { // This check is now fully effective
      print("CRITICAL WARNING: _buildChallengeStatusSection received a null challenge for friend $friendUid. Falling back to 'Start Challenge' UI.");
      return _buildStartChallengeButton(friendData);
    }
    final String status = challenge['status'] ?? 'unknown';
    final String habitType = challenge['habitType'] ?? 'Habit';
    final bool amISender = challenge['senderId'] == _currentUser.uid; // Safe

    num myProgress = amISender ? (challenge['senderProgress'] ?? 0) : (challenge['receiverProgress'] ?? 0); // Safe
    num friendProgress = amISender ? (challenge['receiverProgress'] ?? 0) : (challenge['senderProgress'] ?? 0); // Safe
    num targetMax = challenge['targetMax'] ?? 1; // Safe
    String unit = challenge['unit'] ?? ''; // Safe

    Widget statusSpecificUI;

    switch (status) {
      case 'pending':
        if (amISender) {
          statusSpecificUI = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$habitType ($targetMax $unit)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Waiting for response...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelSentChallenge(challenge),
                  icon: Icon(Icons.cancel_outlined, size: 18, color: Colors.red[600]),
                  label: Text(
                    'Cancel Challenge',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[600],
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red[600]!, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          statusSpecificUI = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_active, size: 20, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${friendData['name']} challenged you!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$habitType ($targetMax $unit)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptChallenge(challenge),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _declineChallenge(challenge),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red[600]!, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Decline',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => _viewChallengeDetails(challenge),
                  child: Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        break;
      case 'active':
      case 'completed_won':
      case 'completed_lost':
      case 'completed_draw':
        String statusLabel = "Active";
        MaterialColor statusColor = Colors.blue;
        if (status == 'completed_won' && amISender || status == 'completed_lost' && !amISender) {
          statusLabel = "You Won!";
          statusColor = Colors.green;
        } else if (status == 'completed_lost' && amISender || status == 'completed_won' && !amISender) {
          statusLabel = "${friendData['name']} Won";
          statusColor = Colors.red;
        } else if (status == 'completed_draw') {
          statusLabel = "It's a Draw!";
          statusColor = Colors.orange;
        }

        statusSpecificUI = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    status == 'active' ? Icons.trending_up : Icons.emoji_events,
                    size: 20,
                    color: statusColor.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$habitType ($targetMax $unit)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildProgressRow("You", myProgress, targetMax, unit, Colors.blue[700]!),
            const SizedBox(height: 12),
            _buildProgressRow(friendData['name'] ?? 'Friend', friendProgress, targetMax, unit, Colors.green[700]!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final String? challengeId = challenge['id'] as String?;
                  if (challengeId != null) {
                    Navigator.pushNamed(
                      context,
                      '/challengeLogger',
                      arguments: {'challengeId': challengeId},
                    ).then((_) => _refreshChallengeForFriend(friendUid));
                  } else {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Challenge ID missing for tracking.")));
                    _refreshChallengeForFriend(friendUid);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Track / View',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (status == 'active') ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  icon: Icon(Icons.cancel_schedule_send, size: 16, color: Colors.orange[700]),
                  label: Text(
                    'Request Cancellation',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () => _requestCancellation(challenge),
                ),
              ),
            ],
          ],
        );
        break;
      case 'cancel_requested':
        String requestMessage = "";
        Widget actionButtons = const SizedBox.shrink();

        if (challenge['cancelRequestedBy'] == _currentUser.uid) {
          requestMessage = "Cancellation requested. Waiting for ${friendData['name']}...";
        } else {
          requestMessage = "${friendData['name']} wants to cancel. Confirm?";
          actionButtons = Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptCancellation(challenge),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Confirm Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _declineCancellation(challenge),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.green[700]!, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Keep Challenge',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        statusSpecificUI = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$habitType ($targetMax $unit)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    requestMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            if (actionButtons != const SizedBox.shrink()) ...[
              const SizedBox(height: 12),
              actionButtons,
            ],
          ],
        );
        break;
      default:
        statusSpecificUI = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "Challenge status: $status",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        );
    }

    return statusSpecificUI;
  }

  Widget _buildProgressRow(String label, num progress, num targetMax, String unit, Color barColor) {
    double progressValue = targetMax > 0 ? (progress / targetMax).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            Text(
              '${progress.toStringAsFixed(0)} / $targetMax $unit',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progressValue,
            backgroundColor: barColor.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(progressValue * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: barColor,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _refreshChallengeForFriend(String friendId) async {
    final challenge = await _getChallengeWithFriend(friendId);
    if (mounted) {
      setState(() {
        _friendChallenges[friendId] = challenge;
      });
    }
  }

  void _cancelSentChallenge(Map<String, dynamic> challenge) async {
    final String? challengeId = challenge['id'] as String?;
    final String? receiverId = challenge['receiverId'] as String?;

    if (challengeId == null || receiverId == null) {
      print("Error cancelling challenge: ID or ReceiverID missing. Challenge: $challenge");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Incomplete challenge data.")));
      if (receiverId != null) _refreshChallengeForFriend(receiverId);
      return;
    }

    if (mounted) {
      setState(() {
        _friendChallenges[receiverId] = null;
      });
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).collection('challenges').doc(challengeId));
      batch.delete(FirebaseFirestore.instance.collection('users').doc(receiverId).collection('challenges').doc(challengeId));
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Challenge cancelled.")));
    } catch (e) {
      print("Error cancelling challenge: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error cancelling: $e")));
        _refreshChallengeForFriend(receiverId);
      }
    }
  }

  void _acceptChallenge(Map<String, dynamic> challenge) async {
    final String? challengeId = challenge['id'] as String?;
    final String? senderId = challenge['senderId'] as String?;

    if (challengeId == null || senderId == null) {
      print("Error accepting challenge: ID or SenderID missing. Challenge: $challenge");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Incomplete challenge data.")));
      if (senderId != null) _refreshChallengeForFriend(senderId);
      return;
    }

    final newStatus = 'active';
    final updatedData = {'status': newStatus, 'acceptedAt': Timestamp.now()};

    if (mounted) {
      setState(() {
        challenge['status'] = newStatus;
        challenge['acceptedAt'] = FieldValue.serverTimestamp(); // For local optimistic update
      });
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).collection('challenges').doc(challengeId), updatedData);
      batch.update(FirebaseFirestore.instance.collection('users').doc(senderId).collection('challenges').doc(challengeId), updatedData);
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Challenge Accepted! Let the games begin!")));
      // NotificationService.showInstantNotification(...);
    } catch (e) {
      print("Error accepting challenge: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        _refreshChallengeForFriend(senderId);
      }
    }
  }

  void _declineChallenge(Map<String, dynamic> challenge) async {
    final String? challengeId = challenge['id'] as String?;
    final String? senderId = challenge['senderId'] as String?;

    if (challengeId == null || senderId == null) {
      print("Error declining challenge: ID or SenderID missing. Challenge: $challenge");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Incomplete challenge data.")));
      if (senderId != null) _refreshChallengeForFriend(senderId);
      return;
    }
    final newStatus = 'declined';
    final updatedData = {'status': newStatus, 'declinedAt': Timestamp.now()};

    if (mounted) {
      setState(() {
        challenge['status'] = newStatus;
        challenge['declinedAt'] = FieldValue.serverTimestamp();
      });
    }
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).collection('challenges').doc(challengeId), updatedData);
      batch.update(FirebaseFirestore.instance.collection('users').doc(senderId).collection('challenges').doc(challengeId), updatedData);
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Challenge declined.")));
    } catch (e) {
      print("Error declining: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        _refreshChallengeForFriend(senderId);
      }
    }
  }

  void _viewChallengeDetails(Map<String, dynamic> challenge) {
    // This method primarily reads, so less critical for write-related null issues
    // but ensure fields are handled with '??' if they can be missing.
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Challenge Details", style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow("Habit:", challenge['habitType'] ?? 'N/A'),
              _detailRow("Unit:", challenge['unit'] ?? 'N/A'),
              _detailRow("Duration:", "${challenge['durationDays'] ?? 0} days"),
              _detailRow("Min Target:", (challenge['targetMin'] ?? 0).toString()),
              _detailRow("Max Target:", (challenge['targetMax'] ?? 0).toString()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontFamily: 'Montserrat'))),
        ],
      ),
    );
  }

  void _requestCancellation(Map<String, dynamic> challenge) async {
    final String? challengeId = challenge['id'] as String?;
    final String? senderId = challenge['senderId'] as String?;
    final String? receiverId = challenge['receiverId'] as String?;

    if (challengeId == null || senderId == null || receiverId == null) {
      print("Error requesting cancellation: Incomplete challenge data. Challenge: $challenge");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot process request: challenge data missing.")));
      // Determine which friend's data to refresh if possible
      final friendToRefresh = (_currentUser.uid == senderId) ? receiverId : senderId;
      if (friendToRefresh != null) _refreshChallengeForFriend(friendToRefresh);
      return;
    }

    final bool amISenderLocal = senderId == _currentUser.uid;
    final String opponentId = amISenderLocal ? receiverId : senderId;

    final updates = {
      'status': 'cancel_requested',
      'cancelRequestedBy': _currentUser.uid,
      'cancelRequestedTo': opponentId,
      'lastUpdated': Timestamp.now(),
    };

    if (mounted) {
      setState(() {
        challenge['status'] = 'cancel_requested';
        challenge['cancelRequestedBy'] = _currentUser.uid;
        challenge['cancelRequestedTo'] = opponentId;
        challenge['lastUpdated'] = FieldValue.serverTimestamp();
      });
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).collection('challenges').doc(challengeId), updates);
      batch.update(FirebaseFirestore.instance.collection('users').doc(opponentId).collection('challenges').doc(challengeId), updates);
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cancellation request sent.")));
    } catch (e) {
      print("Error requesting cancellation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error requesting cancellation: $e")));
        _refreshChallengeForFriend(opponentId);
      }
    }
  }

  void _acceptCancellation(Map<String, dynamic> challenge) async {
    final String? challengeId = challenge['id'] as String?;
    // The one who requested the cancellation is stored in 'cancelRequestedBy'
    final String? requesterId = challenge['cancelRequestedBy'] as String?; // This is the opponent in this context

    if (challengeId == null || requesterId == null) {
      print("Error accepting cancellation: Incomplete challenge data. Challenge: $challenge");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Incomplete challenge data for cancellation.")));
      // Try to refresh based on requesterId if available
      if (requesterId != null) _refreshChallengeForFriend(requesterId);
      // Or find friend from sender/receiver if requesterId is the missing field
      else {
        final String? sId = challenge['senderId'] as String?;
        final String? rId = challenge['receiverId'] as String?;
        if (sId != null && rId != null) {
          _refreshChallengeForFriend( (_currentUser.uid == sId) ? rId : sId );
        }
      }
      return;
    }

    final updates = {'status': 'cancelled_by_agreement', 'lastUpdated': Timestamp.now()};

    if (mounted) {
      setState(() {
        challenge['status'] = 'cancelled_by_agreement';
        challenge['lastUpdated'] = FieldValue.serverTimestamp();
      });
    }
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).collection('challenges').doc(challengeId), updates);
      batch.update(FirebaseFirestore.instance.collection('users').doc(requesterId).collection('challenges').doc(challengeId), updates);
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Challenge cancellation accepted.")));
    } catch (e) {
      print("Error accepting cancellation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        _refreshChallengeForFriend(requesterId);
      }
    }
  }

  void _declineCancellation(Map<String, dynamic> challenge) async {
    final String? challengeId = challenge['id'] as String?;
    final String? requesterId = challenge['cancelRequestedBy'] as String?; // Opponent

    if (challengeId == null || requesterId == null) {
      print("Error declining cancellation: Incomplete challenge data. Challenge: $challenge");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Incomplete challenge data for cancellation.")));
      if (requesterId != null) _refreshChallengeForFriend(requesterId);
      else { // Fallback if requesterId is missing from challenge map
        final String? sId = challenge['senderId'] as String?;
        final String? rId = challenge['receiverId'] as String?;
        if (sId != null && rId != null) {
          _refreshChallengeForFriend( (_currentUser.uid == sId) ? rId : sId );
        }
      }
      return;
    }

    final updates = {
      'status': 'active',
      'cancelRequestedBy': FieldValue.delete(),
      'cancelRequestedTo': FieldValue.delete(),
      'lastUpdated': Timestamp.now(),
    };

    if (mounted) {
      setState(() {
        challenge['status'] = 'active';
        challenge.remove('cancelRequestedBy');
        challenge.remove('cancelRequestedTo');
        challenge['lastUpdated'] = FieldValue.serverTimestamp();
      });
    }
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).collection('challenges').doc(challengeId), updates);
      batch.update(FirebaseFirestore.instance.collection('users').doc(requesterId).collection('challenges').doc(challengeId), updates);
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cancellation declined. The challenge continues!")));
    } catch (e) {
      print("Error declining cancellation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        _refreshChallengeForFriend(requesterId);
      }
    }
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
                      child: const Text(
                        'Challenge Your Friends',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _isLoadingFriends
                          ? const Center(child: CircularProgressIndicator())
                          : _friends.isEmpty
                          ? _buildEmptyState()
                          : _buildFriendsList(),
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

  Widget _buildEmptyState() {
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
              'Add some friends to start a friendly competition!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/friends_screen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Find Friends',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _friends.length,
      itemBuilder: (context, index) => _buildFriendCard(_friends[index]),
    );
  }
}