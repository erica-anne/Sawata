import 'package:flutter/material.dart';

/// Static "what's covered" list. Deliberately has no per-item toggles —
/// these categories are always protected, unlike the specific named
/// sites/apps managed further down the Protection screen.
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
    'Betting Advertisements',
    'AI-Detected Gambling Content',
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
              'No toggles, no switches — everything below is protected automatically.',
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
