import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class PowerupManager {
  static final List<Map<String, dynamic>> powerups = [
    {'name': 'Double Points', 'type': 'multiplier', 'value': 2.0},
    {'name': 'Free Habit Log', 'type': 'passive', 'value': 1},
    {'name': 'Bonus XP +5', 'type': 'reward', 'value': 5},
    {'name': 'Consistency Shield', 'type': 'shield', 'value': true},
  ];

  static Future<Map<String, dynamic>?> getTodayPowerup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final today = DateTime.now();
    final id = "${today.year}-${today.month}-${today.day}";

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('powerups')
        .doc(id);

    final existing = await docRef.get();
    if (existing.exists) return existing.data();

    final random = powerups[Random().nextInt(powerups.length)];

    await docRef.set({
      'name': random['name'],
      'type': random['type'],
      'value': random['value'],
      'claimed': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return random;
  }

  static Future<void> markClaimed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final id = "${today.year}-${today.month}-${today.day}";

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('powerups')
        .doc(id);

    await docRef.update({'claimed': true});
  }
}
