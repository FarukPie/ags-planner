import 'model_utils.dart';

class TopicModel {
  final String id;
  final String lessonName;
  final String topicName;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? review7Date;
  final bool review7Done;
  final DateTime? review30Date;
  final bool review30Done;
  final int totalMinutes;

  const TopicModel({
    required this.id,
    required this.lessonName,
    required this.topicName,
    this.isCompleted = false,
    this.completedAt,
    this.review7Date,
    this.review7Done = false,
    this.review30Date,
    this.review30Done = false,
    this.totalMinutes = 0,
  });

  /// Marks the topic finished at [at] and schedules the 7th/30th-day reviews.
  TopicModel complete(DateTime at) {
    final day = DateTime(at.year, at.month, at.day);
    return TopicModel(
      id: id,
      lessonName: lessonName,
      topicName: topicName,
      isCompleted: true,
      completedAt: at,
      review7Date: day.add(const Duration(days: 7)),
      review30Date: day.add(const Duration(days: 30)),
      totalMinutes: totalMinutes,
    );
  }

  /// Reverts completion and clears the review schedule.
  TopicModel reset() => TopicModel(
        id: id,
        lessonName: lessonName,
        topicName: topicName,
        totalMinutes: totalMinutes,
      );

  TopicModel copyWith({bool? review7Done, bool? review30Done, int? totalMinutes}) =>
      TopicModel(
        id: id,
        lessonName: lessonName,
        topicName: topicName,
        isCompleted: isCompleted,
        completedAt: completedAt,
        review7Date: review7Date,
        review7Done: review7Done ?? this.review7Done,
        review30Date: review30Date,
        review30Done: review30Done ?? this.review30Done,
        totalMinutes: totalMinutes ?? this.totalMinutes,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'lessonName': lessonName,
        'topicName': topicName,
        'isCompleted': isCompleted,
        'completedAt': dateToString(completedAt),
        'review7Date': dateToString(review7Date),
        'review7Done': review7Done,
        'review30Date': dateToString(review30Date),
        'review30Done': review30Done,
        'totalMinutes': totalMinutes,
      };

  factory TopicModel.fromMap(Map<String, dynamic> map) => TopicModel(
        id: map['id'] as String,
        lessonName: map['lessonName'] as String? ?? '',
        topicName: map['topicName'] as String? ?? '',
        isCompleted: map['isCompleted'] as bool? ?? false,
        completedAt: parseDate(map['completedAt']),
        review7Date: parseDate(map['review7Date']),
        review7Done: map['review7Done'] as bool? ?? false,
        review30Date: parseDate(map['review30Date']),
        review30Done: map['review30Done'] as bool? ?? false,
        totalMinutes: (map['totalMinutes'] as num?)?.toInt() ?? 0,
      );
}
