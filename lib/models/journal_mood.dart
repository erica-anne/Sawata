import 'package:flutter/material.dart';

/// A named mood option with its own icon and color pairing, used both when
/// composing an entry and when rendering one in the journal list.
class JournalMood {
  const JournalMood({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
}

const journalMoods = <JournalMood>[
  JournalMood(
    label: 'Great',
    icon: Icons.sentiment_very_satisfied_rounded,
    background: Color(0xFFDDEEE7),
    foreground: Color(0xFF1F5C4D),
  ),
  JournalMood(
    label: 'Good',
    icon: Icons.sentiment_satisfied_rounded,
    background: Color(0xFFDDEEE7),
    foreground: Color(0xFF2E7D6B),
  ),
  JournalMood(
    label: 'Okay',
    icon: Icons.sentiment_neutral_rounded,
    background: Color(0xFFFCEFD2),
    foreground: Color(0xFFB07A1E),
  ),
  JournalMood(
    label: 'Stressed',
    icon: Icons.sentiment_dissatisfied_rounded,
    background: Color(0xFFFBE3D4),
    foreground: Color(0xFFC0682B),
  ),
];

JournalMood moodFor(String label) => journalMoods.firstWhere(
      (m) => m.label == label,
      orElse: () => journalMoods[1],
    );
