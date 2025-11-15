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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNavItem(
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
                label: 'Dashboard',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.flag_outlined,
                selectedIcon: Icons.flag,
                label: 'Challenge',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.add_circle_outline,
                selectedIcon: Icons.add_circle,
                label: 'Add',
                index: 2,
                isCenter: true,
              ),
              _buildNavItem(
                icon: Icons.person_add_outlined,
                selectedIcon: Icons.person_add,
                label: 'Friends',
                index: 3,
                hasNotification: hasPendingRequests,
              ),
              _buildNavItem(
                icon: Icons.leaderboard_outlined,
                selectedIcon: Icons.leaderboard,
                label: 'Leaderboard',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    bool isCenter = false,
    bool hasNotification = false,
  }) {
    final isSelected = currentIndex == index;
    
    if (isCenter) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[700] : Colors.blue[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? selectedIcon : icon,
                      color: isSelected ? Colors.white : Colors.blue[700],
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.blue[700] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? selectedIcon : icon,
                      color: isSelected ? Colors.blue[700] : Colors.grey[600],
                      size: 22,
                    ),
                    if (hasNotification && !isSelected)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.blue[700] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
