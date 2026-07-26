import 'package:flutter/material.dart';

class GuardianActivityItem {
  const GuardianActivityItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isUrgent = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String time;
  final bool isUrgent;
}

class RecentGuardianActivityCard extends StatelessWidget {
  const RecentGuardianActivityCard({
    super.key,
    required this.items,
    this.onViewAll,
  });

  final List<GuardianActivityItem> items;
  final VoidCallback? onViewAll;

  static const _deepTeal = Color(0xFF16332B);
  static const _muted = Color(0xFF5B7269);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'RECENT ACTIVITY',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: _muted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            if (onViewAll != null)
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                _row(items[i], showDivider: i != 0),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(GuardianActivityItem item, {required bool showDivider}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x14000000))),
            )
          : null,
      color: item.isUrgent ? const Color(0xFFFBE7E4) : null,
      margin: item.isUrgent
          ? const EdgeInsets.symmetric(vertical: 2)
          : EdgeInsets.zero,
      child: Padding(
        padding: item.isUrgent
            ? const EdgeInsets.symmetric(horizontal: 8)
            : EdgeInsets.zero,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(item.icon, size: 17, color: item.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: _deepTeal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: const TextStyle(fontSize: 11.5, color: _muted),
                  ),
                ],
              ),
            ),
            Text(
              item.time,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: item.isUrgent ? const Color(0xFFC0392B) : _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
