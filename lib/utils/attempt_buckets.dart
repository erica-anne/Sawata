import 'package:sawata/models/blocked_item.dart';
import 'package:sawata/models/stat_snapshot.dart';

/// Buckets real [BlockAttempt] history into the Week/Month/Year chart series
/// Analytics shows, plus the percent change vs. the immediately preceding
/// period of the same length — all derived from actual `blocked_attempts`
/// timestamps, no simulated figures.
class AttemptBuckets {
  AttemptBuckets._();

  static const _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static int _countInRange(
    List<BlockAttempt> attempts,
    DateTime start,
    DateTime endExclusive,
  ) {
    return attempts
        .where((a) => !a.time.isBefore(start) && a.time.isBefore(endExclusive))
        .length;
  }

  static double _trendPct(int current, int previous) {
    if (previous == 0) return current == 0 ? 0 : 100;
    return (current - previous) / previous * 100;
  }

  /// Attempts per day for the current calendar week (Mon-Sun), plus the
  /// trend vs. last week.
  static ({List<WeeklyStat> series, double trendPct}) week(
    List<BlockAttempt> attempts,
    DateTime now,
  ) {
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final series = [
      for (var i = 0; i < 7; i++)
        WeeklyStat(
          label: _weekdayLabels[i],
          value: _countInRange(
            attempts,
            monday.add(Duration(days: i)),
            monday.add(Duration(days: i + 1)),
          ).toDouble(),
        ),
    ];
    final thisWeekTotal = _countInRange(
      attempts,
      monday,
      monday.add(const Duration(days: 7)),
    );
    final lastWeekTotal = _countInRange(
      attempts,
      monday.subtract(const Duration(days: 7)),
      monday,
    );
    return (series: series, trendPct: _trendPct(thisWeekTotal, lastWeekTotal));
  }

  /// Attempts per week (W1-W4) for the current calendar month, plus the
  /// trend vs. last month.
  static ({List<WeeklyStat> series, double trendPct}) month(
    List<BlockAttempt> attempts,
    DateTime now,
  ) {
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);
    final daysInMonth = nextMonthStart.difference(monthStart).inDays;
    final bucketRanges = <int>[1, 8, 15, 22, daysInMonth + 1];
    final series = [
      for (var i = 0; i < 4; i++)
        WeeklyStat(
          label: 'W${i + 1}',
          value: _countInRange(
            attempts,
            DateTime(now.year, now.month, bucketRanges[i]),
            DateTime(now.year, now.month, bucketRanges[i + 1]),
          ).toDouble(),
        ),
    ];
    final thisMonthTotal = _countInRange(attempts, monthStart, nextMonthStart);
    final prevMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthTotal = _countInRange(attempts, prevMonthStart, monthStart);
    return (
      series: series,
      trendPct: _trendPct(thisMonthTotal, lastMonthTotal),
    );
  }

  /// Attempts per month (Jan-Dec) for the current calendar year, plus the
  /// trend vs. last year.
  static ({List<WeeklyStat> series, double trendPct}) year(
    List<BlockAttempt> attempts,
    DateTime now,
  ) {
    final series = [
      for (var m = 1; m <= 12; m++)
        WeeklyStat(
          label: _monthLabels[m - 1],
          value: _countInRange(
            attempts,
            DateTime(now.year, m, 1),
            DateTime(now.year, m + 1, 1),
          ).toDouble(),
        ),
    ];
    final thisYearTotal = _countInRange(
      attempts,
      DateTime(now.year, 1, 1),
      DateTime(now.year + 1, 1, 1),
    );
    final lastYearTotal = _countInRange(
      attempts,
      DateTime(now.year - 1, 1, 1),
      DateTime(now.year, 1, 1),
    );
    return (series: series, trendPct: _trendPct(thisYearTotal, lastYearTotal));
  }
}
