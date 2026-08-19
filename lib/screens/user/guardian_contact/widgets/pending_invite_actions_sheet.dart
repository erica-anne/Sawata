import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:sawata/app/app_config.dart';
import 'package:sawata/models/guardian_relationship.dart';
import 'package:sawata/services/email_service.dart';
import 'package:sawata/widgets/confirm_dialog.dart';
import 'package:sawata/widgets/snackbar_helper.dart';

/// Bottom sheet opened by tapping a pending invite row on the "My
/// Guardians" screen — the same Check Status / Resend / Cancel actions that
/// used to only be reachable right after sending an invite, now reachable
/// any time from the persisted invite itself.
Future<void> showPendingInviteActionsSheet(
  BuildContext context,
  SentGuardianInvite invite,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _PendingInviteActionsContent(invite: invite),
  );
}

class _PendingInviteActionsContent extends StatefulWidget {
  const _PendingInviteActionsContent({required this.invite});

  final SentGuardianInvite invite;

  @override
  State<_PendingInviteActionsContent> createState() =>
      _PendingInviteActionsContentState();
}

class _PendingInviteActionsContentState
    extends State<_PendingInviteActionsContent> {
  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);
  static const _amber = Color(0xFFB07A1E);
  static const _amberBg = Color(0xFFFCEFD2);

  bool _isChecking = false;
  bool _isResending = false;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _formatDate(DateTime date) =>
      '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

  Future<void> _checkStatus() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('invites')
          .doc(widget.invite.id)
          .get();
      if (!mounted) return;
      final status = doc.data()?['status'] as String?;
      if (status == 'accepted') {
        Navigator.of(context).pop();
        showAppSnackBar(context, '${widget.invite.name} accepted your invitation!');
      } else if (status == 'declined') {
        Navigator.of(context).pop();
        showAppSnackBar(
          context,
          '${widget.invite.name} declined the invitation.',
          isSuccess: false,
        );
      } else {
        showAppSnackBar(context, "Still pending — no response yet.");
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not check status. Try again.', isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resend() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final result = await EmailService.sendGuardianInvite(
        toEmail: widget.invite.email,
        guardianName: widget.invite.name,
        userName: currentUser?.displayName ?? 'A Sawata user',
        appLink: AppConfig.guardianInvitesLink,
      );
      if (!mounted) return;
      if (!result.success) {
        showAppSnackBar(
          context,
          "Couldn't resend the invitation. Please try again.",
          isSuccess: false,
        );
        return;
      }
      await FirebaseFirestore.instance
          .collection('invites')
          .doc(widget.invite.id)
          .update({'resentAt': FieldValue.serverTimestamp()});
      if (!mounted) return;
      showAppSnackBar(context, 'Invitation resent to ${widget.invite.email}');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel invitation?',
      message:
          'This will remove the pending invitation you sent to ${widget.invite.name}.',
      confirmLabel: 'Cancel Invitation',
    );
    if (!confirmed || !mounted) return;
    await FirebaseFirestore.instance
        .collection('invites')
        .doc(widget.invite.id)
        .update({'status': 'cancelled'});
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppSnackBar(context, 'Invitation cancelled', isSuccess: false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFDDEEE7),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.person_outline, size: 24, color: _accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.invite.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _deepTeal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _amberBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hourglass_top, size: 11, color: _amber),
                            SizedBox(width: 4),
                            Text(
                              'Pending Acceptance',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: _amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0x14000000)),
            const SizedBox(height: 14),
            _InfoLine(icon: Icons.mail_outline, text: widget.invite.email),
            const SizedBox(height: 8),
            _InfoLine(icon: Icons.people_outline, text: widget.invite.relationship),
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.calendar_today_outlined,
              text: 'Invited on ${_formatDate(widget.invite.createdAt)}',
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isChecking ? null : _checkStatus,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: Color(0x662E7D6B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 17),
                label: const Text(
                  'Check Status',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isResending ? null : _resend,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: Color(0x662E7D6B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isResending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.mail_outline, size: 17),
                label: const Text(
                  'Resend Invitation',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC0392B),
                  side: const BorderSide(color: Color(0x66C0392B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.delete_outline, size: 17),
                label: const Text(
                  'Cancel Invitation',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF5B7269)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF16332B)),
          ),
        ),
      ],
    );
  }
}
