import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final List<String> categories = [
    'Cardiovascular Fitness',
    'Strength Training',
    'Flexibility and Mobility',
    'Sports and Recreational Activities',
    'Lifestyle Physical Activity',
    'Fitness/Medication for Specific Populations',
    'Custom'
  ];

  final Map<String, List<String>> typesByCategory = {
    'Cardiovascular Fitness': ['Running', 'Brisk walking', 'Cycling', 'Swimming', 'Jump rope', 'Dance or aerobic classes'],
    'Strength Training': ['Weightlifting', 'Push-ups', 'Squats', 'Resistance band workouts', 'CrossFit'],
    'Flexibility and Mobility': ['Stretching routines', 'Yoga', 'Pilates', 'Dynamic warm-ups', 'Cool-downs'],
    'Sports and Recreational Activities': ['Basketball', 'Soccer', 'Tennis', 'Martial arts', 'Hiking', 'Skiing', 'Rock climbing'],
    'Lifestyle Physical Activity': ['Walking to work', 'Taking stairs', 'Housework', 'Gardening', 'Standing desk', 'Walking meetings'],
    'Fitness/Medication for Specific Populations': ['Senior fitness', 'Pregnancy fitness', 'Postpartum fitness', 'Adaptive fitness', 'Youth fitness'],
    'Custom': [],
  };

  final Map<String, List<String>> unitsByCategory = {
    'Cardiovascular Fitness': ['Minutes', 'Distance (km)', 'Sessions'],
    'Strength Training': ['Reps', 'Minutes', 'Sessions'],
    'Flexibility and Mobility': ['Minutes', 'Sessions'],
    'Sports and Recreational Activities': ['Minutes', 'Sessions'],
    'Lifestyle Physical Activity': ['Minutes', 'Sessions'],
    'Fitness/Medication for Specific Populations': ['Minutes', 'Sessions'],
    'Custom': ['Reps', 'Minutes', 'Distance (km)', 'Sessions'],
  };

  final List<String> frequencies = ['Daily', 'Weekly', 'Monthly'];
  final Map<String, List<String>> durationPresets = {
    'Weekly': ['1 week', '2 weeks', '3 weeks', 'Custom'],
    'Monthly': ['1 month', '2 months', '3 months', 'Custom']
  };

  String? selectedCategory;
  String? selectedType;
  String? selectedUnit;
  String? selectedFrequency;
  String? selectedPreset;
  String minTarget = '';
  String maxTarget = '';
  String durationDays = '';

  @override
  Widget build(BuildContext context) {
    final filteredUnits = selectedCategory != null ? unitsByCategory[selectedCategory] ?? [] : [];

    final unitLabel = selectedUnit != null ? selectedUnit!.toLowerCase() : 'unit';

    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            'assets/images/bg.png',
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add New Habit', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  _buildDropdown(
                    title: 'Select Category',
                    value: selectedCategory,
                    items: categories,
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                        selectedType = null;
                        selectedUnit = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  if (selectedCategory != null)
                    _buildDropdown(
                      title: 'Select Type',
                      value: selectedType,
                      items: selectedCategory == 'Custom' ? [] : typesByCategory[selectedCategory] ?? [],
                      onChanged: (value) => setState(() => selectedType = value),
                    ),

                  if (selectedCategory != null)
                    _buildDropdown(
                      title: 'Select Unit',
                      value: selectedUnit,
                      items: List<String>.from(unitsByCategory[selectedCategory] ?? []),
                      onChanged: (value) => setState(() => selectedUnit = value),
                    ),

                  const SizedBox(height: 16),
                  _buildDropdown(
                    title: 'Select Frequency',
                    value: selectedFrequency,
                    items: frequencies,
                    onChanged: (value) {
                      setState(() {
                        selectedFrequency = value;
                        selectedPreset = null;
                        durationDays = '';
                      });
                    },
                  ),

                  const SizedBox(height: 16),
                  _buildTextField('Target per $unitLabel: Minimum (e.g. 10)', (value) => minTarget = value),
                  const SizedBox(height: 12),
                  _buildTextField('Target per $unitLabel: Maximum (e.g. 20)', (value) => maxTarget = value),
                  const SizedBox(height: 16),

                  if (selectedFrequency == 'Weekly' || selectedFrequency == 'Monthly')
                    _buildDropdown(
                      title: 'Duration',
                      value: selectedPreset,
                      items: durationPresets[selectedFrequency]!,
                      onChanged: (value) {
                        setState(() {
                          selectedPreset = value;
                          if (value == 'Custom') {
                            durationDays = '';
                          } else if (value!.contains('week')) {
                            durationDays = (int.parse(value.split(' ')[0]) * 7).toString();
                          } else if (value.contains('month')) {
                            durationDays = (int.parse(value.split(' ')[0]) * 30).toString();
                          }
                        });
                      },
                    ),

                  if ((selectedFrequency == 'Daily') || (selectedPreset == 'Custom'))
                    _buildTextField('For how many days? (e.g. 30)', (value) => durationDays = value),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveHabit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Habit', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String title,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 6, offset: const Offset(2, 4))],
          ),
          child: DropdownButton<String>(
            value: value,
            hint: const Text('Select...'),
            isExpanded: true,
            underline: const SizedBox(),
            items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String hint, Function(String) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 6, offset: const Offset(2, 4))],
      ),
      child: TextField(
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Future<void> _saveHabit() async {
    if (selectedCategory == null || selectedType == null || selectedUnit == null ||
        selectedFrequency == null || minTarget.isEmpty || maxTarget.isEmpty || durationDays.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields.')),
      );
      return;
    }

    final parsedMin = int.tryParse(minTarget);
    final parsedMax = int.tryParse(maxTarget);
    final parsedDuration = int.tryParse(durationDays);

    if (parsedMin == null || parsedMax == null || parsedDuration == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numbers.')),
      );
      return;
    }

    if (parsedMin > parsedMax) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum target cannot be greater than maximum target.')),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in.')),
        );
        return;
      }

      final habitsRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('habits');

      await habitsRef.add({
        'category': selectedCategory,
        'type': selectedType,
        'unit': selectedUnit,
        'frequency': selectedFrequency,
        'targetMin': parsedMin,
        'targetMax': parsedMax,
        'todayProgress': 0,
        'todayExcess': 0,
        'daysCompleted': 0,
        'durationDays': parsedDuration,
        'lastLogged': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Habit saved successfully!')),
      );

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) Navigator.of(context).maybePop();
    } catch (e, stack) {
      debugPrint('❌ Error saving habit: $e');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
}
