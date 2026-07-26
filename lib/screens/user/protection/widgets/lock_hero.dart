import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Large circular lock centerpiece for the Protection screen.
///
/// Tapping toggles [active] (via [onTap], the parent owns the state); on
/// every transition the padlock swings shut, the ring draws itself closed,
/// and the body crossfades from gray to the brand gradient.
class LockHero extends StatefulWidget {
  const LockHero({
    super.key,
    required this.active,
    required this.onTap,
    this.size = 236,
  });

  final bool active;
  final VoidCallback onTap;
  final double size;

  @override
  State<LockHero> createState() => _LockHeroState();
}

class _LockHeroState extends State<LockHero> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pulseController;
  late final AnimationController _breatheController;
  late final Animation<double> _pulseScale;

  static const _gray = Color(0xFFB9C2BD);
  static const _accent = Color(0xFF2E7D6B);
  static const _accentDeep = Color(0xFF16332B);
  static const _track = Color(0xFFD8DFDB);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      value: widget.active ? 1 : 0,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.09,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.09,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 55,
      ),
    ]).animate(_pulseController);
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant LockHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _controller.forward(from: 0);
        _pulseController.forward(from: 0);
      } else {
        _controller.reverse(from: 1);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          _pulseController,
          _breatheController,
        ]),
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Transform.scale(
              scale: _pulseScale.value,
              child: CustomPaint(
                painter: _LockHeroPainter(
                  t: t,
                  glowStrength: _breatheController.value,
                  trackColor: _track,
                  accent: _accent,
                  accentDeep: _accentDeep,
                  gray: _gray,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LockHeroPainter extends CustomPainter {
  _LockHeroPainter({
    required this.t,
    required this.glowStrength,
    required this.trackColor,
    required this.accent,
    required this.accentDeep,
    required this.gray,
  });

  /// Eased progress: 0 = open/gray/inactive, 1 = closed/green/active.
  final double t;
  final double glowStrength;
  final Color trackColor;
  final Color accent;
  final Color accentDeep;
  final Color gray;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 236.0;
    final center = Offset(size.width / 2, size.height / 2);

    if (t > 0.01) {
      final glowPaint = Paint()
        ..color = accent.withValues(
          alpha: 0.28 * t * (0.6 + 0.4 * glowStrength),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 22 * s);
      canvas.drawCircle(center, size.width / 2 - 4 * s, glowPaint);
    }

    final ringRadius = size.width / 2 - 7 * s;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, ringRadius, trackPaint);

    if (t > 0.002) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * s
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(trackColor, accent, t)!;
      final rect = Rect.fromCircle(center: center, radius: ringRadius);
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * t, false, ringPaint);

      final dotOpacity = ((t - 0.85) / 0.15).clamp(0.0, 1.0);
      if (dotOpacity > 0) {
        final angle = -math.pi / 2 + 2 * math.pi * t;
        final dotCenter = Offset(
          center.dx + ringRadius * math.cos(angle),
          center.dy + ringRadius * math.sin(angle),
        );
        canvas.drawCircle(
          dotCenter,
          6.5 * s,
          Paint()..color = accent.withValues(alpha: dotOpacity),
        );
        canvas.drawCircle(
          dotCenter,
          4 * s,
          Paint()..color = Colors.white.withValues(alpha: dotOpacity),
        );
      }
    }

    final discRadius = size.width * 0.40;
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: discRadius)),
      Colors.black.withValues(alpha: 0.18),
      10 * s,
      false,
    );
    canvas.drawCircle(center, discRadius, Paint()..color = Colors.white);

    _paintLock(canvas, center, size.width * 0.46, s);
  }

  void _paintLock(Canvas canvas, Offset center, double lockWidth, double s) {
    final bodyW = lockWidth;
    final bodyH = lockWidth * 0.82;
    final bodyLeft = center.dx - bodyW / 2;
    final bodyTop = center.dy - bodyH * 0.12;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyLeft, bodyTop, bodyW, bodyH),
      Radius.circular(bodyW * 0.22),
    );

    final margin = bodyW * 0.18;
    final hinge = Offset(bodyLeft + margin, bodyTop + 2 * s);
    final latch = Offset(bodyLeft + bodyW - margin, bodyTop + 2 * s);
    final shackleRadius = (latch.dx - hinge.dx) / 2;
    final shackleRect = Rect.fromCircle(
      center: Offset((hinge.dx + latch.dx) / 2, hinge.dy),
      radius: shackleRadius,
    );
    final shacklePath = Path()..addArc(shackleRect, math.pi, math.pi);

    final angle = -0.62 + 0.62 * t;

    canvas.save();
    canvas.translate(hinge.dx, hinge.dy);
    canvas.rotate(angle);
    canvas.translate(-hinge.dx, -hinge.dy);
    canvas.drawPath(
      shacklePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = bodyW * 0.16
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(gray, accent, t)!,
    );
    canvas.restore();

    canvas.drawRRect(bodyRect, Paint()..color = gray.withValues(alpha: 1 - t));

    if (t > 0.001) {
      final gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, accentDeep],
      );
      canvas.saveLayer(
        bodyRect.outerRect.inflate(4),
        Paint()..color = Colors.white.withValues(alpha: t),
      );
      canvas.drawRRect(
        bodyRect,
        Paint()..shader = gradient.createShader(bodyRect.outerRect),
      );
      canvas.restore();
    }

    final khCenter = Offset(center.dx, bodyTop + bodyH * 0.42);
    final khR = bodyW * 0.14;
    canvas.drawCircle(khCenter, khR, Paint()..color = Colors.white);
    final teardrop = Path()
      ..moveTo(khCenter.dx - khR * 0.55, khCenter.dy + khR * 0.4)
      ..lineTo(khCenter.dx + khR * 0.55, khCenter.dy + khR * 0.4)
      ..lineTo(khCenter.dx + khR * 0.22, khCenter.dy + khR * 1.9)
      ..lineTo(khCenter.dx - khR * 0.22, khCenter.dy + khR * 1.9)
      ..close();
    canvas.drawPath(teardrop, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _LockHeroPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.glowStrength != glowStrength;
}
