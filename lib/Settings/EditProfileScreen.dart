import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  DateTime? _selectedBirthday;

  String _selectedGender = 'Male';
  String? _selectedHeight;
  String? _selectedWeight;
  String _heightUnit = 'cm';
  String _weightUnit = 'kg';

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

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('Profiles').doc(user.uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    _nameController.text = data['Name'] ?? '';
    _selectedHeight = heightOptions.contains(data['Height']) ? data['Height'] : null;
    _selectedWeight = weightOptions.contains(data['Weight']) ? data['Weight'] : null;
    _selectedGender = data['Gender'] ?? 'Male';
    final birthdayTimestamp = data['Birthday'];
    if (birthdayTimestamp != null && birthdayTimestamp is Timestamp) {
      _selectedBirthday = birthdayTimestamp.toDate();
    }
    setState(() {});
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ✅ Save updated values to Firestore under /Profiles/{uid}
    await FirebaseFirestore.instance
        .collection('Profiles')
        .doc(user.uid)
        .set({
      'Name': _nameController.text.trim(), // ✅ User name
      'NameLower': _nameController.text.trim().toLowerCase(), // lowercase for searching
      'Age': calculatedAge, // ✅ Calculated from birthday
      'Height': _selectedHeight ?? '', // ✅ Height selection
      'Weight': _selectedWeight ?? '', // ✅ Weight selection
      'Gender': _selectedGender, // ✅ Gender selection
      'Birthday': _selectedBirthday != null
          ? Timestamp.fromDate(_selectedBirthday!)
          : null, // ✅ Save as Firestore Timestamp
    }, SetOptions(merge: true)); // ✅ Prevent overwriting other existing fields

    // ✅ Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully!')),
    );

    // ✅ Navigate back to settings screen
    if (mounted) {
      Navigator.pop(context);
    }
  }


  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontFamily: 'Montserrat'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),

              const Text(
                'Name',
                style: TextStyle(fontFamily: 'Montserrat'),
              ),
              _buildTextField(_nameController, 'Full Name', Icons.person),

              const SizedBox(height: 20),
              const Text(
                'Birthday',
                style: TextStyle(fontFamily: 'Montserrat'),
              ),
              _buildBirthdayPicker(),

              const SizedBox(height: 20),
              const Text(
                'Age',
                style: TextStyle(fontFamily: 'Montserrat'),
              ),
              _buildAgeDisplay(),

              const SizedBox(height: 20),
              const Text(
                'Height',
                style: TextStyle(fontFamily: 'Montserrat'),
              ),
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
                    _selectedHeight = null;
                  });
                },
              ),

              const SizedBox(height: 20),
              const Text(
                'Weight',
                style: TextStyle(fontFamily: 'Montserrat'),
              ),
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
                    _selectedWeight = null;
                  });
                },
              ),

              const SizedBox(height: 20),
              const Text(
                'Gender',
                style: TextStyle(fontFamily: 'Montserrat'),
              ),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(
                  value: g,
                  child: Text(g, style: const TextStyle(fontFamily: 'Montserrat')),
                ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedGender = value!),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBirthdayPicker() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: ListTile(
        title: Text(_selectedBirthday == null
            ? 'Select Birthday'
            : DateFormat.yMMMd().format(_selectedBirthday!)),
        leading: const Icon(Icons.calendar_today),
        onTap: () async {
          DateTime now = DateTime.now();
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: _selectedBirthday ?? DateTime(now.year - 18),
            firstDate: DateTime(1900),
            lastDate: DateTime(now.year, now.month, now.day),
          );
          if (pickedDate != null) {
            setState(() => _selectedBirthday = pickedDate);
          }
        },
      ),
    );
  }

  Widget _buildAgeDisplay() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.cake),
          const SizedBox(width: 12),
          Text('Age: ${calculatedAge}', style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String hint,
      IconData icon, {
        TextInputType type = TextInputType.text,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        validator: (value) => value!.isEmpty ? 'Please enter $hint' : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
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
  }) {
    return Row(
      children: [
        Container(
          width: 80,
          margin: const EdgeInsets.only(right: 8, bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: DropdownButton<String>(
            value: unit,
            underline: const SizedBox(),
            isExpanded: true,
            items: unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
            onChanged: onUnitChanged,
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: value,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '',
              ),
              hint: Text(label),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down),
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: onChanged,
              validator: (val) => val == null || val.isEmpty ? 'Please select $label' : null,
            ),
          ),
        ),
      ],
    );
  }
}
