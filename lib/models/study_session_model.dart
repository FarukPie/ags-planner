import 'model_utils.dart';

enum StudyMode { pomodoro, stopwatch }

/// What the user did in a session: solved questions or studied the topic.
enum StudyActivity { questions, topic }

class StudySessionModel {
  final String id;
  final String lessonName;
  final String? topicId;
  final String? topicName;
  final int durationMinutes;
  final StudyMode mode;
  final StudyActivity activity;
  final int solvedQuestions;
  final DateTime createdAt;

  const StudySessionModel({
    required this.id,
    required this.lessonName,
    this.topicId,
    this.topicName,
    required this.durationMinutes,
    required this.mode,
    this.activity = StudyActivity.topic,
    this.solvedQuestions = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lessonName': lessonName,
        'topicId': topicId,
        'topicName': topicName,
        'durationMinutes': durationMinutes,
        'mode': mode.name,
        'activity': activity.name,
        'solvedQuestions': solvedQuestions,
        'createdAt': dateToString(createdAt),
      };

  factory StudySessionModel.fromMap(Map<String, dynamic> map) =>
      StudySessionModel(
        id: map['id'] as String,
        lessonName: map['lessonName'] as String? ?? '',
        topicId: map['topicId'] as String?,
        topicName: map['topicName'] as String?,
        durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
        mode: StudyMode.values.firstWhere(
          (m) => m.name == map['mode'],
          orElse: () => StudyMode.pomodoro,
        ),
        // Older sessions have no 'activity': any solved question means a question session.
        activity: StudyActivity.values.firstWhere(
          (a) => a.name == map['activity'],
          orElse: () => ((map['solvedQuestions'] as num?)?.toInt() ?? 0) > 0
              ? StudyActivity.questions
              : StudyActivity.topic,
        ),
        solvedQuestions: (map['solvedQuestions'] as num?)?.toInt() ?? 0,
        createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      );
}
