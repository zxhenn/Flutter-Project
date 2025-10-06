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
          const SnackBar(content: Text("🎉 Prize Claimed! Congratulations! 🎉")),
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
    final theme = Theme.of(context);

    if (_isLoading && _challengeData == null) { // Show loading only on initial load
      return Scaffold(
        appBar: AppBar(title: const Text('Challenge Tracker'), elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_challengeData == null) { // Should be handled by listener pop, but as a fallback
      return Scaffold(
        appBar: AppBar(title: const Text('Challenge Tracker'), elevation: 0),
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_habitType, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_isChallengePeriodOver && _status == 'active') // Show refresh if period is over but status not terminal
            IconButton(icon: Icon(Icons.refresh), onPressed: () => _updateProgress(0.0) ) // Force status re-evaluation
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildChallengeInfoCard(theme, timeRemaining),
              const SizedBox(height: 20),
              _buildProgressCard(theme, "Your Progress", _myProgress, _targetMax, _unit, theme.colorScheme.primary),
              const SizedBox(height: 16),
              _buildProgressCard(theme, "${_friendName}'s Progress", _friendProgress, _targetMax, _unit, theme.colorScheme.secondary),
              const SizedBox(height: 30),

              if (_isLoading && _challengeData != null) // Show loading indicator for updates
                const Center(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2.0,),
                )),


              if (canTrackNow)
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 28),
                  label: const Text("Track Now", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  onPressed: _isLoading ? null : _launchTracker,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else if (_canClaimPrize)
                ElevatedButton.icon(
                  icon: const Icon(Icons.emoji_events_rounded, size: 28),
                  label: const Text("Claim Your Prize!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  onPressed: _isLoading ? null : _claimPrize,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else
                _buildStatusDisplay(theme), // Show challenge status if not tracking or claiming

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeInfoCard(ThemeData theme, String timeRemaining) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_circle_outlined, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text("Challenge vs. $_friendName", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Text("Habit: $_habitType", style: theme.textTheme.bodyLarge),
            Text("Target: $_targetMin-$_targetMax $_unit", style: theme.textTheme.bodyLarge),
            if (_createdAt != null)
              Text("Ends: ${DateFormat.yMMMd().add_jm().format(_createdAt!.toDate().add(Duration(days: _durationDays)))}", style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Chip(
              label: Text(timeRemaining, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: DateTime.now().isBefore(_createdAt!.toDate().add(Duration(days: _durationDays)))
                  ? theme.colorScheme.secondary
                  : Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(ThemeData theme, String title, num currentProgress, num targetMax, String unit, Color progressColor) {
    double progressValue = (targetMax > 0) ? (currentProgress / targetMax).clamp(0.0, 1.0) : 0.0;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${currentProgress.toStringAsFixed(unit == 'km' ? 2:0)} / ${targetMax.toStringAsFixed(0)} $unit",
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text("${(progressValue * 100).toStringAsFixed(0)}%", style: theme.textTheme.bodyMedium?.copyWith(color: progressColor)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 12,
                backgroundColor: progressColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDisplay(ThemeData theme) {
    String statusText = "Challenge Ended";
    IconData statusIcon = Icons.check_circle_outline_rounded;
    Color statusColor = Colors.green;

    switch (_status) {
      case 'pending':
        statusText = 'Challenge pending acceptance.';
        statusIcon = Icons.hourglass_empty_rounded;
        statusColor = Colors.orange;
        break;
      case 'active': // Should not reach here if canTrackNow is false and canClaimPrize is false
        statusText = _myProgress >= _targetMax ? "You've reached the target!" : "Challenge is active.";
        statusIcon = _myProgress >= _targetMax ? Icons.star_rounded : Icons.directions_run_rounded;
        statusColor = _myProgress >= _targetMax ? Colors.amber.shade700 : theme.colorScheme.primary;
        break;
      case 'declined':
        statusText = 'Challenge declined by friend.';
        statusIcon = Icons.cancel_rounded;
        statusColor = Colors.red;
        break;
      case 'completed_won':
        statusText = 'You won this challenge! 🎉';
        statusIcon = Icons.emoji_events_rounded;
        statusColor = Colors.amber.shade700;
        break;
      case 'completed_lost':
        statusText = 'Challenge completed. Better luck next time!';
        statusIcon = Icons.sentiment_satisfied_alt_rounded;
        statusColor = theme.colorScheme.secondary;
        break;
      case 'completed_draw':
        statusText = 'Challenge ended in a draw!';
        statusIcon = Icons.handshake_rounded;
        statusColor = Colors.blueGrey;
        break;
      default:
        if(_status.startsWith('prize_claimed_by_')) {
          if (_status == 'prize_claimed_by_$currentUserId') {
            statusText = 'You claimed your prize! Well done!';
          } else {
            statusText = 'Prize claimed by ${_friendName}.';
          }
          statusIcon = Icons.redeem_rounded;
          statusColor = Colors.purple;
        } else {
          statusText = 'Challenge status: $_status';
          statusIcon = Icons.info_outline_rounded;
          statusColor = Colors.grey;
        }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Text(statusText, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: statusColor))),
        ],
      ),
    );
  }
}