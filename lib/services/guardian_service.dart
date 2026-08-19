import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/guardian_relationship.dart';

export '../models/guardian_relationship.dart' show SentGuardianInvite;

/// Firestore-backed access to a user's connected guardian(s).
///
/// Schema:
/// - `users/{protegeUid}/guardians/{guardianUid}` — one doc per accepted
///   guardian relationship, written by [acceptInvite] when a guardian
///   confirms an invite. Fields: name, relationship, email, phone,
///   connectedAt (server timestamp), status, permissions (map).
/// - `invites` — existing collection of sent invites (see
///   `add_guardian_screen.dart`); queried here only to detect a
///   still-pending invite so the contact screen can show a "pending" state
///   instead of a plain empty state.
class GuardianService {
  GuardianService._();

  static final _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _guardiansRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('guardians');

  /// Streams all guardians connected to [protegeUid], most recently
  /// connected first. Empty list means no accepted guardian yet.
  static Stream<List<GuardianRelationship>> streamGuardians(String protegeUid) {
    return _guardiansRef(protegeUid)
        .orderBy('connectedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(GuardianRelationship.fromDoc).toList(),
        );
  }

  /// One-shot fetch of [protegeUid]'s guardians. Used by non-UI call sites
  /// (e.g. security-alert emails in `protection_screen.dart`) that need the
  /// current list without holding a live stream subscription open — this
  /// is the single source of truth for "who is this user's guardian",
  /// replacing the old in-memory `AppStore.guardian`.
  static Future<List<GuardianRelationship>> fetchGuardians(
    String protegeUid,
  ) async {
    final snapshot = await _guardiansRef(
      protegeUid,
    ).orderBy('connectedAt', descending: true).get();
    return snapshot.docs.map(GuardianRelationship.fromDoc).toList();
  }

  /// Whether [uid] currently has a pending (not yet accepted/rejected)
  /// invite awaiting a guardian's response.
  static Future<bool> hasPendingInvite(String uid) async {
    final snapshot = await _firestore
        .collection('invites')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Streams every invite [uid] has ever sent, newest first — every status
  /// included. The "My Guardians" screen filters this client-side instead
  /// of querying per-status. Sorting happens client-side too (rather than
  /// an `orderBy` on the query) so this doesn't need a composite index —
  /// just the existing single-field index on `fromUid`.
  static Stream<List<SentGuardianInvite>> streamSentInvites(String uid) {
    return _firestore
        .collection('invites')
        .where('fromUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final invites = snapshot.docs.map(SentGuardianInvite.fromDoc).toList();
          invites.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return invites;
        });
  }

  /// Persists an accepted guardian relationship so it survives restarts
  /// and is visible from the protege's own Guardian Contact screen.
  ///
  /// Called from the guardian side once they confirm an invite. [inviteId]
  /// must be the Firestore doc ID of the real `invites/{inviteId}` document
  /// that this guardian is accepting — the security rules for
  /// `users/{protegeUid}/guardians/{guardianUid}` require it to be present
  /// and to reference an invite actually sent by [protegeUid] to this
  /// guardian's own signed-in email, so an arbitrary authenticated user
  /// can't write themselves in as someone else's guardian.
  static Future<void> acceptInvite({
    required String protegeUid,
    required String guardianUid,
    required String guardianName,
    required String guardianEmail,
    required String relationship,
    required String inviteId,
    String phone = '',
    GuardianPermissions permissions = const GuardianPermissions(),
  }) {
    return _guardiansRef(protegeUid).doc(guardianUid).set({
      'name': guardianName,
      'relationship': relationship,
      'email': guardianEmail,
      'phone': phone,
      'status': 'active',
      'connectedAt': FieldValue.serverTimestamp(),
      'permissions': permissions.toMap(),
      'inviteId': inviteId,
    }, SetOptions(merge: true));
  }
}
