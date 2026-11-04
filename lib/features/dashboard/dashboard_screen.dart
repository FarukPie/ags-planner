import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/format.dart';
import '../../core/widgets/account_button.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/decor.dart';
import '../../providers/app_provider.dart';
import 'widgets/exam_countdown_card.dart';
import 'widgets/review_alerts_card.dart';
import 'widgets/study_distribution_card.dart';
import 'widgets/today_goal_card.dart';
import 'widgets/topics_preview_card.dart';
import 'widgets/weekly_chart_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static String _greeting(DateTime now) => switch (now.hour) {
    < 6 => 'İyi geceler',
    < 12 => 'Günaydın',
    < 18 => 'İyi günler',
    _ => 'İyi akşamlar',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = p.sessionsOn(now);
    final goal = p.profile?.dailyGoalMinutes ?? 120;
    final name = p.profile?.firstName;

    final sections = <Widget>[
      const ExamCountdownCard(),
      const SizedBox(height: 16),
      TodayGoalCard(
        minutes: today.fold(0, (s, x) => s + x.durationMinutes),
        goalMinutes: goal,
        questions: today.fold(0, (s, x) => s + x.solvedQuestions),
        streak: p.studyStreak(now),
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatCard(
                badge: const IconBadge(icon: Icons.schedule_rounded, color: Color(0xFF4F7DF9)),
                label: 'Toplam Çalışma',
                value: AnimatedCount(
                  value: p.totalStudyMinutes.toDouble(),
                  format: (v) => formatMinutes(v.round()),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                footer: Text('${p.sessions.length} oturum', style: theme.textTheme.bodySmall),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                badge: ProgressRing(
                  progress: p.completionRatio,
                  colors: const [Color(0xFF7B5CFA), Color(0xFF38B6F5)],
                  size: 44,
                  stroke: 5,
                  child: AnimatedCount(
                    value: p.completionRatio * 100,
                    format: (v) => '${v.round()}',
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                label: 'Biten Konular',
                onTap: () => openTopics(context),
                value: AnimatedCount(
                  value: p.completedTopicCount.toDouble(),
                  format: (v) => '${v.round()} / ${p.topics.length}',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                footer: Text('%${(p.completionRatio * 100).round()} tamamlandı', style: theme.textTheme.bodySmall),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const TopicsPreviewCard(),
      const SizedBox(height: 12),
      WeeklyChartCard(days: p.recentDays(7, now), goalMinutes: goal),
      const SizedBox(height: 12),
      ReviewAlertsCard(reviews: p.dueReviews()),
      const SizedBox(height: 12),
      StudyDistributionCard(minutesByLesson: p.minutesByLesson),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name == null ? '${_greeting(now)} 👋' : '${_greeting(now)}, $name 👋',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            ShaderMask(
              shaderCallback: (r) => AppTheme.brandGradient.createShader(r),
              child: const Text(
                'AGS Asistanı',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ],
        ),
        actions: const [AccountButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [for (var i = 0; i < sections.length; i++) FadeSlideIn(index: i ~/ 2, child: sections[i])],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.badge, required this.label, required this.value, required this.footer, this.onTap});

  final Widget badge;
  final String label;
  final Widget value;
  final Widget footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftShadow(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badge,
                const SizedBox(height: 12),
                Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 2),
                value,
                const Spacer(),
                const SizedBox(height: 6),
                footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
