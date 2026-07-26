import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative protection badge: a shield-and-lock mark inside a dashed
/// ring, echoing the app logo mark used on the splash/onboarding screens.
class ShieldHero extends StatelessWidget {
  const ShieldHero({super.key, this.size = 140});

  final double size;

  @override
  Widget build(BuildContext context) {
    const darkTeal = Color(0xFF16332B);
    const mint = Color(0xFFDCEEE6);
    const leafGreen = Color(0xFF7FAE95);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: mint,
              shape: BoxShape.circle,
            ),
          ),
          CustomPaint(
            size: Size(size, size),
            painter: _DashedRingPainter(
              color: darkTeal.withValues(alpha: 0.35),
            ),
          ),
          for (final angle in const [-2.4, -0.6, 1.1])
            _ringDot(size: size, angle: angle, color: darkTeal),
          Icon(Icons.shield, size: size * 0.5, color: darkTeal),
          Icon(Icons.shield, size: size * 0.5 - 9, color: Colors.white),
          Container(
            width: size * 0.15,
            height: size * 0.15,
            decoration: const BoxDecoration(
              color: darkTeal,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              'S',
              style: TextStyle(
                color: mint,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.09,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: -size * 0.06,
            bottom: size * 0.02,
            child: Transform.rotate(
              angle: -0.6,
              child: Icon(Icons.spa, size: size * 0.24, color: leafGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ringDot({
    required double size,
    required double angle,
    required Color color,
  }) {
    final radius = size / 2 * 0.94;
    final center = size / 2;
    final dx = center + radius * math.cos(angle) - 3.5;
    final dy = center + radius * math.sin(angle) - 3.5;
    return Positioned(
      left: dx,
      top: dy,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    const dashCount = 36;
    const gapFraction = 0.55;
    for (var i = 0; i < dashCount; i++) {
      final startAngle = (i / dashCount) * 2 * math.pi;
      final sweep = (2 * math.pi / dashCount) * gapFraction;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
