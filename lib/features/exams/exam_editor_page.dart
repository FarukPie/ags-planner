import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/ags_curriculum_data.dart';
import '../../core/lesson_style.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/decor.dart';
import '../../models/exam_model.dart';
import '../../providers/app_provider.dart';

/// Add (exam == null) or edit a mock exam.
class ExamEditorPage extends StatefulWidget {
  const ExamEditorPage({super.key, this.exam});

  final ExamModel? exam;

  @override
  State<ExamEditorPage> createState() => _ExamEditorPageState();
}

class _ExamEditorPageState extends State<ExamEditorPage> {
  late final TextEditingController _title;
  late DateTime _date;
  late final List<String> _lessons;
  late final Map<String, int> _maxQuestions;

  /// lesson -> [correct, wrong, blank] controllers.
  final Map<String, List<TextEditingController>> _fields = {};
  late final Set<String> _weakTopicIds;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>();
    final exam = widget.exam;
    _title = TextEditingController(text: exam?.title ?? 'Deneme ${p.exams.length + 1}');
    _date = exam?.date ?? DateTime.now();
    _weakTopicIds = {...?exam?.weakTopicIds};
    // Current branch's lessons, plus any lesson the exam already has
    // (e.g. recorded under a previously selected branch).
    // Official answer-sheet structure: 6 AGS subtests + ÖABT (if any), plus
    // any section an older exam already has (e.g. recorded under another field).
    final sections = AgsCurriculum.examSections(p.branchKey);
    _maxQuestions = {for (final s in sections) s.name: s.questions};
    _lessons = {...sections.map((s) => s.name), ...?exam?.branchResults.keys}.toList();
    for (final lesson in _lessons) {
      final r = exam?.branchResults[lesson];
      _fields[lesson] = [
        for (final v in [r?.correct, r?.wrong, r?.blank])
          TextEditingController(text: v == null || v == 0 ? '' : '$v'),
      ];
    }
  }

  @override
  void dispose() {
    _title.dispose();
    for (final list in _fields.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    super.dispose();
  }

  BranchResult _resultOf(String lesson) {
    int v(int i) => int.tryParse(_fields[lesson]![i].text) ?? 0;
    return BranchResult(correct: v(0), wrong: v(1), blank: v(2));
  }

  bool _overLimit(String lesson) {
    final max = _maxQuestions[lesson];
    final r = _resultOf(lesson);
    return max != null && r.correct + r.wrong + r.blank > max;
  }

  Map<String, BranchResult> get _results => {
        for (final l in _lessons)
          if (_resultOf(l) case final r when r.correct + r.wrong + r.blank > 0) l: r,
      };

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickWeakTopics() async {
    final byLesson = context.read<AppProvider>().topicsByLesson;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text('Zayıf Konular', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const Text('Bu denemede zorlandığın konuları işaretle.'),
              for (final e in byLesson.entries) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    IconBadge(icon: LessonStyle.of(e.key).icon, color: LessonStyle.of(e.key).color, size: 28),
                    const SizedBox(width: 8),
                    Text(e.key, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in e.value)
                      FilterChip(
                        label: Text(t.topicName),
                        selected: _weakTopicIds.contains(t.id),
                        selectedColor: LessonStyle.of(e.key).color.withValues(alpha: 0.25),
                        onSelected: (on) {
                          setSheetState(() => on ? _weakTopicIds.add(t.id) : _weakTopicIds.remove(t.id));
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final results = _results;
    String? error;
    if (title.isEmpty) {
      error = 'Deneme adı boş olamaz.';
    } else if (_lessons.any(_overLimit)) {
      error = 'Bazı testlerde doğru + yanlış + boş toplamı soru sayısını aşıyor.';
    } else if (results.isEmpty) {
      error = 'En az bir ders için doğru/yanlış/boş girin.';
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await context.read<AppProvider>().saveExam(ExamModel(
          id: widget.exam?.id ?? AppProvider.newId(),
          title: title,
          date: _date,
          branchResults: results,
          weakTopicIds: _weakTopicIds.toList(),
        ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results.values;
    final totalNet = results.fold<double>(0, (s, r) => s + r.net);
    final correct = results.fold(0, (s, r) => s + r.correct);
    final wrong = results.fold(0, (s, r) => s + r.wrong);
    final blank = results.fold(0, (s, r) => s + r.blank);
    final weakNames = [
      for (final id in _weakTopicIds) context.read<AppProvider>().topicById(id)?.topicName,
    ].whereType<String>().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exam == null ? 'Yeni Deneme' : 'Denemeyi Düzenle'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(onPressed: _save, child: const Text('Kaydet')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          FadeSlideIn(
            child: GradientCard(
              child: Column(
                children: [
                  const Text('Toplam Net', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  AnimatedCount(
                    value: totalNet,
                    duration: const Duration(milliseconds: 400),
                    format: (v) => v.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Pill('$correct D', Colors.white),
                      _Pill('$wrong Y', Colors.white),
                      _Pill('$blank B', Colors.white),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Net = Doğru − Yanlış ÷ 4',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            index: 1,
            child: SoftShadow(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _title,
                        decoration: const InputDecoration(
                          labelText: 'Deneme adı',
                          prefixIcon: Icon(Icons.edit_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tarih',
                            prefixIcon: Icon(Icons.event_rounded),
                          ),
                          child: Text(DateFormat('d MMMM y, EEEE', 'tr_TR').format(_date)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SectionTitle('Ders Sonuçları'),
          for (var i = 0; i < _lessons.length; i++)
            FadeSlideIn(
              index: i + 2,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LessonRow(
                  lesson: _lessons[i],
                  maxQuestions: _maxQuestions[_lessons[i]],
                  subtitle: _lessons[i] == 'ÖABT' ? context.read<AppProvider>().branch.name : null,
                  fields: _fields[_lessons[i]]!,
                  net: _resultOf(_lessons[i]).net,
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
          const SectionTitle('Zayıf Konular'),
          SoftShadow(
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _pickWeakTopics,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const IconBadge(icon: Icons.flag_rounded, color: Color(0xFFFF5F6D), size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              weakNames.isEmpty ? 'Zorlandığın konuları seç' : '${weakNames.length} konu seçildi',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
                        ],
                      ),
                      if (weakNames.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [for (final n in weakNames) Chip(label: Text(n), visualDensity: VisualDensity.compact)],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.maxQuestions,
    required this.subtitle,
    required this.fields,
    required this.net,
    required this.onChanged,
  });

  final String lesson;
  final int? maxQuestions;
  final String? subtitle;
  final List<TextEditingController> fields;
  final double net;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final style = LessonStyle.of(lesson);
    final hasValue = fields.any((c) => c.text.isNotEmpty);
    final answered = fields.fold(0, (sum, c) => sum + (int.tryParse(c.text) ?? 0));
    final over = maxQuestions != null && answered > maxQuestions!;
    final theme = Theme.of(context);

    Widget box(int i, String label, Color accent) => Expanded(
          child: TextField(
            controller: fields[i],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              floatingLabelAlignment: FloatingLabelAlignment.center,
              floatingLabelStyle: TextStyle(color: accent, fontWeight: FontWeight.w700),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accent, width: 2),
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
        );

    return SoftShadow(
      child: Card(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasValue ? style.color.withValues(alpha: 0.6) : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  IconBadge(icon: style.icon, color: style.color, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          [
                            ?subtitle,
                            if (maxQuestions != null) '$answered / $maxQuestions soru',
                          ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: over ? theme.colorScheme.error : null,
                            fontWeight: over ? FontWeight.w700 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: hasValue ? 0.18 : 0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Net: ${net.toStringAsFixed(2)}',
                      style: TextStyle(color: style.color, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  box(0, 'Doğru', const Color(0xFF3FC380)),
                  const SizedBox(width: 8),
                  box(1, 'Yanlış', const Color(0xFFFF5F6D)),
                  const SizedBox(width: 8),
                  box(2, 'Boş', Theme.of(context).colorScheme.outline),
                ],
              ),
              if (over)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Bu testte $maxQuestions soru var; toplam $answered girildi.',
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
