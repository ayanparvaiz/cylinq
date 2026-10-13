import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/models/sales.dart';
import '../../../core/utils/formatters.dart';

/// Cylinders sold per day. A single 2px line with a light wash; the latest
/// day carries the only dot and the only direct label. Touch or hover shows a
/// crosshair with that day's numbers.
class DailyTrendChart extends StatelessWidget {
  const DailyTrendChart({super.key, required this.days, this.height = 220});

  final List<DailyStats> days;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final spots = [for (final (i, d) in days.indexed) FlSpot(i.toDouble(), d.qty.toDouble())];
    final maxY = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m);
    final step = _niceStep(maxY);
    final labelEvery = (days.length / 5).ceil().clamp(1, days.length);
    final axis = text.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: (maxY / step).ceil() * step + (maxY == 0 ? step : 0),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: step,
            getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant.withValues(alpha: 0.6), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: step,
                getTitlesWidget: (v, meta) => v == meta.max && v != 0
                    ? const SizedBox.shrink()
                    : Text(_compact(v), style: axis),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= days.length || (days.length - 1 - i) % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(dayLabel(parseDayKey(days[i].day)), style: axis),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              fitInsideHorizontally: true,
              getTooltipItems: (touched) => [
                for (final t in touched)
                  LineTooltipItem(
                    '${count(days[t.x.toInt()].qty)} cylinders\n',
                    TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w800),
                    children: [
                      TextSpan(
                        text: '${rupees(days[t.x.toInt()].amount)} · ${dayLabel(parseDayKey(days[t.x.toInt()].day))}',
                        style: TextStyle(color: scheme.onInverseSurface.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
              ],
            ),
            getTouchedSpotIndicator: (bar, indexes) => [
              for (final _ in indexes)
                TouchedSpotIndicatorData(
                  FlLine(color: scheme.outline, strokeWidth: 1),
                  FlDotData(
                    getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                      radius: 5,
                      color: AppColors.flame,
                      strokeWidth: 2,
                      strokeColor: scheme.surfaceContainerLow,
                    ),
                  ),
                ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: AppColors.flame,
              barWidth: 2,
              isStrokeCapRound: true,
              isStrokeJoinRound: true,
              belowBarData: BarAreaData(show: true, color: AppColors.flame.withValues(alpha: 0.10)),
              dotData: FlDotData(
                checkToShowDot: (spot, _) => spot.x == spots.last.x,
                getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.flame,
                  strokeWidth: 2,
                  strokeColor: scheme.surfaceContainerLow,
                ),
              ),
            ),
          ],
          showingTooltipIndicators: const [],
        ),
      ),
    );
  }

  static double _niceStep(double max) {
    if (max <= 4) return 1;
    final raw = max / 4;
    const steps = <double>[1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 5000];
    return steps.firstWhere((m) => m >= raw, orElse: () => raw.ceilToDouble());
  }

  static String _compact(double v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K' : v.toInt().toString();
}
