import 'package:flutter/material.dart';

class GuardianStatCard extends StatelessWidget {
  const GuardianStatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.unit,
    required this.caption,
    this.trendUp,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String unit;
  final String caption;

  /// null = no trend shown; true = up (red, more attempts is bad news for a
  /// guardian to see); false = down (green, good news).
  final bool? trendUp;

  static const _deepTeal = Color(0xFF16332B);
  static const _muted = Color(0xFF5B7269);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _muted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _deepTeal,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _deepTeal,
                ),
              ),
              if (trendUp != null) ...[
                const SizedBox(width: 6),
                Icon(
                  trendUp! ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 13,
                  color: trendUp!
                      ? const Color(0xFFC0392B)
                      : const Color(0xFF2E7D6B),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(caption, style: const TextStyle(fontSize: 10.5, color: _muted)),
        ],
      ),
    );
  }
}
