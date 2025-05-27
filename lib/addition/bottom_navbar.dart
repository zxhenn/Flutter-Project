import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool hasPendingRequests;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.hasPendingRequests = false,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        const BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'Challenge'),
        const BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 60), label:  'Add'),
        BottomNavigationBarItem(
          icon: Stack(
            children: [
              const Icon(Icons.person_add),
              if (hasPendingRequests)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          label: 'Friends',
        ),


        const BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
      ],
    );
  }
}
