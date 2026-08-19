import '../models/blocked_item.dart';
import '../models/guardian_contact.dart';
import '../models/journal_entry.dart';
import '../models/stat_snapshot.dart';
import '../models/user_profile.dart';
import 'seed_data.dart';

/// Single in-memory store for the whole app session.
///
/// Nothing here is persisted: on a cold restart everything reseeds from
/// [SeedData]. Screens read [AppStore.instance] directly and call local
/// setState after mutating it.
class AppStore {
  AppStore._internal() {
    protectedSince = DateTime.now().subtract(Duration(days: streakDays));
  }

  static final AppStore instance = AppStore._internal();

  int streakDays = 67;
  int moneySavedPesos = 12450;
  int blockedAttempts = 24;
  bool protectionActive = true;
  DateTime? protectedSince;

  /// Lifetime count of distinct gambling sites/apps ever blocked. Unlike
  /// [blockedAttempts] (a per-period tally), this is a running total and
  /// doesn't reset when the analytics period selector changes.
  int sitesBlockedCount = 127;
  double sitesBlockedTrendPct = 24;

  final List<BlockedItem> blockedItems = SeedData.blockedItems();
  final List<BlockAttempt> recentAttempts = SeedData.recentAttempts();

  final List<JournalEntry> journalEntries = SeedData.journalEntries();

  GuardianContact guardian = SeedData.guardian();
  final List<GuardianMessage> messageLog = SeedData.messageLog();

  UserProfile profile = SeedData.profile();
  bool notificationsEnabled = true;
  bool darkThemePlaceholder = false;

  final List<AnalyticsDataset> analyticsDatasets = SeedData.analyticsDatasets();

  /// Pending guardian-invite count, mirrored to the Guardian bottom nav
  /// badge. The Guardian Invites screen owns the detailed list; this is
  /// just the count other Guardian screens need for their badge.
  int pendingGuardianInvites = 0;

  /// The invitation the current user has sent to their guardian, if any —
  /// set by the Add Guardian wizard, read by the Guardian-side Invites
  /// screen so it shows up in that guardian's pending list.
  PendingGuardianInvite? myGuardianInvite;

  /// Flips true once the guardian confirms [myGuardianInvite]. The Add
  /// Guardian wizard's "Check Status" step reads this instead of always
  /// reporting success.
  bool myGuardianInviteAccepted = false;

  void addJournalEntry(JournalEntry entry) {
    journalEntries.insert(0, entry);
  }

  void removeJournalEntry(String id) {
    journalEntries.removeWhere((e) => e.id == id);
  }

  void toggleBlockedItem(String id) {
    final item = blockedItems.firstWhere((e) => e.id == id);
    item.isBlocked = !item.isBlocked;
  }

  void addBlockedItem({
    required String name,
    required String category,
    String? packageName,
  }) {
    blockedItems.insert(
      0,
      BlockedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        category: category,
        icon: iconForBlockedCategory(category),
        isBlocked: true,
        isCustom: true,
        packageName: packageName,
      ),
    );
    sitesBlockedCount += 1;
  }

  void updateBlockedItem(
    String id, {
    required String name,
    required String category,
    String? packageName,
  }) {
    final item = blockedItems.firstWhere((e) => e.id == id);
    item.name = name;
    item.category = category;
    item.icon = iconForBlockedCategory(category);
    item.packageName = packageName;
  }

  void removeBlockedItem(String id) {
    blockedItems.removeWhere((e) => e.id == id);
  }

  void simulateBlockAttempt(String itemName) {
    blockedAttempts += 1;
    recentAttempts.insert(0, BlockAttempt(itemName: itemName, time: DateTime.now()));
  }

  void logGuardianNotification(String text) {
    messageLog.insert(0, GuardianMessage(text: text, time: DateTime.now(), fromUser: true));
  }
}
