import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import '/addition/gps_running_tracker.dart';
import '/addition/minutes_timer_page.dart';
import '/addition/session_timer_page.dart';
import 'dart:async';
// import '/utils/pointing_system.dart'; // If you award points for winning

class ChallengeLoggerPage extends StatefulWidget {
  final String challengeId;

  const ChallengeLoggerPage({
    super.key,
    required this.challengeId,
  });

  @override
  State<ChallengeLoggerPage> createState() => _ChallengeLoggerPageState();
}

class _ChallengeLoggerPageState extends State<ChallengeLoggerPage> {
  late String currentUserId;
  bool _isLoading = true;
  Map<String, dynamic>? _challengeData;
  StreamSubscription<DocumentSnapshot>? _challengeListener;

  // Extracted for easier access
  String get _habitType => _challengeData?['habitType'] ?? 'N/A';
  String get _unit {
    final type = _habitType.toLowerCase();
    if (type == 'running' || type == 'cycling') { // Assuming cycling unit can also be distance
      return _challengeData?['unit']?.toLowerCase() == 'distance (km)' ? 'km' : (_challengeData?['unit']?.toLowerCase() == 'minutes' ? 'min' : 'sessions');
    } else if (type == 'meditation' || type == 'yoga' || type == 'journaling') {
      return _challengeData?['unit']?.toLowerCase() == 'minutes' ? 'min' : 'sessions';
    }
    return _challengeData?['unit'] ?? 'sessions';
  }

  num get _targetMin => _challengeData?['targetMin'] ?? 0;
  num get _targetMax => _challengeData?['targetMax'] ?? 0;
  num get _myProgress => _isSender ? (_challengeData?['senderProgress'] ?? 0) : (_challengeData?['receiverProgress'] ?? 0);
  num get _friendProgress => _isSender ? (_challengeData?['receiverProgress'] ?? 0) : (_challengeData?['senderProgress'] ?? 0);
  String get _friendName => _isSender ? (_challengeData?['receiverName'] ?? 'Friend') : (_challengeData?['senderName'] ?? 'Friend');
  bool get _isSender => currentUserId == _challengeData?['senderId'];
  Timestamp? get _createdAt => _challengeData?['createdAt'] as Timestamp?;
  int get _durationDays => _challengeData?['durationDays'] ?? 7;
  String get _status => _challengeData?['status'] ?? 'unknown';


  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _listenToChallenge();
  }

  @override
  void dispose() {
    _challengeListener?.cancel();
    super.dispose();
  }

  void _listenToChallenge() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    _challengeListener = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid) // Listen to my copy of the challenge
        .collection('challenges')
        .doc(widget.challengeId)
        .snapshots()
        .listen((doc) {
      if (mounted) {
        if (doc.exists) {
          setState(() {
            _challengeData = doc.data();
            _isLoading = false;
          });
        } else {
          // Challenge might have been deleted
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Challenge not found or has been removed.")),
            );
            Navigator.of(context).pop();
          }
        }
      }
    }, onError: (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading challenge: $error")),
        );
      }
      print("Error listening to challenge: $error");
    });
  }

  bool get _isChallengePeriodOver {
    if (_createdAt == null) return false;
    final endDate = _createdAt!.toDate().add(Duration(days: _durationDays));
    return DateTime.now().isAfter(endDate);
  }

  String get _winnerId {
    if (!_isChallengePeriodOver || _status != 'active') return ''; // Only determine winner if over and active
    if (_myProgress > _friendProgress) return currentUserId;
    if (_friendProgress > _myProgress) return _isSender ? _challengeData!['receiverId'] : _challengeData!['senderId'];
    return 'draw'; // Or handle draws differently
  }

  bool get _canClaimPrize {
    return _isChallengePeriodOver &&
        _winnerId == currentUserId &&
        _status == 'active'; // Assuming 'active' means prize not yet claimed
  }


  Future<void> _launchTracker() async {
    if (_challengeData == null) return;
    if (_myProgress >= _targetMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You've already reached the max target for this challenge!")),
      );
      return;
    }
    if (_status != 'active' && _status != 'pending') { // Assuming pending means you can start, active means ongoing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("This challenge is not active. Status: $_status")),
      );
      return;
    }


    dynamic result;
    final habitTypeLower = _habitType.toLowerCase();
    final unitLower = _unit.toLowerCase();

    if (habitTypeLower == 'running' || (habitTypeLower == 'cycling' && unitLower == 'km')) {
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GPSRunningTrackerPage(
            habitId: widget.challengeId, // Technically challengeId, not habitId
            target: _targetMax,      // Pass the overall target
            unit: 'km', // Ensure GPS tracker expects km
          ),
        ),
      );
      if (result != null && result is double && result > 0) {
        await _updateProgress(result, isDistance: true);
      }
    } else if (habitTypeLower == 'meditation' ||
        habitTypeLower == 'yoga' ||
        habitTypeLower == 'journaling' ||
        (habitTypeLower == 'cycling' && unitLower == 'min') ||
        (habitTypeLower == 'running' && unitLower == 'min')) {
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MinutesTimerPage(
            habitId: widget.challengeId,
            targetMin: _targetMin.toDouble(),
            targetMax: _targetMax.toDouble(),
          ),
        ),
      );
      if (result != null && result is int && result > 0) { // MinutesTimerPage returns int seconds
        await _updateProgress((result / 60.0), isDurationInMinutes: true); // Convert seconds to minutes for progress
      }
    } else { // Default to SessionTimerPage for 'sessions' unit or other types
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionTimerPage(
            habitId: widget.challengeId,
            targetMin: _targetMin,
            targetMax: _targetMax,
          ),
        ),
      );
      if (result != null && result is Map && result['sessionCount'] != null) {
        await _updateProgress(result['sessionCount'].toDouble());
      }
    }
  }

  Future<void> _updateProgress(double value, {bool isDistance = false, bool isDurationInMinutes = false}) async {
    if (_challengeData == null) return;
    setState(() => _isLoading = true); // Show loading indicator during update

    final String progressField = _isSender ? 'senderProgress' : 'receiverProgress';
    final String friendId = _isSender ? _challengeData!['receiverId'] : _challengeData!['senderId'];
    final String logField = _isSender ? 'senderLogs' : 'receiverLogs';

    final logEntry = {
      'timestamp': Timestamp.now(),
      'value': value,
      if (isDistance) 'unit': 'km',
      if (isDurationInMinutes) 'unit': 'minutes',
      if (!isDistance && !isDurationInMinutes) 'unit': 'sessions',
    };

    final batch = FirebaseFirestore.instance.batch();

    final myDocRef = FirebaseFirestore.instance.collection('users').doc(currentUserId).collection('challenges').doc(widget.challengeId);
    final friendDocRef = FirebaseFirestore.instance.collection('users').doc(friendId).collection('challenges').doc(widget.challengeId);

    // Update progress, ensuring it doesn't exceed targetMax
    num newProgress = _myProgress + value;
    if (newProgress > _targetMax) {
      newProgress = _targetMax;
    }

    batch.update(myDocRef, {
      progressField: newProgress,
      logField: FieldValue.arrayUnion([logEntry]),
      'lastUpdated': Timestamp.now(),
    });
    batch.update(friendDocRef, { // Mirror the progress field name for the other user too
      progressField: newProgress,
      logField: FieldValue.arrayUnion([logEntry]), // Also mirror logs if you want both to see all logs for that person
      'lastUpdated': Timestamp.now(),
    });

    // Check if this progress update completes the challenge for the current user
    String newStatus = _status;
    if (newProgress >= _targetMax && _status == 'active') {
      // Potentially update status if one user completes target, but winner is decided at end
      // For now, winner logic is separate
    }

    // If challenge period is over, determine winner and update status
    if (_isChallengePeriodOver && _status == 'active') {
      final determinedWinnerId = _winnerId; // Recalculate with potentially new progress
      if (determinedWinnerId == currentUserId) {
        newStatus = 'completed_won';
      } else if (determinedWinnerId == 'draw') {
        newStatus = 'completed_draw';
      } else if (determinedWinnerId.isNotEmpty) { // Friend won
        newStatus = 'completed_lost';
      }
      // Only update status if it changed and is a terminal state
      if(newStatus != _status && (newStatus.startsWith('completed'))) {
        batch.update(myDocRef, {'status': newStatus});
        batch.update(friendDocRef, {'status': newStatus});
      }
    }


    try {
      await batch.commit();
      // No need to call _listenToChallenge or setState here as the listener will pick it up.
      // setState(() => _isLoading = false); // Listener will set isLoading to false
    } catch (e) {
      print("Error updating progress: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update progress: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _claimPrize() async {
    if (!_canClaimPrize || _challengeData == null) return;
    setState(() => _isLoading = true);

    final String friendId = _isSender ? _challengeData!['receiverId'] : _challengeData!['senderId'];
    final batch = FirebaseFirestore.instance.batch();

    final myDocRef = FirebaseFirestore.instance.collection('users').doc(currentUserId).collection('challenges').doc(widget.challengeId);
    final friendDocRef = FirebaseFirestore.instance.collection('users').doc(friendId).collection('challenges').doc(widget.challengeId);

    final newStatus = 'prize_claimed_by_$currentUserId';

    batch.update(myDocRef, {'status': newStatus, 'lastUpdated': Timestamp.now()});
    batch.update(friendDocRef, {'status': newStatus, 'lastUpdated': Timestamp.now()});

    // --- Placeholder for actual prize awarding ---
    // Example: Awarding points using PointingSystem (if you have one)
    // await PointingSystem.rewardHonorPoints(currentUserId, 50); // Award 50 honor points
    // --- End placeholder ---

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Prize Claimed! Congratulations!")),
        );
      }
      // Listener will update the UI with the new status
    } catch (e) {
      print("Error claiming prize: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to claim prize: $e")));
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading && _challengeData == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.grey[50],
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.grey[900]),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Challenge Tracker',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_challengeData == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.grey[50],
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.grey[900]),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Challenge Tracker',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
        ),
        body: const Center(child: Text('Challenge data not available.')),
      );
    }

    bool canTrackNow = (_status == 'active' || _status == 'pending') && _myProgress < _targetMax;
    final challengeEndDate = _createdAt?.toDate().add(Duration(days: _durationDays));
    final String timeRemaining = challengeEndDate != null ?
    (DateTime.now().isBefore(challengeEndDate) ?
    "${challengeEndDate.difference(DateTime.now()).inDays}d ${challengeEndDate.difference(DateTime.now()).inHours % 24}h left"
        : "Ended")
        : "Date N/A";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[900]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _habitType,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        actions: [
          if (_isChallengePeriodOver && _status == 'active')
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.grey[900]),
              onPressed: () => _updateProgress(0.0),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChallengeInfoCard(timeRemaining),
              const SizedBox(height: 24),
              _buildProgressCard("Your Progress", _myProgress, _targetMax, _unit, Colors.blue[700]!),
              const SizedBox(height: 16),
              _buildProgressCard("${_friendName}'s Progress", _friendProgress, _targetMax, _unit, Colors.green[700]!),
              const SizedBox(height: 32),

              if (_isLoading && _challengeData != null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  ),
                ),

              if (canTrackNow)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _launchTracker,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700], // modern blue
                      padding: const EdgeInsets.symmetric(vertical: 18), // taller button
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4, // subtle shadow
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 10),
                        Text(
                          "Track Now",
                          style: TextStyle(
                            fontSize: 18, // slightly bigger text
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_canClaimPrize)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _claimPrize,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700], // warm color for claim
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.star, color: Colors.white, size: 24),
                        SizedBox(width: 10),
                        Text(
                          "Claim Your Prize!",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildStatusDisplay(),



              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeInfoCard(String timeRemaining) {
    final isActive = DateTime.now().isBefore(_createdAt!.toDate().add(Duration(days: _durationDays)));
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.flag, color: Colors.blue[700], size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Challenger: $_friendName",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _habitType,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.track_changes_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      "Target: $_targetMin-$_targetMax $_unit",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                  ],
                ),
                if (_createdAt != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        "Ends: ${DateFormat.yMMMd().add_jm().format(_createdAt!.toDate().add(Duration(days: _durationDays)))}",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? Colors.blue.shade50 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.timer : Icons.check_circle,
                  size: 16,
                  color: isActive ? Colors.blue[700] : Colors.grey[700],
                ),
                const SizedBox(width: 6),
                Text(
                  timeRemaining,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.blue[700] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String title, num currentProgress, num targetMax, String unit, Color progressColor) {
    double progressValue = (targetMax > 0) ? (currentProgress / targetMax).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${currentProgress.toStringAsFixed(unit == 'km' ? 2 : 0)} / ${targetMax.toStringAsFixed(0)} $unit",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${(progressValue * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 16,
              backgroundColor: progressColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDisplay() {
    String statusText = "Challenge Ended";
    IconData statusIcon = Icons.check_circle_outline;
    Color statusColor = Colors.green;

    switch (_status) {
      case 'pending':
        statusText = 'Challenge pending acceptance.';
        statusIcon = Icons.hourglass_empty;
        statusColor = Colors.orange;
        break;
      case 'active':
        statusText = _myProgress >= _targetMax ? "You've reached the target!" : "Challenge is active.";
        statusIcon = _myProgress >= _targetMax ? Icons.star : Icons.directions_run;
        statusColor = _myProgress >= _targetMax ? Colors.amber.shade700! : Colors.blue[700]!;
        break;
      case 'declined':
        statusText = 'Challenge declined by friend.';
        statusIcon = Icons.cancel;
        statusColor = Colors.red;
        break;
      case 'completed_won':
        statusText = 'You won this challenge! 🎉';
        statusIcon = Icons.star;
        statusColor = Colors.amber.shade700!;
        break;
      case 'completed_lost':
        statusText = 'Challenge completed. Better luck next time!';
        statusIcon = Icons.sentiment_satisfied_alt;
        statusColor = Colors.green[700]!;
        break;
      case 'completed_draw':
        statusText = 'Challenge ended in a draw!';
        statusIcon = Icons.handshake;
        statusColor = Colors.blueGrey;
        break;
      default:
        if(_status.startsWith('prize_claimed_by_')) {
          if (_status == 'prize_claimed_by_$currentUserId') {
            statusText = 'You claimed your prize! Well done!';
          } else {
            statusText = 'Prize claimed by ${_friendName}.';
          }
          statusIcon = Icons.redeem;
          statusColor = Colors.purple;
        } else {
          statusText = 'Challenge status: $_status';
          statusIcon = Icons.info_outline;
          statusColor = Colors.grey;
        }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}