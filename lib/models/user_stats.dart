import 'package:cloud_firestore/cloud_firestore.dart';

/// Live, per-user recovery stats — backed by the `users/{uid}` Firestore
/// document. Replaces the scalar fields that used to live on
/// `AppStore` (streakDays, moneySavedPesos, blockedAttempts,
/// protectionActive, protectedSince).
///
/// NOTE: weekly/period breakdowns for charts (see
/// `AnalyticsDataset`/`WeeklyStat` in lib/models/stat_snapshot.dart) are
/// NOT covered by this model yet — that needs a rollup aggregation and is
/// still sourced from `AppStore.analyticsDatasets` (seeded/simulated).
class UserStats {
  const UserStats({
    required this.streakDays,
    required this.moneySavedPesos,
    required this.blockedAttempts,
    required this.protectionActive,
    required this.protectedSince,
  });

  final int streakDays;
  final int moneySavedPesos;
  final int blockedAttempts;
  final bool protectionActive;
  final DateTime? protectedSince;

  /// Defaults written for a brand-new user document.
  factory UserStats.initial() => const UserStats(
    streakDays: 0,
    moneySavedPesos: 0,
    blockedAttempts: 0,
    protectionActive: false,
    protectedSince: null,
  );

  factory UserStats.fromMap(Map<String, dynamic> data) {
    return UserStats(
      streakDays: (data['streakDays'] as num?)?.toInt() ?? 0,
      moneySavedPesos: (data['moneySavedPesos'] as num?)?.toInt() ?? 0,
      blockedAttempts: (data['blockedAttempts'] as num?)?.toInt() ?? 0,
      protectionActive: data['protectionActive'] as bool? ?? false,
      protectedSince: (data['protectedSince'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'streakDays': streakDays,
      'moneySavedPesos': moneySavedPesos,
      'blockedAttempts': blockedAttempts,
      'protectionActive': protectionActive,
      'protectedSince': protectedSince == null
          ? null
          : Timestamp.fromDate(protectedSince!),
    };
  }
}
