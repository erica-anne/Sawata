import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.onBellTap,
    required this.onSettingsTap,
    this.hasNotification = true,
  });

  final VoidCallback onBellTap;
  final VoidCallback onSettingsTap;
  final bool hasNotification;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        const SizedBox(width: 96),
        Expanded(
          child: Center(
            child: Image.asset(
              'images/sawata_logo.png',
              height: 42,
              fit: BoxFit.contain,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: onSettingsTap,
        ),
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: onBellTap,
              ),
              if (hasNotification)
                Positioned(
                  top: 9,
                  right: 7,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.surface,
                        width: 1.5,
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
