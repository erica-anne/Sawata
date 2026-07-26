import 'package:flutter/material.dart';

/// Mint insight banner at the bottom of the Reports screen.
class ReportInsightCard extends StatelessWidget {
  const ReportInsightCard({super.key, required this.message});

  final String message;

  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);
  static const _mintBg = Color(0xFFDDEEE7);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _mintBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.trending_up_rounded,
              size: 16,
              color: _accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: _deepTeal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
