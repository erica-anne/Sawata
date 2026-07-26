import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/data/dummy_data_store.dart';
import 'package:sawata/widgets/snackbar_helper.dart';

import 'widgets/guardian_bottom_nav.dart';
import 'widgets/guardian_header.dart';
import 'widgets/guardian_stat_card.dart';
import 'widgets/live_alert_card.dart';
import 'widgets/recent_guardian_activity_card.dart';
import 'widgets/send_encouragement_card.dart';
import 'widgets/streak_status_hero.dart';
import 'widgets/user_switcher_chip.dart';

/// The real Guardian-side dashboard — what a guardian like Maria sees when
/// monitoring someone else's recovery. Distinct from
/// `screens/user/guardian_contact`, which is the User app's screen about
/// *their own* guardian.
class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({super.key});

  @override
  State<GuardianDashboardScreen> createState() =>
      _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  final store = AppStore.instance;
  int _navIndex = 0;

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

  String _formatDate(DateTime date) =>
      '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

  String _formatTime(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $ampm';
  }

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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final guardianFirstName = store.guardian.name.split(' ').first;
    final linkedUserName = store.profile.name;
    final protectedSince = store.protectedSince ?? now;
    final longestStreak = store.analyticsDatasets.isNotEmpty
        ? store.analyticsDatasets.first.longestStreakDays
        : store.streakDays;

    final todayCount = _attemptsOn(now);
    final yesterdayCount = _attemptsOn(now.subtract(const Duration(days: 1)));

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            GuardianHeader(
              notificationCount: 2,
              onBellTap: () =>
                  Navigator.of(context).pushReplacementNamed(
                    AppRoutes.guardianAlerts,
                  ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good evening, $guardianFirstName! 👋',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16332B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "You're supporting ${linkedUserName.split(' ').first}'s recovery.",
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF5B7269),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                UserSwitcherChip(name: linkedUserName),
              ],
            ),
            const SizedBox(height: 18),
            LiveAlertCard(
              title: 'Uninstall Attempt Detected',
              description:
                  '${linkedUserName.split(' ').first} tried to delete the Sawatâ app from his device.',
              timestamp: 'Today, ${_formatTime(now)}',
              statusLabel: 'Action Detected',
              onTap: () =>
                  showAppSnackBar(context, 'Alert details coming soon'),
            ),
            const SizedBox(height: 18),
            StreakStatusHero(
              streakDays: store.streakDays,
              startedOnLabel: _formatDate(protectedSince),
              protectionActive: store.protectionActive,
              sinceDateLabel: _formatDate(protectedSince),
              sinceTimeLabel: _formatTime(protectedSince),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GuardianStatCard(
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF2E7D6B),
                    iconBg: const Color(0xFFDDEEE7),
                    label: "Today's Uninstall Attempts",
                    value: '$todayCount',
                    unit: '',
                    caption: 'vs yesterday',
                    trendUp: todayCount == yesterdayCount
                        ? null
                        : todayCount > yesterdayCount,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GuardianStatCard(
                    icon: Icons.calendar_month_outlined,
                    iconColor: const Color(0xFF3B6FE0),
                    iconBg: const Color(0xFFE3ECFB),
                    label: 'Streak',
                    value: '$longestStreak',
                    unit: 'Days',
                    caption: 'Personal best',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            RecentGuardianActivityCard(
              onViewAll: () =>
                  showAppSnackBar(context, 'Full activity log coming soon'),
              items: [
                GuardianActivityItem(
                  icon: Icons.delete_outline,
                  iconColor: const Color(0xFFC0392B),
                  iconBg: const Color(0xFFFBE7E4),
                  title: 'Uninstall attempt detected',
                  subtitle:
                      '${linkedUserName.split(' ').first} tried to delete the Sawatâ app.',
                  time: 'Just now',
                  isUrgent: true,
                ),
                GuardianActivityItem(
                  icon: Icons.language,
                  iconColor: const Color(0xFFB07A1E),
                  iconBg: const Color(0xFFFCEFD2),
                  title: 'Blocked gambling website',
                  subtitle: 'bet88.com',
                  time: _formatTime(now.subtract(const Duration(minutes: 5))),
                ),
                GuardianActivityItem(
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0xFF3B6FE0),
                  iconBg: const Color(0xFFE3ECFB),
                  title: 'Multiple blocked attempts',
                  subtitle: '5 attempts in the last hour',
                  time: _formatTime(
                    now.subtract(const Duration(hours: 1, minutes: 26)),
                  ),
                ),
                GuardianActivityItem(
                  icon: Icons.star_outline,
                  iconColor: const Color(0xFF2E7D6B),
                  iconBg: const Color(0xFFDDEEE7),
                  title: 'Milestone reached!',
                  subtitle:
                      '${linkedUserName.split(' ').first} reached 20 days of recovery.',
                  time: 'Yesterday',
                ),
              ],
            ),
            const SizedBox(height: 20),
            SendEncouragementCard(
              onViewAll: () =>
                  showAppSnackBar(context, 'Message history coming soon'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: GuardianBottomNav(
        currentIndex: _navIndex,
        requestCount: store.pendingGuardianInvites,
        onTap: (i) {
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
          if (i == 3) {
            Navigator.of(
              context,
            ).pushReplacementNamed(AppRoutes.guardianReports);
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
