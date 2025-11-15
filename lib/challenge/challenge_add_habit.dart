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

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInputCard({required String title, required Widget child, IconData? titleIcon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              if (titleIcon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(titleIcon, color: Colors.blue[700], size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUnitOptions = _getUnitOptionsForType(_selectedType);

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
          'Send Challenge',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Friend Info Card
                Container(
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.blue[700],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Challenging',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.friendName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

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

                // Send Challenge Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitChallenge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Send Challenge',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
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
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300!),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400!, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: Colors.grey[700]),
    );
  }
}