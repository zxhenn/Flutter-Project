import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  DateTime? _selectedBirthday;

  String _selectedGender = 'Male'; // Default gender

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
        _usernameStatus = 'Invalid (3-20 chars, a-z, 0-9, _)';
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
        _usernameStatus = isTaken ? 'Username taken' : 'Username available';
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
        _usernameStatus = 'Username taken';
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
        'Height': _heightController.text.trim().isNotEmpty 
            ? '${_heightController.text.trim()} $_heightUnit' 
            : '',
        'Weight': _weightController.text.trim().isNotEmpty 
            ? '${_weightController.text.trim()} $_weightUnit' 
            : '',
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
    _heightController.dispose();
    _weightController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          SizedBox.expand(
            child: Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          // Overlay to reduce background opacity
          Container(
            color: Colors.white.withOpacity(0.7),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // App Logo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/app_icon.png',
                        height: 70,
                        width: 70,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Center(
                      child: Text(
                        'Create Your Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Let\'s get you started',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Username Section
                    _buildTextField(
                      controller: _usernameController,
                      hintText: 'Username',
                      icon: Icons.alternate_email,
                      onChanged: _checkUsernameAvailability,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter a username';
                        if (!RegExp(r"^[a-zA-Z0-9_]{3,20}$").hasMatch(value.trim())) {
                          return 'Invalid (3-20 chars, a-z, 0-9, _)';
                        }
                        if (_usernameStatusColor == Colors.red) return 'Username is taken or invalid';
                        return null;
                      },
                    ),
                    if (_usernameStatus.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                        child: Text(
                          _usernameStatus,
                          style: TextStyle(
                            color: _usernameStatusColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Birthday Picker
                    _buildBirthdayPicker(),
                    const SizedBox(height: 20),

                    // Height & Weight Section
                    _buildHeightWeightInput(
                      controller: _heightController,
                      label: 'Height',
                      icon: Icons.height,
                      unit: _heightUnit,
                      unitOptions: ['cm', 'ft'],
                      onUnitChanged: (val) {
                        setState(() {
                          _heightUnit = val ?? 'cm';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your height';
                        }
                        final num = double.tryParse(value.trim());
                        if (num == null) {
                          return 'Please enter a valid number';
                        }
                        if (num <= 0) {
                          return 'Height must be greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildHeightWeightInput(
                      controller: _weightController,
                      label: 'Weight',
                      icon: Icons.monitor_weight,
                      unit: _weightUnit,
                      unitOptions: ['kg', 'lbs'],
                      onUnitChanged: (val) {
                        setState(() {
                          _weightUnit = val ?? 'kg';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your weight';
                        }
                        final num = double.tryParse(value.trim());
                        if (num == null) {
                          return 'Please enter a valid number';
                        }
                        if (num <= 0) {
                          return 'Weight must be greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Gender Section
                    _buildGenderDropdown(),
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
                          activeColor: Colors.blue[700],
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/terms');
                            },
                            child: RichText(
                              text: TextSpan(
                                text: 'I agree to the ',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Terms and Conditions',
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      color: Colors.blue[700],
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
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildBirthdayPicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
          firstDate: DateTime(1900),
          lastDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
          helpText: 'Select Your Birth Date',
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.blue[700]!,
                  onPrimary: Colors.white,
                  onSurface: Colors.black87,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[700],
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedBirthday == null
                      ? 'Select Birthday'
                      : DateFormat.yMMMd().format(_selectedBirthday!),
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedBirthday == null ? Colors.grey[500] : Colors.black87,
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

  Widget _buildGenderDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration: InputDecoration(
          hintText: 'Gender',
          prefixIcon: Icon(Icons.person, color: Colors.blue),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        items: ['Male', 'Female', 'Other', 'Prefer not to say']
            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
            .toList(),
        onChanged: (value) => setState(() => _selectedGender = value!),
        validator: (value) => value == null ? 'Please select gender' : null,
      ),
    );
  }

  Widget _buildHeightWeightInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String unit,
    required void Function(String?) onUnitChanged,
    required List<String> unitOptions,
    String? Function(String?)? validator,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final text = newValue.text;
                  if (text.isEmpty) return newValue;
                  
                  // Count decimal points
                  final dotCount = '.'.allMatches(text).length;
                  if (dotCount > 1) return oldValue;
                  
                  // Prevent leading dot
                  if (text.startsWith('.')) return oldValue;
                  
                  // Prevent multiple consecutive dots
                  if (text.contains('..')) return oldValue;
                  
                  return newValue;
                }),
              ],
              validator: validator,
              decoration: InputDecoration(
                hintText: label,
                prefixIcon: Icon(icon, color: Colors.blue),
                suffixText: unit,
                suffixStyle: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: unit,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              ),
              items: unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
              onChanged: onUnitChanged,
            ),
          ),
        ),
      ],
    );
  }
}