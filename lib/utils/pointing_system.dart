import 'package:cloud_firestore/cloud_firestore.dart';

class PointingSystem {
  // 🔵 Main point formula
  static double calculateEarnedPoints({
    required double targetMax,
    required int durationDays,
    required double todayProgress,
    required String unit,
  }) {
    final double progressRatio = (todayProgress / targetMax).clamp(0.0, 1.0);

    final unitWeight = _getUnitWeight(unit);
    final double basePoints = durationDays * 0.2;
    final double effortPoints = targetMax * unitWeight;
    final double rawPoints = basePoints + effortPoints;

    final double finalPoints = progressRatio < 0.5
        ? 0
        : rawPoints * progressRatio.clamp(0.5, 1.0);

    return double.parse(finalPoints.toStringAsFixed(1)); // 1 decimal
  }

  // 🧠 Unit weights
  static double _getUnitWeight(String unit) {
    switch (unit.toLowerCase()) {
      case 'minutes':
        return 0.05;
      case 'sessions':
        return 1.0;
      case 'distance (km)':
        return 0.5;
      default:
        return 0.1;
    }
  }

  // 🔁 Habit consistency/rank update
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
    final String category = data['category'] ?? 'Misc';

    await habitRef.update({
      'daysPassed': daysPassed,
      'overallProgressRatio': overallProgressRatio,
      'consistencyRatio': consistencyRatio,
      'overallProgressStatus': overallProgressRatio >= 1.0 ? 'Completed' : 'Ongoing',
      '${_getCategoryPointsField(type)}': FieldValue.increment(0), // no-op but keeps field consistent
    });
  }

  // 🔢 Mapping types to category fields
  static String _getCategoryPointsField(String type) {
    if (type.toLowerCase().contains('run') || type.toLowerCase().contains('walk')) return 'cardioPoints';
    if (type.toLowerCase().contains('weight') || type.toLowerCase().contains('lift')) return 'strengthPoints';
    return 'miscPoints';
  }

  // 📊 Totals and category breakdown
  static int calculateTotalPoints(List<Map<String, dynamic>> habits) {
    int total = 0;
    for (var habit in habits) {
      total += (habit['points'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  static Map<String, int> calculateCategoryPoints(List<Map<String, dynamic>> habits) {
    Map<String, int> categoryMap = {};
    for (var habit in habits) {
      final category = habit['category'] ?? 'Other';
      final points = (habit['points'] as num?)?.toInt() ?? 0;
      categoryMap[category] = (categoryMap[category] ?? 0) + points;
    }
    return categoryMap;
  }

  // 🪙 Honor Points (bonus system)
  static Future<void> rewardHonorPoints(String uid, int amount) async {
    final ref = FirebaseFirestore.instance.collection('Profiles').doc(uid);
    await ref.set({'honorPoints': FieldValue.increment(amount)}, SetOptions(merge: true));
  }

  // 🏆 Rank Calculation
  static Future<int> getTotalPoints(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('Profiles').doc(uid).get();
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
