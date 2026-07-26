import 'package:flutter/material.dart';

class GuardianInvite {
  const GuardianInvite({
    required this.name,
    required this.avatarColor,
    required this.dateLabel,
  });

  final String name;
  final Color avatarColor;
  final String dateLabel;
}

/// A single pending invite row on the "Request" tab: who invited you, when,
/// and Reject / Confirm actions.
class GuardianInviteCard extends StatelessWidget {
  const GuardianInviteCard({
    super.key,
    required this.invite,
    required this.onReject,
    required this.onConfirm,
  });

  final GuardianInvite invite;
  final VoidCallback onReject;
  final VoidCallback onConfirm;

  static const _deepTeal = Color(0xFF16332B);
  static const _muted = Color(0xFF5B7269);
  static const _red = Color(0xFFC0392B);
  static const _accent = Color(0xFF2E7D6B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: invite.avatarColor.withValues(alpha: 0.15),
                child: Text(
                  invite.name.trim().isEmpty
                      ? '?'
                      : invite.name.trim()[0].toUpperCase(),
                  style: TextStyle(
                    color: invite.avatarColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: _deepTeal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'invited you to become their guardian',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: _muted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Requested ${invite.dateLabel}',
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: _muted),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: const BorderSide(color: _red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 15),
                    label: const Text(
                      'Reject',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 15),
                    label: const Text(
                      'Confirm',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
