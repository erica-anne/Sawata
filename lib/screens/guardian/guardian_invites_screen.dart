import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/data/dummy_data_store.dart';

import 'widgets/guardian_bottom_nav.dart';
import 'widgets/guardian_connection_card.dart';
import 'widgets/guardian_header.dart';
import 'widgets/guardian_invite_card.dart';

/// The Guardian-side "Guardian Invites" screen — pending requests from
/// people asking this guardian to support their recovery, plus a list of
/// already-accepted connections.
class GuardianInvitesScreen extends StatefulWidget {
  const GuardianInvitesScreen({super.key});

  @override
  State<GuardianInvitesScreen> createState() => _GuardianInvitesScreenState();
}

class _GuardianInvitesScreenState extends State<GuardianInvitesScreen> {
  final store = AppStore.instance;
  int _navIndex = 1;
  bool _showAccepted = false;

  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);
  static const _muted = Color(0xFF5B7269);
  static const _mintBg = Color(0xFFDDEEE7);

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _formatDate(DateTime date) =>
      '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

  late final now = DateTime.now();

  late final List<GuardianInvite> _pending = [
    GuardianInvite(
      name: 'Juan D. Abao',
      avatarColor: _accent,
      dateLabel: _formatDate(now),
    ),
    GuardianInvite(
      name: 'Maria Santos',
      avatarColor: const Color(0xFFB07A1E),
      dateLabel: _formatDate(now.subtract(const Duration(days: 1))),
    ),
    GuardianInvite(
      name: 'Peter Cruz',
      avatarColor: const Color(0xFF3B6FE0),
      dateLabel: _formatDate(now.subtract(const Duration(days: 2))),
    ),
  ];

  late final List<GuardianConnection> _accepted = [
    GuardianConnection(
      name: 'Juan D. Abao',
      avatarColor: _accent,
      dateLabel: _formatDate(now),
    ),
    GuardianConnection(
      name: 'Maria Santos',
      avatarColor: const Color(0xFFB07A1E),
      dateLabel: _formatDate(now.subtract(const Duration(days: 1))),
    ),
    GuardianConnection(
      name: 'Peter Cruz',
      avatarColor: const Color(0xFF3B6FE0),
      dateLabel: _formatDate(now.subtract(const Duration(days: 2))),
    ),
  ];

  void _reject(GuardianInvite invite) {
    setState(() {
      _pending.remove(invite);
      store.pendingGuardianInvites = _pending.length;
    });
  }

  void _confirm(GuardianInvite invite) {
    setState(() {
      _pending.remove(invite);
      store.pendingGuardianInvites = _pending.length;
      _accepted.insert(
        0,
        GuardianConnection(
          name: invite.name,
          avatarColor: invite.avatarColor,
          dateLabel: _formatDate(now),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            GuardianHeader(notificationCount: 2, onBellTap: () {}),
            const SizedBox(height: 18),
            const Text(
              'Guardian Invites',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _deepTeal,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'People who invited you to be their guardian.',
              style: TextStyle(fontSize: 12.5, color: _muted),
            ),
            const SizedBox(height: 16),
            _SegmentedTabs(
              showAccepted: _showAccepted,
              pendingCount: _pending.length,
              acceptedCount: _accepted.length,
              onChanged: (value) => setState(() => _showAccepted = value),
            ),
            const SizedBox(height: 16),
            if (!_showAccepted) ...[
              if (_pending.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No pending invites right now.',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                )
              else
                for (var i = 0; i < _pending.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  GuardianInviteCard(
                    invite: _pending[i],
                    onReject: () => _reject(_pending[i]),
                    onConfirm: () => _confirm(_pending[i]),
                  ),
                ],
            ] else ...[
              for (var i = 0; i < _accepted.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                GuardianConnectionCard(connection: _accepted[i]),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _mintBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: _accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thank you for being a guardian.',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: _accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "You're helping make a big difference in their "
                            'recovery journey.',
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.favorite, size: 28, color: _accent),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: GuardianBottomNav(
        currentIndex: _navIndex,
        requestCount: _pending.length,
        onTap: (i) {
          if (i == 0) {
            Navigator.of(
              context,
            ).pushReplacementNamed(AppRoutes.guardianDashboard);
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

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.showAccepted,
    required this.pendingCount,
    required this.acceptedCount,
    required this.onChanged,
  });

  final bool showAccepted;
  final int pendingCount;
  final int acceptedCount;
  final ValueChanged<bool> onChanged;

  static const _accent = Color(0xFF2E7D6B);
  static const _deepTeal = Color(0xFF16332B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Expanded(
            child: _Segment(
              label: 'Request ($pendingCount)',
              selected: !showAccepted,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _Segment(
              label: 'Accepted ($acceptedCount)',
              selected: showAccepted,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _SegmentedTabs._accent : null,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: selected ? Colors.white : _SegmentedTabs._deepTeal,
            ),
          ),
        ),
      ),
    );
  }
}
