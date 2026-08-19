import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/data/dummy_data_store.dart';
import 'package:sawata/models/stat_snapshot.dart';
import 'package:sawata/models/user_stats.dart';
import 'package:sawata/services/user_data_service.dart';
import 'package:sawata/widgets/snackbar_helper.dart';
import 'widgets/clean_days_calendar.dart';
import 'widgets/daily_reminder_card.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_stat_card.dart';
import 'widgets/protection_status_card.dart';
import 'widgets/shield_hero.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onNavigateToTab});

  final void Function(int index) onNavigateToTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Weekly chart history (sparklines/mini-bars below) still comes from the
  // seeded AppStore — real per-user stats now stream from Firestore via
  // UserDataService, but weekly rollups need a separate aggregation job.
  final store = AppStore.instance;

  static const _mint = Color(0xFF2E7D6B);
  static const _mintBg = Color(0xFFDDEEE7);
  static const _blue = Color(0xFF3B6FE0);
  static const _blueBg = Color(0xFFE3ECFB);
  static const _amber = Color(0xFFC98A2E);
  static const _amberBg = Color(0xFFFBEBD6);

  List<double> _normalized(List<WeeklyStat> stats) {
    if (stats.isEmpty) return const [0.05, 0.05];
    final maxValue = stats
        .map((s) => s.value)
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (maxValue <= 0) return List.filled(stats.length, 0.05);
    return [for (final s in stats) (s.value / maxValue).clamp(0.05, 1.0)];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = FirebaseAuth.instance.currentUser?.displayName ?? '';
    final firstName = displayName.trim().isEmpty
        ? 'there'
        : displayName.trim().split(RegExp(r'\s+')).first;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<UserStats>(
          stream: uid == null
              ? null
              : UserDataService.watchStats(uid),
          builder: (context, snapshot) {
            final stats = snapshot.data ?? UserStats.initial();
            return RefreshIndicator(
              onRefresh: () async {
                showAppSnackBar(context, 'Stats refreshed');
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  DashboardHeader(
                    onBellTap: () =>
                        showAppSnackBar(context, "You're all caught up!"),
                    onSettingsTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.settings),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good to see you,',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            Text(
                              '$firstName.',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Every day without gambling is a step toward freedom.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const ShieldHero(size: 130),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const DailyReminderCard(),
                  const SizedBox(height: 14),
                  ProtectionStatusCard(
                    active: stats.protectionActive,
                    onViewDetails: () => widget.onNavigateToTab(1),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DashboardStatCard(
                          icon: Icons.public,
                          iconColor: _mint,
                          iconBg: _mintBg,
                          value: '${stats.blockedAttempts}',
                          label: 'Sites Blocked',
                          footer: SparklineFooter(
                            color: _mint,
                            points: _normalized(
                              store.analyticsDatasets.isEmpty
                                  ? const []
                                  : store.analyticsDatasets[0].attempts,
                            ),
                          ),
                          onTap: () => widget.onNavigateToTab(1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DashboardStatCard(
                          icon: Icons.calendar_today_outlined,
                          iconColor: _blue,
                          iconBg: _blueBg,
                          value: '${stats.streakDays}',
                          label: 'Days Streak',
                          footer: StreakDotsFooter(
                            completed: stats.streakDays.clamp(0, 7),
                            color: _blue,
                          ),
                          onTap: () => widget.onNavigateToTab(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DashboardStatCard(
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: _amber,
                          iconBg: _amberBg,
                          value: '₱${stats.moneySavedPesos}',
                          label: 'Money Saved',
                          footer: MiniBarsFooter(
                            color: _amber,
                            values: _normalized(
                              store.analyticsDatasets.isEmpty
                                  ? const []
                                  : store.analyticsDatasets[0].savings,
                            ),
                          ),
                          onTap: () => widget.onNavigateToTab(2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CleanDaysCalendar(streakDays: stats.streakDays),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
