import 'package:flutter/material.dart';

import 'alert_card.dart';

/// Horizontal filter row for the Alerts list: an "All" chip plus one per
/// [AlertCategory], with a fixed funnel button for (future) advanced
/// filtering pinned at the end.
class AlertFilterChips extends StatelessWidget {
  const AlertFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onFilterTap,
  });

  final AlertCategory? selected;
  final ValueChanged<AlertCategory?> onChanged;
  final VoidCallback onFilterTap;

  static const _accent = Color(0xFF2E7D6B);
  static const _muted = Color(0xFF5B7269);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(
                  label: 'All',
                  selected: selected == null,
                  onTap: () => onChanged(null),
                ),
                for (final category in AlertCategory.values) ...[
                  const SizedBox(width: 8),
                  _Chip(
                    label: category.label,
                    selected: selected == category,
                    onTap: () => onChanged(category),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onFilterTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.filter_list,
                size: 19,
                color: _muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AlertFilterChips._accent : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? null
                : Border.all(color: Colors.black.withValues(alpha: 0.1)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AlertFilterChips._muted,
            ),
          ),
        ),
      ),
    );
  }
}
