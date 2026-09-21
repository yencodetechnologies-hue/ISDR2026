import 'package:flutter/material.dart';
import '../../../../../../core/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool showComplaints;
  final bool showNotices;
  final bool showProfile;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showComplaints = true,
    this.showNotices = true,
    this.showProfile = true,
  });

  @override
  Widget build(BuildContext context) {
    final navItems = [
      const _NavItemData(
        label: 'Home',
        activeIcon: Icons.home_rounded,
        inactiveIcon: Icons.home_outlined,
      ),
      if (showNotices)
        const _NavItemData(
          label: 'Notices',
          activeIcon: Icons.calendar_month_rounded,
          inactiveIcon: Icons.calendar_month_outlined,
        ),
      if (showComplaints)
        const _NavItemData(
          label: 'Complaints',
          activeIcon: Icons.warning_rounded,
          inactiveIcon: Icons.warning_amber_rounded,
        ),
      if (showProfile)
      const _NavItemData(
        label: 'Profile',
        activeIcon: Icons.person_rounded,
        inactiveIcon: Icons.person_outline_rounded,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = currentIndex == index;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: BorderRadius.circular(12),
                  splashColor: AppTheme.primaryColor.withValues(alpha: 0.05),
                  highlightColor: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFEEF2FF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isSelected ? item.activeIcon : item.inactiveIcon,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : const Color(0xFF64748B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : const Color(0xFF64748B),
                            letterSpacing: -0.1,
                          ),
                          child: Text(item.label),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _NavItemData({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
  });
}


