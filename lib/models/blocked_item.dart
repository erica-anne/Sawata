import 'package:flutter/material.dart';

class BlockedItem {
  BlockedItem({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.isBlocked,
    this.isCustom = false,
  });

  final String id;
  String name;
  String category;
  IconData icon;
  bool isBlocked;

  /// True for sites/apps the user added themselves, as opposed to the
  /// curated default list Sawatâ ships with. Only custom items can be
  /// edited or removed — the default list can only be toggled.
  final bool isCustom;
}

/// Fixed set of categories a user can file a custom blocked site/app under,
/// each with a matching icon so entries don't need a separate icon picker.
const blockedItemCategories = <String>[
  'Online Casino',
  'Sports Betting',
  'Poker',
  'Slots',
  'App',
  'Website',
];

IconData iconForBlockedCategory(String category) {
  switch (category) {
    case 'Online Casino':
      return Icons.casino_outlined;
    case 'Sports Betting':
      return Icons.sports_soccer_outlined;
    case 'Poker':
      return Icons.style_outlined;
    case 'Slots':
      return Icons.diamond_outlined;
    case 'App':
      return Icons.phone_android_outlined;
    case 'Website':
      return Icons.language_outlined;
    default:
      return Icons.block_outlined;
  }
}

class BlockAttempt {
  BlockAttempt({
    required this.itemName,
    required this.time,
    this.category = 'Website',
    this.icon = Icons.language_outlined,
  });

  final String itemName;
  final DateTime time;

  /// e.g. "Website" or "App" — shown alongside the timestamp.
  final String category;
  final IconData icon;
}
