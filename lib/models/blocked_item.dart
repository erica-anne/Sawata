import 'package:flutter/material.dart';

class BlockedItem {
  BlockedItem({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.isBlocked,
    this.isCustom = false,
    this.packageName,
  });

  final String id;
  String name;
  String category;
  IconData icon;
  bool isBlocked;

  /// True for sites/apps the user added themselves, as opposed to the
  /// curated default list Sawatâ used to ship with (that seeded list is
  /// retired — see UserDataService.ensureInitialized — so every item a user
  /// can currently have is custom).
  final bool isCustom;

  /// The real Android package name (e.g. `com.example.betapp`), required for
  /// `category == 'App'` entries. Read directly from this user's own
  /// `blocked_items` doc by the Accessibility Service (unioned with
  /// Sawatâ's global default blocklist in `blocked_packages`) to match
  /// against. Null for website entries, which aren't package-blockable.
  String? packageName;
}

/// [iconForBlockedCategory] still handles the old granular categories
/// ('Online Casino', 'Sports Betting', 'Poker', 'Slots') so any item added
/// before the Blocked Sites & Apps redesign still renders a sensible icon —
/// new adds only ever use 'App' or 'Website' (see AddBlockedItemSheet),
/// which is why there's no longer a matching category picker/constant list
/// in the UI.
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
