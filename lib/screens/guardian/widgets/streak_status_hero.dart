import 'package:flutter/material.dart';

/// Full-width dark hero card combining the linked user's recovery streak
/// with their live protection status, anchored by a lock ring in the middle.
class StreakStatusHero extends StatelessWidget {
  const StreakStatusHero({
    super.key,
    required this.streakDays,
    required this.startedOnLabel,
    required this.protectionActive,
    required this.sinceDateLabel,
    required this.sinceTimeLabel,
  });

  final int streakDays;
  final String startedOnLabel;
  final bool protectionActive;
  final String sinceDateLabel;
  final String sinceTimeLabel;

  static const _mint = Color(0xFFA9E3CB);
  static const _card = Color(0xFF123227);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RECOVERY STREAK',
                  style: TextStyle(
                    color: _mint,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$streakDays Days',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Locked in. Stronger every day.',
                  style: TextStyle(color: Color(0xFFBFD8CC), fontSize: 11.5),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 12, color: _mint),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Started on $startedOnLabel',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
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
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 5,
                    color: _mint,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.lock, color: Colors.white, size: 26),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'PROTECTION STATUS',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _mint,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _mint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        protectionActive ? Icons.lock : Icons.lock_open,
                        size: 13,
                        color: _card,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        protectionActive ? 'LOCKED' : 'UNLOCKED',
                        style: const TextStyle(
                          color: _card,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Since',
                  style: TextStyle(color: Color(0xFFBFD8CC), fontSize: 11),
                ),
                Text(
                  sinceDateLabel,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  sinceTimeLabel,
                  style: const TextStyle(
                    color: Color(0xFFBFD8CC),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
