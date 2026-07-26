import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/data/dummy_data_store.dart';
import 'package:sawata/widgets/confirm_dialog.dart';
import 'package:sawata/widgets/snackbar_helper.dart';

import 'widgets/guardian_bottom_nav.dart';
import 'widgets/guardian_header.dart';

class GuardianSettingsScreen extends StatefulWidget {
  const GuardianSettingsScreen({super.key});

  @override
  State<GuardianSettingsScreen> createState() =>
      _GuardianSettingsScreenState();
}

class _GuardianSettingsScreenState extends State<GuardianSettingsScreen> {
  final store = AppStore.instance;
  int _navIndex = 4;

  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);
  static const _muted = Color(0xFF5B7269);

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('About Sawatâ Guardian'),
        content: Text(
          'Sawatâ Guardian v0.1.0 (prototype build)\n\n'
          'A UI prototype for supporting someone else\'s recovery journey. '
          'All data shown is simulated for demonstration purposes.',
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'Are you sure you want to log out of Sawatâ Guardian?',
      confirmLabel: 'Log out',
    );
    if (!confirmed || !mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final guardian = store.guardian;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            GuardianHeader(
              notificationCount: 2,
              onBellTap: () => Navigator.of(
                context,
              ).pushReplacementNamed(AppRoutes.guardianAlerts),
            ),
            const SizedBox(height: 18),
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _deepTeal,
              ),
            ),
            const SizedBox(height: 16),
            Container(
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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFDDEEE7),
                    child: Text(
                      guardian.initials,
                      style: const TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guardian.name,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: _deepTeal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          guardian.email,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
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
                children: [
                  SwitchListTile(
                    secondary: const Icon(
                      Icons.notifications_outlined,
                      color: _deepTeal,
                    ),
                    title: const Text(
                      'Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _deepTeal,
                      ),
                    ),
                    activeThumbColor: _accent,
                    value: store.notificationsEnabled,
                    onChanged: (value) {
                      setState(() => store.notificationsEnabled = value);
                      showAppSnackBar(
                        context,
                        value
                            ? 'Notifications enabled'
                            : 'Notifications disabled',
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: _deepTeal),
                    title: const Text(
                      'About & Privacy',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _deepTeal,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showAbout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
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
          if (i == 3) {
            Navigator.of(
              context,
            ).pushReplacementNamed(AppRoutes.guardianReports);
            return;
          }
          setState(() => _navIndex = i);
        },
      ),
    );
  }
}
