import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/data/dummy_data_store.dart';
import 'package:sawata/widgets/snackbar_helper.dart';
import 'widgets/clean_days_calendar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_stat_card.dart';
import 'widgets/motivation_banner.dart';
import 'widgets/protection_status_card.dart';
import 'widgets/shield_hero.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onNavigateToTab});

  final void Function(int index) onNavigateToTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final store = AppStore.instance;

  static const _mint = Color(0xFF2E7D6B);
  static const _mintBg = Color(0xFFDDEEE7);
  static const _blue = Color(0xFF3B6FE0);
  static const _blueBg = Color(0xFFE3ECFB);
  static const _amber = Color(0xFFC98A2E);
  static const _amberBg = Color(0xFFFBEBD6);

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {});
    showAppSnackBar(context, 'Stats refreshed');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final firstName = store.profile.name.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
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
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
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
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const ShieldHero(size: 130),
                ],
              ),
              const SizedBox(height: 24),
              ProtectionStatusCard(
                active: store.protectionActive,
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
                      value: '${store.blockedAttempts}',
                      label: 'Sites Blocked',
                      footer: const SparklineFooter(color: _mint),
                      onTap: () => widget.onNavigateToTab(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DashboardStatCard(
                      icon: Icons.calendar_today_outlined,
                      iconColor: _blue,
                      iconBg: _blueBg,
                      value: '${store.streakDays}',
                      label: 'Days Streak',
                      footer: StreakDotsFooter(
                        completed: store.streakDays.clamp(0, 7),
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
                      value: '₱${store.moneySavedPesos}',
                      label: 'Money Saved',
                      footer: const MiniBarsFooter(color: _amber),
                      onTap: () => widget.onNavigateToTab(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CleanDaysCalendar(streakDays: store.streakDays),
              const SizedBox(height: 18),
              MotivationBanner(onTap: () => widget.onNavigateToTab(3)),
            ],
          ),
        ),
      ),
    );
  }
}
