import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController(); // Changed from _nameController
  DateTime? _selectedBirthday;

  String _selectedGender = 'Male'; // Default gender
  String? _selectedHeight;
  String? _selectedWeight;

  String _heightUnit = 'cm';
  String _weightUnit = 'kg';
  bool _agreedToTerms = false;

  String _usernameStatus = ''; // For username availability
  Color _usernameStatusColor = Colors.transparent;
  bool _isCheckingUsername = false;
  Timer? _usernameDebounce;

  int calculateAge(DateTime birthday) {
    final today = DateTime.now();
    int age = today.year - birthday.year;
    if (today.month < birthday.month ||
        (today.month == birthday.month && today.day < birthday.day)) {
      age--;
    }
    return age;
  }

  List<String> get heightOptions {
    if (_heightUnit == 'cm') {
      return List.generate(111, (i) => '${120 + i} cm'); // Adjusted range
    } else {
      List<String> imperial = [];
      for (int ft = 4; ft <= 7; ft++) {
        for (int inch = 0; inch < 12; inch++) {
          if (ft == 4 && inch < 0) continue; // Start from 4'0"
          if (ft == 7 && inch > 6) break;   // Up to 7'6"
          imperial.add("${ft}'${inch}\"");
        }
      }
      return imperial;
    }
  }

  List<String> get weightOptions {
    if (_weightUnit == 'kg') {
      return List.generate(171, (i) => '${30 + i} kg');
    } else {
      return List.generate(335, (i) => '${66 + i} lbs'); // Adjusted range for lbs
    }
  }

  Future<void> _checkUsernameAvailability(String username) async {
    final trimmedUsername = username.trim();
    if (trimmedUsername.isEmpty) {
      setState(() {
        _usernameStatus = '';
        _usernameStatusColor = Colors.transparent;
        _isCheckingUsername = false;
      });
      return;
    }

    // Basic username validation (you can make this stricter)
    if (!RegExp(r"^[a-zA-Z0-9_]{3,20}$").hasMatch(trimmedUsername)) {
      setState(() {
        _usernameStatus = '❌ Invalid (3-20 chars, a-z, 0-9, _)';
        _usernameStatusColor = Colors.red;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameStatus = 'Checking...';
      _usernameStatusColor = Colors.orange;
    });

    if (_usernameDebounce?.isActive ?? false) _usernameDebounce!.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 700), () async {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      // Query by 'UsernameLower' for case-insensitive check
      final query = await FirebaseFirestore.instance
          .collection('Profiles')
          .where('UsernameLower', isEqualTo: trimmedUsername.toLowerCase())
          .limit(1) // We only need to know if at least one exists
          .get();

      if (!mounted) return;

      final isTaken = query.docs.any((doc) => doc.id != currentUserId);

      setState(() {
        _usernameStatus = isTaken ? '❌ Username taken' : '✅ Username available';
        _usernameStatusColor = isTaken ? Colors.red : Colors.green;
        _isCheckingUsername = false;
      });
    });
  }

  Future<void> _saveProfile() async {
    if (_isCheckingUsername) { // Don't save if username check is in progress
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for username check.')),
      );
      return;
    }
    if (_usernameStatusColor == Colors.red || _usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid and available username.')),
      );
      return;
    }

    if (_formKey.currentState?.validate() != true) return;
    if (!_agreedToTerms || _selectedBirthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields and agree to terms.')),
      );
      return;
    }

    final username = _usernameController.text.trim();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not authenticated.')),
      );
      return;
    }

    // Final check before saving (though _checkUsernameAvailability should cover it)
    final nameCheck = await FirebaseFirestore.instance
        .collection('Profiles')
        .where('UsernameLower', isEqualTo: username.toLowerCase())
        .get();

    if (nameCheck.docs.isNotEmpty && nameCheck.docs.first.id != user.uid) {
      setState(() { // Update UI if somehow it got taken between check and save
        _usernameStatus = '❌ Username taken';
        _usernameStatusColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username was just taken. Please choose another.')),
      );
      return;
    }

    final calculatedAge = calculateAge(_selectedBirthday!);

    try {
      await FirebaseFirestore.instance.collection('Profiles').doc(user.uid).set({
        'Username': username,
        'UsernameLower': username.toLowerCase(), // For case-insensitive querying
        'Name': username, // If you still need a 'Name' field, use username or ask for full name separately
        'NameLower': username.toLowerCase(),
        'Age': calculatedAge,
        'Birthday': Timestamp.fromDate(_selectedBirthday!),
        'Height': _selectedHeight ?? '',
        'Weight': _selectedWeight ?? '',
        'Gender': _selectedGender,
        'FocusArea': '', // To be set in profile_setup2
        'receiveRequests': true,
        'Email': user.email, // Email from Auth
        'photoUrl': user.photoURL, // Photo from Auth (if available)
        'Uid': user.uid,
        'searchableField': '${username.toLowerCase()} ${email.toLowerCase()}',
        // Initialize points fields
        'strengthPoints': 0,
        'cardioPoints': 0,
        'miscPoints': 0,
        'rank': 'Bronze', // Default starting rank
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Also create a document in the 'users' collection if it's separate and needed
      // This is important for the PointingSystem.getTotalPoints if it reads from 'users'
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'Username': username,
        'strengthPoints': 0,
        'cardioPoints': 0,
        'miscPoints': 0,
        'rank': 'Bronze',
        // Add any other fields your 'users' collection schema needs
      }, SetOptions(merge: true)); // Merge true to not overwrite if doc exists with other data


      if (mounted) {
        Navigator.pushReplacementNamed(context, '/profile_setup2');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: ${e.toString()}')),
        );
      }
      print("Error saving profile: $e");
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[100], // Light background color
      appBar: AppBar(
        title: const Text('Create Your Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
        titleTextStyle: TextStyle(color: theme.textTheme.titleLarge?.color, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '👋 Welcome!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Let’s get your profile set up.',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // Username Section
                _buildInputCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Username', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _usernameController,
                        keyboardType: TextInputType.text,
                        onChanged: _checkUsernameAvailability,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Please enter a username';
                          if (!RegExp(r"^[a-zA-Z0-9_]{3,20}$").hasMatch(value.trim())) {
                            return 'Invalid (3-20 chars, a-z, 0-9, _)';
                          }
                          if (_usernameStatusColor == Colors.red) return 'Username is taken or invalid';
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'e.g., FitnessFan123',
                          prefixIcon: const Icon(Icons.alternate_email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        ),
                      ),
                      if (_usernameStatus.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Text(
                            _usernameStatus,
                            style: TextStyle(
                                color: _usernameStatusColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Birthday Picker
                _buildInputCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Birthday', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _buildBirthdayPicker(theme),
                      ],
                    )
                ),
                const SizedBox(height: 20),

                // Height & Weight Section
                _buildInputCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Physical Info', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        _buildDropdownRow(
                          label: 'Height',
                          value: _selectedHeight,
                          items: heightOptions,
                          onChanged: (val) => setState(() => _selectedHeight = val),
                          unit: _heightUnit,
                          unitOptions: ['cm', 'ft'],
                          onUnitChanged: (val) {
                            setState(() {
                              _heightUnit = val ?? 'cm';
                              _selectedHeight = null; // Reset selection when unit changes
                            });
                          },
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownRow(
                          label: 'Weight',
                          value: _selectedWeight,
                          items: weightOptions,
                          onChanged: (val) => setState(() => _selectedWeight = val),
                          unit: _weightUnit,
                          unitOptions: ['kg', 'lbs'],
                          onUnitChanged: (val) {
                            setState(() {
                              _weightUnit = val ?? 'kg';
                              _selectedWeight = null; // Reset selection
                            });
                          },
                          theme: theme,
                        ),
                      ],
                    )
                ),
                const SizedBox(height: 20),

                // Gender Section
                _buildInputCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gender', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          ),
                          items: ['Male', 'Female', 'Other', 'Prefer not to say']
                              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                              .toList(),
                          onChanged: (value) => setState(() => _selectedGender = value!),
                          validator: (value) => value == null ? 'Please select gender' : null,
                        ),
                      ],
                    )
                ),
                const SizedBox(height: 24),

                // Terms and Conditions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: (value) {
                        setState(() => _agreedToTerms = value ?? false);
                      },
                      activeColor: theme.colorScheme.primary,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Navigate to your terms and conditions screen
                          // Navigator.pushNamed(context, '/terms');
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Navigate to Terms & Conditions page (not implemented).'))
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            text: 'I agree to the ',
                            style: theme.textTheme.bodyMedium,
                            children: [
                              TextSpan(
                                text: 'Terms and Conditions',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Save Button
                ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Save & Continue 🚀', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 30), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper to build styled input cards
  Widget _buildInputCard({required Widget child}) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 0), // Margin handled by SizedBox between cards
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }


  Widget _buildBirthdayPicker(ThemeData theme) {
    return InkWell( // Use InkWell for better tap feedback
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
          firstDate: DateTime(1900),
          lastDate: DateTime.now().subtract(const Duration(days: 365 * 5)), // Minimum age 5
          helpText: 'Select Your Birth Date',
          builder: (context, child) { // Optional: Theme the date picker
            return Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(
                  primary: theme.colorScheme.primary, // header background color
                  onPrimary: Colors.white, // header text color
                  onSurface: theme.textTheme.bodyLarge?.color, // body text color
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary, // button text color
                  ),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null && picked != _selectedBirthday) {
          setState(() => _selectedBirthday = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedBirthday == null
                      ? 'Select Birthday'
                      : DateFormat.yMMMd().format(_selectedBirthday!),
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedBirthday == null ? Colors.grey[600] : theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    required String unit,
    required void Function(String?) onUnitChanged,
    required List<String> unitOptions,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top
      children: [
        // Unit Dropdown
        SizedBox(
          width: 90, // Slightly wider for units like 'ft/in'
          child: DropdownButtonFormField<String>(
            value: unit,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            ),
            items: unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
            onChanged: onUnitChanged,
          ),
        ),
        const SizedBox(width: 12),
        // Value Dropdown
        Expanded(
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              hintText: label, // Show label as hint
              filled: true,
              fillColor: Colors.white.withOpacity(0.8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            isExpanded: true,
            items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: onChanged,
            validator: (val) => val == null || val.isEmpty ? 'Please select' : null,
          ),
        ),
      ],
    );
  }
}