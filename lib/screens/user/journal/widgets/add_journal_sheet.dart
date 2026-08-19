import 'package:flutter/material.dart';

import 'package:sawata/models/journal_entry.dart';
import 'package:sawata/models/journal_mood.dart';
import 'package:sawata/widgets/snackbar_helper.dart';

class JournalEntryDraft {
  const JournalEntryDraft({
    required this.mood,
    required this.title,
    required this.body,
  });

  final String mood;
  final String title;
  final String body;
}

/// Opens the journal composer. Pass [existing] to pre-fill it for editing —
/// the same form is reused for both create and update so the two flows can't
/// drift apart visually.
Future<JournalEntryDraft?> showAddJournalSheet(
  BuildContext context, {
  JournalEntry? existing,
}) {
  return Navigator.of(context).push<JournalEntryDraft>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => _AddJournalPage(existing: existing),
    ),
  );
}

class _AddJournalPage extends StatefulWidget {
  const _AddJournalPage({this.existing});

  final JournalEntry? existing;

  @override
  State<_AddJournalPage> createState() => _AddJournalPageState();
}

class _AddJournalPageState extends State<_AddJournalPage> {
  static const _accent = Color(0xFF2E7D6B);
  static const _accentDark = Color(0xFF1F5C4D);
  static const _paperBg = Color(0xFFFAF8F1);
  static const _hairline = Color(0xFFE7E1D3);
  static const _ruleColor = Color(0xFFE7E1D3);
  static const _marginColor = Color(0xFFE7A9A6);

  late String _mood = widget.existing?.mood ?? journalMoods[1].label;
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _bodyController = TextEditingController(
    text: widget.existing?.body ?? '',
  );

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _save() {
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;
    Navigator.of(context).pop(
      JournalEntryDraft(
        mood: _mood,
        title: _titleController.text.trim(),
        body: body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paperBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNavRow(),
              const SizedBox(height: 18),
              _buildMoodSelector(),
              const SizedBox(height: 16),
              _buildTitleField(),
              const SizedBox(height: 16),
              Expanded(child: _buildBodyField()),
              const SizedBox(height: 14),
              _buildActionPills(),
              const SizedBox(height: 14),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavRow() {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: _accent,
                padding: EdgeInsets.zero,
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 16.5)),
            ),
          ),
          Text(
            _isEditing ? 'Edit Journal Entry' : 'New Journal Entry',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _accentDark,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AnimatedBuilder(
              animation: _bodyController,
              builder: (context, _) {
                final canSave = _bodyController.text.trim().isNotEmpty;
                return TextButton(
                  onPressed: canSave ? _save : null,
                  style: TextButton.styleFrom(
                    foregroundColor: _accent,
                    disabledForegroundColor: _accent.withValues(alpha: 0.35),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hairline),
      ),
      child: Row(children: [for (final mood in journalMoods) _moodOption(mood)]),
    );
  }

  Widget _moodOption(JournalMood mood) {
    final selected = _mood == mood.label;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _mood = mood.label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE4E2DC) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? mood.foreground : Colors.transparent,
                  border: selected
                      ? null
                      : Border.all(color: mood.foreground, width: 1.4),
                ),
                alignment: Alignment.center,
                child: Icon(
                  mood.icon,
                  size: 15,
                  color: selected ? Colors.white : mood.foreground,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  mood.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? _accentDark
                        : mood.foreground.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Title (optional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _accent,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  maxLength: 80,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    hintText: 'Give your entry a title...',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _titleController,
                builder: (context, _) => Text(
                  '${_titleController.text.length}/80',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: _RuledPaperPainter(
                lineColor: _ruleColor,
                marginColor: _marginColor,
                lineSpacing: 26,
                topOffset: 46,
                marginX: 34,
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 46,
                right: 14,
                top: 34,
                bottom: 30,
              ),
              child: TextField(
                controller: _bodyController,
                maxLines: null,
                expands: true,
                maxLength: 2000,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 15,
                  height: 26 / 15,
                  color: Color(0xFF3A3A34),
                ),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  hintText: 'Write here...',
                  hintStyle: TextStyle(color: _accent, fontWeight: FontWeight.w500),
                  counterText: '',
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 8,
            child: AnimatedBuilder(
              animation: _bodyController,
              builder: (context, _) => Text(
                '${_bodyController.text.length}/2000',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPills() {
    return Row(
      children: [
        Expanded(
          child: _pillButton(icon: Icons.image_outlined, label: 'Add Photo'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _pillButton(icon: Icons.mood_outlined, label: 'Add Mood Note'),
        ),
      ],
    );
  }

  Widget _pillButton({required IconData icon, required String label}) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => showAppSnackBar(context, 'Coming soon'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFDDEEE7),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: _accent),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _accentDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return AnimatedBuilder(
      animation: _bodyController,
      builder: (context, _) {
        final canSave = _bodyController.text.trim().isNotEmpty;
        return FilledButton.icon(
          onPressed: canSave ? _save : null,
          style: FilledButton.styleFrom(
            backgroundColor: _accentDark,
            disabledBackgroundColor: _accentDark.withValues(alpha: 0.4),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.bookmark_outline, size: 19),
          label: Text(
            _isEditing ? 'Save Changes' : 'Save Entry',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}

/// Paints faint notebook-style ruling behind the entry body field: evenly
/// spaced horizontal rules plus a left margin line, matching the paper-journal
/// look of the design this composer is based on.
class _RuledPaperPainter extends CustomPainter {
  const _RuledPaperPainter({
    required this.lineColor,
    required this.marginColor,
    required this.lineSpacing,
    required this.topOffset,
    required this.marginX,
  });

  final Color lineColor;
  final Color marginColor;
  final double lineSpacing;
  final double topOffset;
  final double marginX;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (double y = topOffset; y < size.height - 8; y += lineSpacing) {
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), linePaint);
    }

    final marginPaint = Paint()
      ..color = marginColor
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(marginX, 12),
      Offset(marginX, size.height - 12),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RuledPaperPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.marginColor != marginColor ||
        oldDelegate.lineSpacing != lineSpacing ||
        oldDelegate.topOffset != topOffset ||
        oldDelegate.marginX != marginX;
  }
}
