import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/models/guardian_relationship.dart';
import 'package:sawata/services/guardian_service.dart';
import 'package:sawata/widgets/empty_state.dart';
import 'package:sawata/widgets/snackbar_helper.dart';

import 'widgets/pending_invite_actions_sheet.dart';

/// The User's own "My Guardians" screen — every guardian relationship this
/// user has ever started, connected or not, filterable by status.
///
/// All data (connected guardians, sent invites of every status) is read
/// live from Firestore via [GuardianService] — nothing here is hardcoded or
/// sample data.
class GuardianContactScreen extends StatefulWidget {
  const GuardianContactScreen({super.key});

  @override
  State<GuardianContactScreen> createState() => _GuardianContactScreenState();
}

enum _GuardianFilter { all, connected, pending, declined, expired }

class _GuardianContactScreenState extends State<GuardianContactScreen> {
  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);
  static const _muted = Color(0xFF5B7269);
  static const _mintBg = Color(0xFFDDEEE7);
  static const _amber = Color(0xFFB07A1E);
  static const _amberBg = Color(0xFFFCEFD2);
  static const _red = Color(0xFFC0392B);
  static const _redBg = Color(0xFFFBE7E4);
  static const _greyBg = Color(0xFFE7EBE9);

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  _GuardianFilter _filter = _GuardianFilter.all;

  String _formatDate(DateTime date) =>
      '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      body: SafeArea(
        child: uid == null
            ? _buildMessage(
                context,
                icon: Icons.error_outline,
                message: "You're not signed in. Please log in to view your guardians.",
              )
            : StreamBuilder<List<GuardianRelationship>>(
                stream: GuardianService.streamGuardians(uid),
                builder: (context, guardianSnap) {
                  return StreamBuilder<List<SentGuardianInvite>>(
                    stream: GuardianService.streamSentInvites(uid),
                    builder: (context, inviteSnap) {
                      if (guardianSnap.connectionState == ConnectionState.waiting ||
                          inviteSnap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: _accent),
                        );
                      }
                      if (guardianSnap.hasError || inviteSnap.hasError) {
                        return _buildMessage(
                          context,
                          icon: Icons.error_outline,
                          message: 'Could not load your guardian information.',
                          onRetry: () => setState(() {}),
                        );
                      }
                      final connected = guardianSnap.data ?? const [];
                      final invites = inviteSnap.data ?? const [];
                      return _buildBody(context, connected, invites);
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context, {
    required IconData icon,
    required String message,
    VoidCallback? onRetry,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
      children: [
        Icon(icon, size: 40, color: _muted),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _deepTeal),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(color: _accent),
              ),
              child: const Text('Try Again'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<GuardianRelationship> connected,
    List<SentGuardianInvite> invites,
  ) {
    final pending = invites.where((i) => i.status == 'pending').toList();
    final declined = invites.where((i) => i.status == 'declined').toList();
    final expired = invites.where((i) => i.status == 'expired').toList();
    final totalCount = connected.length + pending.length + declined.length + expired.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _Header(),
        const SizedBox(height: 20),
        const Text(
          'My Guardians',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _deepTeal),
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage the people supporting your recovery.',
          style: TextStyle(fontSize: 12.5, color: _muted),
        ),
        const SizedBox(height: 18),
        if (totalCount == 0)
          EmptyState(
            icon: Icons.shield_outlined,
            message: 'No guardians yet. Invite someone you trust to support your recovery.',
            ctaLabel: 'Add Guardian',
            onCta: () => Navigator.of(context).pushNamed(AppRoutes.addGuardian),
          )
        else ...[
          _buildFilterChips(connected.length, pending.length, declined.length, expired.length),
          const SizedBox(height: 18),
          ..._buildSections(connected, pending, declined, expired),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.addGuardian),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(color: _accent),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Invite Another Guardian',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _mintBg, borderRadius: BorderRadius.circular(16)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 18, color: _accent),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'For your safety',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: _deepTeal),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Guardians cannot be removed or replaced within the app.',
                        style: TextStyle(fontSize: 11.5, color: _muted),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'This helps maintain accountability throughout your recovery journey.',
                        style: TextStyle(fontSize: 11.5, color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChips(int connectedN, int pendingN, int declinedN, int expiredN) {
    final total = connectedN + pendingN + declinedN + expiredN;
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            count: total,
            dotColor: _muted,
            selected: _filter == _GuardianFilter.all,
            onTap: () => setState(() => _filter = _GuardianFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Connected',
            count: connectedN,
            dotColor: _accent,
            selected: _filter == _GuardianFilter.connected,
            onTap: () => setState(() => _filter = _GuardianFilter.connected),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Pending',
            count: pendingN,
            dotColor: _amber,
            selected: _filter == _GuardianFilter.pending,
            onTap: () => setState(() => _filter = _GuardianFilter.pending),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Declined',
            count: declinedN,
            dotColor: _red,
            selected: _filter == _GuardianFilter.declined,
            onTap: () => setState(() => _filter = _GuardianFilter.declined),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Expired',
            count: expiredN,
            dotColor: _muted,
            selected: _filter == _GuardianFilter.expired,
            onTap: () => setState(() => _filter = _GuardianFilter.expired),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSections(
    List<GuardianRelationship> connected,
    List<SentGuardianInvite> pending,
    List<SentGuardianInvite> declined,
    List<SentGuardianInvite> expired,
  ) {
    final showConnected = _filter == _GuardianFilter.all || _filter == _GuardianFilter.connected;
    final showPending = _filter == _GuardianFilter.all || _filter == _GuardianFilter.pending;
    final showDeclined = _filter == _GuardianFilter.all || _filter == _GuardianFilter.declined;
    final showExpired = _filter == _GuardianFilter.all || _filter == _GuardianFilter.expired;

    final sections = <Widget>[];

    if (showConnected && connected.isNotEmpty) {
      sections.add(_sectionLabel('Connected Guardians'));
      for (final g in connected) {
        sections.add(
          _GuardianRow(
            initials: g.initials,
            name: g.name,
            email: g.email,
            dateLabel: 'Connected on ${_formatDate(g.connectedAt)}',
            relationship: g.relationship,
            statusLabel: 'Connected',
            statusFg: _accent,
            statusBg: _mintBg,
            statusIcon: Icons.check,
            onTap: () => _showConnectedDetail(g),
          ),
        );
        sections.add(const SizedBox(height: 10));
      }
    }
    if (showPending && pending.isNotEmpty) {
      sections.add(_sectionLabel('Pending Invitations'));
      for (final i in pending) {
        sections.add(
          _GuardianRow(
            initials: i.initials,
            name: i.name,
            email: i.email,
            dateLabel: 'Invited on ${_formatDate(i.createdAt)}',
            relationship: i.relationship,
            statusLabel: 'Pending',
            statusFg: _amber,
            statusBg: _amberBg,
            statusIcon: Icons.hourglass_top,
            onTap: () => showPendingInviteActionsSheet(context, i),
          ),
        );
        sections.add(const SizedBox(height: 10));
      }
    }
    if (showDeclined && declined.isNotEmpty) {
      sections.add(_sectionLabel('Declined Invitations'));
      for (final i in declined) {
        sections.add(
          _GuardianRow(
            initials: i.initials,
            name: i.name,
            email: i.email,
            dateLabel: 'Invited on ${_formatDate(i.createdAt)}',
            relationship: i.relationship,
            statusLabel: 'Declined',
            statusFg: _red,
            statusBg: _redBg,
            statusIcon: Icons.close,
            onTap: () => _showDeclinedDetail(i),
          ),
        );
        sections.add(const SizedBox(height: 10));
      }
    }
    if (showExpired && expired.isNotEmpty) {
      sections.add(_sectionLabel('Expired Invitations'));
      for (final i in expired) {
        sections.add(
          _GuardianRow(
            initials: i.initials,
            name: i.name,
            email: i.email,
            dateLabel: 'Invited on ${_formatDate(i.createdAt)}',
            relationship: i.relationship,
            statusLabel: 'Expired',
            statusFg: _muted,
            statusBg: _greyBg,
            statusIcon: Icons.schedule,
            onTap: () => _showDeclinedDetail(i),
          ),
        );
        sections.add(const SizedBox(height: 10));
      }
    }

    if (sections.isEmpty) {
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('No ${_filter.name} guardians.', style: const TextStyle(color: _muted)),
          ),
        ),
      );
    }
    return sections;
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _deepTeal),
    ),
  );

  void _showConnectedDetail(GuardianRelationship g) {
    final rows = <({IconData icon, String label, bool enabled})>[
      (
        icon: Icons.notifications_active_outlined,
        label: 'Receives uninstall attempt alerts',
        enabled: g.permissions.uninstallAlerts,
      ),
      (
        icon: Icons.shield_outlined,
        label: 'Receives blocked app/site alerts',
        enabled: g.permissions.blockedAlerts,
      ),
      (icon: Icons.show_chart, label: 'Views recovery streak', enabled: g.permissions.viewStreak),
      (
        icon: Icons.description_outlined,
        label: 'Views recovery reports',
        enabled: g.permissions.viewReports,
      ),
      (
        icon: Icons.favorite_border,
        label: 'Sends encouragement',
        enabled: g.permissions.sendEncouragement,
      ),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: _mintBg, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      g.initials,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _accent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _deepTeal),
                        ),
                        Text(
                          g.relationship,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(g.email, style: const TextStyle(fontSize: 12.5, color: _deepTeal)),
              const SizedBox(height: 4),
              Text(
                'Connected since ${_formatDate(g.connectedAt)}',
                style: const TextStyle(fontSize: 12.5, color: _deepTeal),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0x14000000)),
              const SizedBox(height: 12),
              const Text(
                'Guardian Permissions',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _deepTeal),
              ),
              const SizedBox(height: 6),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(row.icon, size: 17, color: _muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(row.label, style: const TextStyle(fontSize: 12.5, color: _deepTeal)),
                      ),
                      Icon(
                        row.enabled ? Icons.check_circle : Icons.cancel,
                        size: 17,
                        color: row.enabled ? _accent : const Color(0xFFCBD5D0),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeclinedDetail(SentGuardianInvite invite) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(invite.name),
        content: Text(
          invite.status == 'declined'
              ? '${invite.name} declined this invitation on ${_formatDate(invite.createdAt)}.'
              : 'This invitation to ${invite.name} is no longer active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(AppRoutes.addGuardian);
            },
            child: const Text('Invite Someone Else'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: const Color(0xFFDDEEE7),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF16332B)),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Image.asset('images/sawata_guardian_logo.png', height: 40),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () => showAppSnackBar(context, "You're all caught up!"),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.dotColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color dotColor;
  final bool selected;
  final VoidCallback onTap;

  static const _accent = Color(0xFF2E7D6B);
  static const _mintBg = Color(0xFFDDEEE7);
  static const _deepTeal = Color(0xFF16332B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _mintBg : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? _accent : const Color(0x1A16332B)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                '$label $count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? _accent : _deepTeal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuardianRow extends StatelessWidget {
  const _GuardianRow({
    required this.initials,
    required this.name,
    required this.email,
    required this.dateLabel,
    required this.relationship,
    required this.statusLabel,
    required this.statusFg,
    required this.statusBg,
    required this.statusIcon,
    required this.onTap,
  });

  final String initials;
  final String name;
  final String email;
  final String dateLabel;
  final String relationship;
  final String statusLabel;
  final Color statusFg;
  final Color statusBg;
  final IconData statusIcon;
  final VoidCallback onTap;

  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);
  static const _muted = Color(0xFF5B7269);
  static const _mintBg = Color(0xFFDDEEE7);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: _mintBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _deepTeal),
                    ),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 56,
                child: Text(
                  relationship,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: _muted, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 10, color: statusFg),
                    const SizedBox(width: 3),
                    Text(
                      statusLabel,
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: statusFg),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}
