import 'package:flutter/material.dart';

/// App bar for the Guardian dashboard: logo lockup and a notification bell.
/// Deliberately has no menu icon — the Guardian dashboard is a single
/// focused screen, not a hub with a drawer.
class GuardianHeader extends StatelessWidget {
  const GuardianHeader({
    super.key,
    required this.onBellTap,
    this.notificationCount = 0,
  });

  final VoidCallback onBellTap;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 44),
        Expanded(
          child: Center(
            child: Image.asset('images/sawata_guardian_logo.png', height: 44),
          ),
        ),
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: onBellTap,
              ),
              if (notificationCount > 0)
                Positioned(
                  top: 4,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC0392B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
