import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show Icons;

import '../models/app_suggestion.dart';
import '../models/blocked_item.dart';
import '../models/journal_entry.dart';
import '../models/user_stats.dart';

/// Firestore-backed replacement for the scalar stats + blocked-items list
/// that used to live on `AppStore` (see lib/data/dummy_data_store.dart).
///
/// Schema:
/// - `users/{uid}` — see [UserStats] for fields.
/// - `users/{uid}/blocked_items/{itemId}` — per-user blocked sites/apps
///   (`name`, `category`, `isBlocked`, `isCustom`, `packageName`). Icons are
///   derived client-side from `category` via [iconForBlockedCategory],
///   never stored.
///
/// This is a proof-of-concept migration covering the User Dashboard and
/// Protection screens only — journal, guardian relationship, and analytics
/// history are still on `AppStore` pending a follow-up migration.
class UserDataService {
  UserDataService._();

  static final _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  static CollectionReference<Map<String, dynamic>> _blockedItemsCollection(
    String uid,
  ) => _userDoc(uid).collection('blocked_items');

  static CollectionReference<Map<String, dynamic>> _suggestionsCollection(
    String uid,
  ) => _userDoc(uid).collection('suggestions');

  static CollectionReference<Map<String, dynamic>> _journalCollection(
    String uid,
  ) => _userDoc(uid).collection('journal_entries');

  /// Ensures `users/{uid}` has stat fields. Safe to call on every login —
  /// uses `merge: true` so it never clobbers an existing user's progress.
  /// Blocked items start empty; the user (or a gambling-keyword suggestion)
  /// populates the list from here.
  static Future<void> ensureInitialized(String uid) async {
    final doc = await _userDoc(uid).get();
    if (!doc.exists || doc.data()?['streakDays'] == null) {
      await _userDoc(uid).set(UserStats.initial().toMap(), SetOptions(merge: true));
    }
    await _removeLegacySeededBlockedItems(uid);
  }

  /// One-time cleanup for accounts created before the fake starter list
  /// (`SeedData.blockedItems()`, e.g. "LuckySpin Casino") was removed from
  /// this flow — those docs were written with `isCustom: false`, which the
  /// UI treats as an undeletable default, so a user who signed up earlier
  /// can never clear them on their own. Real items (manual adds, accepted
  /// suggestions) are always written with `isCustom: true` and are never
  /// touched here. Safe/cheap to call on every login: a no-op once cleaned.
  static Future<void> _removeLegacySeededBlockedItems(String uid) async {
    final snapshot = await _blockedItemsCollection(uid).get();
    final legacy = snapshot.docs.where(
      (doc) => doc.data()['isCustom'] != true,
    );
    if (legacy.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in legacy) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  static Stream<UserStats> watchStats(String uid) {
    return _userDoc(uid).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? UserStats.initial() : UserStats.fromMap(data);
    });
  }

  static Stream<List<BlockedItem>> watchBlockedItems(String uid) {
    return _blockedItemsCollection(uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => BlockedItem(
              id: doc.id,
              name: doc.data()['name'] as String? ?? '',
              category: doc.data()['category'] as String? ?? 'Website',
              icon: iconForBlockedCategory(
                doc.data()['category'] as String? ?? 'Website',
              ),
              isBlocked: doc.data()['isBlocked'] as bool? ?? true,
              isCustom: doc.data()['isCustom'] as bool? ?? false,
              packageName: doc.data()['packageName'] as String?,
            ),
          )
          .toList(),
    );
  }

  static Future<void> toggleBlockedItem(String uid, BlockedItem item) {
    return _blockedItemsCollection(
      uid,
    ).doc(item.id).update({'isBlocked': !item.isBlocked});
  }

  static Future<void> addBlockedItem(
    String uid, {
    required String name,
    required String category,
    String? packageName,
  }) {
    return _blockedItemsCollection(uid).add({
      'name': name,
      'category': category,
      'isBlocked': true,
      'isCustom': true,
      'packageName': packageName,
    });
  }

  static Future<void> updateBlockedItem(
    String uid,
    String itemId, {
    required String name,
    required String category,
    String? packageName,
  }) {
    return _blockedItemsCollection(uid).doc(itemId).update({
      'name': name,
      'category': category,
      'packageName': packageName,
    });
  }

  static Future<void> removeBlockedItem(String uid, String itemId) {
    return _blockedItemsCollection(uid).doc(itemId).delete();
  }

  /// True if this user already has an app entry for [packageName] — used to
  /// reject a duplicate add before it happens, rather than after.
  static Future<bool> hasBlockedPackage(String uid, String packageName) async {
    final snapshot = await _blockedItemsCollection(
      uid,
    ).where('packageName', isEqualTo: packageName).limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  /// True if this user already has a website entry for [domain] (already
  /// normalized — see lib/utils/domain_utils.dart — since that's exactly
  /// what's stored in `name` for `category == 'Website'` items).
  static Future<bool> hasBlockedDomain(String uid, String domain) async {
    final snapshot = await _blockedItemsCollection(uid)
        .where('category', isEqualTo: 'Website')
        .where('name', isEqualTo: domain)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// True if [packageName] is already covered by Sawatâ's global default
  /// blocklist (`blocked_packages`, admin-curated — see firestore.rules) —
  /// used to avoid creating a redundant personal `blocked_items` entry for
  /// something everyone already has blocked.
  static Future<bool> isGloballyBlockedPackage(String packageName) async {
    final doc = await _firestore
        .collection('blocked_packages')
        .doc(packageName)
        .get();
    return doc.exists;
  }

  /// Same as [isGloballyBlockedPackage], for the `blocked_domains` global
  /// default blocklist.
  static Future<bool> isGloballyBlockedDomain(String domain) async {
    final doc = await _firestore
        .collection('blocked_domains')
        .doc(domain)
        .get();
    return doc.exists;
  }

  /// Pending gambling-app suggestions written natively by
  /// `SawataAccessibilityService.maybeSuggestPackage()` — see
  /// `users/{uid}/suggestions/{packageName}`.
  static Stream<List<AppSuggestion>> watchSuggestions(String uid) {
    return _suggestionsCollection(uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AppSuggestion(
                  packageName: doc.id,
                  name: doc.data()['name'] as String? ?? doc.id,
                ),
              )
              .toList(),
        );
  }

  /// Resolves a suggestion once the matching item has been added to the
  /// blocked list — deletes the suggestion doc since membership in
  /// `blocked_packages` already prevents the native side from re-suggesting
  /// it (see `SawataAccessibilityService.onAccessibilityEvent`).
  static Future<void> acceptSuggestion(String uid, String packageName) {
    return _suggestionsCollection(uid).doc(packageName).delete();
  }

  /// Marks a suggestion as not-gambling — kept (not deleted) so the native
  /// side's `suggestedPackages` cache keeps excluding it, since it stays
  /// unblocked and would otherwise be re-suggested on its next foreground.
  static Future<void> dismissSuggestion(String uid, String packageName) {
    return _suggestionsCollection(
      uid,
    ).doc(packageName).update({'status': 'dismissed'});
  }

  static Future<void> setProtectionActive(String uid, bool active) {
    return _userDoc(uid).set({
      'protectionActive': active,
      if (active) 'protectedSince': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  /// Increments the lifetime blocked-attempts counter and logs the attempt
  /// to the top-level `blocked_attempts` collection (read by
  /// AnalyticsScreen's real attempts stream, see [watchBlockAttempts]).
  static Future<void> recordBlockAttempt(
    String uid, {
    required String appName,
  }) {
    final batch = _firestore.batch();
    batch.set(_userDoc(uid), {
      'blockedAttempts': FieldValue.increment(1),
    }, SetOptions(merge: true));
    batch.set(_firestore.collection('blocked_attempts').doc(), {
      'uid': uid,
      'appName': appName,
      'timestamp': FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }

  /// This user's real blocked-attempt history. Currently written only by
  /// `SawataAccessibilityService.logBlockedAttempt()` (native Kotlin) when a
  /// blocked app is foregrounded — the DNS-level website blocker
  /// (`UdpRelay.kt`) doesn't log attempts yet, so every entry here is an app
  /// block; hence the hardcoded 'App' category below. [recordBlockAttempt]
  /// exists for the same collection but nothing currently calls it. No
  /// `orderBy` on purpose — that would need a composite index just for a
  /// per-user list that's realistically small enough to sort client-side,
  /// so callers sort/bucket the result themselves (see AnalyticsScreen).
  static Stream<List<BlockAttempt>> watchBlockAttempts(String uid) {
    return _firestore
        .collection('blocked_attempts')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return BlockAttempt(
              itemName: data['appName'] as String? ?? 'Unknown',
              time:
                  (data['timestamp'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              category: 'App',
              icon: Icons.phone_android_outlined,
            );
          }).toList(),
        );
  }

  /// A private space for the user's own notes — never shared with a
  /// guardian. Ordered newest first.
  static Stream<List<JournalEntry>> watchJournalEntries(String uid) {
    return _journalCollection(uid).orderBy('date', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        final data = doc.data();
        return JournalEntry(
          id: doc.id,
          date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          mood: data['mood'] as String? ?? 'Good',
          title: data['title'] as String? ?? '',
          body: data['body'] as String? ?? '',
        );
      }).toList(),
    );
  }

  static Future<void> addJournalEntry(
    String uid, {
    required String mood,
    required String title,
    required String body,
  }) {
    return _journalCollection(uid).add({
      'date': Timestamp.now(),
      'mood': mood,
      'title': title,
      'body': body,
    });
  }

  static Future<void> updateJournalEntry(
    String uid,
    String entryId, {
    required String mood,
    required String title,
    required String body,
  }) {
    return _journalCollection(uid).doc(entryId).update({
      'mood': mood,
      'title': title,
      'body': body,
    });
  }

  static Future<void> removeJournalEntry(String uid, String entryId) {
    return _journalCollection(uid).doc(entryId).delete();
  }
}
