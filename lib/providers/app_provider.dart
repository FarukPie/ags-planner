import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../core/ags_curriculum_data.dart';
import '../core/app_constants.dart';
import '../core/local_storage.dart';
import '../core/services/calendar_service.dart';
import '../core/services/cloud_sync_service.dart';
import '../core/services/notification_service.dart';
import '../models/agenda_model.dart';
import '../models/exam_model.dart';
import '../models/note_model.dart';
import '../models/study_session_model.dart';
import '../models/topic_model.dart';
import '../models/user_profile.dart';

/// A spaced-repetition review that is due today or overdue.
class DueReview {
  final TopicModel topic;
  final int day; // 7 or 30
  final DateTime dueDate;

  const DueReview(this.topic, this.day, this.dueDate);
}

/// Central app state.
///
/// Local storage is the source the UI reads from and is updated on every
/// change, so the app works fully offline and without Firebase. When a user
/// is signed in, every change is also mirrored to Firestore (see [setCloudUser]).
class AppProvider extends ChangeNotifier {
  AppProvider(
    this._storage, {
    this.notifications,
    this.calendar,
    @visibleForTesting CloudSyncService Function(String uid)? cloudFactory,
  }) : _cloudFactory = cloudFactory ?? CloudSyncService.new {
    _load();
    _rescheduleReviewReminder();
    purgeExpiredTrash();
  }

  final LocalStorage _storage;
  final NotificationService? notifications;
  final CalendarService? calendar;
  final CloudSyncService Function(String uid) _cloudFactory;
  CloudSyncService? _cloud;

  late DateTime _examDate;
  late ThemeMode _themeMode;
  UserProfile? _profile;
  late String _branchKey;

  /// Progress for every topic ever touched, keyed by topic id — including
  /// topics of a previously selected branch, so switching branches loses nothing.
  final Map<String, TopicModel> _topicProgress = {};
  List<TopicModel> _topics = [];
  final Map<String, CurriculumTopic> _topicInfo = {};
  List<StudySessionModel> _sessions = [];
  List<ExamModel> _exams = [];
  List<NoteModel> _notes = [];
  List<AgendaModel> _agenda = [];

  bool _isSyncing = false;
  bool _syncAttempted = false;
  String? _syncError;
  DateTime? _lastSyncedAt;

  DateTime get examDate => _examDate;
  ThemeMode get themeMode => _themeMode;

  /// Null until the user completes the profile form (then the app opens).
  UserProfile? get profile => _profile;

  /// False while the first cloud sync for the signed-in user is pending —
  /// the profile may still arrive from the cloud (e.g. on a new device).
  bool get initialSyncDone => _cloud == null || _syncAttempted;
  String get branchKey => _branchKey;
  FieldBranch get branch => AgsCurriculum.branchByKey(_branchKey);
  List<TopicModel> get topics => List.unmodifiable(_topics);
  List<StudySessionModel> get sessions => List.unmodifiable(_sessions);
  List<NoteModel> get notes => List.unmodifiable(_notes);
  List<AgendaModel> get agenda => List.unmodifiable(_agenda);

  /// Exams, newest first.
  List<ExamModel> get exams =>
      List.of(_exams)..sort((a, b) => b.date.compareTo(a.date));

  bool get isCloudLinked => _cloud != null;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get canUseCalendar => calendar != null && _cloud != null;

  // ---------------------------------------------------------------- loading

  void _load() {
    _examDate = _migrateExamDate(DateTime.tryParse(_storage.getString(StorageKeys.examDate) ?? '')) ??
        AppConstants.defaultExamDate;
    _branchKey =
        _storage.getString(StorageKeys.branchKey) ?? AppConstants.defaultBranchKey;
    _themeMode = ThemeMode.values.asNameMap()[_storage.getString(StorageKeys.themeMode)] ??
        ThemeMode.system;
    _profile = _decodeProfile(_storage.getString(StorageKeys.profile));
    _import({
      for (final key in StorageKeys.syncedCollections) key: _storage.getMaps(key),
    });
  }

  /// Replaces all collections from raw maps (local storage or Firestore).
  void _import(Map<String, List<Map<String, dynamic>>> data) {
    _topicProgress
      ..clear()
      ..addEntries(data[StorageKeys.topics]!
          .map(TopicModel.fromMap)
          .map((t) => MapEntry(t.id, t)));
    _sessions = data[StorageKeys.sessions]!.map(StudySessionModel.fromMap).toList();
    _exams = data[StorageKeys.exams]!.map(ExamModel.fromMap).toList();
    _notes = data[StorageKeys.notes]!.map(NoteModel.fromMap).toList();
    _agenda = data[StorageKeys.agenda]!.map(AgendaModel.fromMap).toList();
    _buildTopics();
  }

  List<Map<String, dynamic>> _export(String key) => switch (key) {
        StorageKeys.topics => _topicProgress.values.map((t) => t.toMap()).toList(),
        StorageKeys.sessions => _sessions.map((s) => s.toMap()).toList(),
        StorageKeys.exams => _exams.map((e) => e.toMap()).toList(),
        StorageKeys.notes => _notes.map((n) => n.toMap()).toList(),
        StorageKeys.agenda => _agenda.map((a) => a.toMap()).toList(),
        _ => throw ArgumentError(key),
      };

  /// Curriculum for the selected branch, overlaid with saved progress.
  /// Names always come from the curriculum so fixes there propagate.
  void _buildTopics() {
    // Progress saved under an older id scheme (index-based) is matched by
    // lesson + topic name so a curriculum update never loses or misplaces it.
    final byName = <String, TopicModel>{
      for (final t in _topicProgress.values) '${t.lessonName}|${t.topicName}': t,
    };
    _topicInfo.clear();
    _topics = [
      for (final lesson in AgsCurriculum.lessonsFor(_branchKey))
        for (var i = 0; i < lesson.topics.length; i++)
          _progressFor(lesson.topicId(i), lesson.name, lesson.topics[i], byName),
    ];
  }

  TopicModel _progressFor(
    String id,
    String lessonName,
    CurriculumTopic topic,
    Map<String, TopicModel> byName,
  ) {
    _topicInfo[id] = topic;
    var progress = _topicProgress[id];
    if (progress == null) {
      final legacy = byName['$lessonName|${topic.name}'];
      if (legacy != null) {
        progress = TopicModel.fromMap({...legacy.toMap(), 'id': id});
        _topicProgress[id] = progress; // persisted with the next topic save
      }
    }
    return _withNames(progress ?? TopicModel(id: id, lessonName: '', topicName: ''), lessonName, topic.name);
  }

  /// Official metadata (weight, scope) of a topic in the current curriculum.
  CurriculumTopic? topicInfo(String id) => _topicInfo[id];

  TopicModel _withNames(TopicModel t, String lesson, String topic) =>
      TopicModel.fromMap({...t.toMap(), 'lessonName': lesson, 'topicName': topic});

  // ---------------------------------------------------------------- persistence

  /// Saves collection [key] locally and mirrors the single change to the cloud.
  Future<void> _commit(String key, {Map<String, dynamic>? upsert, String? deleteId}) async {
    final cloud = _cloud;
    if (cloud != null) {
      // Not awaited: Firestore queues writes offline; awaiting would block.
      if (upsert != null) cloud.upsert(key, upsert).catchError(_onCloudError);
      if (deleteId != null) cloud.delete(key, deleteId).catchError(_onCloudError);
    }
    await _storage.setMaps(key, _export(key));
  }

  Future<void> _saveSettings() async {
    await _storage.setString(StorageKeys.examDate, _examDate.toIso8601String());
    await _storage.setString(StorageKeys.branchKey, _branchKey);
    if (_profile != null) {
      await _storage.setString(StorageKeys.profile, jsonEncode(_profile!.toMap()));
    }
    _cloud?.setSettings(_settingsMap()).catchError(_onCloudError);
  }

  Map<String, dynamic> _settingsMap() => {
        'examDate': _examDate.toIso8601String(),
        'branchKey': _branchKey,
        if (_profile != null) 'profile': _profile!.toMap(),
      };

  /// The old placeholder default becomes the official 2027 date.
  static DateTime? _migrateExamDate(DateTime? d) =>
      d == AppConstants.legacyDefaultExamDate ? AppConstants.defaultExamDate : d;

  static UserProfile? _decodeProfile(String? json) {
    if (json == null) return null;
    try {
      return UserProfile.tryFromMap(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  void _onCloudError(Object e) {
    debugPrint('Cloud write failed: $e');
    _syncError = 'Bulut kaydı başarısız: $e';
    notifyListeners();
  }

  // ---------------------------------------------------------------- cloud sync

  /// Called whenever the signed-in user changes (null = signed out).
  Future<void> setCloudUser(String? uid) async {
    if (uid == _cloud?.uid) return;
    if (uid == null) {
      _cloud = null;
      _syncError = null;
      await _storage.remove(StorageKeys.syncedUid);
      notifyListeners();
      return;
    }
    _cloud = _cloudFactory(uid);
    _syncAttempted = false;
    await syncNow();
    _syncAttempted = true;
    notifyListeners();
  }

  /// Two cases:
  /// * First link of this device's data to [uid]: union of local and cloud
  ///   data (local wins on the same id), then local data is uploaded.
  /// * Already linked: the cloud is authoritative (every local change was
  ///   mirrored there), so it replaces local data — this also applies
  ///   deletions made on other devices.
  /// If the server can't be reached nothing local is changed.
  Future<void> syncNow() async {
    final cloud = _cloud;
    if (cloud == null || _isSyncing) return;
    _isSyncing = true;
    _syncError = null;
    notifyListeners();
    try {
      final remote = <String, List<Map<String, dynamic>>>{};
      for (final key in StorageKeys.syncedCollections) {
        final docs = await cloud.pullAll(key);
        if (docs == null) throw const _OfflineException();
        remote[key] = docs;
      }
      final remoteSettings = await cloud.getSettings();
      if (remoteSettings == null) throw const _OfflineException();
      if (cloud != _cloud) return; // user changed meanwhile

      final firstLink = _storage.getString(StorageKeys.syncedUid) != cloud.uid;
      if (firstLink) {
        final local = {for (final k in StorageKeys.syncedCollections) k: _export(k)};
        _import({
          for (final k in StorageKeys.syncedCollections)
            k: {
              for (final m in remote[k]!) m['id']: m,
              for (final m in local[k]!) m['id']: m,
            }.values.toList(),
        });
        for (final k in StorageKeys.syncedCollections) {
          cloud.pushAll(k, local[k]!, _onCloudError);
        }
        // A device that was never set up adopts the account's settings/profile.
        if (_profile == null) _adoptSettings(remoteSettings);
      } else {
        _import(remote);
        _adoptSettings(remoteSettings);
      }

      for (final k in StorageKeys.syncedCollections) {
        await _storage.setMaps(k, _export(k));
      }
      await _saveSettings();
      await _storage.setString(StorageKeys.syncedUid, cloud.uid);
      _lastSyncedAt = DateTime.now();
      _rescheduleReviewReminder();
    } on _OfflineException {
      _syncError = 'Sunucuya ulaşılamadı. Verileriniz cihazda güvende; değişiklikler bağlantı gelince gönderilecek.';
    } catch (e) {
      _syncError = 'Senkronizasyon hatası: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _adoptSettings(Map<String, dynamic> s) {
    final date = _migrateExamDate(DateTime.tryParse(s['examDate'] as String? ?? ''));
    if (date != null) _examDate = date;
    final branch = s['branchKey'] as String?;
    if (branch != null) _branchKey = branch;
    _profile = UserProfile.tryFromMap(s['profile']) ?? _profile;
    _buildTopics();
  }

  // ---------------------------------------------------------------- settings

  Future<void> setExamDate(DateTime date) async {
    _examDate = date;
    notifyListeners();
    await _saveSettings();
  }

  /// Saves the profile form (also the branch / exam date chosen there).
  Future<void> saveProfile(UserProfile profile, {required String branchKey, DateTime? examDate}) async {
    _profile = profile;
    if (examDate != null) _examDate = examDate;
    if (branchKey != _branchKey) {
      _branchKey = branchKey;
      _buildTopics();
    }
    notifyListeners();
    await _saveSettings();
    _rescheduleReviewReminder();
  }

  /// Waits briefly for queued cloud writes. False means some changes have not
  /// reached the server yet (e.g. offline) and would be lost by signing out.
  Future<bool> flushCloudWrites() async =>
      await _cloud?.flushPendingWrites(const Duration(seconds: 6)) ?? true;

  /// Removes this account's data from the device after sign-out, so the next
  /// account signing in on this device never sees or merges it.
  Future<void> clearUserData() async {
    for (final key in [
      ...StorageKeys.syncedCollections,
      StorageKeys.profile,
      StorageKeys.examDate,
      StorageKeys.branchKey,
      StorageKeys.syncedUid,
    ]) {
      await _storage.remove(key);
    }
    _cloud = null;
    _syncError = null;
    _lastSyncedAt = null;
    _load();
    notifyListeners();
    _rescheduleReviewReminder();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _storage.setString(StorageKeys.themeMode, mode.name);
  }

  Future<void> setBranch(String key) async {
    if (key == _branchKey) return;
    _branchKey = key;
    _buildTopics();
    notifyListeners();
    await _saveSettings();
    _rescheduleReviewReminder();
  }

  // ---------------------------------------------------------------- topics

  /// Topics of the selected branch grouped by lesson, in curriculum order.
  Map<String, List<TopicModel>> get topicsByLesson {
    final result = <String, List<TopicModel>>{};
    for (final t in _topics) {
      (result[t.lessonName] ??= []).add(t);
    }
    return result;
  }

  TopicModel? topicById(String id) =>
      _topics.where((t) => t.id == id).firstOrNull ?? _topicProgress[id];

  Future<void> toggleTopicCompleted(String id) =>
      _updateTopic(id, (t) => t.isCompleted ? t.reset() : t.complete(DateTime.now()));

  Future<void> completeReview(String id, int day) => _updateTopic(
        id,
        (t) => day == 7 ? t.copyWith(review7Done: true) : t.copyWith(review30Done: true),
      );

  Future<void> _updateTopic(String id, TopicModel Function(TopicModel) change) async {
    final updated = _changeTopic(id, change);
    if (updated == null) return;
    notifyListeners();
    await _commit(StorageKeys.topics, upsert: updated.toMap());
    _rescheduleReviewReminder();
  }

  /// Applies [change] to a topic of the current branch, or to stored progress
  /// of another branch (e.g. a session logged before switching branches).
  TopicModel? _changeTopic(String id, TopicModel Function(TopicModel) change) {
    final index = _topics.indexWhere((t) => t.id == id);
    final current = index >= 0 ? _topics[index] : _topicProgress[id];
    if (current == null) return null;
    final updated = change(current);
    if (index >= 0) _topics[index] = updated;
    _topicProgress[id] = updated;
    return updated;
  }

  // ---------------------------------------------------------------- sessions

  /// Records a finished study session and adds its minutes to the topic.
  Future<void> addSession({
    required String lessonName,
    String? topicId,
    String? topicName,
    required int durationMinutes,
    required StudyMode mode,
    StudyActivity activity = StudyActivity.topic,
    int solvedQuestions = 0,
  }) async {
    final session = StudySessionModel(
      id: newId(),
      lessonName: lessonName,
      topicId: topicId,
      topicName: topicName,
      durationMinutes: durationMinutes,
      mode: mode,
      activity: activity,
      solvedQuestions: activity == StudyActivity.questions ? solvedQuestions : 0,
      createdAt: DateTime.now(),
    );
    _sessions.add(session);
    final topic = topicId == null
        ? null
        : _changeTopic(topicId, (t) => t.copyWith(totalMinutes: t.totalMinutes + durationMinutes));
    notifyListeners();
    await _commit(StorageKeys.sessions, upsert: session.toMap());
    if (topic != null) await _commit(StorageKeys.topics, upsert: topic.toMap());
  }

  /// Deletes a session and takes its minutes back from the topic.
  Future<void> deleteSession(String id) async {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index < 0) return;
    final s = _sessions.removeAt(index);
    final topic = s.topicId == null
        ? null
        : _changeTopic(
            s.topicId!,
            (t) => t.copyWith(totalMinutes: (t.totalMinutes - s.durationMinutes).clamp(0, 1 << 31)),
          );
    notifyListeners();
    await _commit(StorageKeys.sessions, deleteId: id);
    if (topic != null) await _commit(StorageKeys.topics, upsert: topic.toMap());
  }

  /// Sessions started on the same calendar day as [day], newest first.
  List<StudySessionModel> sessionsOn(DateTime day) => _sessions
      .where((s) => _sameDay(s.createdAt, day))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ---------------------------------------------------------------- exams

  Future<void> saveExam(ExamModel exam) async {
    _upsert(_exams, exam, (e) => e.id);
    notifyListeners();
    await _commit(StorageKeys.exams, upsert: exam.toMap());
  }

  Future<void> deleteExam(String id) async {
    _exams.removeWhere((e) => e.id == id);
    notifyListeners();
    await _commit(StorageKeys.exams, deleteId: id);
  }

  // ---------------------------------------------------------------- notes

  /// Trashed notes are deleted for good after this long.
  static const trashRetention = Duration(days: 30);

  /// Notes in [status]: pinned first (active notes only), then manual order.
  List<NoteModel> notesIn(NoteStatus status) {
    final list = _notes.where((n) => n.status == status).toList();
    if (status == NoteStatus.trashed) {
      return list..sort((a, b) => (b.trashedAt ?? b.updatedAt).compareTo(a.trashedAt ?? a.updatedAt));
    }
    return list
      ..sort((a, b) => status == NoteStatus.active && a.isPinned != b.isPinned
          ? (a.isPinned ? -1 : 1)
          : a.sortKey.compareTo(b.sortKey));
  }

  NoteModel? noteById(String id) => _notes.where((n) => n.id == id).firstOrNull;

  /// Sort key that puts a new note at the top of the list.
  double get topNoteSortKey =>
      _notes.isEmpty ? 0 : _notes.map((n) => n.sortKey).reduce((a, b) => a < b ? a : b) - 1;

  /// Saves (creates or updates) a note.
  Future<void> saveNote(NoteModel note) async {
    _upsert(_notes, note, (n) => n.id);
    notifyListeners();
    await _commit(StorageKeys.notes, upsert: note.toMap());
  }

  /// Moves a note to the main list, the archive or the trash.
  Future<void> setNoteStatus(String id, NoteStatus status) async {
    final note = noteById(id);
    if (note == null || note.status == status) return;
    await saveNote(note.copyWith(
      status: status,
      trashedAt: status == NoteStatus.trashed ? DateTime.now() : null,
      clearTrashedAt: status != NoteStatus.trashed,
      // A restored/unarchived note comes back at the top.
      sortKey: status == NoteStatus.active ? topNoteSortKey : null,
    ));
  }

  Future<void> toggleNotePinned(String id) async {
    final note = noteById(id);
    if (note != null) await saveNote(note.copyWith(isPinned: !note.isPinned));
  }

  /// Drag & drop: puts [id] where [targetId] is (before it when moving up,
  /// after it when moving down) and adopts the target's pinned state.
  Future<void> moveNote(String id, String targetId) async {
    final note = noteById(id);
    final target = noteById(targetId);
    if (note == null || target == null || id == targetId) return;
    final list = notesIn(target.status)..removeWhere((n) => n.id == id);
    final oldList = notesIn(target.status);
    final movingDown = oldList.indexWhere((n) => n.id == id) < oldList.indexWhere((n) => n.id == targetId) &&
        note.isPinned == target.isPinned;
    final t = list.indexWhere((n) => n.id == targetId);
    final before = movingDown ? list[t] : (t > 0 ? list[t - 1] : null);
    final after = movingDown ? (t + 1 < list.length ? list[t + 1] : null) : list[t];
    // Only neighbors in the same (pinned/unpinned) group bound the new key.
    final lo = before != null && before.isPinned == target.isPinned ? before.sortKey : null;
    final hi = after != null && after.isPinned == target.isPinned ? after.sortKey : null;
    final key = lo != null && hi != null
        ? (lo + hi) / 2
        : lo != null
            ? lo + 1
            : hi != null
                ? hi - 1
                : target.sortKey;
    await saveNote(note.copyWith(sortKey: key, isPinned: target.isPinned));
  }

  Future<void> deleteNoteForever(String id) async {
    final note = noteById(id);
    if (note == null) return;
    _notes.remove(note);
    notifyListeners();
    await _commit(StorageKeys.notes, deleteId: id);
  }

  Future<void> emptyTrash() async {
    for (final n in notesIn(NoteStatus.trashed)) {
      await deleteNoteForever(n.id);
    }
  }

  /// Deletes notes that have been in the trash longer than [trashRetention].
  Future<void> purgeExpiredTrash([DateTime? now]) async {
    final limit = (now ?? DateTime.now()).subtract(trashRetention);
    for (final n in notesIn(NoteStatus.trashed)) {
      if ((n.trashedAt ?? n.updatedAt).isBefore(limit)) await deleteNoteForever(n.id);
    }
  }

  // ---------------------------------------------------------------- agenda

  /// Items on [day]: all-day first, then by start time.
  List<AgendaModel> agendaOn(DateTime day) => _agenda.where((a) => a.isOn(day)).toList()
    ..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));

  /// Saves the item and mirrors it to Google Calendar if requested.
  /// Returns a user-facing warning if the calendar part failed.
  Future<String?> saveAgenda(AgendaModel item) async {
    await _putAgenda(item);
    if (item.syncToGoogleCalendar) {
      if (!canUseCalendar) return 'Google Takvim için önce Google ile giriş yapın.';
      try {
        final eventId = await calendar!.upsertEvent(item);
        if (eventId != item.googleEventId) {
          await _putAgenda(item.copyWith(googleEventId: eventId));
        }
      } catch (e) {
        return 'Ajandaya kaydedildi ama Google Takvim\'e eklenemedi: $e';
      }
    } else if (item.googleEventId != null) {
      // Sync was switched off: remove the mirrored event.
      final warning = await _deleteCalendarEvent(item.googleEventId!);
      await _putAgenda(item.copyWith(clearGoogleEventId: true));
      return warning;
    }
    return null;
  }

  Future<void> toggleAgendaCompleted(String id) async {
    final item = _agenda.where((a) => a.id == id).firstOrNull;
    if (item != null) await _putAgenda(item.copyWith(isCompleted: !item.isCompleted));
  }

  Future<String?> deleteAgenda(String id) async {
    final item = _agenda.where((a) => a.id == id).firstOrNull;
    if (item == null) return null;
    _agenda.remove(item);
    notifyListeners();
    await _commit(StorageKeys.agenda, deleteId: id);
    return item.googleEventId == null ? null : _deleteCalendarEvent(item.googleEventId!);
  }

  Future<void> _putAgenda(AgendaModel item) async {
    _upsert(_agenda, item, (a) => a.id);
    notifyListeners();
    await _commit(StorageKeys.agenda, upsert: item.toMap());
  }

  Future<String?> _deleteCalendarEvent(String eventId) async {
    if (!canUseCalendar) return 'Google Takvim etkinliği silinemedi (giriş yapılmamış).';
    try {
      await calendar!.deleteEvent(eventId);
      return null;
    } catch (e) {
      return 'Google Takvim etkinliği silinemedi: $e';
    }
  }

  // ---------------------------------------------------------------- stats

  int get totalStudyMinutes =>
      _sessions.fold(0, (sum, s) => sum + s.durationMinutes);

  /// Lesson name -> studied minutes, largest first.
  Map<String, int> get minutesByLesson {
    final result = <String, int>{};
    for (final s in _sessions) {
      result[s.lessonName] = (result[s.lessonName] ?? 0) + s.durationMinutes;
    }
    final entries = result.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  int minutesOn(DateTime day) =>
      sessionsOn(day).fold(0, (sum, s) => sum + s.durationMinutes);

  /// Minutes per day for the last [days] days, oldest first (today last).
  List<({DateTime day, int minutes})> recentDays([int days = 7, DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return [
      for (var i = days - 1; i >= 0; i--)
        (day: today.subtract(Duration(days: i)), minutes: minutesOn(today.subtract(Duration(days: i)))),
    ];
  }

  /// Consecutive days with at least one session, ending today (or yesterday
  /// if nothing is logged yet today — the streak is still alive).
  int studyStreak([DateTime? now]) {
    final n = now ?? DateTime.now();
    var day = DateTime(n.year, n.month, n.day);
    if (minutesOn(day) == 0) day = day.subtract(const Duration(days: 1));
    var streak = 0;
    while (minutesOn(day) > 0) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int get completedTopicCount => _topics.where((t) => t.isCompleted).length;

  double get completionRatio =>
      _topics.isEmpty ? 0 : completedTopicCount / _topics.length;

  /// Reviews due on [now]'s day or earlier and not yet done, oldest first.
  List<DueReview> dueReviews([DateTime? now]) {
    final n = now ?? DateTime.now();
    final endOfDay = DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
    final result = <DueReview>[
      for (final t in _topics.where((t) => t.isCompleted)) ...[
        if (!t.review7Done && t.review7Date != null && t.review7Date!.isBefore(endOfDay))
          DueReview(t, 7, t.review7Date!),
        if (!t.review30Done && t.review30Date != null && t.review30Date!.isBefore(endOfDay))
          DueReview(t, 30, t.review30Date!),
      ],
    ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return result;
  }

  /// Reminder at the next 09:00 with the number of reviews due by then.
  void _rescheduleReviewReminder() {
    final n = notifications;
    if (n == null) return;
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, 9);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    n.scheduleReviewReminder(at, dueReviews(at).length);
  }

  // ---------------------------------------------------------------- helpers

  static int _lastId = 0;

  /// Time-based id, strictly increasing so rapid calls never collide even
  /// when the clock's resolution is coarser than a microsecond.
  static String newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _lastId = now > _lastId ? now : _lastId + 1;
    return '$_lastId';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static void _upsert<T>(List<T> list, T item, String Function(T) id) {
    final i = list.indexWhere((x) => id(x) == id(item));
    if (i >= 0) {
      list[i] = item;
    } else {
      list.add(item);
    }
  }
}

class _OfflineException implements Exception {
  const _OfflineException();
}
