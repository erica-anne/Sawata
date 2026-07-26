import 'package:flutter/material.dart';

/// White pill row showing the active date range for the selected report
/// period. The arrow buttons are presentational only for now — paging
/// between periods isn't wired up yet.
class ReportDateRangeBar extends StatelessWidget {
  const ReportDateRangeBar({super.key, required this.label});

  final String label;

  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _deepTeal,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left, size: 20),
            color: _deepTeal,
            onPressed: () {},
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right, size: 20),
            color: _deepTeal,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
