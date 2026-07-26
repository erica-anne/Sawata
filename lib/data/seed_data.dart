import 'package:flutter/material.dart';

import '../models/blocked_item.dart';
import '../models/guardian_contact.dart';
import '../models/journal_entry.dart';
import '../models/stat_snapshot.dart';
import '../models/user_profile.dart';

class SeedData {
  SeedData._();

  static List<BlockedItem> blockedItems() => [
        BlockedItem(
          id: 'b1',
          name: 'LuckySpin Casino',
          category: 'Online Casino',
          icon: Icons.casino_outlined,
          isBlocked: true,
        ),
        BlockedItem(
          id: 'b2',
          name: 'BetPro Sportsbook',
          category: 'Sports Betting',
          icon: Icons.sports_soccer_outlined,
          isBlocked: true,
        ),
        BlockedItem(
          id: 'b3',
          name: 'GoldenPoker App',
          category: 'Poker',
          icon: Icons.style_outlined,
          isBlocked: true,
        ),
        BlockedItem(
          id: 'b4',
          name: 'JackpotHub.com',
          category: 'Online Casino',
          icon: Icons.language_outlined,
          isBlocked: true,
        ),
        BlockedItem(
          id: 'b5',
          name: 'QuickBet Mobile',
          category: 'Sports Betting',
          icon: Icons.phone_android_outlined,
          isBlocked: false,
        ),
        BlockedItem(
          id: 'b6',
          name: 'RoyalFlush Slots',
          category: 'Slots',
          icon: Icons.diamond_outlined,
          isBlocked: true,
        ),
      ];

  static List<JournalEntry> journalEntries() => [
        JournalEntry(
          id: 'j1',
          date: DateTime.now().copyWith(hour: 9, minute: 30),
          mood: 'Good',
          title: 'Walked away from it',
          body:
              'I felt the urge again today after seeing an ad during the game, but I chose to walk outside instead. '
              "I'm proud of myself.",
        ),
        JournalEntry(
          id: 'j2',
          date: DateTime.now().subtract(const Duration(days: 1)).copyWith(hour: 20, minute: 15),
          mood: 'Stressed',
          title: 'Tough day',
          body: "It was a tough day. Work stress got the best of me, but I didn't act on it.",
        ),
        JournalEntry(
          id: 'j3',
          date: DateTime.now().subtract(const Duration(days: 4)).copyWith(hour: 19, minute: 45),
          mood: 'Good',
          title: 'Great support call',
          body: 'Had a great conversation with my guardian. It really helped to talk things through.',
        ),
        JournalEntry(
          id: 'j4',
          date: DateTime.now().subtract(const Duration(days: 9)).copyWith(hour: 21, minute: 10),
          mood: 'Okay',
          title: 'A bit tempted',
          body: 'Saw an ad for a betting site and felt the old pull for a minute. Went for a walk and it passed.',
        ),
        JournalEntry(
          id: 'j5',
          date: DateTime.now().subtract(const Duration(days: 14)).copyWith(hour: 18, minute: 30),
          mood: 'Good',
          title: 'Productive day',
          body: 'Productive day. I finished my checklist and stayed focused the whole time!',
        ),
        JournalEntry(
          id: 'j6',
          date: DateTime.now().subtract(const Duration(days: 20)).copyWith(hour: 20, minute: 0),
          mood: 'Great',
          title: 'One month milestone',
          body: 'Cannot believe it has been this long. Savings are adding up and I actually feel in control again.',
        ),
      ];

  static GuardianContact guardian() => GuardianContact(
        name: 'Maria Santos',
        relationship: 'Sister',
        phone: '+63 912 345 6789',
        email: 'maria.santos@example.com',
      );

  static List<BlockAttempt> recentAttempts() => [
        BlockAttempt(
          itemName: 'stake.com',
          category: 'Website',
          icon: Icons.language_outlined,
          time: DateTime.now().copyWith(hour: 14, minute: 15),
        ),
        BlockAttempt(
          itemName: 'LuckyBet — Casino & Slots',
          category: 'App',
          icon: Icons.phone_android_outlined,
          time: DateTime.now().copyWith(hour: 11, minute: 24),
        ),
        BlockAttempt(
          itemName: '1xbet.com',
          category: 'Website',
          icon: Icons.language_outlined,
          time: DateTime.now().subtract(const Duration(days: 1)).copyWith(hour: 21, minute: 45),
        ),
      ];

  static List<GuardianMessage> messageLog() => [
        GuardianMessage(
          text: 'Weekly check-in sent to Maria.',
          time: DateTime.now().subtract(const Duration(days: 3)),
          fromUser: true,
        ),
        GuardianMessage(
          text: "Maria: Proud of you, keep it up!",
          time: DateTime.now().subtract(const Duration(days: 3, hours: -1)),
          fromUser: false,
        ),
        GuardianMessage(
          text: 'Notified Maria after a blocked attempt.',
          time: DateTime.now().subtract(const Duration(days: 7)),
          fromUser: true,
        ),
      ];

  static UserProfile profile() => UserProfile(
        name: 'Juan Dela Cruz',
        email: 'juan.delacruz@example.com',
      );

  static List<AnalyticsDataset> analyticsDatasets() => [
        AnalyticsDataset(
          label: 'Week',
          periodLabel: 'This Week',
          moneySavedTrendPct: 28,
          attemptsTrendPct: -16,
          savings: const [
            WeeklyStat(label: 'Mon', value: 200),
            WeeklyStat(label: 'Tue', value: 150),
            WeeklyStat(label: 'Wed', value: 300),
            WeeklyStat(label: 'Thu', value: 100),
            WeeklyStat(label: 'Fri', value: 400),
            WeeklyStat(label: 'Sat', value: 250),
            WeeklyStat(label: 'Sun', value: 350),
          ],
          attempts: const [
            WeeklyStat(label: 'Mon', value: 1),
            WeeklyStat(label: 'Tue', value: 0),
            WeeklyStat(label: 'Wed', value: 2),
            WeeklyStat(label: 'Thu', value: 0),
            WeeklyStat(label: 'Fri', value: 1),
            WeeklyStat(label: 'Sat', value: 0),
            WeeklyStat(label: 'Sun', value: 1),
          ],
          longestStreakDays: 89,
        ),
        AnalyticsDataset(
          label: 'Month',
          periodLabel: 'This Month',
          moneySavedTrendPct: 15,
          attemptsTrendPct: -8,
          savings: const [
            WeeklyStat(label: 'W1', value: 1500),
            WeeklyStat(label: 'W2', value: 2000),
            WeeklyStat(label: 'W3', value: 1800),
            WeeklyStat(label: 'W4', value: 2450),
          ],
          attempts: const [
            WeeklyStat(label: 'W1', value: 5),
            WeeklyStat(label: 'W2', value: 3),
            WeeklyStat(label: 'W3', value: 8),
            WeeklyStat(label: 'W4', value: 2),
          ],
          longestStreakDays: 89,
        ),
        AnalyticsDataset(
          label: 'Year',
          periodLabel: 'This Year',
          moneySavedTrendPct: 42,
          attemptsTrendPct: -22,
          savings: const [
            WeeklyStat(label: 'Jan', value: 4000),
            WeeklyStat(label: 'Feb', value: 5200),
            WeeklyStat(label: 'Mar', value: 3000),
            WeeklyStat(label: 'Apr', value: 6100),
            WeeklyStat(label: 'May', value: 7000),
            WeeklyStat(label: 'Jun', value: 6450),
          ],
          attempts: const [
            WeeklyStat(label: 'Jan', value: 12),
            WeeklyStat(label: 'Feb', value: 9),
            WeeklyStat(label: 'Mar', value: 15),
            WeeklyStat(label: 'Apr', value: 6),
            WeeklyStat(label: 'May', value: 4),
            WeeklyStat(label: 'Jun', value: 3),
          ],
          longestStreakDays: 89,
        ),
      ];
}
