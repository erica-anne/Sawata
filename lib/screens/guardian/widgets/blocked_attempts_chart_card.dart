import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:sawata/models/stat_snapshot.dart';

/// "Blocked Attempts Over Time" card — a simple bar chart driven by whatever
/// [data] the caller passes in for the currently selected report period.
class BlockedAttemptsChartCard extends StatelessWidget {
  const BlockedAttemptsChartCard({
    super.key,
    required this.data,
    required this.rangeLabel,
  });

  final List<WeeklyStat> data;
  final String rangeLabel;

  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);
  static const _muted = Color(0xFF5B7269);

  static const List<double> _niceIntervals = [2, 5, 10, 20, 50, 100];

  double _niceInterval(double maxValue) {
    for (final step in _niceIntervals) {
      if (maxValue / step <= 4) return step;
    }
    return _niceIntervals.last;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxValue = data
        .map((e) => e.value)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final yInterval = _niceInterval(maxValue == 0 ? 1 : maxValue);
    final chartMaxY = ((maxValue / yInterval).ceil() + 1) * yInterval;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'BLOCKED ATTEMPTS OVER TIME',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _muted,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rangeLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _deepTeal,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            child: BarChart(
              key: ValueKey(data.map((e) => '${e.label}${e.value}').join()),
              BarChartData(
                maxY: chartMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10.5, color: _muted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            data[i].label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: _muted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    tooltipPadding: EdgeInsets.zero,
                    tooltipMargin: 8,
                    fitInsideHorizontally: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        rod.toY.toStringAsFixed(0),
                        const TextStyle(
                          color: _deepTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < data.length; i++)
                    BarChartGroupData(
                      x: i,
                      showingTooltipIndicators: const [0],
                      barRods: [
                        BarChartRodData(
                          toY: data[i].value,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [_deepTeal, _accent],
                          ),
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: DecoratedBox(decoration: BoxDecoration(color: _accent)),
              ),
              SizedBox(width: 6),
              Text(
                'Blocked Attempts',
                style: TextStyle(fontSize: 11.5, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
