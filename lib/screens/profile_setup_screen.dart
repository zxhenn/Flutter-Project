import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  String _selectedGender = 'Male';
  String? _selectedHeight;
  String? _selectedWeight;

  String _heightUnit = 'cm';
  String _weightUnit = 'kg';
  bool _agreedToTerms = false;

  List<String> get heightOptions {
    if (_heightUnit == 'cm') {
      return List.generate(81, (i) => '${140 + i} cm');
    } else {
      List<String> imperial = [];
      for (int ft = 4; ft <= 7; ft++) {
        for (int inch = 0; inch < 12; inch++) {
          if (ft == 4 && inch < 8) continue; // Start at 4'8"
          if (ft == 7 && inch > 2) break; // End at 7'2"
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

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() != true) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must agree to the Terms and Conditions.')),
      );
      return;
    }
    final name = _nameController.text.trim();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('Profiles').doc(user.uid).set({
      'Name': _nameController.text.trim(),
      'Age': int.tryParse(_ageController.text.trim()) ?? 0,
      'Height': _selectedHeight ?? '',
      'Weight': _selectedWeight ?? '',
      'Gender': _selectedGender,
      'FocusArea': '',
      'receiveRequests': true,
      'Email': user.email,
      'Uid': user.uid,
      'searchableField': '${name.toLowerCase()} ${email.toLowerCase()}',
    });

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/profile_setup2');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: Image.asset('assets/images/bg.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      '👋 Welcome to Solitum!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Let’s set up your profile to get started.',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 30),

                    _buildTextField(_nameController, 'Full Name', Icons.person),
                    _buildTextField(_ageController, 'Age', Icons.cake, type: TextInputType.number),

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
                          _selectedHeight = null; // Reset on change
                        });
                      },
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

                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Gender',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: ['Male', 'Female', 'Other']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedGender = value!),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          onChanged: (value) {
                            setState(() => _agreedToTerms = value ?? false);
                          },
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/terms'),
                            child: const Text.rich(
                              TextSpan(
                                text: 'I agree to the ',
                                children: [
                                  TextSpan(
                                    text: 'Terms and Conditions',
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Continue to Next Step 🚀'),
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
        // Unit dropdown
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

        // Value dropdown
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
