import 'model_utils.dart';

/// Where a note lives: the main list, the archive or the trash.
enum NoteStatus { active, archived, trashed }

class ChecklistItem {
  final String id;
  final String text;
  final bool done;

  const ChecklistItem({required this.id, this.text = '', this.done = false});

  ChecklistItem copyWith({String? text, bool? done}) =>
      ChecklistItem(id: id, text: text ?? this.text, done: done ?? this.done);

  Map<String, dynamic> toMap() => {'id': id, 'text': text, 'done': done};

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        id: map['id'] as String? ?? '',
        text: map['text'] as String? ?? '',
        done: map['done'] as bool? ?? false,
      );
}

class NoteModel {
  final String id;
  final String title;
  final String content;

  /// When true the note is a to-do list ([checklist]) instead of [content].
  final bool isChecklist;
  final List<ChecklistItem> checklist;

  /// Index into the note palette; 0 = the theme's card color.
  final int colorIndex;
  final bool isPinned;
  final NoteStatus status;
  final DateTime? trashedAt;

  /// Optional lesson/topic tag (AGS notes); null for general notes.
  final String? lessonName;
  final String? topicId;

  /// Manual order (drag & drop): smaller comes first.
  final double sortKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteModel({
    required this.id,
    this.title = '',
    this.content = '',
    this.isChecklist = false,
    this.checklist = const [],
    this.colorIndex = 0,
    this.isPinned = false,
    this.status = NoteStatus.active,
    this.trashedAt,
    String? lessonName,
    this.topicId,
    double? sortKey,
    required this.createdAt,
    DateTime? updatedAt,
  })  : lessonName = (lessonName?.isEmpty ?? true) ? null : lessonName,
        // Default order: newest first.
        sortKey = sortKey ?? -createdAt.millisecondsSinceEpoch.toDouble(),
        updatedAt = updatedAt ?? createdAt;

  /// True when there is nothing worth keeping.
  bool get isEmpty =>
      title.trim().isEmpty &&
      (isChecklist ? checklist.every((i) => i.text.trim().isEmpty) : content.trim().isEmpty);

  /// Everything searchable, lower-cased.
  String get searchText => [
        title,
        content,
        for (final i in checklist) i.text,
        ?lessonName,
      ].join('\n').toLowerCase();

  NoteModel copyWith({
    String? title,
    String? content,
    bool? isChecklist,
    List<ChecklistItem>? checklist,
    int? colorIndex,
    bool? isPinned,
    NoteStatus? status,
    DateTime? trashedAt,
    bool clearTrashedAt = false,
    String? lessonName,
    String? topicId,
    bool clearLesson = false,
    double? sortKey,
    DateTime? updatedAt,
  }) =>
      NoteModel(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        isChecklist: isChecklist ?? this.isChecklist,
        checklist: checklist ?? this.checklist,
        colorIndex: colorIndex ?? this.colorIndex,
        isPinned: isPinned ?? this.isPinned,
        status: status ?? this.status,
        trashedAt: clearTrashedAt ? null : (trashedAt ?? this.trashedAt),
        lessonName: clearLesson ? null : (lessonName ?? this.lessonName),
        topicId: clearLesson ? null : (topicId ?? this.topicId),
        sortKey: sortKey ?? this.sortKey,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'isChecklist': isChecklist,
        'checklist': [for (final i in checklist) i.toMap()],
        'colorIndex': colorIndex,
        'isPinned': isPinned,
        'status': status.name,
        'trashedAt': trashedAt == null ? null : dateToString(trashedAt!),
        'lessonName': lessonName,
        'topicId': topicId,
        'sortKey': sortKey,
        'createdAt': dateToString(createdAt),
        'updatedAt': dateToString(updatedAt),
      };

  /// Also reads notes from older versions (lesson required, `isCritical`
  /// instead of pinning). Photo fields of older versions are ignored.
  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      isChecklist: map['isChecklist'] as bool? ?? false,
      checklist: [
        for (final i in (map['checklist'] as List? ?? const []))
          ChecklistItem.fromMap(Map<String, dynamic>.from(i as Map)),
      ],
      colorIndex: (map['colorIndex'] as num?)?.toInt() ?? 0,
      isPinned: map['isPinned'] as bool? ?? map['isCritical'] as bool? ?? false,
      status: NoteStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => NoteStatus.active,
      ),
      trashedAt: parseDate(map['trashedAt']),
      lessonName: map['lessonName'] as String?,
      topicId: map['topicId'] as String?,
      sortKey: (map['sortKey'] as num?)?.toDouble(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
