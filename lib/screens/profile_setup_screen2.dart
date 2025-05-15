import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileSetupScreen2 extends StatefulWidget {
  const ProfileSetupScreen2({super.key});

  @override
  State<ProfileSetupScreen2> createState() => _ProfileSetupScreen2State();
}

class _ProfileSetupScreen2State extends State<ProfileSetupScreen2> {
  String selectedFocus = '';
  bool _isSaving = false;

  Future<void> onProfileSetupComplete() async {
    if (selectedFocus.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a focus area")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not logged in.")),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('Profiles')
          .doc(user.uid)
          .update({'FocusArea': selectedFocus});

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving focus: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Text(
                'WHAT DO YOU WANT TO FOCUS ON?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 24),

              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  focusButton('Workout', Icons.fitness_center),
                  focusButton('Running', Icons.directions_run),
                  focusButton('Medicine', Icons.medical_services),
                  focusButton('Therapy', Icons.healing),
                  focusButton('Yoga', Icons.self_improvement),
                  focusButton('Other', Icons.more_horiz),
                ],
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : onProfileSetupComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget focusButton(String label, IconData icon) {
    final isSelected = selectedFocus == label;

    return GestureDetector(
      onTap: () => setState(() => selectedFocus = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: MediaQuery.of(context).size.width * 0.4,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[100] : Colors.teal[50],
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(2, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.blue[800]),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
