import 'package:flutter/material.dart';

/// Decorative header icon used beside each step's title: a circle holding
/// [icon], an optional small badge overlapping its bottom-right corner, and
/// optional scattered sparkle accents — matching the mockup's per-step hero
/// graphics (clipboard for Review, envelope for Invitation Sent, hourglass
/// for Guardian Status).
class GuardianStepIcon extends StatelessWidget {
  const GuardianStepIcon({
    super.key,
    required this.icon,
    this.badgeIcon,
    this.sparkles = false,
    this.size = 76,
  });

  final IconData icon;
  final IconData? badgeIcon;
  final bool sparkles;
  final double size;

  static const _accent = Color(0xFF2E7D6B);
  static const _mintBg = Color(0xFFDDEEE7);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: _mintBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: size * 0.42, color: _accent),
          ),
          if (badgeIcon != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.34,
                height: size * 0.34,
                decoration: const BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 2),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  badgeIcon,
                  size: size * 0.18,
                  color: Colors.white,
                ),
              ),
            ),
          if (sparkles) ...[
            Positioned(
              top: -4,
              right: 4,
              child: Icon(
                Icons.auto_awesome,
                size: size * 0.16,
                color: _accent.withValues(alpha: 0.7),
              ),
            ),
            Positioned(
              bottom: 2,
              left: -6,
              child: Icon(
                Icons.auto_awesome,
                size: size * 0.12,
                color: _accent.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
