import 'package:flutter/material.dart';

/// Bottom nav shared by every Guardian screen. No badge on the Alerts icon —
/// unread counts surface via the header bell instead. The Request tab shows
/// a badge for pending guardian invites.
class GuardianBottomNav extends StatelessWidget {
  const GuardianBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.requestCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int requestCount;

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    (icon: Icons.mail_outline, activeIcon: Icons.mail, label: 'Request'),
    (
      icon: Icons.notifications_none_rounded,
      activeIcon: Icons.notifications,
      label: 'Alerts',
    ),
    (
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
      label: 'Reports',
    ),
    (
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF2E7D6B),
      unselectedItemColor: const Color(0xFF8EA198),
      backgroundColor: Colors.white,
      items: [
        for (var i = 0; i < _items.length; i++)
          BottomNavigationBarItem(
            icon: i == 1 && requestCount > 0
                ? _BadgedIcon(icon: _items[i].icon, count: requestCount)
                : Icon(_items[i].icon),
            activeIcon: i == 1 && requestCount > 0
                ? _BadgedIcon(icon: _items[i].activeIcon, count: requestCount)
                : Icon(_items[i].activeIcon),
            label: _items[i].label,
          ),
      ],
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          top: -4,
          right: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D6B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
