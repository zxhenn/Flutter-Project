import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> updateStreakAndBadges(String habitId, double todayValue, double targetMin) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('habits')
      .doc(habitId);

  final doc = await docRef.get();
  final data = doc.data() ?? {};

  final Timestamp? lastDate = data['lastSuccessDate'];
  final int currentStreak = data['currentStreak'] ?? 0;
  final int longestStreak = data['longestStreak'] ?? 0;

  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime? lastSuccess = lastDate?.toDate();

  int newStreak = currentStreak;

  if (todayValue >= targetMin) {
    if (lastSuccess != null) {
      final diff = today.difference(DateTime(lastSuccess.year, lastSuccess.month, lastSuccess.day)).inDays;
      if (diff == 1) {
        newStreak += 1;
      } else if (diff > 1) {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }
  }

  await docRef.update({
    'currentStreak': newStreak,
    'longestStreak': newStreak > longestStreak ? newStreak : longestStreak,
    'lastSuccessDate': todayValue >= targetMin ? FieldValue.serverTimestamp() : lastDate,
  });
}