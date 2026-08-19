import 'package:flutter/material.dart';

/// Static "what's covered" list. Deliberately has no per-item toggles —
/// these categories are covered automatically by Sawatâ's global gambling
/// database (`blocked_packages`/`blocked_domains`) once Protection Lock is
/// on, with no manual setup required. `BlockedSitesScreen` is a separate,
/// optional list for *additional* items the user personally wants blocked.
/// Only lists categories the blocking mechanism (package/domain matching)
/// can actually enforce — no ad-blocking or content-classification exists
/// in this app, so those aren't listed here even though they're common
/// gambling-blocker marketing claims.
class ProtectionChecklistCard extends StatelessWidget {
  const ProtectionChecklistCard({super.key});

  static const _items = [
    'Gambling Websites',
    'Gambling Applications',
    'Sports Betting',
    'Online Casinos',
    'Poker Platforms',
    'Lottery Websites',
    'Crypto Gambling',
    'Mirror Websites',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What Will Be Protected',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              'Automatically blocked once Protection Lock is on — no need '
              'to add these yourself. Want to block something extra, like '
              'a specific app or site? Use Blocked Sites & Apps.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _items.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
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
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDDEEE7),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.check,
                        size: 13,
                        color: Color(0xFF2E7D6B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _items[i],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
