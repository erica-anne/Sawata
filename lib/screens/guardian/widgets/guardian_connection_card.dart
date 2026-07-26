import 'package:flutter/material.dart';

class GuardianConnection {
  const GuardianConnection({
    required this.name,
    required this.avatarColor,
    required this.dateLabel,
  });

  final String name;
  final Color avatarColor;
  final String dateLabel;
}

/// A single already-accepted relationship row on the "Accepted" tab.
class GuardianConnectionCard extends StatelessWidget {
  const GuardianConnectionCard({super.key, required this.connection});

  final GuardianConnection connection;

  static const _deepTeal = Color(0xFF16332B);
  static const _muted = Color(0xFF5B7269);
  static const _accent = Color(0xFF2E7D6B);
  static const _mintBg = Color(0xFFDDEEE7);

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
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: connection.avatarColor.withValues(alpha: 0.15),
            child: Text(
              connection.name.trim().isEmpty
                  ? '?'
                  : connection.name.trim()[0].toUpperCase(),
              style: TextStyle(
                color: connection.avatarColor,
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
                  connection.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: _deepTeal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Connected ${connection.dateLabel}',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _mintBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 12, color: _accent),
                SizedBox(width: 4),
                Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18, color: _muted),
        ],
      ),
    );
  }
}
