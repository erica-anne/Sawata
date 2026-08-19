import 'package:cloud_firestore/cloud_firestore.dart';

/// Which alerts/data a connected guardian is allowed to receive/view.
///
/// NOTE: there is currently no settings UI for the user to toggle these —
/// they are written with sensible defaults (all enabled) when a guardian
/// relationship is created in [GuardianService.acceptInvite], and read back
/// here so the Guardian Permissions card reflects real Firestore data
/// instead of hardcoded checkmarks. Wire up a settings screen that writes
/// to `users/{uid}/guardians/{guardianUid}.permissions` to make these
/// user-configurable.
class GuardianPermissions {
  const GuardianPermissions({
    this.uninstallAlerts = true,
    this.blockedAlerts = true,
    this.viewStreak = true,
    this.viewReports = true,
    this.sendEncouragement = true,
  });

  final bool uninstallAlerts;
  final bool blockedAlerts;
  final bool viewStreak;
  final bool viewReports;
  final bool sendEncouragement;

  factory GuardianPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const GuardianPermissions();
    return GuardianPermissions(
      uninstallAlerts: map['uninstallAlerts'] as bool? ?? true,
      blockedAlerts: map['blockedAlerts'] as bool? ?? true,
      viewStreak: map['viewStreak'] as bool? ?? true,
      viewReports: map['viewReports'] as bool? ?? true,
      sendEncouragement: map['sendEncouragement'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'uninstallAlerts': uninstallAlerts,
    'blockedAlerts': blockedAlerts,
    'viewStreak': viewStreak,
    'viewReports': viewReports,
    'sendEncouragement': sendEncouragement,
  };
}

/// A real, persisted guardian relationship read from
/// `users/{protegeUid}/guardians/{guardianUid}` in Firestore.
///
/// Created when a guardian accepts an invite (see
/// `GuardianInvitesScreen._confirm`), so it survives app restarts and is
/// visible to the current authenticated user regardless of in-memory state.
class GuardianRelationship {
  GuardianRelationship({
    required this.guardianUid,
    required this.name,
    required this.relationship,
    required this.email,
    required this.phone,
    required this.connectedAt,
    required this.status,
    required this.permissions,
  });

  final String guardianUid;
  final String name;
  final String relationship;
  final String email;
  final String phone;
  final DateTime connectedAt;

  /// 'active' — currently the only status this app writes, but modeled as
  /// a string so a future "paused"/"removed" state can be added without a
  /// schema change.
  final String status;
  final GuardianPermissions permissions;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  bool get isActive => status == 'active';

  factory GuardianRelationship.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final connectedAtRaw = data['connectedAt'];
    return GuardianRelationship(
      guardianUid: doc.id,
      name: data['name'] as String? ?? 'Guardian',
      relationship: data['relationship'] as String? ?? '—',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      connectedAt: connectedAtRaw is Timestamp
          ? connectedAtRaw.toDate()
          : DateTime.now(),
      status: data['status'] as String? ?? 'active',
      permissions: GuardianPermissions.fromMap(
        data['permissions'] as Map<String, dynamic>?,
      ),
    );
  }
}

/// A single `invites/{id}` document sent by the current user, as read back
/// on the "My Guardians" screen. Covers every stage of an invite's life —
/// 'pending', 'accepted', 'declined', 'cancelled', 'expired' — so that
/// screen can group and filter by status without a separate query per
/// state.
class SentGuardianInvite {
  SentGuardianInvite({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.relationship,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String relationship;
  final String status;
  final DateTime createdAt;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory SentGuardianInvite.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAtRaw = data['createdAt'];
    return SentGuardianInvite(
      id: doc.id,
      name: data['toName'] as String? ?? 'Guardian',
      email: data['toEmail'] as String? ?? '',
      phone: data['toPhone'] as String? ?? '',
      relationship: data['relationship'] as String? ?? '—',
      status: data['status'] as String? ?? 'pending',
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : DateTime.now(),
    );
  }
}
