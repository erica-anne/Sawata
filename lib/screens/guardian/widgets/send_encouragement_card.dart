import 'package:flutter/material.dart';

/// Quick-reply encouragement panel. Tapping a chip or "View All Messages"
/// is presentational only for now — no message is actually sent.
class SendEncouragementCard extends StatelessWidget {
  const SendEncouragementCard({super.key, required this.onViewAll});

  final VoidCallback onViewAll;

  static const _accent = Color(0xFF2E7D6B);
  static const _deepTeal = Color(0xFF16332B);
  static const _mintBg = Color(0xFFDDEEE7);

  static const _chips = [
    'Good job! Keep going! 💚',
    'You are doing great! 🎉',
    'Proud of you! Stay strong! 💪',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _mintBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.favorite, size: 16, color: _accent),
                    SizedBox(width: 6),
                    Text(
                      'SEND ENCOURAGEMENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _accent,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'A few words can make a big difference.',
                  style: TextStyle(fontSize: 12, color: _deepTeal),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in _chips)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          chip,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _deepTeal,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onViewAll,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 42),
                    side: const BorderSide(color: _accent),
                    foregroundColor: _accent,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View All Messages',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _EncouragementBadge(),
        ],
      ),
    );
  }
}

class _EncouragementBadge extends StatelessWidget {
  const _EncouragementBadge();

  static const _accent = Color(0xFF2E7D6B);
  static const _deepTeal = Color(0xFF16332B);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: _avatar('M', const Color(0xFF6FBFA0)),
          ),
          Positioned(right: 0, bottom: 0, child: _avatar('J', _deepTeal)),
          Positioned(
            top: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.favorite, size: 15, color: _accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String initial, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}
