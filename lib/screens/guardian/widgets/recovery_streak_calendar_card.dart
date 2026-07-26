import 'package:flutter/material.dart';

enum StreakDayStatus { clean, milestone, today, upcoming }

class StreakDay {
  const StreakDay({
    required this.weekdayLabel,
    required this.dayNumber,
    required this.status,
  });

  final String weekdayLabel;
  final int dayNumber;
  final StreakDayStatus status;
}

/// "Recovery Streak Calendar" card — a 7-day strip with a legend, matching
/// the Guardian Reports mockup.
class RecoveryStreakCalendarCard extends StatelessWidget {
  const RecoveryStreakCalendarCard({super.key, required this.days});

  final List<StreakDay> days;

  static const _deepTeal = Color(0xFF16332B);
  static const _muted = Color(0xFF5B7269);
  static const _accent = Color(0xFF2E7D6B);

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
          const Text(
            'RECOVERY STREAK CALENDAR',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: _muted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final day in days) _DayCell(day: day)],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: const [
              _LegendItem(
                icon: Icons.check,
                color: _accent,
                filled: true,
                label: 'Clean Day',
              ),
              _LegendItem(
                icon: Icons.star,
                color: _deepTeal,
                filled: true,
                label: 'Milestone',
              ),
              _LegendItem(
                icon: null,
                color: _muted,
                filled: false,
                label: 'Today',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day});

  final StreakDay day;

  static const _deepTeal = Color(0xFF16332B);
  static const _muted = Color(0xFF5B7269);
  static const _accent = Color(0xFF2E7D6B);

  @override
  Widget build(BuildContext context) {
    Widget circle;
    switch (day.status) {
      case StreakDayStatus.clean:
        circle = Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: _accent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        );
      case StreakDayStatus.milestone:
        circle = Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: _deepTeal,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.star, size: 16, color: Colors.white),
        );
      case StreakDayStatus.today:
        circle = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _accent, width: 2),
          ),
        );
      case StreakDayStatus.upcoming:
        circle = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF3F1),
            shape: BoxShape.circle,
          ),
        );
    }

    return Column(
      children: [
        Text(
          day.weekdayLabel,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: _muted,
          ),
        ),
        const SizedBox(height: 6),
        circle,
        const SizedBox(height: 4),
        Text(
          '${day.dayNumber}',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: _deepTeal,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.icon,
    required this.color,
    required this.filled,
    required this.label,
  });

  final IconData? icon;
  final Color color;
  final bool filled;
  final String label;

  static const _muted = Color(0xFF5B7269);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: filled ? null : Border.all(color: color, width: 1.5),
          ),
          alignment: Alignment.center,
          child: icon == null
              ? null
              : Icon(icon, size: 9, color: Colors.white),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
      ],
    );
  }
}
