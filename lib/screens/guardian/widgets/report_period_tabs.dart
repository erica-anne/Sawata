import 'package:flutter/material.dart';

enum ReportPeriod { daily, weekly, monthly, yearly }

extension ReportPeriodLabels on ReportPeriod {
  String get label => switch (this) {
    ReportPeriod.daily => 'Day',
    ReportPeriod.weekly => 'Week',
    ReportPeriod.monthly => 'Month',
    ReportPeriod.yearly => 'Year',
  };

  /// Reads naturally in a sentence, e.g. "vs last week".
  String get noun => switch (this) {
    ReportPeriod.daily => 'day',
    ReportPeriod.weekly => 'week',
    ReportPeriod.monthly => 'month',
    ReportPeriod.yearly => 'year',
  };
}

/// Segmented filter row: Daily / Weekly / Monthly / Yearly.
class ReportPeriodTabs extends StatelessWidget {
  const ReportPeriodTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onChanged;

  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);
  static const _muted = Color(0xFF5B7269);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
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
      child: Row(
        children: [
          for (final period in ReportPeriod.values)
            Expanded(
              child: _Tab(
                label: period.label,
                selected: period == selected,
                onTap: () => onChanged(period),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [
                      ReportPeriodTabs._deepTeal,
                      ReportPeriodTabs._accent,
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: selected ? Colors.white : ReportPeriodTabs._muted,
            ),
          ),
        ),
      ),
    );
  }
}
