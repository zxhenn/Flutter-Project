// addition/bottom_navbar.dart
import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key, // simplified
    required this.currentIndex,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.flag),
          label: 'Challenge',
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.person_add),
          label: 'Friends',
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle, size: 40),
          label: '',
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.leaderboard),
          label: 'Leaderboard',
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.emoji_events),
          label: 'Badge',
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),

      ],


    );
  }
}
