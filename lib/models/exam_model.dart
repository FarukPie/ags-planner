import 'model_utils.dart';

/// Result of one branch (ders) inside a mock exam.
/// AGS rule: 4 wrong answers cancel 1 correct answer.
class BranchResult {
  final int correct;
  final int wrong;
  final int blank;

  const BranchResult({this.correct = 0, this.wrong = 0, this.blank = 0});

  double get net => correct - wrong / 4;

  Map<String, dynamic> toMap() => {
        'correct': correct,
        'wrong': wrong,
        'blank': blank,
        'net': net,
      };

  factory BranchResult.fromMap(Map<String, dynamic> map) => BranchResult(
        correct: (map['correct'] as num?)?.toInt() ?? 0,
        wrong: (map['wrong'] as num?)?.toInt() ?? 0,
        blank: (map['blank'] as num?)?.toInt() ?? 0,
      );
}

class ExamModel {
  final String id;
  final String title;
  final DateTime date;

  /// Lesson name -> result.
  final Map<String, BranchResult> branchResults;
  final List<String> weakTopicIds;

  const ExamModel({
    required this.id,
    required this.title,
    required this.date,
    this.branchResults = const {},
    this.weakTopicIds = const [],
  });

  double get totalNet => branchResults.values.fold(0, (sum, r) => sum + r.net);

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': dateToString(date),
        'branchResults': branchResults.map((k, v) => MapEntry(k, v.toMap())),
        'weakTopicIds': weakTopicIds,
      };

  factory ExamModel.fromMap(Map<String, dynamic> map) => ExamModel(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        date: parseDate(map['date']) ?? DateTime.now(),
        branchResults: (map['branchResults'] as Map? ?? const {}).map(
          (k, v) => MapEntry(
            k as String,
            BranchResult.fromMap(Map<String, dynamic>.from(v as Map)),
          ),
        ),
        weakTopicIds: List<String>.from(map['weakTopicIds'] as List? ?? const []),
      );
}
