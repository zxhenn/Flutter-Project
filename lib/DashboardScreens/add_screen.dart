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
    'Strength Training': ['Minutes', 'Sessions'],
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Habit',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('Category & Type'),
            const SizedBox(height: 12),
            _buildDropdownCard(
              icon: Icons.category,
              title: 'Category',
              value: selectedCategory,
              items: categories,
              onChanged: (val) {
                setState(() {
                  selectedCategory = val;
                  selectedType = null;
                  selectedUnit = null;
                });
              },
            ),
            if (selectedCategory != null && selectedCategory != 'Custom') ...[
              const SizedBox(height: 16),
              _buildDropdownCard(
                icon: Icons.fitness_center,
                title: 'Type',
                value: selectedType,
                items: typesByCategory[selectedCategory]!,
                onChanged: (val) => setState(() => selectedType = val),
              ),
            ],
            if (selectedCategory == 'Custom') ...[
              const SizedBox(height: 16),
              _buildTextFieldCard(
                icon: Icons.edit,
                title: 'Custom Type',
                hint: 'Enter custom type',
                onChanged: (val) => setState(() => selectedType = val),
              ),
            ],
            if (selectedCategory != null) ...[
              const SizedBox(height: 16),
              _buildDropdownCard(
                icon: Icons.straighten,
                title: 'Unit',
                value: selectedUnit,
                items: getFilteredUnits(),
                onChanged: (val) => setState(() => selectedUnit = val),
              ),
            ],
            const SizedBox(height: 24),
            _buildSectionLabel('Frequency & Duration'),
            const SizedBox(height: 12),
            _buildDropdownCard(
              icon: Icons.calendar_today,
              title: 'Frequency',
              value: selectedFrequency,
              items: frequencies,
              onChanged: (val) {
                setState(() {
                  selectedFrequency = val;
                  selectedPreset = null;
                  durationDays = '';
                });
              },
            ),
            if (selectedFrequency == 'Weekly' || selectedFrequency == 'Monthly') ...[
              const SizedBox(height: 16),
              _buildDropdownCard(
                icon: Icons.schedule,
                title: 'Duration',
                value: selectedPreset,
                items: durationPresets[selectedFrequency]!,
                onChanged: (val) {
                  setState(() {
                    selectedPreset = val;
                    if (val == 'Custom') {
                      durationDays = '';
                    } else if (val != null && val.contains('week')) {
                      durationDays = (int.parse(val.split(' ')[0]) * 7).toString();
                    } else if (val != null && val.contains('month')) {
                      durationDays = (int.parse(val.split(' ')[0]) * 30).toString();
                    }
                  });
                },
              ),
            ],
            if (selectedFrequency == 'Daily' || selectedPreset == 'Custom') ...[
              const SizedBox(height: 16),
              _buildTextFieldCard(
                icon: Icons.date_range,
                title: 'Duration (Days)',
                hint: 'e.g. 30',
                keyboardType: TextInputType.number,
                onChanged: (val) => durationDays = val,
              ),
            ],
            const SizedBox(height: 24),
            _buildSectionLabel('Targets'),
            const SizedBox(height: 12),
            if (selectedUnit == 'Minutes') ...[
              _buildMinutesTargetSection(),
            ] else if (selectedUnit != null) ...[
              _buildTextFieldCard(
                icon: Icons.trending_down,
                title: 'Minimum Target',
                hint: 'e.g. 10 $unitLabel',
                keyboardType: TextInputType.number,
                onChanged: (val) => minTarget = val,
              ),
              const SizedBox(height: 16),
              _buildTextFieldCard(
                icon: Icons.trending_up,
                title: 'Maximum Target',
                hint: 'e.g. 20 $unitLabel',
                keyboardType: TextInputType.number,
                onChanged: (val) => maxTarget = val,
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveHabit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Create Habit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildDropdownCard({
    required IconData icon,
    required String title,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButton<String>(
                      value: value,
                      hint: Text(
                        'Select $title',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      items: items.map((item) {
                        return DropdownMenuItem<String>(
                          value: item,
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[900],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: onChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldCard({
    required IconData icon,
    required String title,
    required String hint,
    TextInputType? keyboardType,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    keyboardType: keyboardType,
                    onChanged: onChanged,
                    decoration: InputDecoration(
                      hintText: hint,
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[900],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinutesTargetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.trending_down,
                        size: 20,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Minimum Target',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeField('HH', minHours),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTimeField('MM', minMinutes),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTimeField('SS', minSeconds),
                    ),
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
                        final hours = int.tryParse(minHours.text) ?? 0;
                        final minutes = int.tryParse(minMinutes.text) ?? 0;
                        final seconds = int.tryParse(minSeconds.text) ?? 0;
                        final totalMinutes = (hours * 60) + minutes + (seconds ~/ 60);
                        return Text(
                          '≈ $totalMinutes min',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        size: 20,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Maximum Target',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeField('HH', maxHours),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTimeField('MM', maxMinutes),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTimeField('SS', maxSeconds),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: maxHours,
                  builder: (_, __, ___) => ValueListenableBuilder(
                    valueListenable: maxMinutes,
                    builder: (_, __, ___) => ValueListenableBuilder(
                      valueListenable: maxSeconds,
                      builder: (_, __, ___) {
                        final hours = int.tryParse(maxHours.text) ?? 0;
                        final minutes = int.tryParse(maxMinutes.text) ?? 0;
                        final seconds = int.tryParse(maxSeconds.text) ?? 0;
                        final totalMinutes = (hours * 60) + minutes + (seconds ~/ 60);
                        return Text(
                          '≈ $totalMinutes min',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField(String hint, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 2,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          counterText: '',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[900],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }


  Future<void> _saveHabit() async {
    final bool isMinutes = selectedUnit == 'Minutes';

    // Validate required fields
    if (selectedCategory == null || selectedType == null || selectedUnit == null || selectedFrequency == null || durationDays.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all fields.')));
      return;
    }

    // Validate targets based on unit type
    if (isMinutes) {
      final minTotal = (int.tryParse(minHours.text) ?? 0) * 3600 +
          (int.tryParse(minMinutes.text) ?? 0) * 60 +
          (int.tryParse(minSeconds.text) ?? 0);
      final maxTotal = (int.tryParse(maxHours.text) ?? 0) * 3600 +
          (int.tryParse(maxMinutes.text) ?? 0) * 60 +
          (int.tryParse(maxSeconds.text) ?? 0);
      if (minTotal == 0 || maxTotal == 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter minimum and maximum targets.')));
        return;
      }
    } else {
      if (minTarget.isEmpty || maxTarget.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter minimum and maximum targets.')));
        return;
      }
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
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }
}
