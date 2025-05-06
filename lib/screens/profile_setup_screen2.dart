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
  bool _isSaving = false; // Add loading state

  Future<void> onProfileSetupComplete() async {
    if (selectedFocus.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a focus area")),
      );
      return;
    }

    setState(() => _isSaving = true); // Show loading indicator

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
          .collection('Profiles') // ✅ Fixed: Always use Profiles
          .doc(user.uid)
          .update({
        'FocusArea': selectedFocus,
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving focus: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false); // Stop loading
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
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

                  // Focus area buttons
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      focusButton('Workout', Icons.fitness_center),
                      focusButton('Running', Icons.directions_run),
                      focusButton('Medicine', Icons.medical_services),
                      focusButton('Therapy', Icons.healing),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Done button
                  ElevatedButton(
                    onPressed: _isSaving ? null : onProfileSetupComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Done', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget for focus area button
  Widget focusButton(String label, IconData icon) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFocus = label;
        });
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: selectedFocus == label ? Colors.blue[100] : Colors.teal[50],
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.grey, blurRadius: 4, offset: Offset(2, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blue[800]),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
