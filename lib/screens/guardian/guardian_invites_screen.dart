import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/data/dummy_data_store.dart';
import 'package:sawata/services/email_service.dart';
import 'package:sawata/services/guardian_service.dart';

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

  late final List<GuardianInvite> _pending;

  @override
  void initState() {
    super.initState();
    final myInvite = store.myGuardianInvite;
    _pending = [
      if (myInvite != null)
        GuardianInvite(
          name: myInvite.name,
          avatarColor: _accent,
          dateLabel: _formatDate(myInvite.sentAt),
          isFromCurrentUser: true,
        ),
    ];
  }

  final List<GuardianConnection> _accepted = [];

  /// Looks up the still-pending `invites` doc sent by [fromUid] — used both
  /// to notify the original inviter by email (name/email fields) and, on
  /// accept, to pass a real invite doc ID into [GuardianService.acceptInvite]
  /// so the Firestore security rules can verify this acceptance is tied to
  /// a genuine invite rather than trusting client-supplied UIDs alone.
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _fetchPendingInviteDoc(
    String fromUid,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('invites')
          .where('fromUid', isEqualTo: fromUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first;
    } catch (_) {
      return null;
    }
  }

  void _reject(GuardianInvite invite) {
    final myInvite = store.myGuardianInvite;
    final guardianName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Your guardian';
    setState(() {
      _pending.remove(invite);
      if (invite.isFromCurrentUser) {
        store.myGuardianInvite = null;
      }
      store.pendingGuardianInvites = _pending.length;
    });
    if (invite.isFromCurrentUser && myInvite?.fromUid != null) {
      _fetchPendingInviteDoc(myInvite!.fromUid!).then((doc) {
        if (doc == null) return;
        // Persist the decline so the protege's "My Guardians" screen can
        // show it — without this write, that screen has no way to learn a
        // guardian on a different device/account ever saw the invite.
        doc.reference.update({'status': 'declined'});
        final data = doc.data();
        final email = data['fromEmail'] as String? ?? '';
        final name = data['fromName'] as String? ?? '';
        if (email.isEmpty) return;
        EmailService.sendGuardianRejected(
          toEmail: email,
          toName: name.isNotEmpty ? name : 'there',
          guardianName: guardianName,
        );
      });
    }
  }

  Future<void> _confirm(GuardianInvite invite) async {
    final myInvite = store.myGuardianInvite;
    final guardianName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Your guardian';

    // Fetch the real invite doc *before* mutating local state — its ID is
    // required by GuardianService.acceptInvite so the Firestore security
    // rules can verify this acceptance against a genuine invite instead of
    // trusting the client-supplied UIDs alone.
    final inviteDoc = invite.isFromCurrentUser && myInvite?.fromUid != null
        ? await _fetchPendingInviteDoc(myInvite!.fromUid!)
        : null;

    if (!mounted) return;
    setState(() {
      _pending.remove(invite);
      if (invite.isFromCurrentUser && myInvite != null) {
        // The persisted relationship lives in Firestore now (see
        // GuardianService.acceptInvite below) — that's the single source
        // of truth the protege's Guardian Contact screen streams from.
        // We only clear the local pending-invite bookkeeping here.
        store.myGuardianInvite = null;
      }
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
    if (invite.isFromCurrentUser && myInvite?.fromUid != null && inviteDoc != null) {
      _linkGuardianInFirestore(myInvite!.fromUid!);
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        GuardianService.acceptInvite(
          protegeUid: myInvite.fromUid!,
          guardianUid: currentUser.uid,
          guardianName: currentUser.displayName ?? myInvite.name,
          guardianEmail: currentUser.email ?? myInvite.email,
          relationship: myInvite.relationship,
          inviteId: inviteDoc.id,
          phone: myInvite.phone,
        );
      }
      final data = inviteDoc.data();
      final email = data['fromEmail'] as String? ?? '';
      final name = data['fromName'] as String? ?? '';
      if (email.isNotEmpty) {
        EmailService.sendGuardianAccepted(
          toEmail: email,
          toName: name.isNotEmpty ? name : 'there',
          guardianName: guardianName,
        );
      }
    }
  }

  /// Persists the accepted relationship to Firestore so the native
  /// Accessibility Service (which has no access to this in-memory
  /// AppStore) can resolve which guardian to notify for a blocked attempt.
  /// Best-effort: failures here don't affect the in-memory UI state above,
  /// which already reflects the acceptance regardless.
  Future<void> _linkGuardianInFirestore(String fromUid) async {
    final guardianUid = FirebaseAuth.instance.currentUser?.uid;
    if (guardianUid == null) return;
    final firestore = FirebaseFirestore.instance;
    try {
      final batch = firestore.batch();
      batch.set(
        firestore.collection('users').doc(fromUid),
        {'linkedUid': guardianUid, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      batch.set(
        firestore.collection('users').doc(guardianUid),
        {'linkedUid': fromUid, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await batch.commit();

      final pendingInvites = await firestore
          .collection('invites')
          .where('fromUid', isEqualTo: fromUid)
          .where('status', isEqualTo: 'pending')
          .get();
      for (final doc in pendingInvites.docs) {
        await doc.reference.update({'status': 'accepted'});
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await firestore.collection('users').doc(guardianUid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Non-fatal — e.g. no Play Services for FCM token, or offline.
    }
  }

  @override
  Widget build(BuildContext context) {
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
            ] else if (_accepted.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No accepted connections yet.',
                    style: TextStyle(color: _muted),
                  ),
                ),
              ),
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
