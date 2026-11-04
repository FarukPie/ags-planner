import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/ags_curriculum_data.dart';
import '../../core/format.dart';
import '../../core/lesson_style.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/branch_picker_page.dart';
import '../../core/widgets/decor.dart';
import '../../models/topic_model.dart';
import '../../providers/app_provider.dart';

enum _TopicFilter {
  all('Tümü'),
  open('Devam eden'),
  done('Tamamlanan');

  const _TopicFilter(this.label);
  final String label;
}

class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({super.key});

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  _TopicFilter _filter = _TopicFilter.all;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(TopicModel t) {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty && !t.topicName.toLowerCase().contains(q)) return false;
    return switch (_filter) {
      _TopicFilter.all => true,
      _TopicFilter.open => !t.isCompleted,
      _TopicFilter.done => t.isCompleted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final branch = p.branch;
    final filtering = _filter != _TopicFilter.all || _search.text.trim().isNotEmpty;
    final lessons = [
      for (final e in p.topicsByLesson.entries)
        if (e.value.where(_matches).toList() case final shown when shown.isNotEmpty)
          (name: e.key, all: e.value, shown: shown),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Konular')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          FadeSlideIn(
            child: GradientCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      ProgressRing(
                        progress: p.completionRatio,
                        colors: const [Colors.white, Colors.white],
                        trackColor: Colors.white24,
                        size: 84,
                        stroke: 9,
                        child: AnimatedCount(
                          value: p.completionRatio * 100,
                          format: (v) => '%${v.round()}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Genel İlerleme',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${p.completedTopicCount} / ${p.topics.length} konu tamamlandı',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                            ),
                            Text(
                              '${p.dueReviews().length} tekrar bekliyor',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Current field; tap to change.
                  Material(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final key = await pickBranch(context, current: p.branchKey);
                        if (key != null) await p.setBranch(key);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(branch.icon, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                branch.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Text('Değiştir', style: TextStyle(color: Colors.white, fontSize: 12)),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            index: 1,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Konu ara',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Temizle',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FadeSlideIn(
            index: 1,
            child: Wrap(
              spacing: 8,
              children: [
                for (final f in _TopicFilter.values)
                  ChoiceChip(
                    label: Text(f.label),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SectionTitle('Dersler', trailing: Text('${lessons.length} ders', style: theme.textTheme.bodySmall)),
          if (lessons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.manage_search_rounded, size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  Text(
                    _filter == _TopicFilter.done ? 'Henüz tamamlanan konu yok.' : 'Eşleşen konu bulunamadı.',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          for (var i = 0; i < lessons.length; i++)
            FadeSlideIn(
              key: ValueKey('${lessons[i].name}_${_filter}_$filtering'),
              index: i + 2,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LessonTile(
                  lessonName: lessons[i].name,
                  topics: lessons[i].all,
                  shown: lessons[i].shown,
                  initiallyExpanded: filtering,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lessonName,
    required this.topics,
    required this.shown,
    required this.initiallyExpanded,
  });

  final String lessonName;
  final List<TopicModel> topics; // all topics (for progress)
  final List<TopicModel> shown; // after filter/search
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = LessonStyle.of(lessonName);
    final done = topics.where((t) => t.isCompleted).length;
    final ratio = topics.isEmpty ? 0.0 : done / topics.length;
    final minutes = topics.fold(0, (sum, t) => sum + t.totalMinutes);

    return SoftShadow(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          // Keyed by lesson so expansion state survives list rebuilds.
          key: PageStorageKey('$lessonName$initiallyExpanded'),
          initiallyExpanded: initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
          leading: IconBadge(icon: style.icon, color: style.color),
          title: Text(lessonName, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            [
              '$done / ${topics.length} konu',
              if (AgsCurriculum.lessonNamed(lessonName)?.questions case final q?) '~$q soru',
              if (minutes > 0) formatMinutes(minutes),
            ].join(' • '),
            style: theme.textTheme.bodySmall,
          ),
          trailing: ratio == 1
              ? const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF3FC380),
                  child: Icon(Icons.check_rounded, color: Colors.white),
                )
              : ProgressRing(
            progress: ratio,
            colors: [style.color, style.color.withValues(alpha: 0.6)],
            size: 40,
            stroke: 5,
            child: Text(
              '${(ratio * 100).round()}',
              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          children: [for (final t in shown) _TopicRow(topic: t, color: style.color)],
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.color});

  final TopicModel topic;
  final Color color;

  Future<void> _toggle(BuildContext context) async {
    final provider = context.read<AppProvider>();
    if (topic.isCompleted) {
      // Un-completing wipes the review schedule — confirm first.
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Tamamlandı işareti kaldırılsın mı?'),
          content: Text('"${topic.topicName}" için 7. ve 30. gün tekrar planı sıfırlanacak.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kaldır')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await provider.toggleTopicCompleted(topic.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateFormat('d MMM', 'tr_TR');

    Widget reviewChip(int day, DateTime? due, bool doneReview) => Padding(
          padding: const EdgeInsets.only(right: 6, top: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (doneReview ? const Color(0xFF3FC380) : color).withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  doneReview ? Icons.check_circle_rounded : Icons.schedule_rounded,
                  size: 14,
                  color: doneReview ? const Color(0xFF3FC380) : color,
                ),
                const SizedBox(width: 4),
                Text(
                  '$day. gün${due == null ? '' : ' • ${date.format(due)}'}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        );

    return InkWell(
      onTap: () => _toggle(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AnimatedCheck(checked: topic.isCompleted, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: topic.isCompleted ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                      decoration: topic.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    child: Text(topic.topicName),
                  ),
                  if (context.read<AppProvider>().topicInfo(topic.id) case final info?) ...[
                    if (info.weight != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            // Weights are % of the 50-question ÖABT.
                            '%${_fmtWeight(info.weight!)} • ~${_fmtWeight(info.weight! * AgsCurriculum.oabtQuestions / 100)} soru',
                            style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    if (info.detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text.rich(
                          TextSpan(children: [
                            if (info.officialDetail)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(Icons.verified_rounded, size: 14, color: color),
                                ),
                              ),
                            TextSpan(text: info.detail),
                          ]),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ),
                  ],
                  if (topic.totalMinutes > 0)
                    Text('Çalışma: ${formatMinutes(topic.totalMinutes)}', style: theme.textTheme.bodySmall),
                  if (topic.isCompleted)
                    Wrap(
                      children: [
                        reviewChip(7, topic.review7Date, topic.review7Done),
                        reviewChip(30, topic.review30Date, topic.review30Done),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round check that fills with color and pops when checked.
class _AnimatedCheck extends StatelessWidget {
  const _AnimatedCheck({required this.checked, required this.color});

  final bool checked;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? color : Colors.transparent,
          border: Border.all(color: checked ? color : Theme.of(context).colorScheme.outline, width: 2),
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          scale: checked ? 1 : 0,
          child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

String _fmtWeight(double w) => w == w.roundToDouble() ? w.toInt().toString() : w.toString().replaceAll('.', ',');
