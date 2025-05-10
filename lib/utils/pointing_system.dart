import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PointingSystem {
  static const int pointsPerUnit = 1;

  static final List<String> defaultCategories = [
    "Cardiovascular Fitness",
    "Strength Training",
    "Flexibility and Mobility",
    "Sports and Recreational Activities",
    "Lifestyle Physical Activity",
    "Fitness/Medication for Specific Populations",
    "Custom"
  ];

  /// Returns calculated points based on completed days and total progress value (e.g. reps, minutes, km)
  static int calculatePoints(int totalProgress) {
    return totalProgress * pointsPerUnit;
  }

  /// Calculates consistency ratio (0.0–1.0) for visual indicators
  static double calculateConsistencyRatio(int completedDays, int daysSinceStart) {
    if (daysSinceStart == 0) return 0.0;
    return (completedDays / daysSinceStart).clamp(0.0, 1.0);
  }

  /// Permanently store final points after habit is marked completed
  static Future<void> storeFinalPointsIfCompleted({
    required String category,
    required int daysCompleted,
    required int durationDays,
    required int totalProgressValue,
    required String habitId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final habitRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('habits')
        .doc(habitId);

    final habitSnap = await habitRef.get();
    final habitData = habitSnap.data() ?? {};

    if (daysCompleted == durationDays && !(habitData['pointsClaimed'] == true)) {
      final int finalPoints = calculatePoints(totalProgressValue);

      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userSnap = await userDocRef.get();
      final Map<String, dynamic> userData = userSnap.data() ?? {};
      final dynamic raw = userData['categoryPoints'];
      final Map<String, dynamic> categoryPoints =
      raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : {};

      for (var cat in defaultCategories) {
        categoryPoints.putIfAbsent(cat, () => 0);
      }

      categoryPoints[category] = (categoryPoints[category] ?? 0) + finalPoints;

      await userDocRef.set({'categoryPoints': categoryPoints}, SetOptions(merge: true));
      await habitRef.update({
        'pointsClaimed': true,
        'finalPoints': finalPoints
      });
    }
  }

  /// Fetches categoryPoints for the current user
  static Future<Map<String, int>> fetchUserCategoryPoints() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null || !data.containsKey('categoryPoints')) {
      return {for (var cat in defaultCategories) cat: 0};
    }

    final Map<String, dynamic> raw = data['categoryPoints'];
    return {
      for (var cat in defaultCategories)
        cat: (raw[cat] ?? 0) is int ? raw[cat] : (raw[cat] as num).toInt()
    };
  }

  /// Sums total points across all categories
  static Future<int> getTotalPointsAcrossAllCategories() async {
    final categoryPoints = await fetchUserCategoryPoints();
    int total = 0;
    for (var val in categoryPoints.values) {
      total += val;
    }
    return total;
  }

  /// Initializes all category points to 0 for a new user if not set
  static Future<void> initializeCategoryPoints() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnap = await docRef.get();
    final data = docSnap.data() ?? {};

    final current = Map<String, dynamic>.from(data['categoryPoints'] ?? {});
    bool updated = false;

    for (var cat in defaultCategories) {
      if (!current.containsKey(cat)) {
        current[cat] = 0;
        updated = true;
      }
    }

    if (updated) {
      await docRef.set({'categoryPoints': current}, SetOptions(merge: true));
    }
  }
}
