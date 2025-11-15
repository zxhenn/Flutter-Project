import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart'; // For TextInputFormatters

class ChallengeAddHabitPage extends StatefulWidget {
  final String friendId;
  final String friendName;

  const ChallengeAddHabitPage({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<ChallengeAddHabitPage> createState() => _ChallengeAddHabitPageState();
}

class _ChallengeAddHabitPageState extends State<ChallengeAddHabitPage> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'Running'; // Underscore for private state
  int _minTarget = 1;
  int _maxTarget = 5;
  int _duration = 7; // In days
  String _selectedUnit = 'Sessions'; // Default, will adjust based on type

  bool _isSubmitting = false;

  final List<String> _habitTypes = [ // Underscore for private state
    'Running',
    'Yoga',
    'Weightlifting',
    'Cycling',
    'Meditation',
    'Reading',
    'Journaling',
    // Add more common types
  ];
  static const Map<String, List<String>> habitTypeUnitMap = {
    'Running': ['Distance (km)', 'Minutes', 'Sessions'],
    'Cycling': ['Distance (km)', 'Minutes', 'Sessions'],
    'Weightlifting': ['Sets', 'Reps', 'Minutes', 'Sessions'],
    'Yoga': ['Minutes', 'Sessions'],
    'Meditation': ['Minutes', 'Sessions'],
    'Reading': ['Pages', 'Minutes', 'Sessions'],
    'Journaling': ['Pages', 'Minutes', 'Sessions'],
    // add other types here — keep this map synced with your habit logger code
  };

  late final List<String> _habitTypesList; // derived from the map

  List<String> _getUnitOptionsForType(String type) {
    return habitTypeUnitMap[type] ?? ['Sessions'];
  }

// in initState:
  @override
  void initState() {
    super.initState();
    _habitTypesList = habitTypeUnitMap.keys.toList();
    // ensure _selectedType is a valid type; if not, pick first from list
    if (!_habitTypesList.contains(_selectedType)) {
      _selectedType = _habitTypesList.isNotEmpty ? _habitTypesList.first : 'Sessions';
    }
    _selectedUnit = _getUnitOptionsForType(_selectedType).first;
  }
  // Initialize selectedUnit based on the default selectedType



  Future<void> _submitChallenge() async {
    if (!_formKey.currentState!.validate()) return;

    // authoritative numeric validation
    if (_minTarget <= 0 || _maxTarget <= 0 || _duration <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Targets and duration must be positive numbers.")),
      );
      return;
    }
    if (_minTarget > _maxTarget) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Min target cannot be greater than max target.")),
      );
      return;
    }


    setState(() => _isSubmitting = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not authenticated.")));
      }
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final allChallenges = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('challenges')
          .where('status', whereIn: ['pending', 'active']) // don't block on completed
          .get();

      final hasActiveChallengeWithFriend = allChallenges.docs.any((doc) {
        final data = doc.data();
        final idA = data['senderId'];
        final idB = data['receiverId'];
        return ((idA == currentUser.uid && idB == widget.friendId) ||
            (idA == widget.friendId && idB == currentUser.uid));
      });

      if (hasActiveChallengeWithFriend) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You already have an active or pending challenge with this friend.")),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      final challengeId = const Uuid().v4();
      final challengeData = {
        'id': challengeId,
        'senderId': currentUser.uid,
        'receiverId': widget.friendId,
        'senderName': currentUser.displayName ?? currentUser.email ?? 'Challenger',
        'receiverName': widget.friendName,
        'habitType': _selectedType,
        'unit': _selectedUnit,
        'targetMin': _minTarget,
        'targetMax': _maxTarget,
        'durationDays': _duration,
        'status': 'pending', // Initial status
        'createdAt': Timestamp.now(),
        'senderProgress': 0,  // Initial progress
        'receiverProgress': 0, // Initial progress
        'senderLogs': [],     // To store individual logs with timestamp and value
        'receiverLogs': [],
        // 'lastUpdated': Timestamp.now(), // Optional: for sorting or activity feed
      };

      final batch = FirebaseFirestore.instance.batch();

      final senderChallengeRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('challenges')
          .doc(challengeId);
      batch.set(senderChallengeRef, challengeData);

      final receiverChallengeRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.friendId)
          .collection('challenges')
          .doc(challengeId);
      batch.set(receiverChallengeRef, challengeData);

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Challenge sent successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send challenge: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildInputCard({required String title, required Widget child, IconData? titleIcon}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (titleIcon != null) ...[
                  Icon(titleIcon, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    // color: theme.colorScheme.onSurface.withOpacity(0.87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUnitOptions = _getUnitOptionsForType(_selectedType);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Challenge ${widget.friendName}", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.textTheme.titleLarge?.color ?? theme.colorScheme.primary),
        titleTextStyle: TextStyle(color: theme.textTheme.titleLarge?.color ?? theme.colorScheme.primary, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Friend Info
                _buildInputCard(
                    title: "Challenging",
                    titleIcon: Icons.person_pin_circle_outlined,
                    child: Text(widget.friendName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary))),

                // Habit Type
                _buildInputCard(
                  title: "Habit Type",
                  titleIcon: Icons.category_outlined,
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: _inputDecoration(hint: "Select Habit Type"),
                      items: _habitTypesList
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final newUnitOptions = _getUnitOptionsForType(val);
                        setState(() {
                          _selectedType = val;
                          // Update selectedUnit only if it's not in the new options
                          if (!newUnitOptions.contains(_selectedUnit)) {
                            _selectedUnit = newUnitOptions.first;
                          }
                        });
                      }
                    },
                    validator: (value) => value == null ? 'Please select a habit type' : null,
                  ),
                ),

                // Unit for selected Habit Type
                _buildInputCard(
                  title: "Unit of Measurement",
                  titleIcon: Icons.straighten_outlined,
                  child: DropdownButtonFormField<String>(
                    value: currentUnitOptions.contains(_selectedUnit) ? _selectedUnit : currentUnitOptions.first,
                    decoration: _inputDecoration(hint: "Select Unit"),
                    items: currentUnitOptions
                        .map((unit) => DropdownMenuItem(
                      value: unit,
                      child: Text(unit),
                    ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedUnit = val);
                      }
                    },
                    validator: (value) => value == null ? 'Please select a unit' : null,
                  ),
                ),

                // Target Range
                _buildInputCard(
                  title: "Target Range per Log",
                  titleIcon: Icons.track_changes_outlined,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _minTarget.toString(),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _inputDecoration(label: 'Min Target'),
                          onChanged: (val) => _minTarget = int.tryParse(val) ?? _minTarget,
                          validator: (val) => (int.tryParse(val ?? "") ?? 0) <= 0 ? 'Must be > 0' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                            initialValue: _maxTarget.toString(),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: _inputDecoration(label: 'Max Target'),
                            onChanged: (val) => _maxTarget = int.tryParse(val) ?? _maxTarget,
                            validator: (val) {
                              if ((int.tryParse(val ?? "") ?? 0) <= 0) return 'Must be > 0';
                              if ((int.tryParse(val ?? "") ?? 0) < _minTarget) return 'Max ≥ Min';
                              return null;
                            }
                        ),
                      ),
                    ],
                  ),
                ),

                // Duration
                _buildInputCard(
                  title: "Challenge Duration",
                  titleIcon: Icons.date_range_outlined,
                  child: TextFormField(
                    initialValue: _duration.toString(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDecoration(label: 'Duration (in days)'),
                    onChanged: (val) => _duration = int.tryParse(val) ?? _duration,
                    validator: (val) => (int.tryParse(val ?? "") ?? 0) <= 0 ? 'Must be > 0 days' : null,
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  icon: _isSubmitting ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white),
                  label: Text(_isSubmitting ? "Sending..." : "Send Challenge",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _submitChallenge,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}