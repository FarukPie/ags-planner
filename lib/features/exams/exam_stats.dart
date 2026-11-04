import '../../core/ags_curriculum_data.dart';
import '../../models/exam_model.dart';

/// Per-lesson net statistics across all exams that include the lesson.
class LessonNetStat {
  final String lesson;
  final double averageNet;
  final double lastNet; // from the most recent exam containing the lesson
  final int examCount;

  const LessonNetStat(this.lesson, this.averageNet, this.lastNet, this.examCount);
}

/// Pure statistics over a list of exams (any order).
class ExamStats {
  ExamStats(List<ExamModel> exams)
      : exams = List.of(exams)..sort((a, b) => a.date.compareTo(b.date));

  /// Chronological (oldest first).
  final List<ExamModel> exams;

  /// Lessons ordered by average net, best first.
  List<LessonNetStat> get lessonStats {
    final nets = <String, List<double>>{};
    for (final e in exams) {
      for (final r in e.branchResults.entries) {
        (nets[r.key] ??= []).add(r.value.net);
      }
    }
    return [
      for (final e in nets.entries)
        LessonNetStat(e.key, e.value.reduce((a, b) => a + b) / e.value.length, e.value.last, e.value.length),
    ]..sort((a, b) => b.averageNet.compareTo(a.averageNet));
  }

  /// Topic id -> how many exams marked it weak, most frequent first.
  List<MapEntry<String, int>> get weakTopicFrequency {
    final counts = <String, int>{};
    for (final e in exams) {
      for (final id in e.weakTopicIds.toSet()) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Total correct / wrong / blank answers of one exam.
  static ({int correct, int wrong, int blank}) totals(ExamModel e) => (
        correct: e.branchResults.values.fold(0, (s, r) => s + r.correct),
        wrong: e.branchResults.values.fold(0, (s, r) => s + r.wrong),
        blank: e.branchResults.values.fold(0, (s, r) => s + r.blank),
      );

  /// AGS subtest names, including names used by older app versions.
  static final Set<String> _agsNames = {
    ...AgsCurriculum.agsSections.map((s) => s.name),
    'Coğrafya',
    'Eğitimin Temelleri',
  };

  /// Net of the 80-question AGS part and of the ÖABT part (null if absent).
  static ({double ags, double? oabt}) splitNets(ExamModel e) {
    var ags = 0.0;
    double? oabt;
    for (final r in e.branchResults.entries) {
      if (_agsNames.contains(r.key)) {
        ags += r.value.net;
      } else {
        oabt = (oabt ?? 0) + r.value.net;
      }
    }
    return (ags: ags, oabt: oabt);
  }
}
