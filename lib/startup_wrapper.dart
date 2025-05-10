import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartUpWrapper extends StatefulWidget {
  const StartUpWrapper({super.key});

  @override
  State<StartUpWrapper> createState() => _StartUpWrapperState();
}

class _StartUpWrapperState extends State<StartUpWrapper> {
  @override
  void initState() {
    super.initState();
    _checkState();
  }

  Future<void> _checkState() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;
    final user = FirebaseAuth.instance.currentUser;

    if (!hasSeenWelcome) {
      Navigator.pushReplacementNamed(context, '/welcome');
      return;
    }

    if (user == null) {
      Navigator.pushReplacementNamed(context, '/auth');
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('Profiles').doc(user.uid).get();
    if (!doc.exists) {
      Navigator.pushReplacementNamed(context, '/setup1');
    } else if ((doc.data()?['FocusArea'] ?? '').toString().isEmpty) {
      Navigator.pushReplacementNamed(context, '/setup2');
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
