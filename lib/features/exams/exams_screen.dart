import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/ags_curriculum_data.dart';
import '../../core/app_theme.dart';
import '../../core/lesson_style.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/decor.dart';
import '../../models/exam_model.dart';
import '../../providers/app_provider.dart';
import 'exam_editor_page.dart';
import 'exam_stats.dart';

const _green = Color(0xFF3FC380);
const _red = Color(0xFFFF5F6D);

class ExamsScreen extends StatelessWidget {
  const ExamsScreen({super.key});

  void _openEditor(BuildContext context, [ExamModel? exam]) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => ExamEditorPage(exam: exam)),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final exams = p.exams; // newest first

    if (exams.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Denemeler')),
        body: _EmptyState(onAdd: () => _openEditor(context)),
      );
    }

    final stats = ExamStats(exams);
    final best = exams.map((e) => e.totalNet).reduce((a, b) => a > b ? a : b);
    final weak = stats.weakTopicFrequency;

    final sections = <Widget>[
      _NetSummaryCard(exams: stats.exams),
      const SectionTitle('Ders Bazlı Performans'),
      _LessonPerformanceCard(stats: stats.lessonStats),
      if (weak.isNotEmpty) ...[
        const SectionTitle('Odaklanman Gereken Konular'),
        _WeakTopicsCard(
          items: [
            for (final w in weak.take(6))
              if (p.topicById(w.key) case final t?) (topic: t.topicName, lesson: t.lessonName, count: w.value),
          ],
        ),
      ],
      SectionTitle('Deneme Geçmişi', trailing: Text('${exams.length} deneme')),
      for (var i = 0; i < exams.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ExamCard(
            exam: exams[i],
            isBest: exams[i].totalNet == best && exams.length > 1,
            previousNet: i + 1 < exams.length ? exams[i + 1].totalNet : null,
            topicName: (id) => p.topicById(id)?.topicName,
            onEdit: () => _openEditor(context, exams[i]),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Denemeler')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'exam_fab',
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Deneme Ekle'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          for (var i = 0; i < sections.length; i++) FadeSlideIn(index: i, child: sections[i]),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- empty state

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget step(int n, IconData icon, Color color, String title, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconBadge(icon: icon, color: color),
                  Positioned(
                    right: -4,
                    top: -4,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: color,
                      child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(text, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        );

    final sections = <Widget>[
      GradientCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.insights_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Deneme Takibi',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Her denemeden sonra sonuçlarını gir; netlerini, ders bazlı gelişimini ve zayıf konularını tek ekranda gör.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF5B45E0),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('İlk Denemeni Ekle'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SoftShadow(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nasıl çalışır?', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                step(1, Icons.edit_note_rounded, const Color(0xFF7B5CFA), 'Sonuçlarını gir',
                    'Her ders için doğru, yanlış ve boş sayısını yaz.'),
                step(2, Icons.calculate_rounded, const Color(0xFF4F7DF9), 'Net otomatik hesaplanır',
                    'Ders netleri ve toplam net anında çıkar.'),
                step(3, Icons.flag_rounded, const Color(0xFFFF7A59), 'Zayıf konuları işaretle',
                    'En sık zorlandığın konular burada listelenir.'),
                step(4, Icons.trending_up_rounded, _green, 'Gelişimini izle',
                    'Grafik ve ders karşılaştırmalarıyla ilerlemeni gör.'),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      SoftShadow(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const IconBadge(icon: Icons.lightbulb_rounded, color: Color(0xFFFFB648)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AGS net hesabı', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('4 yanlış 1 doğruyu götürür: Net = D − Y ÷ 4', style: theme.textTheme.bodySmall),
                      Text('Örnek: 40 D, 8 Y → 40 − 2 = 38 net', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      const _SamplePreview(),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [for (var i = 0; i < sections.length; i++) FadeSlideIn(index: i ~/ 2, child: sections[i])],
    );
  }
}

/// Faded sample chart hinting at what the screen will show.
class _SamplePreview extends StatelessWidget {
  const _SamplePreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const sample = [52.0, 58.5, 56.0, 63.25, 67.5, 71.0];
    return SoftShadow(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Örnek görünüm', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('Denemelerini ekledikçe oluşur', style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: 0.35,
                child: SizedBox(
                  height: 110,
                  child: LineChart(
                    LineChartData(
                      minY: 40,
                      maxY: 80,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [for (var i = 0; i < sample.length; i++) FlSpot(i.toDouble(), sample[i])],
                          isCurved: true,
                          gradient: AppTheme.brandGradient,
                          barWidth: 4,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF7B5CFA).withValues(alpha: 0.4),
                                const Color(0xFF7B5CFA).withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- summary

/// Gradient card: last / best / average net and the trend chart.
class _NetSummaryCard extends StatelessWidget {
  const _NetSummaryCard({required this.exams});

  final List<ExamModel> exams; // chronological

  @override
  Widget build(BuildContext context) {
    final nets = exams.map((e) => e.totalNet).toList();
    final best = nets.reduce((a, b) => a > b ? a : b);
    final avg = nets.reduce((a, b) => a + b) / nets.length;
    final change = nets.length >= 2 ? nets.last - nets[nets.length - 2] : null;
    const white = Colors.white;

    Widget stat(String label, double v, IconData icon) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(icon, color: white.withValues(alpha: 0.85), size: 18),
                const SizedBox(height: 2),
                AnimatedCount(
                  value: v,
                  format: (x) => x.toStringAsFixed(2),
                  style: const TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                Text(label, style: TextStyle(color: white.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ),
        );

    return GradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Net Gelişimi', style: TextStyle(color: white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              if (change != null && change != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(change > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${change > 0 ? '+' : ''}${change.toStringAsFixed(2)} son deneme',
                        style: const TextStyle(color: white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('Son', nets.last, Icons.schedule_rounded),
              stat('En iyi', best, Icons.emoji_events_rounded),
              stat('Ortalama', avg, Icons.functions_rounded),
            ],
          ),
          const SizedBox(height: 18),
          if (exams.length >= 2)
            SizedBox(
              height: 170,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  // Headroom above the best net so the top label/dot aren't clipped.
                  maxY: ((best + 5) / 20).ceil() * 20.0,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (_) => FlLine(color: white.withValues(alpha: 0.15), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.black.withValues(alpha: 0.7),
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                            '${exams[s.x.toInt()].title}\n${s.y.toStringAsFixed(2)} net',
                            const TextStyle(color: white, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: 20,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(meta.formattedValue, style: TextStyle(color: white.withValues(alpha: 0.8), fontSize: 11)),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= exams.length || value != i.toDouble()) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              DateFormat('d/M').format(exams[i].date),
                              style: TextStyle(color: white.withValues(alpha: 0.8), fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < nets.length; i++) FlSpot(i.toDouble(), nets[i])],
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: white,
                      barWidth: 3.5,
                      dotData: FlDotData(
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 4.5,
                          color: white,
                          strokeWidth: 2.5,
                          strokeColor: const Color(0xFF7B5CFA),
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [white.withValues(alpha: 0.35), white.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 600),
              ),
            )
          else
            Text(
              'Gelişim grafiği için bir deneme daha ekle 📈',
              style: TextStyle(color: white.withValues(alpha: 0.9)),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- lessons

class _LessonPerformanceCard extends StatelessWidget {
  const _LessonPerformanceCard({required this.stats});

  final List<LessonNetStat> stats; // best first

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxAvg = stats.map((s) => s.averageNet).fold<double>(0, (a, b) => b > a ? b : a);

    return SoftShadow(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            children: [
              for (final s in stats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      IconBadge(icon: LessonStyle.of(s.lesson).icon, color: LessonStyle.of(s.lesson).color, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(s.lesson,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                Text('ort. ${s.averageNet.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                                if (s.examCount > 1 && s.lastNet != s.averageNet) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    s.lastNet > s.averageNet ? Icons.north_east_rounded : Icons.south_east_rounded,
                                    size: 16,
                                    color: s.lastNet > s.averageNet ? _green : _red,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            _AnimatedBar(
                              fraction: maxAvg <= 0 ? 0 : (s.averageNet / maxAvg).clamp(0.0, 1.0),
                              color: LessonStyle.of(s.lesson).color,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Oklar son denemenin ders ortalamasına göre yönünü gösterir.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal bar that grows to [fraction] of the available width.
class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, f, _) => FractionallySizedBox(
          widthFactor: f,
          heightFactor: 1, // without it the empty DecoratedBox collapses to 0 height
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- weak topics

class _WeakTopicsCard extends StatelessWidget {
  const _WeakTopicsCard({required this.items});

  final List<({String topic, String lesson, int count})> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftShadow(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              for (final w in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      IconBadge(icon: LessonStyle.of(w.lesson).icon, color: LessonStyle.of(w.lesson).color, size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(w.topic, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(w.lesson, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${w.count} denemede',
                          style: const TextStyle(color: _red, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
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

// ----------------------------------------------------------------- history

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.exam,
    required this.isBest,
    required this.previousNet,
    required this.topicName,
    required this.onEdit,
  });

  final ExamModel exam;
  final bool isBest;
  final double? previousNet;
  final String? Function(String id) topicName;
  final VoidCallback onEdit;

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Deneme silinsin mi?'),
        content: Text('"${exam.title}" kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true && context.mounted) await context.read<AppProvider>().deleteExam(exam.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weak = exam.weakTopicIds.map(topicName).whereType<String>().toList();
    final delta = previousNet == null ? null : exam.totalNet - previousNet!;
    final t = ExamStats.totals(exam);
    final answered = t.correct + t.wrong + t.blank;
    final split = ExamStats.splitNets(exam);

    return SoftShadow(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Net bubble.
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: isBest ? AppTheme.warmGradient : AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.all(8),
                      // Scales down instead of overflowing with large system fonts.
                      child: FittedBox(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              exam.totalNet.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            const Text('net', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  exam.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              if (isBest) ...[
                                const SizedBox(width: 6),
                                const Text('🏆'),
                              ],
                            ],
                          ),
                          Text(DateFormat('d MMMM y, EEEE', 'tr_TR').format(exam.date), style: theme.textTheme.bodySmall),
                          if (delta != null && delta != 0)
                            Row(
                              children: [
                                Icon(
                                  delta > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                  size: 16,
                                  color: delta > 0 ? _green : _red,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(2)} önceki denemeye göre',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: delta > 0 ? _green : _red,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) => v == 'edit' ? onEdit() : _delete(context),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                        PopupMenuItem(value: 'delete', child: Text('Sil')),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12, right: 12),
                  child: Row(
                    children: [
                      _PartPill('AGS', split.ags, AgsCurriculum.agsQuestions, const Color(0xFF7B5CFA)),
                      if (split.oabt != null) ...[
                        const SizedBox(width: 8),
                        _PartPill('ÖABT', split.oabt!, AgsCurriculum.oabtQuestions, const Color(0xFFFF7A59)),
                      ],
                    ],
                  ),
                ),
                if (answered > 0) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _AnswerBar(correct: t.correct, wrong: t.wrong, blank: t.blank),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in exam.branchResults.entries)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: LessonStyle.of(r.key).color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LessonStyle.of(r.key).icon, size: 14, color: LessonStyle.of(r.key).color),
                            const SizedBox(width: 4),
                            Text('${r.key}  ', style: theme.textTheme.labelSmall),
                            Text(
                              r.value.net.toStringAsFixed(2),
                              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (weak.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.flag_rounded, size: 16, color: _red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Zayıf: ${weak.join(', ')}',
                          style: theme.textTheme.bodySmall?.copyWith(color: _red),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stacked correct / wrong / blank bar with a small legend.
class _AnswerBar extends StatelessWidget {
  const _AnswerBar({required this.correct, required this.wrong, required this.blank});

  final int correct;
  final int wrong;
  final int blank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grey = theme.colorScheme.outline.withValues(alpha: 0.35);

    Widget legend(Color c, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(text, style: theme.textTheme.labelSmall),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              // Stretch so the childless ColoredBoxes get the full 10px height.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (correct > 0) Expanded(flex: correct, child: const ColoredBox(color: _green)),
                if (wrong > 0) Expanded(flex: wrong, child: const ColoredBox(color: _red)),
                if (blank > 0) Expanded(flex: blank, child: ColoredBox(color: grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          children: [
            legend(_green, '$correct doğru'),
            legend(_red, '$wrong yanlış'),
            legend(grey, '$blank boş'),
          ],
        ),
      ],
    );
  }
}

/// "AGS 52,25 / 80" style pill.
class _PartPill extends StatelessWidget {
  const _PartPill(this.label, this.net, this.questions, this.color);

  final String label;
  final double net;
  final int questions;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
            Text.rich(TextSpan(children: [
              TextSpan(text: net.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              TextSpan(text: ' / $questions net', style: Theme.of(context).textTheme.bodySmall),
            ])),
          ],
        ),
      ),
    );
  }
}
