class JournalEntry {
  JournalEntry({
    required this.id,
    required this.date,
    required this.mood,
    required this.title,
    required this.body,
  });

  final String id;
  final DateTime date;
  final String mood;
  final String title;
  final String body;
}
