class WeeklyStat {
  const WeeklyStat({required this.label, required this.value});

  final String label;
  final double value;
}

class AnalyticsDataset {
  const AnalyticsDataset({
    required this.label,
    required this.periodLabel,
    required this.savings,
    required this.attempts,
    required this.longestStreakDays,
    required this.moneySavedTrendPct,
    required this.attemptsTrendPct,
  });

  final String label;

  /// Reads naturally in a sentence, e.g. "This Week".
  final String periodLabel;
  final List<WeeklyStat> savings;
  final List<WeeklyStat> attempts;
  final int longestStreakDays;

  /// Percent change vs. the previous period. Positive = more saved (good).
  final double moneySavedTrendPct;

  /// Percent change vs. the previous period. Negative = fewer attempts (good).
  final double attemptsTrendPct;
}
