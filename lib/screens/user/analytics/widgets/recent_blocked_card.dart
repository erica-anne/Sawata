import 'package:flutter/material.dart';

import 'package:sawata/models/blocked_item.dart';

class RecentBlockedCard extends StatelessWidget {
  const RecentBlockedCard({
    super.key,
    required this.attempts,
    this.onViewAll,
    this.onTapItem,
  });

  final List<BlockAttempt> attempts;
  final VoidCallback? onViewAll;
  final void Function(BlockAttempt attempt)? onTapItem;

  static const _mint = Color(0xFFDDEEE7);
  static const _accent = Color(0xFF2E7D6B);
  static const _blockedBg = Color(0xFFFBE7E4);
  static const _blockedFg = Color(0xFFC0392B);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent Blocked',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View All'),
                        Icon(Icons.chevron_right, size: 16),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < attempts.length; i++)
              InkWell(
                onTap: onTapItem == null ? null : () => onTapItem!(attempts[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : Border(
                            top: BorderSide(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _mint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Icon(attempts[i].icon, size: 17, color: _accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attempts[i].itemName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${attempts[i].category} · ${_formatAbsolute(attempts[i].time)}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _blockedBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Blocked',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _blockedFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatAbsolute(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(time.year, time.month, time.day);
    final String dayLabel;
    if (thatDay == today) {
      dayLabel = 'Today';
    } else if (thatDay == today.subtract(const Duration(days: 1))) {
      dayLabel = 'Yesterday';
    } else {
      dayLabel = '${time.month}/${time.day}';
    }
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$dayLabel, $hour12:$minute $ampm';
  }
}
