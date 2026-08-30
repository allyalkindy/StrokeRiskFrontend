import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/prediction.dart';
import 'ui_kit.dart';

/// Rounds a raw step up to a "nice" value (1, 2, 2.5, 5 × 10^n) so grid
/// lines and axis labels land on clean numbers.
double _niceInterval(double raw) {
  if (raw <= 0) return 1;
  final mag = pow(10, (log(raw) / ln10).floor()).toDouble();
  final norm = raw / mag;
  final nice = norm <= 1
      ? 1.0
      : norm <= 2
          ? 2.0
          : norm <= 2.5
              ? 2.5
              : norm <= 5
                  ? 5.0
                  : 10.0;
  return nice * mag;
}

/// Single-series trend line: 2px line, soft area fill, horizontal-only
/// recessive grid, muted axis ink. One hue per chart — measures of
/// different scale get their own chart, never a second axis.
class AppLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> xLabels;
  final String unit;
  final Color color;
  final double? minY;
  final double? maxY;

  const AppLineChart({
    super.key,
    required this.values,
    required this.xLabels,
    this.unit = '',
    this.color = AppTheme.primaryGreen,
    this.minY,
    this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: AppTheme.inkMuted);
    final spots = [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i]),
    ];
    final lo = minY ?? values.reduce((a, b) => a < b ? a : b) * .9;
    final hi = maxY ?? values.reduce((a, b) => a > b ? a : b) * 1.1;
    final yInterval = _niceInterval((hi - lo) / 4);
    final xInterval = (values.length / 6).ceilToDouble().clamp(1, 30);

    return LineChart(
      LineChartData(
        minY: lo,
        maxY: hi,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (v) =>
              const FlLine(color: AppTheme.gridLine, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: yInterval,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '${v.toStringAsFixed(0)}$unit',
                  style: labelStyle,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: xInterval.toDouble(),
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= xLabels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(xLabels[i], style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.white,
            tooltipBorder: const BorderSide(color: AppTheme.gridLine),
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(1)}$unit',
                      const TextStyle(
                        color: AppTheme.inkPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: .3,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: .22),
                  color.withValues(alpha: .01),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Risk distribution — one bar per risk level in its status color, each
/// directly labeled with its count and named on the axis (icon + label in
/// the legend row below), so color never carries meaning alone.
class RiskDistributionChart extends StatelessWidget {
  final int low;
  final int medium;
  final int high;

  const RiskDistributionChart({
    super.key,
    required this.low,
    required this.medium,
    required this.high,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: AppTheme.inkMuted);
    final levels = RiskLevel.values;
    final counts = [low, medium, high];
    final maxCount =
        counts.reduce((a, b) => a > b ? a : b).toDouble().clamp(1, 999);

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxCount * 1.3,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxCount / 3).ceilToDouble(),
                getDrawingHorizontalLine: (v) =>
                    const FlLine(color: AppTheme.gridLine, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        levels[v.toInt()].label.split(' ').first,
                        style: labelStyle,
                      ),
                    ),
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.white,
                  tooltipBorder: const BorderSide(color: AppTheme.gridLine),
                  getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                    '${levels[group.x].label}\n${rod.toY.toInt()} patients',
                    const TextStyle(
                      color: AppTheme.inkPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < levels.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: counts[i].toDouble(),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            levels[i].color,
                            levels[i].color.withValues(alpha: .65),
                          ],
                        ),
                        width: 32,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ],
                    showingTooltipIndicators: const [],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend: icon + label + count per level.
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < levels.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(levels[i].icon, size: 14, color: levels[i].color),
                  const SizedBox(width: 4),
                  Text('${levels[i].label} · ${counts[i]}',
                      style: labelStyle),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Card wrapper giving every chart a titled, padded, fixed-height home.
class ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final double height;

  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: text.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style:
                    text.bodySmall?.copyWith(color: AppTheme.inkMuted)),
          ],
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}
