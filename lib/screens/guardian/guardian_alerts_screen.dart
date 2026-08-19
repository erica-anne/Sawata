import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/data/dummy_data_store.dart';
import 'package:sawata/models/blocked_item.dart';
import 'package:sawata/widgets/snackbar_helper.dart';

import 'widgets/alert_card.dart';
import 'widgets/alert_filter_chips.dart';
import 'widgets/guardian_bottom_nav.dart';
import 'widgets/guardian_header.dart';
import 'widgets/user_switcher_chip.dart';

/// The Guardian-side "Alerts" screen — a filterable feed of security and
/// activity events for the linked user.
class GuardianAlertsScreen extends StatefulWidget {
  const GuardianAlertsScreen({super.key});

  @override
  State<GuardianAlertsScreen> createState() => _GuardianAlertsScreenState();
}

class _GuardianAlertsScreenState extends State<GuardianAlertsScreen> {
  final store = AppStore.instance;
  int _navIndex = 2;
  AlertCategory? _selectedCategory;

  static const _deepTeal = Color(0xFF16332B);

  String _formatTime(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $ampm';
  }

  AlertItem _alertItem(BlockAttempt attempt) {
    final isApp = attempt.category == 'App';
    return AlertItem(
      icon: attempt.icon,
      title: isApp ? 'Gambling App Blocked' : 'Gambling Website Blocked',
      description: 'Blocked: ${attempt.itemName}',
      category: isApp ? AlertCategory.apps : AlertCategory.websites,
      time: _formatTime(attempt.time),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alerts = store.recentAttempts.map(_alertItem).toList();

    final visibleAlerts = _selectedCategory == null
        ? alerts
        : alerts.where((a) => a.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            GuardianHeader(
              notificationCount: store.pendingGuardianInvites,
              onBellTap: () {},
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
                        'Alerts',
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
                UserSwitcherChip(name: store.profile.name),
              ],
            ),
            const SizedBox(height: 3),
            const Text(
              'Monitor important activities and security events.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF5B7269)),
            ),
            const SizedBox(height: 16),
            AlertFilterChips(
              selected: _selectedCategory,
              onChanged: (category) =>
                  setState(() => _selectedCategory = category),
              onFilterTap: () =>
                  showAppSnackBar(context, 'Advanced filters coming soon'),
            ),
            const SizedBox(height: 18),
            const Text(
              'Today',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _deepTeal,
              ),
            ),
            const SizedBox(height: 10),
            if (visibleAlerts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No alerts in this category.',
                    style: TextStyle(color: Color(0xFF5B7269)),
                  ),
                ),
              )
            else
              for (var i = 0; i < visibleAlerts.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                AlertCard(
                  item: visibleAlerts[i],
                  onTap: () =>
                      showAppSnackBar(context, 'Alert details coming soon'),
                ),
              ],
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
