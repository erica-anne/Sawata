import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/data/dummy_data_store.dart';
import 'package:sawata/models/stat_snapshot.dart';

import 'widgets/blocked_attempts_chart_card.dart';
import 'widgets/guardian_bottom_nav.dart';
import 'widgets/guardian_header.dart';
import 'widgets/recovery_streak_calendar_card.dart';
import 'widgets/report_date_range_bar.dart';
import 'widgets/report_insight_card.dart';
import 'widgets/report_period_tabs.dart';
import 'widgets/user_switcher_chip.dart';
import 'widgets/weekly_summary_card.dart';

/// The Guardian-side "Recovery Reports" screen — journal entries, blocked
/// attempts, most active time and protection status for the linked user,
/// filterable by Daily / Weekly / Monthly / Yearly.
class GuardianReportsScreen extends StatefulWidget {
  const GuardianReportsScreen({super.key});

  @override
  State<GuardianReportsScreen> createState() => _GuardianReportsScreenState();
}

class _GuardianReportsScreenState extends State<GuardianReportsScreen> {
  final store = AppStore.instance;
  int _navIndex = 3;
  ReportPeriod _period = ReportPeriod.weekly;

  static const _accent = Color(0xFF2E7D6B);
  static const _mintBg = Color(0xFFDDEEE7);
  static const _blue = Color(0xFF3B6FE0);
  static const _blueBg = Color(0xFFE3ECFB);
  static const _deepTeal = Color(0xFF16332B);

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _weekdayLabels = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  int _attemptsOn(DateTime day) {
    return store.recentAttempts
        .where(
          (a) =>
              a.time.year == day.year &&
              a.time.month == day.month &&
              a.time.day == day.day,
        )
        .length;
  }

  static const _timeBucketLabels = [
    'Morning (6 AM – 12 PM)',
    'Afternoon (12 PM – 6 PM)',
    'Evening (6 PM – 10 PM)',
    'Night (10 PM – 6 AM)',
  ];

  int _timeBucketIndex(int hour) => hour >= 6 && hour < 12
      ? 0
      : hour >= 12 && hour < 18
      ? 1
      : hour >= 18 && hour < 22
      ? 2
      : 3;

  String _mostActiveTimeLabel() {
    if (store.recentAttempts.isEmpty) return '—';
    final counts = List<int>.filled(4, 0);
    for (final attempt in store.recentAttempts) {
      counts[_timeBucketIndex(attempt.time.hour)]++;
    }
    var busiest = 0;
    for (var i = 1; i < counts.length; i++) {
      if (counts[i] > counts[busiest]) busiest = i;
    }
    return _timeBucketLabels[busiest];
  }

  List<WeeklyStat> _dailyBuckets(DateTime today) {
    const labels = ['Morning', 'Afternoon', 'Evening', 'Night'];
    final counts = List<int>.filled(4, 0);
    for (final attempt in store.recentAttempts) {
      final t = attempt.time;
      if (t.year != today.year || t.month != today.month || t.day != today.day) {
        continue;
      }
      final hour = t.hour;
      final idx = hour >= 6 && hour < 12
          ? 0
          : hour >= 12 && hour < 18
          ? 1
          : hour >= 18 && hour < 22
          ? 2
          : 3;
      counts[idx]++;
    }
    return [
      for (var i = 0; i < labels.length; i++)
        WeeklyStat(label: labels[i], value: counts[i].toDouble()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday % 7));
    final linkedUserName = store.profile.name;
    final firstName = linkedUserName.split(' ').first;

    final chartData = switch (_period) {
      ReportPeriod.daily => _dailyBuckets(today),
      ReportPeriod.weekly => store.analyticsDatasets[0].attempts,
      ReportPeriod.monthly => store.analyticsDatasets[1].attempts,
      ReportPeriod.yearly => store.analyticsDatasets[2].attempts,
    };
    final trendDataset = _period == ReportPeriod.daily
        ? null
        : store.analyticsDatasets[switch (_period) {
            ReportPeriod.weekly => 0,
            ReportPeriod.monthly => 1,
            ReportPeriod.yearly => 2,
            ReportPeriod.daily => 0,
          }];
    final totalAttempts = chartData
        .fold<double>(0, (sum, e) => sum + e.value)
        .toInt();

    final dateRangeLabel = switch (_period) {
      ReportPeriod.daily =>
        '${_monthNames[today.month - 1]} ${today.day}, ${today.year}',
      ReportPeriod.weekly => () {
        final weekEnd = weekStart.add(const Duration(days: 6));
        return '${_monthNames[weekStart.month - 1]} ${weekStart.day} – '
            '${_monthNames[weekEnd.month - 1]} ${weekEnd.day}, ${weekEnd.year}';
      }(),
      ReportPeriod.monthly => '${_monthNames[today.month - 1]} ${today.year}',
      ReportPeriod.yearly => '${today.year}',
    };

    final journalEntriesThisWeek = store.journalEntries
        .where((e) => !e.date.isBefore(weekStart))
        .length
        .clamp(0, 7);

    final streakDays = <StreakDay>[
      for (var i = 0; i < 7; i++)
        () {
          final date = weekStart.add(Duration(days: i));
          final status = date.isBefore(today)
              ? StreakDayStatus.clean
              : date.isAtSameMomentAs(today)
              ? StreakDayStatus.today
              : StreakDayStatus.upcoming;
          return StreakDay(
            weekdayLabel: _weekdayLabels[i],
            dayNumber: date.day,
            status: status,
          );
        }(),
    ];

    final todayCount = _attemptsOn(now);
    final yesterdayCount = _attemptsOn(now.subtract(const Duration(days: 1)));
    final insightMessage = todayCount <= yesterdayCount
        ? "Great job! $firstName had fewer blocked attempts compared to yesterday. Keep encouraging and supporting him!"
        : "$firstName had more blocked attempts today than yesterday. This might be a good time to send some encouragement.";

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            GuardianHeader(
              notificationCount: store.pendingGuardianInvites,
              onBellTap: () => Navigator.of(
                context,
              ).pushReplacementNamed(AppRoutes.guardianAlerts),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recovery Reports',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _deepTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                UserSwitcherChip(name: linkedUserName),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              "Track $firstName's progress and recovery journey.",
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF5B7269)),
            ),
            const SizedBox(height: 16),
            ReportPeriodTabs(
              selected: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
            const SizedBox(height: 12),
            ReportDateRangeBar(label: dateRangeLabel),
            const SizedBox(height: 18),
            WeeklySummaryCard(
              title: '${_period.label} Summary',
              subtitle: "Here's how $firstName did this ${_period.noun}.",
              stats: [
                SummaryStat(
                  icon: Icons.calendar_today,
                  iconColor: _accent,
                  iconBg: _mintBg,
                  label: 'Recovery Streak',
                  value: '${store.streakDays} Days',
                  caption: 'No change vs last ${_period.noun}',
                ),
                SummaryStat(
                  icon: Icons.shield_outlined,
                  iconColor: _accent,
                  iconBg: _mintBg,
                  label: 'Blocked Attempts',
                  value: '$totalAttempts',
                  delta: trendDataset == null
                      ? null
                      : '${trendDataset.attemptsTrendPct.abs().toStringAsFixed(0)}%',
                  deltaUp: trendDataset == null
                      ? null
                      : trendDataset.attemptsTrendPct > 0,
                  caption: 'vs last ${_period.noun}',
                ),
                SummaryStat(
                  icon: Icons.lock_outline,
                  iconColor: _blue,
                  iconBg: _blueBg,
                  label: 'Journal Entries',
                  value: '$journalEntriesThisWeek / 7 Days',
                  caption: 'Logged this week',
                ),
                SummaryStat(
                  icon: Icons.access_time,
                  iconColor: const Color(0xFF7A5FCB),
                  iconBg: const Color(0xFFE8E2F9),
                  label: 'Most Active Time',
                  value: _mostActiveTimeLabel(),
                  caption: 'Peak of blocked attempts',
                ),
                SummaryStat(
                  icon: Icons.lock,
                  iconColor: _accent,
                  iconBg: _mintBg,
                  label: 'Protection Status',
                  value: store.protectionActive ? 'Locked' : 'Unlocked',
                  caption: 'All ${_period.noun}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            BlockedAttemptsChartCard(
              data: chartData,
              rangeLabel: 'This ${_period.label}',
            ),
            const SizedBox(height: 18),
            RecoveryStreakCalendarCard(days: streakDays),
            const SizedBox(height: 18),
            ReportInsightCard(message: insightMessage),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'All reports are based on Sawatâ data and updated daily.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF8EA198)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: GuardianBottomNav(
        currentIndex: _navIndex,
        requestCount: store.pendingGuardianInvites,
        onTap: (i) {
          if (i == 0) {
            Navigator.of(
              context,
            ).pushReplacementNamed(AppRoutes.guardianDashboard);
            return;
          }
          if (i == 1) {
            Navigator.of(
              context,
            ).pushReplacementNamed(AppRoutes.guardianInvites);
            return;
          }
          if (i == 2) {
            Navigator.of(
              context,
            ).pushReplacementNamed(AppRoutes.guardianAlerts);
            return;
          }
          if (i == 4) {
            Navigator.of(
              context,
            ).pushReplacementNamed(AppRoutes.guardianSettings);
            return;
          }
          setState(() => _navIndex = i);
        },
      ),
    );
  }
}
