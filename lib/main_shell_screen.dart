// main_shell_screen.dart (or a similar name)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For friend request check
import 'package:cloud_firestore/cloud_firestore.dart'; // For friend request check

// Import your screen widgets
import '/DashboardScreens/dashboard_screen.dart'; // Replace with your actual screen
import '/DashboardScreens/challenge_screen.dart'; // Replace with your actual screen
import '/DashboardScreens/add_screen.dart';       // Replace with your actual screen
import '/DashboardScreens/friends_screen.dart';    // Your FriendsScreen
import '/DashboardScreens/leaderboard_screen.dart';// Replace with your actual screen

import '/addition/bottom_navbar.dart'; // Your BottomNavBar widget

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  bool _hasPendingFriendRequests = false; // Manage this state

  // Define your screens that correspond to the BottomNavBar items
  final List<Widget> _screens = [
    const DashboardHomeContent(),   // Index 0
    const ChallengeScreen(),   // Index 1
    const AddScreen(),         // Index 2 (or handle as modal)
    const FriendsScreen(),     // Index 3
    const LeaderboardScreen(), // Index 4
  ];

  void _onItemTapped(int index) {
    if (index == 2) { // "Add" button
      // Handle special action for "Add" - e.g., show a modal
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => const AddScreen(), // Or your specific Add UI
      );
      // Don't change _currentIndex if it's a modal action that doesn't switch main tabs
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  // TODO: Implement _listenForFriendRequests() if you haven't already
  // void _listenForFriendRequests() { ... }
  // @override
  // void initState() {
  //   super.initState();
  //   _listenForFriendRequests();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The AppBar should ideally be part of each individual screen
      // OR, if you want a *truly global* AppBar that changes title with tabs,
      // you'd manage its title here based on _currentIndex.
      // For now, let's assume individual screens have their own (e.g., TopHeader) or no AppBar.

      body: IndexedStack( // Use IndexedStack to keep screen states when switching tabs
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        hasPendingRequests: _hasPendingFriendRequests,
      ),
    );
  }
}