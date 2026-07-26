import 'package:flutter/material.dart';

enum AlertCategory { critical, apps, websites, protection }

extension AlertCategoryStyle on AlertCategory {
  String get label => switch (this) {
    AlertCategory.critical => 'Critical',
    AlertCategory.apps => 'Apps',
    AlertCategory.websites => 'Websites',
    AlertCategory.protection => 'Protection',
  };

  Color get color => switch (this) {
    AlertCategory.critical => const Color(0xFFC0392B),
    AlertCategory.apps => const Color(0xFFB07A1E),
    AlertCategory.websites => const Color(0xFFB07A1E),
    AlertCategory.protection => const Color(0xFF3B6FE0),
  };

  Color get background => switch (this) {
    AlertCategory.critical => const Color(0xFFFBE7E4),
    AlertCategory.apps => const Color(0xFFFCEFD2),
    AlertCategory.websites => const Color(0xFFFCEFD2),
    AlertCategory.protection => const Color(0xFFE3ECFB),
  };
}

class AlertItem {
  const AlertItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.category,
    required this.time,
  });

  final IconData icon;
  final String title;
  final String description;
  final AlertCategory category;
  final String time;
}

/// A single row in the Guardian Alerts list — icon badge (with a small
/// warning dot), title/description, a category tag, and a timestamp.
class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.item, this.onTap});

  final AlertItem item;
  final VoidCallback? onTap;

  static const _deepTeal = Color(0xFF16332B);
  static const _muted = Color(0xFF5B7269);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.category.background,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        item.icon,
                        size: 20,
                        color: item.category.color,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFFC0392B),
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: Colors.white, width: 1.5),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: item.category.color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.description,
                      style: const TextStyle(fontSize: 12.5, color: _muted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: item.category.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.category.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: item.category.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.time,
                    style: const TextStyle(fontSize: 11.5, color: _muted),
                  ),
                  const SizedBox(height: 22),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: _deepTeal,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
