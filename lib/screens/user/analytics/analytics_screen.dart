import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/models/blocked_item.dart';
import 'package:sawata/models/stat_snapshot.dart';
import 'package:sawata/models/user_stats.dart';
import 'package:sawata/services/user_data_service.dart';
import 'package:sawata/utils/attempt_buckets.dart';
import 'package:sawata/widgets/snackbar_helper.dart';
import '../dashboard/widgets/dashboard_header.dart';
import 'widgets/recent_blocked_card.dart';
import 'widgets/streak_hero_card.dart';
import 'widgets/trend_stat_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, this.onNavigateToTab});

  /// Optional so this screen still works if instantiated without shell
  /// wiring; used by "View All" to jump to the Protection tab.
  final void Function(int index)? onNavigateToTab;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selected = 0;

  static const _accent = Color(0xFF2E7D6B);
  static const _accentDeep = Color(0xFF16332B);
  static const _mintBg = Color(0xFFDDEEE7);
  static const _blueBg = Color(0xFFE3ECFB);
  static const _blue = Color(0xFF3B6FE0);

  static const _periodLabels = ['Week', 'Month', 'Year'];
  static const _periodCaptions = ['This Week', 'This Month', 'This Year'];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static const List<double> _niceIntervals = [
    5,
    10,
    25,
    50,
    100,
    250,
    500,
    1000,
  ];

  double _niceInterval(double maxValue) {
    for (final step in _niceIntervals) {
      if (maxValue / step <= 4) return step;
    }
    return _niceIntervals.last;
  }

  ({List<WeeklyStat> series, double trendPct}) _bucket(
    List<BlockAttempt> attempts,
  ) {
    final now = DateTime.now();
    switch (_selected) {
      case 1:
        return AttemptBuckets.month(attempts, now);
      case 2:
        return AttemptBuckets.year(attempts, now);
      default:
        return AttemptBuckets.week(attempts, now);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return StreamBuilder<UserStats>(
      stream: uid == null ? null : UserDataService.watchStats(uid),
      builder: (context, statsSnapshot) {
        final stats = statsSnapshot.data ?? UserStats.initial();
        return StreamBuilder<List<BlockedItem>>(
          stream: uid == null ? null : UserDataService.watchBlockedItems(uid),
          builder: (context, itemsSnapshot) {
            final items = itemsSnapshot.data ?? const <BlockedItem>[];
            return StreamBuilder<List<BlockAttempt>>(
              stream: uid == null
                  ? null
                  : UserDataService.watchBlockAttempts(uid),
              builder: (context, attemptsSnapshot) {
                final attempts =
                    attemptsSnapshot.data ?? const <BlockAttempt>[];
                return _buildBody(context, stats, items, attempts);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    UserStats stats,
    List<BlockedItem> items,
    List<BlockAttempt> attempts,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final bucket = _bucket(attempts);
    final periodTotal = bucket.series.fold<double>(0, (s, e) => s + e.value);
    final maxSeries = bucket.series
        .map((e) => e.value)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final yInterval = _niceInterval(maxSeries <= 0 ? 1 : maxSeries);
    final chartMaxY = (maxSeries / yInterval).ceil() * yInterval + yInterval;

    final recentAttempts = [...attempts]
      ..sort((a, b) => b.time.compareTo(a.time));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            DashboardHeader(
              onBellTap: () =>
                  showAppSnackBar(context, "You're all caught up!"),
              onSettingsTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.settings),
            ),
            const SizedBox(height: 18),
            Text(
              'Analytics',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Track your progress and celebrate every step forward.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: [
                for (var i = 0; i < _periodLabels.length; i++)
                  ButtonSegment(value: i, label: Text(_periodLabels[i])),
              ],
              selected: {_selected},
              onSelectionChanged: (selection) =>
                  setState(() => _selected = selection.first),
            ),
            const SizedBox(height: 18),
            StreakHeroCard(
              currentStreak: stats.streakDays,
              // No streak-history tracking exists yet, so the longest streak
              // we can honestly report is the current one.
              longestStreak: stats.streakDays,
              goalDays: 100,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TrendStatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: _accent,
                    iconBg: _mintBg,
                    label: 'Money Saved',
                    value: '₱${stats.moneySavedPesos}',
                    trendPct: 0,
                    trendCaption: 'not tracked yet',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TrendStatCard(
                    icon: Icons.public,
                    iconColor: _blue,
                    iconBg: _blueBg,
                    label: 'Sites Blocked',
                    value: '${items.length}',
                    trendPct: 0,
                    trendCaption: 'total on your list',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TrendStatCard(
                    icon: Icons.shield_outlined,
                    iconColor: _accent,
                    iconBg: _mintBg,
                    label: 'Attempts Blocked',
                    value: periodTotal.toStringAsFixed(0),
                    trendPct: bucket.trendPct,
                    trendCaption:
                        'vs last ${_periodLabels[_selected].toLowerCase()}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Attempts Blocked',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _periodCaptions[_selected],
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const Icon(Icons.keyboard_arrow_down, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 210,
                      child: BarChart(
                        key: ValueKey(_selected),
                        BarChartData(
                          maxY: chartMaxY,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: yInterval,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.35,
                              ),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                interval: yInterval,
                                getTitlesWidget: (value, meta) => Text(
                                  '${value.toInt()}',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final i = value.toInt();
                                  if (i < 0 || i >= bucket.series.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      bucket.series[i].label,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => Colors.transparent,
                              tooltipPadding: EdgeInsets.zero,
                              tooltipMargin: 8,
                              fitInsideHorizontally: true,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      rod.toY.toStringAsFixed(0),
                                      const TextStyle(
                                        color: _accentDeep,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    );
                                  },
                            ),
                          ),
                          barGroups: [
                            for (var i = 0; i < bucket.series.length; i++)
                              BarChartGroupData(
                                x: i,
                                showingTooltipIndicators: const [0],
                                barRods: [
                                  BarChartRodData(
                                    toY: bucket.series[i].value,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [_accentDeep, _accent],
                                    ),
                                    width: 16,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            RecentBlockedCard(
              attempts: recentAttempts.take(3).toList(),
              onViewAll: widget.onNavigateToTab == null
                  ? null
                  : () => widget.onNavigateToTab!(1),
              onTapItem: (attempt) => showAppSnackBar(
                context,
                '${attempt.itemName} was automatically blocked by Sawatâ.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
