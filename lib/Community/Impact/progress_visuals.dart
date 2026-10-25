// lib/Community/Impact/progress_visuals.dart
//
// 14-day points chart for the Impact dashboard. Bars stack verified points
// (viz-1) under points still pending review (viz-5) so an estimate never
// reads as earned. Axis labels are real dates, not "day 1…14".

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Models/contribution.dart';
import '../../theme/canopy_components.dart';

class ProgressVisuals extends StatelessWidget {
  final List<Contribution> contributions;
  final int days;

  const ProgressVisuals({
    super.key,
    required this.contributions,
    this.days = 14,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.canopy;
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final verified = List<int>.filled(days, 0);
    final pending = List<int>.filled(days, 0);
    for (final c in contributions) {
      final dt = c.createdAt;
      if (dt == null) continue;
      final i = DateTime(dt.year, dt.month, dt.day).difference(start).inDays;
      if (i < 0 || i >= days) continue;
      if (c.isVerified) {
        verified[i] += c.estimatedImpactPoints;
      } else {
        pending[i] += c.estimatedImpactPoints;
      }
    }
    final maxY = [for (var i = 0; i < days; i++) verified[i] + pending[i]]
        .fold<int>(0, (a, b) => a > b ? a : b);
    final total = verified.fold<int>(0, (a, b) => a + b) +
        pending.fold<int>(0, (a, b) => a + b);
    final fmt = DateFormat('d MMM');

    return CanopyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last $days days',
              style: CanopyType.subhead.copyWith(color: p.ink)),
          Text('Points logged per day',
              style: CanopyType.caption.copyWith(color: p.inkMuted)),
          const SizedBox(height: CanopySpace.s16),
          if (total == 0)
            SizedBox(
              height: 120,
              child: Center(
                child: Text('Nothing logged in the last $days days.',
                    style: CanopyType.body.copyWith(color: p.inkMuted)),
              ),
            )
          else
            SizedBox(
              height: 170,
              child: Semantics(
                label:
                    '$total points logged in the last $days days, ${verified.fold<int>(0, (a, b) => a + b)} verified.',
                child: BarChart(
                  BarChartData(
                    maxY: (maxY * 1.15).ceilToDouble(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: p.outline, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (v, meta) => v == meta.max
                              ? const SizedBox.shrink()
                              : Text('${v.toInt()}',
                                  style: CanopyType.micro
                                      .copyWith(color: p.inkMuted)),
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i != 0 && i != days - 1 && i != days ~/ 2) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: CanopySpace.s4),
                              child: Text(
                                  fmt.format(start.add(Duration(days: i))),
                                  style: CanopyType.micro
                                      .copyWith(color: p.inkMuted)),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < days; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: (verified[i] + pending[i]).toDouble(),
                            width: 12,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3)),
                            rodStackItems: [
                              BarChartRodStackItem(
                                  0, verified[i].toDouble(), p.viz[0]),
                              BarChartRodStackItem(
                                  verified[i].toDouble(),
                                  (verified[i] + pending[i]).toDouble(),
                                  p.viz[4]),
                            ],
                            color: Colors.transparent,
                          ),
                        ]),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: CanopySpace.s12),
          Row(
            children: [
              _Swatch(color: p.viz[0], label: 'Verified'),
              const SizedBox(width: CanopySpace.s16),
              _Swatch(color: p.viz[4], label: 'Pending review'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final String label;
  const _Swatch({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: CanopySpace.s4 + 2),
          Text(label,
              style: CanopyType.caption.copyWith(color: context.canopy.inkMuted)),
        ],
      );
}
