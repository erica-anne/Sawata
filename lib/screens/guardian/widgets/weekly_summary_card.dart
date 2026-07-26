import 'package:flutter/material.dart';

class SummaryStat {
  const SummaryStat({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.caption,
    this.delta,
    this.deltaUp,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String caption;

  /// e.g. "12" rendered next to an up/down arrow. Null = no delta shown.
  final String? delta;

  /// true = up arrow, false = down arrow. Only read when [delta] is set.
  final bool? deltaUp;
}

/// "Weekly Summary" (title varies by period) card: a 2-column grid of six
/// stat rows, matching the Guardian Reports mockup.
class WeeklySummaryCard extends StatelessWidget {
  const WeeklySummaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stats,
  });

  final String title;
  final String subtitle;
  final List<SummaryStat> stats;

  static const _muted = Color(0xFF5B7269);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: _muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 14),
          for (var i = 0; i < stats.length; i += 2)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: i == 0
                  ? null
                  : const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0x14000000)),
                      ),
                    ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _Tile(stat: stats[i])),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < stats.length
                        ? _Tile(stat: stats[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.stat});

  final SummaryStat stat;

  static const _deepTeal = Color(0xFF16332B);
  static const _muted = Color(0xFF5B7269);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: stat.iconBg,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Icon(stat.icon, size: 15, color: stat.iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          stat.label,
          style: const TextStyle(fontSize: 11.5, color: _muted),
        ),
        const SizedBox(height: 2),
        Text(
          stat.value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _deepTeal,
          ),
        ),
        const SizedBox(height: 2),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (stat.delta != null) ...[
              Icon(
                stat.deltaUp == true ? Icons.arrow_upward : Icons.arrow_downward,
                size: 11,
                color: stat.deltaUp == true
                    ? const Color(0xFFC0392B)
                    : const Color(0xFF2E7D6B),
              ),
              Text(
                ' ${stat.delta}  ',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: stat.deltaUp == true
                      ? const Color(0xFFC0392B)
                      : const Color(0xFF2E7D6B),
                ),
              ),
            ],
            Text(
              stat.caption,
              style: const TextStyle(fontSize: 10.5, color: _muted),
            ),
          ],
        ),
      ],
    );
  }
}
