import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  DateTime? _selectedBirthday;

  String _selectedGender = 'Male';
  String? _selectedHeight;
  String? _selectedWeight;
  String _heightUnit = 'cm';
  String _weightUnit = 'kg';

  String _usernameStatus = '';
  Color _usernameStatusColor = Colors.transparent;
  bool _isCheckingUsername = false;
  Timer? _usernameDebounce;

  int get calculatedAge {
    if (_selectedBirthday == null) return 0;
    final today = DateTime.now();
    int age = today.year - _selectedBirthday!.year;
    if (today.month < _selectedBirthday!.month ||
        (today.month == _selectedBirthday!.month && today.day < _selectedBirthday!.day)) {
      age--;
    }
    return age;
  }

  List<String> get heightOptions {
    if (_heightUnit == 'cm') {
      return List.generate(81, (i) => '${140 + i} cm');
    } else {
      List<String> imperial = [];
      for (int ft = 4; ft <= 7; ft++) {
        for (int inch = 0; inch < 12; inch++) {
          if (ft == 4 && inch < 8) continue;
          if (ft == 7 && inch > 2) break;
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
      return List.generate(175, (i) => '${66 + i} lbs');
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

    // Basic username validation
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
      if (currentUserId == null) return;

      // Query by 'UsernameLower' for case-insensitive check
      final query = await FirebaseFirestore.instance
          .collection('Profiles')
          .where('UsernameLower', isEqualTo: trimmedUsername.toLowerCase())
          .limit(1)
          .get();

      if (!mounted) return;

      // Check if username is taken by another user
      final isTaken = query.docs.any((doc) => doc.id != currentUserId);

      // Check if it's the current user's username
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('Profiles')
          .doc(currentUserId)
          .get();
      final currentUsername = currentUserDoc.data()?['Username'] ?? 
                              currentUserDoc.data()?['Name'] ?? '';

      if (!mounted) return;

      setState(() {
        if (isTaken) {
          _usernameStatus = 'Username taken';
          _usernameStatusColor = Colors.red;
        } else if (trimmedUsername.toLowerCase() == currentUsername.toLowerCase()) {
          _usernameStatus = 'Current username';
          _usernameStatusColor = Colors.green;
        } else {
          _usernameStatus = 'Username available';
          _usernameStatusColor = Colors.green;
        }
        _isCheckingUsername = false;
      });
    });
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('Profiles').doc(user.uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    // Load username (prefer Username field, fallback to Name)
    final username = data['Username'] ?? data['Name'] ?? '';
    _usernameController.text = username;
    
    // Load height - extract numeric value and unit if it exists
    final heightStr = data['Height'] ?? '';
    if (heightStr.isNotEmpty) {
      // Detect unit from saved string
      if (heightStr.toLowerCase().contains('ft') || heightStr.contains("'")) {
        _heightUnit = 'ft';
      } else {
        _heightUnit = 'cm';
      }
      
      // Extract numeric value
      final heightMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(heightStr);
      if (heightMatch != null) {
        _heightController.text = heightMatch.group(1) ?? '';
      }
      _selectedHeight = heightStr;
    }
    
    // Load weight - extract numeric value and unit if it exists
    final weightStr = data['Weight'] ?? '';
    if (weightStr.isNotEmpty) {
      // Detect unit from saved string
      if (weightStr.toLowerCase().contains('lbs') || weightStr.toLowerCase().contains('lb')) {
        _weightUnit = 'lbs';
      } else {
        _weightUnit = 'kg';
      }
      
      // Extract numeric value
      final weightMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(weightStr);
      if (weightMatch != null) {
        _weightController.text = weightMatch.group(1) ?? '';
      }
      _selectedWeight = weightStr;
    }
    
    _selectedGender = data['Gender'] ?? 'Male';
    final birthdayTimestamp = data['Birthday'];
    if (birthdayTimestamp != null && birthdayTimestamp is Timestamp) {
      _selectedBirthday = birthdayTimestamp.toDate();
    }
    setState(() {});
  }

  Future<void> _saveProfile() async {
    if (_isCheckingUsername) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for username check.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final username = _usernameController.text.trim();
    
    // Check if username is valid
    if (!RegExp(r"^[a-zA-Z0-9_]{3,20}$").hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid username (3-20 chars, a-z, 0-9, _)')),
      );
      return;
    }

    // Final check before saving - make sure username is available (unless it's the current user's)
    final currentUserDoc = await FirebaseFirestore.instance
        .collection('Profiles')
        .doc(user.uid)
        .get();
    final currentUsername = currentUserDoc.data()?['Username'] ?? currentUserDoc.data()?['Name'] ?? '';
    
    if (username.toLowerCase() != currentUsername.toLowerCase()) {
      // Only check availability if username changed
      final nameCheck = await FirebaseFirestore.instance
          .collection('Profiles')
          .where('UsernameLower', isEqualTo: username.toLowerCase())
          .get();

      if (nameCheck.docs.isNotEmpty && nameCheck.docs.first.id != user.uid) {
        setState(() {
          _usernameStatus = 'Username taken';
          _usernameStatusColor = Colors.red;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username is already taken. Please choose another.')),
        );
        return;
      }
    }

    // Build height and weight strings with units
    final heightValue = _heightController.text.trim();
    final weightValue = _weightController.text.trim();
    final heightStr = heightValue.isNotEmpty ? '$heightValue $_heightUnit' : '';
    final weightStr = weightValue.isNotEmpty ? '$weightValue $_weightUnit' : '';

    // ✅ Save updated values to Firestore under /Profiles/{uid}
    await FirebaseFirestore.instance
        .collection('Profiles')
        .doc(user.uid)
        .set({
      'Username': username,
      'UsernameLower': username.toLowerCase(),
      'Name': username, // Keep Name for backward compatibility
      'NameLower': username.toLowerCase(),
      'Age': calculatedAge,
      'Height': heightStr,
      'Weight': weightStr,
      'Gender': _selectedGender,
      'Birthday': _selectedBirthday != null
          ? Timestamp.fromDate(_selectedBirthday!)
          : null,
    }, SetOptions(merge: true));

    // ✅ Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _heightController.dispose();
    _weightController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Username Field
              _buildSectionLabel('Username'),
              const SizedBox(height: 8),
              _buildUsernameField(),

              const SizedBox(height: 24),

              // Birthday Field
              _buildSectionLabel('Birthday'),
              const SizedBox(height: 8),
              _buildBirthdayPicker(),

              const SizedBox(height: 24),

              // Age Display
              _buildSectionLabel('Age'),
              const SizedBox(height: 8),
              _buildAgeDisplay(),

              const SizedBox(height: 24),

              // Height Field
              _buildSectionLabel('Height'),
              const SizedBox(height: 8),
              _buildHeightWeightField(
                controller: _heightController,
                hint: 'Enter height',
                icon: Icons.height,
                unit: _heightUnit,
                unitOptions: ['cm', 'ft'],
                onUnitChanged: (val) {
                  setState(() {
                    _heightUnit = val ?? 'cm';
                    _heightController.clear();
                    _selectedHeight = null;
                  });
                },
              ),

              const SizedBox(height: 24),

              // Weight Field
              _buildSectionLabel('Weight'),
              const SizedBox(height: 8),
              _buildHeightWeightField(
                controller: _weightController,
                hint: 'Enter weight',
                icon: Icons.monitor_weight_outlined,
                unit: _weightUnit,
                unitOptions: ['kg', 'lbs'],
                onUnitChanged: (val) {
                  setState(() {
                    _weightUnit = val ?? 'kg';
                    _weightController.clear();
                    _selectedWeight = null;
                  });
                },
              ),

              const SizedBox(height: 24),

              // Gender Field
              _buildSectionLabel('Gender'),
              const SizedBox(height: 8),
              _buildGenderDropdown(),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildBirthdayPicker() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          DateTime now = DateTime.now();
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: _selectedBirthday ?? DateTime(now.year - 18),
            firstDate: DateTime(1900),
            lastDate: DateTime(now.year, now.month, now.day),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: Colors.blue[700]!,
                    onPrimary: Colors.white,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (pickedDate != null) {
            setState(() => _selectedBirthday = pickedDate);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.calendar_today, size: 20, color: Colors.blue[700]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _selectedBirthday == null
                      ? 'Select Birthday'
                      : DateFormat.yMMMd().format(_selectedBirthday!),
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedBirthday == null ? Colors.grey[400] : Colors.grey[900],
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgeDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.cake, size: 20, color: Colors.blue[700]),
          ),
          const SizedBox(width: 16),
          Text(
            calculatedAge > 0 ? '$calculatedAge years old' : 'Select birthday to calculate age',
            style: TextStyle(
              fontSize: 16,
              color: calculatedAge > 0 ? Colors.grey[900] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _usernameStatusColor == Colors.red
                  ? Colors.red.shade300
                  : _usernameStatusColor == Colors.green
                      ? Colors.green.shade300
                      : Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _usernameController,
            onChanged: _checkUsernameAvailability,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a username';
              }
              if (!RegExp(r"^[a-zA-Z0-9_]{3,20}$").hasMatch(value.trim())) {
                return 'Invalid (3-20 chars, a-z, 0-9, _)';
              }
              if (_usernameStatusColor == Colors.red) {
                return 'Username is taken';
              }
              return null;
            },
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
            ],
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Enter username',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.alternate_email, size: 20, color: Colors.blue[700]),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (_usernameStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
            child: _isCheckingUsername
                ? Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _usernameStatus,
                        style: TextStyle(
                          color: _usernameStatusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _usernameStatus,
                    style: TextStyle(
                      color: _usernameStatusColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _buildHeightWeightField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String unit,
    required List<String> unitOptions,
    required void Function(String?) onUnitChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter $hint';
                }
                final numValue = double.tryParse(value);
                if (numValue == null || numValue <= 0) {
                  return 'Please enter a valid number';
                }
                return null;
              },
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: Colors.blue[700]),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: unit,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            items: unitOptions.map((u) => DropdownMenuItem(
              value: u,
              child: Text(u, style: const TextStyle(fontSize: 14)),
            )).toList(),
            onChanged: onUnitChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration: InputDecoration(
          prefixIcon: Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person_outline, size: 20, color: Colors.blue[700]),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(
          value: g,
          child: Text(g, style: const TextStyle(fontSize: 16)),
        )).toList(),
        onChanged: (value) => setState(() => _selectedGender = value!),
      ),
    );
  }

}
