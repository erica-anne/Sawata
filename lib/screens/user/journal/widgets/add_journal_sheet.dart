import 'package:flutter/material.dart';

import 'package:sawata/models/journal_entry.dart';
import 'package:sawata/models/journal_mood.dart';
import 'package:sawata/widgets/app_primary_button.dart';

Future<JournalEntry?> showAddJournalSheet(BuildContext context) {
  return showModalBottomSheet<JournalEntry>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _AddJournalSheetContent(),
  );
}

class _AddJournalSheetContent extends StatefulWidget {
  const _AddJournalSheetContent();

  @override
  State<_AddJournalSheetContent> createState() =>
      _AddJournalSheetContentState();
}

class _AddJournalSheetContentState extends State<_AddJournalSheetContent> {
  String _mood = journalMoods[1].label;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in a title and a note.');
      return;
    }
    final entry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      mood: _mood,
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New Journal Entry',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: journalMoods
                .map(
                  (mood) => ChoiceChip(
                    avatar: Icon(mood.icon, size: 18, color: mood.foreground),
                    label: Text(mood.label),
                    selected: _mood == mood.label,
                    onSelected: (_) => setState(() => _mood = mood.label),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'What is on your mind?',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          AppPrimaryButton(label: 'Save Entry', onPressed: _save),
        ],
      ),
    );
  }
}
