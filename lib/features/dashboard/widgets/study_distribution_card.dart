import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/lesson_style.dart';
import '../../../core/widgets/decor.dart';

/// Donut chart + legend of studied minutes per lesson. The donut spins and
/// grows in on first show; later data changes animate via fl_chart.
class StudyDistributionCard extends StatelessWidget {
  const StudyDistributionCard({super.key, required this.minutesByLesson});

  final Map<String, int> minutesByLesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = minutesByLesson.values.fold(0, (a, b) => a + b);
    final entries = minutesByLesson.entries.toList();

    return SoftShadow(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(icon: Icons.donut_large_rounded, color: Color(0xFF00B8A9), size: 40),
                  const SizedBox(width: 12),
                  Text(
                    'Ders Bazlı Dağılım',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (total == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Henüz çalışma kaydı yok.\nPomodoro sekmesinden ilk oturumunu başlat!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ),
                )
              else ...[
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Transform.rotate(
                    angle: (1 - t) * -math.pi / 2,
                    child: Transform.scale(scale: 0.6 + 0.4 * t, child: Opacity(opacity: t, child: child)),
                  ),
                  child: SizedBox(
                    height: 190,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            centerSpaceRadius: 52,
                            sectionsSpace: 3,
                            sections: [
                              for (final e in entries)
                                PieChartSectionData(
                                  value: e.value.toDouble(),
                                  color: LessonStyle.of(e.key).color,
                                  radius: 34,
                                  title: e.value / total >= 0.08 ? '%${(e.value * 100 / total).round()}' : '',
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          duration: const Duration(milliseconds: 600),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatMinutes(total), style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('toplam', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        IconBadge(icon: LessonStyle.of(e.key).icon, color: LessonStyle.of(e.key).color, size: 30),
                        const SizedBox(width: 10),
                        Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis)),
                        Text(formatMinutes(e.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
