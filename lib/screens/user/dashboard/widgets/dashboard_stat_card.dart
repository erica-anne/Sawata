import 'package:flutter/material.dart';

/// Compact stat tile used in the dashboard's 3-up summary row: an icon
/// badge, a headline value/label pair, and a small footer visualization
/// (sparkline, streak dots, or bars) supplied by the caller.
class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    required this.footer,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final Widget footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(height: 22, child: footer),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small rising line-and-fill graph.
class SparklineFooter extends StatelessWidget {
  const SparklineFooter({
    super.key,
    required this.color,
    this.points = const [0.3, 0.45, 0.35, 0.55, 0.5, 0.7, 0.6, 0.9],
  });

  final Color color;
  final List<double> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _SparklinePainter(points: points, color: color),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.points, required this.color});

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (points.length - 1);

    for (var i = 0; i < points.length; i++) {
      final x = stepX * i;
      final y = size.height - (points[i] * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

/// Row of small dots marking days completed within the current streak.
class StreakDotsFooter extends StatelessWidget {
  const StreakDotsFooter({
    super.key,
    required this.completed,
    required this.color,
    this.total = 7,
  });

  final int completed;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(total, (i) {
        final done = i < completed;
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: done ? color : color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: done
              ? const Icon(Icons.check, size: 7, color: Colors.white)
              : null,
        );
      }),
    );
  }
}

/// Row of ascending bars.
class MiniBarsFooter extends StatelessWidget {
  const MiniBarsFooter({
    super.key,
    required this.color,
    this.values = const [0.2, 0.3, 0.35, 0.5, 0.65, 0.8, 1.0],
  });

  final Color color;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: values
          .map(
            (v) => Container(
              width: 6,
              height: 22 * v,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.35 + 0.65 * v),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          )
          .toList(),
    );
  }
}
