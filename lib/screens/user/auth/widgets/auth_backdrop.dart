import 'package:flutter/material.dart';

const _leaf = Color(0xFF8FB6A0);
const _deepTeal = Color(0xFF16332B);

/// Fixed decorative background shared by the auth screens: a soft mint wash
/// with blob highlights and leaf clusters near the top corners. Safe to pin
/// behind scrollable content since it never extends far enough down to
/// collide with it — the bottom hill art lives in [AuthFooterArt] instead,
/// which scrolls with the form so it can never overlap taller content.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF8FBF9), Color(0xFFE9F4EF)],
              ),
            ),
          ),
        ),
        Positioned(top: -70, left: -60, child: _blob(220, 0.55)),
        Positioned(top: -50, right: -70, child: _blob(190, 0.45)),
        Positioned(top: 26, left: 14, child: _leafCluster()),
        Positioned(top: 30, right: 16, child: _leafCluster()),
      ],
    );
  }

  Widget _blob(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _leaf.withValues(alpha: opacity * 0.5),
            _leaf.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Closing flourish for the auth forms: a layered hill silhouette with the
/// "Your recovery. Our priority." tagline. Placed as the last item in each
/// screen's scrollable column so it always sits after the real content,
/// regardless of how tall that content is.
///
/// [height] fixes the illustration's height (used on Register, whose content
/// already fills the screen). Pass null and wrap in an [Expanded] instead
/// (used on Login) to have the hills stretch and soak up any leftover
/// vertical space rather than leaving it blank above the art.
class AuthFooterArt extends StatelessWidget {
  const AuthFooterArt({super.key, this.height = 190});

  final double? height;

  @override
  Widget build(BuildContext context) {
    final art = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: CustomPaint(painter: _HillWavesPainter())),
        Positioned(
          right: -6,
          top: 14,
          child: Transform.rotate(angle: 0.4, child: _leafCluster(big: true)),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 26,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.verified_user, size: 16, color: _deepTeal),
              SizedBox(width: 6),
              Text(
                'Your recovery. Our priority.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _deepTeal,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (height == null) {
      return SizedBox.expand(child: art);
    }
    return SizedBox(height: height, width: double.infinity, child: art);
  }
}

Widget _leafCluster({bool big = false}) {
  final base = big ? 34.0 : 22.0;
  return SizedBox(
    width: base * 2.2,
    height: base * 2.2,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          top: base * 0.3,
          child: Transform.rotate(
            angle: -0.5,
            child: Icon(
              Icons.eco,
              size: base,
              color: _leaf.withValues(alpha: 0.55),
            ),
          ),
        ),
        Positioned(
          left: base * 0.7,
          top: 0,
          child: Transform.rotate(
            angle: 0.3,
            child: Icon(
              Icons.eco,
              size: base * 0.8,
              color: _leaf.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    ),
  );
}

class _HillWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    Path wave(double topFrac, double amp) {
      return Path()
        ..moveTo(0, h)
        ..lineTo(0, h * topFrac)
        ..quadraticBezierTo(w * 0.25, h * topFrac - amp, w * 0.5, h * topFrac)
        ..quadraticBezierTo(
          w * 0.75,
          h * topFrac + amp,
          w,
          h * topFrac - amp * 0.4,
        )
        ..lineTo(w, h)
        ..close();
    }

    canvas.drawPath(wave(0.15, 14), Paint()..color = const Color(0xFFE3F1EA));
    canvas.drawPath(wave(0.4, 16), Paint()..color = const Color(0xFFB7D9C6));
    canvas.drawPath(wave(0.65, 18), Paint()..color = const Color(0xFF87B69C));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
