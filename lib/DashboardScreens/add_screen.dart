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

  // For "Minutes" unit input
  final TextEditingController minHours = TextEditingController();
  final TextEditingController minMinutes = TextEditingController();
  final TextEditingController minSeconds = TextEditingController();
  final TextEditingController maxHours = TextEditingController();
  final TextEditingController maxMinutes = TextEditingController();
  final TextEditingController maxSeconds = TextEditingController();


  final List<String> categories = [
    'Cardiovascular Fitness',
    'Strength Training',
    'Custom',
  ];

  final Map<String, List<String>> typesByCategory = {
    'Cardiovascular Fitness': ['Running', 'Brisk walking', 'Cycling', 'Swimming', 'Jump rope', 'Dance or aerobic classes', 'Taking stairs'],
    'Strength Training': ['Weightlifting', 'Push-ups', 'Squats', 'CrossFit'],
    'Custom': [],
  };

  final Map<String, List<String>> baseUnits = {
    'Cardiovascular Fitness': ['Minutes', 'Distance (km)'],
    'Strength Training': [ 'Minutes', 'Sessions'],
    'Custom': ['Minutes', 'Distance (km)', 'Sessions'],
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

  List<String> getFilteredUnits() {
    if (selectedCategory == null) return [];

    final units = baseUnits[selectedCategory!] ?? [];

    if (selectedType == null) return units;

    final type = selectedType!.toLowerCase();

    if (type.contains('run') || type.contains('walk')) {
      return ['Minutes', 'Distance (km)'];
    }

    if (type.contains('lift') || type.contains('push') || type.contains('squat') || type.contains('weight')) {
      return ['Sessions'];
    }

    if (type.contains('yoga') || type.contains('stretch') || type.contains('pilates')) {
      return ['Minutes', 'Sessions'];
    }

    return units;
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = selectedUnit != null ? selectedUnit!.toLowerCase() : 'unit';

    return Scaffold(
      body: Stack(
        children: [
          // Image.asset('assets/images/bg.png', fit: BoxFit.cover, height: double.infinity, width: double.infinity),
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add New Habit', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue, fontFamily: 'Montserrat')),
                  const SizedBox(height: 24),
                  _buildDropdown('Select Category', selectedCategory, categories, (val) {
                    setState(() {
                      selectedCategory = val;
                      selectedType = null;
                      selectedUnit = null;
                    });
                  }),
                  const SizedBox(height: 16),
                  if (selectedCategory != null && selectedCategory != 'Custom')
                    _buildDropdown('Select Type', selectedType, typesByCategory[selectedCategory]!, (val) => setState(() => selectedType = val)),
                  if (selectedCategory == 'Custom') ...[
                    const Text('Custom Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 6, offset: const Offset(2, 4))]),
                      child: TextField(
                        onChanged: (val) => setState(() => selectedType = val),
                        decoration: const InputDecoration(hintText: 'Enter custom type', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (selectedCategory != null)
                    _buildDropdown('Select Unit', selectedUnit, getFilteredUnits(), (val) => setState(() => selectedUnit = val)),
                  const SizedBox(height: 16),
                  _buildDropdown('Select Frequency', selectedFrequency, frequencies, (val) {
                    setState(() {
                      selectedFrequency = val;
                      selectedPreset = null;
                      durationDays = '';
                    });
                  }),
                  if (selectedUnit == 'Minutes') ...[
                    const Text('Minimum Target', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(child: _buildTextFieldWithController('HH', minHours)),
                        const SizedBox(width: 6),
                        Flexible(child: _buildTextFieldWithController('MM', minMinutes)),
                        const SizedBox(width: 6),
                        Flexible(child: _buildTextFieldWithController('SS', minSeconds)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder(
                      valueListenable: minHours,
                      builder: (_, __, ___) => ValueListenableBuilder(
                        valueListenable: minMinutes,
                        builder: (_, __, ___) => ValueListenableBuilder(
                          valueListenable: minSeconds,
                          builder: (_, __, ___) {
                            final total = ((int.tryParse(minHours.text) ?? 0) * 60 +
                                (int.tryParse(minMinutes.text) ?? 0) +
                                (int.tryParse(minSeconds.text) ?? 0)) ~/ 1;
                            return Text('≈ $total min', style: const TextStyle(color: Colors.grey));
                          },
                        ),
                      ),
                    ),


                    const SizedBox(height: 16),
                    const Text('Maximum Target', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(child: _buildTextFieldWithController('HH', maxHours)),
                        const SizedBox(width: 6),
                        Flexible(child: _buildTextFieldWithController('MM', maxMinutes)),
                        const SizedBox(width: 6),
                        Flexible(child: _buildTextFieldWithController('SS', maxSeconds)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '≈ ${(int.tryParse(maxHours.text) ?? 0) * 60 + (int.tryParse(maxMinutes.text) ?? 0) + (int.tryParse(maxSeconds.text) ?? 0) ~/ 60} min',
                      style: const TextStyle(color: Colors.grey),
                    ),
                ] else ...[
                    const Text('Minimum Target', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    _buildTextField('e.g. 10 $unitLabel', (val) => minTarget = val),
                    const SizedBox(height: 16),
                    const Text('Maximum Target', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    _buildTextField('e.g. 20 $unitLabel', (val) => maxTarget = val),
                  ],

                  if (selectedFrequency == 'Weekly' || selectedFrequency == 'Monthly')
                    _buildDropdown('Duration', selectedPreset, durationPresets[selectedFrequency]!, (val) {
                      setState(() {
                        selectedPreset = val;
                        if (val == 'Custom') durationDays = '';
                        else if (val!.contains('week')) durationDays = (int.parse(val.split(' ')[0]) * 7).toString();
                        else if (val.contains('month')) durationDays = (int.parse(val.split(' ')[0]) * 30).toString();
                      });
                    }),
                  if (selectedFrequency == 'Daily' || selectedPreset == 'Custom') ...[
                    const Text('Duration (Days)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    _buildTextField('e.g. 30', (val) => durationDays = val),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveHabit,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Save Habit', style: TextStyle(fontSize: 18, color: Colors.white, fontFamily: 'Montserrat')),
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

  Widget _buildDropdown(String title, String? value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 6, offset: const Offset(2, 4))]),
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
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: const Offset(2, 4),
          ),
        ],
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

  Widget _buildTextFieldWithController(String hint, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 6, offset: const Offset(2, 4))],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }


  Future<void> _saveHabit() async {
    final bool isMinutes = selectedUnit == 'Minutes';

    if (selectedCategory == null || selectedType == null || selectedUnit == null || selectedFrequency == null || durationDays.isEmpty ||
        (!isMinutes && (minTarget.isEmpty || maxTarget.isEmpty))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all fields.')));
      return;
    }


    final double parsedMin = selectedUnit == 'Minutes'
        ? ((int.tryParse(minHours.text) ?? 0) * 3600 +
        (int.tryParse(minMinutes.text) ?? 0) * 60 +
        (int.tryParse(minSeconds.text) ?? 0)) / 60
        : double.tryParse(minTarget) ?? 0;

    final double parsedMax = selectedUnit == 'Minutes'
        ? ((int.tryParse(maxHours.text) ?? 0) * 3600 +
        (int.tryParse(maxMinutes.text) ?? 0) * 60 +
        (int.tryParse(maxSeconds.text) ?? 0)) / 60
        : double.tryParse(maxTarget) ?? 0;

    final parsedDuration = int.tryParse(durationDays);

    if (parsedMin <= 0 || parsedMax <= 0 || parsedMin > parsedMax || parsedDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check targets and duration values.')),
      );
      return;
    }


    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final habitsRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('habits');

      final existing = await habitsRef
          .where('type', isEqualTo: selectedType)
          .where('unit', isEqualTo: selectedUnit)
          .where('frequency', isEqualTo: selectedFrequency)
          .get();
      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This habit already exists.')));
        return;
      }

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
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }
}
