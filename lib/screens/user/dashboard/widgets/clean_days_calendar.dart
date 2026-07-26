import 'package:flutter/material.dart';

/// Month-view calendar card showing which days fall within the user's
/// current gamble-free streak, with a trophy summary panel alongside it.
class CleanDaysCalendar extends StatefulWidget {
  const CleanDaysCalendar({super.key, required this.streakDays});

  final int streakDays;

  @override
  State<CleanDaysCalendar> createState() => _CleanDaysCalendarState();
}

class _CleanDaysCalendarState extends State<CleanDaysCalendar> {
  late DateTime _displayedMonth;

  static const _weekdayLabels = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];
  static const _monthLabels = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + delta,
      );
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _displayedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Jump to month',
    );
    if (picked == null) return;
    setState(() => _displayedMonth = DateTime(picked.year, picked.month));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final streakStart = todayDateOnly.subtract(
      Duration(days: widget.streakDays),
    );

    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final firstOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    final leadingBlanks = firstOfMonth.weekday % 7;

    final cells = <DateTime?>[
      for (var i = 0; i < leadingBlanks; i++) null,
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(_displayedMonth.year, _displayedMonth.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final weeks = [
      for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your Clean Days Calendar',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _pickMonth,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_monthLabels[_displayedMonth.month - 1]} ${_displayedMonth.year}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Icon(Icons.keyboard_arrow_down, size: 18),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftMonth(-1),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: _weekdayLabels
                              .map(
                                (label) => Expanded(
                                  child: Center(
                                    child: Text(
                                      label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 4),
                        for (final week in weeks)
                          Row(
                            children: week
                                .map(
                                  (date) => Expanded(
                                    child: _DayCell(
                                      date: date,
                                      isToday:
                                          date != null && date == todayDateOnly,
                                      isChecked:
                                          date != null &&
                                          !date.isBefore(streakStart) &&
                                          date.isBefore(todayDateOnly),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 104,
                    child: _StreakBadgePanel(streakDays: widget.streakDays),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isToday,
    required this.isChecked,
  });

  final DateTime? date;
  final bool isToday;
  final bool isChecked;

  static const _green = Color(0xFF2E7D6B);

  @override
  Widget build(BuildContext context) {
    final date = this.date;
    if (date == null) {
      return const SizedBox(height: 38);
    }
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 38,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (isToday)
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${date.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              )
            else
              Text(
                '${date.day}',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            if (isChecked)
              Positioned(
                bottom: -6,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 9, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StreakBadgePanel extends StatelessWidget {
  const _StreakBadgePanel({required this.streakDays});

  final int streakDays;

  static const _mint = Color(0xFFDDEEE7);
  static const _darkTeal = Color(0xFF16332B);
  static const _leafGreen = Color(0xFF7FAE95);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -4,
            bottom: -4,
            child: Icon(
              Icons.spa,
              size: 26,
              color: _leafGreen.withValues(alpha: 0.6),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: _darkTeal,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.emoji_events, size: 16, color: _mint),
              ),
              const SizedBox(height: 8),
              Text(
                '$streakDays',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _darkTeal,
                ),
              ),
              Text(
                'Days Clean',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _darkTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Keep going! You're doing amazing.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _darkTeal.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
