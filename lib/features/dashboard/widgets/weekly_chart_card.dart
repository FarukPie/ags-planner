import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/app_theme.dart';
import '../../../core/format.dart';
import '../../../core/widgets/decor.dart';

/// Last 7 days of study minutes as bars, with the daily goal as a dashed line.
class WeeklyChartCard extends StatelessWidget {
  const WeeklyChartCard({super.key, required this.days, required this.goalMinutes});

  final List<({DateTime day, int minutes})> days; // oldest first, today last
  final int goalMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = days.fold(0, (s, d) => s + d.minutes);
    final metGoal = days.where((d) => d.minutes >= goalMinutes && goalMinutes > 0).length;
    final maxMinutes = days.map((d) => d.minutes).fold(goalMinutes, (a, b) => b > a ? b : a);
    final maxY = ((maxMinutes * 1.2) / 30).ceil() * 30.0;

    return SoftShadow(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(icon: Icons.bar_chart_rounded, color: Color(0xFF4F7DF9), size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bu Hafta', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        Text(
                          '${formatMinutes(total)} • $metGoal/7 gün hedef tamam',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 150,
                child: BarChart(
                  BarChartData(
                    maxY: maxY <= 0 ? 60 : maxY,
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        if (goalMinutes > 0)
                          HorizontalLine(
                            y: goalMinutes.toDouble(),
                            color: const Color(0xFF3FC380),
                            strokeWidth: 1.5,
                            dashArray: [6, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              style: const TextStyle(color: Color(0xFF3FC380), fontSize: 10, fontWeight: FontWeight.w700),
                              labelResolver: (_) => 'hedef',
                            ),
                          ),
                      ],
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.black.withValues(alpha: 0.75),
                        getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                          formatMinutes(rod.toY.round()),
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      topTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, meta) {
                            final i = v.toInt();
                            final isToday = i == days.length - 1;
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                isToday ? 'Bugün' : DateFormat('E', 'tr_TR').format(days[i].day),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                  color: isToday ? theme.colorScheme.primary : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < days.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: days[i].minutes.toDouble(),
                            width: 18,
                            borderRadius: BorderRadius.circular(6),
                            gradient: days[i].minutes >= goalMinutes && goalMinutes > 0
                                ? const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Color(0xFF2EAD6B), Color(0xFF3FC380)],
                                  )
                                : LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: AppTheme.brandGradient.colors.take(2).toList(),
                                  ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxY <= 0 ? 60 : maxY,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                            ),
                          ),
                        ]),
                    ],
                  ),
                  duration: const Duration(milliseconds: 600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
