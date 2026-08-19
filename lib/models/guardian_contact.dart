class GuardianContact {
  GuardianContact({
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
  });

  final String name;
  final String relationship;
  final String phone;
  final String email;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// An invitation the user has sent to become their guardian, tracked in
/// `AppStore` so the Guardian-side Invites screen can show it and the Add
/// Guardian wizard's "Check Status" step can reflect a real acceptance.
class PendingGuardianInvite {
  PendingGuardianInvite({
    required this.name,
    required this.email,
    required this.phone,
    required this.relationship,
    required this.sentAt,
    this.fromUid,
  });

  final String name;
  final String email;
  final String phone;
  final String relationship;
  final DateTime sentAt;

  /// The sending user's Firebase Auth UID, when they're actually signed in
  /// (currently only true via Google Sign-In). Lets the Guardian side link
  /// the real Firestore `users/{uid}` documents together on accept.
  final String? fromUid;
}

class GuardianMessage {
  GuardianMessage({
    required this.text,
    required this.time,
    required this.fromUser,
  });

  final String text;
  final DateTime time;
  final bool fromUser;
}
