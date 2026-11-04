import 'model_utils.dart';

class AgendaModel {
  final String id;
  final String title;
  final DateTime date;

  /// "HH:mm" strings; null means an all-day item.
  final String? startTime;
  final String? endTime;
  final bool isCompleted;
  final bool syncToGoogleCalendar;

  /// Id of the mirrored Google Calendar event, so it can be updated/deleted.
  final String? googleEventId;

  const AgendaModel({
    required this.id,
    required this.title,
    required this.date,
    this.startTime,
    this.endTime,
    this.isCompleted = false,
    this.syncToGoogleCalendar = false,
    this.googleEventId,
  });

  bool isOn(DateTime day) =>
      date.year == day.year && date.month == day.month && date.day == day.day;

  AgendaModel copyWith({
    bool? isCompleted,
    String? googleEventId,
    bool clearGoogleEventId = false,
  }) =>
      AgendaModel(
        id: id,
        title: title,
        date: date,
        startTime: startTime,
        endTime: endTime,
        isCompleted: isCompleted ?? this.isCompleted,
        syncToGoogleCalendar: syncToGoogleCalendar,
        googleEventId: clearGoogleEventId ? null : googleEventId ?? this.googleEventId,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': dateToString(date),
        'startTime': startTime,
        'endTime': endTime,
        'isCompleted': isCompleted,
        'syncToGoogleCalendar': syncToGoogleCalendar,
        'googleEventId': googleEventId,
      };

  factory AgendaModel.fromMap(Map<String, dynamic> map) => AgendaModel(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        date: parseDate(map['date']) ?? DateTime.now(),
        startTime: map['startTime'] as String?,
        endTime: map['endTime'] as String?,
        isCompleted: map['isCompleted'] as bool? ?? false,
        syncToGoogleCalendar: map['syncToGoogleCalendar'] as bool? ?? false,
        googleEventId: map['googleEventId'] as String?,
      );
}
