import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'screens/profile_setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/welcome_screen.dart';
import 'DashboardScreens/dashboard_screen.dart';
import 'screens/profile_setup_screen2.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/Terms.dart';
import 'Settings/settings_page.dart';
import 'DashboardScreens/friends_screen.dart';
import 'DashboardScreens/add_screen.dart';
import 'Settings/EditProfileScreen.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import '/addition/awesome_notifications.dart';
import '/DashboardScreens/challenge_screen.dart';
import 'challenge/challenge_logger_page.dart';
import 'challenge/challenge_add_habit.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize(); // ✅ Add this
  // Initialize Timezone (only needed if you use scheduled notifications)
  tz.initializeTimeZones();

  // Initialize Awesome Notifications
  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'social_channel', // ✅ this must match
        channelName: 'Social Alerts',
        channelDescription: 'Friend requests and social activity',
        defaultColor: Colors.blue,
        ledColor: Colors.white,
        importance: NotificationImportance.High,
      ),
    ],
  );

  if (!await AwesomeNotifications().isNotificationAllowed()) {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  final prefs = await SharedPreferences.getInstance();
  final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;

  runApp(MyApp(hasSeenWelcome: hasSeenWelcome));
}
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

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
        '/terms': (context) => const TermsScreen(),
        '/EditProfileScreen':(context) => const EditProfileScreen(),
        '/challenge_screen':(context) => const ChallengeScreen(),


      },
      onGenerateRoute: (settings) {
        if (settings.name == '/challengeLogger') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ChallengeLoggerPage(
              challengeId: args['challengeData']['id'],
            ),
          );
        }

        if (settings.name == '/challengeAddHabit') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ChallengeAddHabitPage(
              friendId: args['friendId'],
              friendName: args['friendName'],
            ),
          );
        }

        return null;
      },

      navigatorObservers: [routeObserver],
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<String> _getProfileStatus(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('Profiles').doc(userId).get();

      if (!doc.exists) return 'incomplete1';

      final data = doc.data();
      if (data == null) return 'incomplete1';

      final name = (data['Name'] ?? '').toString().trim();
      final height = (data['Height'] ?? '').toString().trim();
      final weight = (data['Weight'] ?? '').toString().trim();
      final focusArea = (data['FocusArea'] ?? '').toString().trim();
      final ageRaw = data['Age'];

      int age = 0;
      if (ageRaw is int) age = ageRaw;
      if (ageRaw is String) age = int.tryParse(ageRaw) ?? 0;

      debugPrint('🔥 Profile Data: Name=$name, Height=$height, Weight=$weight, Age=$age, Focus=$focusArea');

      if (name.isEmpty || height.isEmpty || weight.isEmpty || age <= 0) {
        return 'incomplete1';
      }

      if (focusArea.isEmpty) {
        return 'incomplete2';
      }

      return 'complete';
    } catch (e) {
      debugPrint('🔥 Profile check error: $e');
      return 'incomplete1';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        return FutureBuilder<String>(
          future: _getProfileStatus(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (profileSnapshot.hasError) {
              return const LoginScreen();
            }

            final status = profileSnapshot.data;
            debugPrint('🚦 Profile Status Result: $status');

            if (status == 'complete') {
              return const DashboardScreen();
            } else if (status == 'incomplete2') {
              return const ProfileSetupScreen2();
            } else {
              return const ProfileSetupScreen();
            }
          },
        );
      },
    );
  }
}
