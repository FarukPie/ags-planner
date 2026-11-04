import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/decor.dart';

/// Today's study minutes against the daily goal, plus streak and questions.
class TodayGoalCard extends StatelessWidget {
  const TodayGoalCard({
    super.key,
    required this.minutes,
    required this.goalMinutes,
    required this.questions,
    required this.streak,
  });

  final int minutes;
  final int goalMinutes;
  final int questions;
  final int streak;

  String get _message {
    final r = goalMinutes == 0 ? 0 : minutes / goalMinutes;
    if (r >= 1) return 'Günlük hedefini tamamladın, harikasın! 🎉';
    if (r >= 0.5) return 'Yarıyı geçtin, az kaldı! 💪';
    if (minutes > 0) return 'Güzel başlangıç, devam et! 🚀';
    return 'Bugün ilk oturumunu başlatmaya ne dersin?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = goalMinutes == 0 ? 0.0 : (minutes / goalMinutes).clamp(0.0, 1.0);
    final done = minutes >= goalMinutes && goalMinutes > 0;

    Widget pill(IconData icon, String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        );

    return SoftShadow(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ProgressRing(
                progress: ratio,
                colors: done
                    ? const [Color(0xFF3FC380), Color(0xFF2EAD6B)]
                    : const [Color(0xFF7B5CFA), Color(0xFF38B6F5)],
                size: 96,
                stroke: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedCount(
                      value: ratio * 100,
                      format: (v) => '%${v.round()}',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text('hedef', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bugünkü Hedef', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: formatMinutes(minutes),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                        TextSpan(text: ' / ${formatMinutes(goalMinutes)}', style: theme.textTheme.bodyMedium),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    Text(_message, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        pill(Icons.local_fire_department_rounded, '$streak gün seri', const Color(0xFFFF7A59)),
                        pill(Icons.quiz_rounded, '$questions soru', const Color(0xFF4F7DF9)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
