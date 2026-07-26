import 'package:flutter/material.dart';

/// Decorative progress ring with a gradient padlock centerpiece, echoing
/// the app's brand mark. Purely static/informational (unlike the
/// interactive [LockHero] on the Protection screen).
class StreakRingBadge extends StatelessWidget {
  const StreakRingBadge({super.key, required this.progress, this.size = 116});

  /// 0..1 fill amount.
  final double progress;
  final double size;

  static const _mint = Color(0xFFDCEEE6);
  static const _accent = Color(0xFF2E7D6B);
  static const _accentDeep = Color(0xFF16332B);
  static const _track = Color(0xFFE2E8E5);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size * 0.84,
            height: size * 0.84,
            decoration: const BoxDecoration(
              color: _mint,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress.clamp(0, 1),
              strokeWidth: 6,
              backgroundColor: _track,
              valueColor: const AlwaysStoppedAnimation(_accent),
              strokeCap: StrokeCap.round,
            ),
          ),
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_accent, _accentDeep],
            ).createShader(rect),
            child: Icon(Icons.lock, size: size * 0.36, color: Colors.white),
          ),
          Positioned(
            top: size * 0.03,
            left: size * 0.1,
            child: Icon(
              Icons.auto_awesome,
              size: size * 0.09,
              color: _accent.withValues(alpha: 0.5),
            ),
          ),
          Positioned(
            top: size * 0.12,
            right: size * 0.0,
            child: Icon(
              Icons.auto_awesome,
              size: size * 0.06,
              color: _accent.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
