import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/models/journal_entry.dart';
import 'package:sawata/models/journal_mood.dart';
import 'package:sawata/services/user_data_service.dart';
import 'package:sawata/widgets/empty_state.dart';
import 'package:sawata/widgets/snackbar_helper.dart';
import '../dashboard/widgets/dashboard_header.dart';
import 'widgets/add_journal_sheet.dart';
import 'widgets/journal_entry_card.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const _accent = Color(0xFF2E7D6B);
  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _monthShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  Future<void> _addEntry() async {
    final uid = _uid;
    if (uid == null) return;
    final draft = await showAddJournalSheet(context);
    if (draft == null) return;
    await UserDataService.addJournalEntry(
      uid,
      mood: draft.mood,
      title: draft.title,
      body: draft.body,
    );
    if (!mounted) return;
    showAppSnackBar(context, 'Entry saved');
  }

  Future<void> _deleteEntry(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await UserDataService.removeJournalEntry(uid, id);
    if (!mounted) return;
    showAppSnackBar(context, 'Entry deleted', isSuccess: false);
  }

  Future<void> _editEntry(JournalEntry entry) async {
    final uid = _uid;
    if (uid == null) return;
    final draft = await showAddJournalSheet(context, existing: entry);
    if (draft == null) return;
    await UserDataService.updateJournalEntry(
      uid,
      entry.id,
      mood: draft.mood,
      title: draft.title,
      body: draft.body,
    );
    if (!mounted) return;
    showAppSnackBar(context, 'Entry updated');
  }

  void _openDetail(JournalEntry entry) {
    final mood = moodFor(entry.mood);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: mood.background,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(mood.icon, size: 18, color: mood.foreground),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(entry.title.isEmpty ? 'Journal Entry' : entry.title),
            ),
          ],
        ),
        content: SingleChildScrollView(child: Text(entry.body)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _editEntry(entry);
            },
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return _weekdayNames[date.weekday - 1];
    return '${_monthShort[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return StreamBuilder<List<JournalEntry>>(
      stream: uid == null ? null : UserDataService.watchJournalEntries(uid),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <JournalEntry>[];
        return _buildBody(context, entries);
      },
    );
  }

  Widget _buildBody(BuildContext context, List<JournalEntry> entries) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final filteredEntries = _query.isEmpty
        ? entries
        : entries
              .where(
                (e) =>
                    e.title.toLowerCase().contains(_query) ||
                    e.body.toLowerCase().contains(_query),
              )
              .toList();

    final todayEntries = <JournalEntry>[];
    final thisWeekEntries = <JournalEntry>[];
    final earlierEntries = <JournalEntry>[];
    for (final entry in filteredEntries) {
      final that = DateTime(entry.date.year, entry.date.month, entry.date.day);
      final diff = today.difference(that).inDays;
      if (diff <= 0) {
        todayEntries.add(entry);
      } else if (diff < 7) {
        thisWeekEntries.add(entry);
      } else {
        earlierEntries.add(entry);
      }
    }

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget entryCard(JournalEntry entry) => JournalEntryCard(
      entry: entry,
      dayLabel: _dayLabel(entry.date),
      onTap: () => _openDetail(entry),
      onDelete: () => _deleteEntry(entry.id),
    );

    return Scaffold(
      body: SafeArea(
        child: entries.isEmpty
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: DashboardHeader(
                      onBellTap: () =>
                          showAppSnackBar(context, "You're all caught up!"),
                      onSettingsTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.settings),
                    ),
                  ),
                  Expanded(
                    child: EmptyState(
                      icon: Icons.book_outlined,
                      message:
                          'No journal entries yet. Tap New Entry to write your first one.',
                      ctaLabel: 'Write an entry',
                      onCta: _addEntry,
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  DashboardHeader(
                    onBellTap: () =>
                        showAppSnackBar(context, "You're all caught up!"),
                    onSettingsTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.settings),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Journal',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'A private space for your thoughts, feelings, and progress.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _addEntry,
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text('New Entry'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _JournalSearchField(
                    controller: _searchController,
                    onClear: () => _searchController.clear(),
                  ),
                  const SizedBox(height: 20),
                  if (filteredEntries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No entries match "${_searchController.text.trim()}".',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else ...[
                    for (final entry in todayEntries) entryCard(entry),
                    if (thisWeekEntries.isNotEmpty) ...[
                      sectionLabel('This Week'),
                      for (final entry in thisWeekEntries) entryCard(entry),
                    ],
                    if (earlierEntries.isNotEmpty) ...[
                      sectionLabel('Earlier'),
                      for (final entry in earlierEntries) entryCard(entry),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

/// Compact rounded search box for filtering journal entries by title/body,
/// styled to match the app's list-screen surface/outlineVariant containers.
class _JournalSearchField extends StatelessWidget {
  const _JournalSearchField({required this.controller, required this.onClear});

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintText: 'Search your entries',
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClear,
                  ),
          ),
        ),
      ),
    );
  }
}
