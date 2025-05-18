import 'package:cloud_firestore/cloud_firestore.dart';

class PointingSystem {
  static Future<void> updateHabitProgress(String userId, String habitId) async {
    final habitRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habitId);

    final doc = await habitRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final int daysCompleted = data['daysCompleted'] ?? 0;
    final int daysLogged = data['daysLogged'] ?? 0;
    final int durationDays = data['durationDays'] ?? 1;
    final Timestamp createdAt = data['createdAt'];
    final int daysPassed = DateTime.now().difference(createdAt.toDate()).inDays + 1;

    final double overallProgressRatio = daysCompleted / durationDays;
    final double consistencyRatio = daysLogged / daysPassed;

    final String type = data['type'] ?? '';
    int points = _getPointsByType(type);

    await habitRef.update({
      'daysPassed': daysPassed,
      'overallProgressRatio': overallProgressRatio,
      'consistencyRatio': consistencyRatio,
      'overallProgressStatus': overallProgressRatio >= 1.0 ? 'Completed' : 'Ongoing',
      '${_getCategoryPointsField(type)}': points,
    });
  }

  static int _getPointsByType(String type) {
    final typePoints = {
      'Running': 10,
      'Yoga': 5,
      'Weightlifting': 8,
      // Add other mappings here
    };
    return typePoints[type] ?? 3;
  }

  static String _getCategoryPointsField(String type) {
    // You can expand this logic for other categories
    if (type == 'Running') return 'cardioPoints';
    if (type == 'Weightlifting') return 'strengthPoints';
    return 'miscPoints';
  }
  static int calculateTotalPoints(List<Map<String, dynamic>> habits) {

    int total = 0;
    for (var habit in habits) {
      total += (habit['points'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  Map<String, int> calculateCategoryPoints(List<Map<String, dynamic>> habits) {
    Map<String, int> categoryMap = {};
    for (var habit in habits) {
      final category = habit['category'] ?? 'Other';
      final points = (habit['points'] as num?)?.toInt() ?? 0;
      categoryMap[category] = (categoryMap[category] ?? 0) + points;
    }
    return categoryMap;
  }

  static Future<void> rewardHonorPoints(String uid, int amount) async {
    final ref = FirebaseFirestore.instance.collection('Profiles').doc(uid);
    await ref.set({'honorPoints': FieldValue.increment(amount)}, SetOptions(merge: true));
  }
  static Future<int> getTotalPoints(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('Profiles')
        .doc(uid)
        .get();

    if (!doc.exists) return 0;

    final data = doc.data() ?? {};
    final cardio = (data['cardioPoints'] ?? 0) as int;
    final strength = (data['strengthPoints'] ?? 0) as int;
    final misc = (data['miscPoints'] ?? 0) as int;

    return cardio + strength + misc;
  }
  static String getRankFromPoints(int points) {
    if (points >= 700) return 'Grandmaster';
    if (points >= 500) return 'Master';
    if (points >= 350) return 'Diamond';
    if (points >= 200) return 'Platinum';
    if (points >= 100) return 'Gold';
    if (points >= 50) return 'Silver';
    return 'Bronze';
  }


}

