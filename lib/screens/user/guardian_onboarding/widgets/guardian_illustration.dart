import 'package:flutter/material.dart';

/// Compact header illustration for Step 1 of the Add Guardian flow: two
/// overlapping simplified avatars with a small shield-heart badge between
/// them, standing in for the mockup's detailed character art (not feasible
/// in pure Flutter without image assets). Sized to sit inline beside the
/// step title, not as a full-width block.
class GuardianIllustration extends StatelessWidget {
  const GuardianIllustration({super.key});

  static const _accent = Color(0xFF2E7D6B);
  static const _deepTeal = Color(0xFF16332B);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 66,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            child: _Avatar(color: _accent, initial: 'J', size: 60),
          ),
          Positioned(
            right: 0,
            top: 6,
            child: _Avatar(color: _deepTeal, initial: 'M', size: 60),
          ),
          Positioned(
            left: 34,
            top: -6,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.favorite, size: 14, color: _accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.color, required this.initial, required this.size});

  final Color color;
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.62,
        height: size * 0.62,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.26,
          ),
        ),
      ),
    );
  }
}
