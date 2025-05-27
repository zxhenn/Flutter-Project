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
      '${getCategoryPointsField(category)}': FieldValue.increment(0), // no-op but keeps field consistent
    });
  }

  // 🔢 Mapping types to category fields
  static String getCategoryPointsField(String category) {
    switch (category.trim().toLowerCase()) {
      case 'strength training':
        return 'strengthPoints';
      case 'cardiovascular fitness':
        return 'cardioPoints';
      default:
        return 'miscPoints';
    }
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
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    await ref.set({'honorPoints': FieldValue.increment(amount)}, SetOptions(merge: true));
  }

  // 🏆 Rank Calculation
  static Future<int> getTotalPoints(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!doc.exists) return 0;

    final data = doc.data() ?? {};
    final strength = (data['strengthPoints'] ?? 0) as int;
    final cardio = (data['cardioPoints'] ?? 0) as int;
    final misc = (data['miscPoints'] ?? 0) as int;
    return strength + cardio + misc;

  }

  static String getRankFromPoints(int points) {
    if (points >= 4000) return 'Grandmaster';
    if (points >= 1000) return 'Master';
    if (points >= 500) return 'Diamond';
    if (points >= 200) return 'Emerald';
    if (points >= 100) return 'Gold';
    if (points >= 50) return 'Silver';
    return 'Bronze';
  }
  static Future<String?> getTodayPowerupAssetPath(String uid) async {
    final now = DateTime.now();
    final docId = '${now.year}-${now.month}-${now.day}';
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('powerups')
        .doc(docId)
        .get();

    if (!doc.exists) return null;

    final type = doc.data()?['type'];
    switch (type) {
      case 'cardio':
        return 'assets/boosts/cardio_charge.png';
      case 'strength':
        return 'assets/boosts/iron_boost.png';
      case 'custom':
        return 'assets/boosts/focus_boost.png';
      default:
        return null;
    }
  }

}
