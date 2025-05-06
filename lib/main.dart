import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/profile_setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/welcome_screen.dart';
import 'DashboardScreens/dashboard_screen.dart';
import 'screens/profile_setup_screen2.dart';
import 'screens/forgot_password_screen.dart';
import 'Settings/settings_page.dart';
import 'DashboardScreens/friends_screen.dart';
import 'DashboardScreens/add_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;

  runApp(MyApp(hasSeenWelcome: hasSeenWelcome));
}

class MyApp extends StatelessWidget {
  final bool hasSeenWelcome;

  const MyApp({super.key, required this.hasSeenWelcome});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gamified Habit Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      initialRoute: hasSeenWelcome ? '/auth' : '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/auth': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/profile_setup': (context) => const ProfileSetupScreen(),
        '/profile_setup2': (context) => const ProfileSetupScreen2(),
        '/dashboard': (context) => const DashboardScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/settings_page': (context) => const SettingsPage(),
        '/friends_screen': (context) => const FriendsScreen(),
        '/add_screen': (context) => const AddScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _isProfileComplete(String userId) async {
    try {
      final profilesDoc = await FirebaseFirestore.instance
          .collection('Profiles')
          .doc(userId)
          .get();

      if (!profilesDoc.exists) {
        return false;
      }

      final profileData = profilesDoc.data();
      if (profileData == null) {
        return false;
      }

      // Safer reading
      final name = (profileData['Name'] ?? '').toString().trim();
      final height = (profileData['Height'] ?? '').toString().trim();
      final weight = (profileData['Weight'] ?? '').toString().trim();
      final ageRaw = profileData['Age'];

      int age = 0;
      if (ageRaw is int) {
        age = ageRaw;
      } else if (ageRaw is String) {
        age = int.tryParse(ageRaw) ?? 0;
      }

      debugPrint('🔥 Profile Check => Name: $name, Height: $height, Weight: $weight, Age: $age');

      if (name.isEmpty || height.isEmpty || weight.isEmpty || age <= 0) {
        return false; // Missing or invalid info
      }

      return true; // All info present and valid
    } catch (e) {
      debugPrint('🔥 Profile Check Error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnapshot.hasData) {
          final user = authSnapshot.data!;
          return FutureBuilder<bool>(
            future: _isProfileComplete(user.uid),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (profileSnapshot.hasError) {
                return const LoginScreen();
              }

              if (profileSnapshot.data == true) {
                return const DashboardScreen();
              } else {
                return const ProfileSetupScreen(); // Start Profile Setup flow
              }
            },
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
