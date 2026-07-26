import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small hand-drawn rendition of the multi-color Google "G" mark, used on
/// the "Continue with Google" buttons. Avoids pulling in an SVG dependency
/// for a single decorative icon.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.22;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Four arcs leave a gap on the right (around 0 degrees) for the G's
    // mouth, matching the real logo's silhouette.
    canvas.drawArc(rect, _rad(24), _rad(100), false, ringPaint..color = _blue);
    canvas.drawArc(rect, _rad(124), _rad(88), false, ringPaint..color = _green);
    canvas.drawArc(rect, _rad(212), _rad(62), false, ringPaint..color = _yellow);
    canvas.drawArc(rect, _rad(274), _rad(62), false, ringPaint..color = _red);

    // Crossbar of the G, reaching from the center out to the ring opening.
    final barPaint = Paint()..color = _blue;
    final barRect = Rect.fromLTWH(
      center.dx - strokeWidth * 0.2,
      center.dy - strokeWidth / 2,
      radius + strokeWidth * 0.7,
      strokeWidth,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, Radius.circular(strokeWidth * 0.25)),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
