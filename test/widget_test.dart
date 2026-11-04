import 'package:ags_planner/core/ags_curriculum_data.dart';
import 'package:ags_planner/core/app_constants.dart';
import 'package:ags_planner/core/local_storage.dart';
import 'package:ags_planner/core/services/auth_service.dart';
import 'package:ags_planner/core/services/cloud_sync_service.dart';
import 'package:ags_planner/features/exams/exam_stats.dart';
import 'package:ags_planner/features/home/home_shell.dart';
import 'package:ags_planner/features/onboarding/auth_gate.dart';
import 'package:ags_planner/features/pomodoro/study_timer_controller.dart';
import 'package:ags_planner/features/pomodoro/widgets/save_session_dialog.dart';
import 'package:ags_planner/models/agenda_model.dart';
import 'package:ags_planner/models/exam_model.dart';
import 'package:ags_planner/models/note_model.dart';
import 'package:ags_planner/models/study_session_model.dart';
import 'package:ags_planner/models/topic_model.dart';
import 'package:ags_planner/models/user_profile.dart';
import 'package:ags_planner/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for Firestore.
class FakeCloud extends CloudSyncService {
  FakeCloud(super.uid, this.db);

  final Map<String, Map<String, Map<String, dynamic>>> db; // collection -> id -> doc
  Map<String, dynamic> settings = {};
  bool offline = false;

  @override
  Future<void> upsert(String collection, Map<String, dynamic> data) async =>
      (db[collection] ??= {})[data['id'] as String] = data;

  @override
  Future<void> delete(String collection, String id) async => db[collection]?.remove(id);

  @override
  Future<void> setSettings(Map<String, dynamic> s) async => settings.addAll(s);

  @override
  Future<Map<String, dynamic>?> getSettings() async => offline ? null : settings;

  @override
  Future<List<Map<String, dynamic>>?> pullAll(String collection) async =>
      offline ? null : (db[collection]?.values.toList() ?? []);

  @override
  void pushAll(String collection, List<Map<String, dynamic>> items, void Function(Object) onError) {
    for (final i in items) {
      (db[collection] ??= {})[i['id'] as String] = i;
    }
  }
}

Future<AppProvider> newProvider([
  Map<String, Object> prefs = const {},
  CloudSyncService Function(String)? cloud,
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return AppProvider(LocalStorage(await SharedPreferences.getInstance()), cloudFactory: cloud);
}

Future<void> pumpApp(WidgetTester tester, AppProvider p) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: p),
      ChangeNotifierProvider(create: (_) => AuthService(firebaseReady: false)),
    ],
    child: const MaterialApp(home: HomeShell()),
  ));
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('topics', () {
    test('completing a topic schedules 7/30 day reviews and persists', () async {
      final p = await newProvider();
      final id = p.topics.first.id;
      await p.toggleTopicCompleted(id);

      final t = p.topics.first;
      expect(t.isCompleted, isTrue);
      expect(t.review7Date!.difference(t.review30Date!).inDays, -23);
      expect(p.dueReviews(), isEmpty);
      expect(p.dueReviews(DateTime.now().add(const Duration(days: 7))).length, 1);
      expect(p.dueReviews(DateTime.now().add(const Duration(days: 31))).length, 2);

      await p.completeReview(id, 7);
      expect(p.dueReviews(DateTime.now().add(const Duration(days: 31))).length, 1);

      final reloaded = AppProvider(LocalStorage(await SharedPreferences.getInstance()));
      expect(reloaded.topics.first.isCompleted, isTrue);
      expect(reloaded.topics.first.review7Done, isTrue);
    });

    test('switching branch keeps progress of previous branch', () async {
      final p = await newProvider();
      final fieldTopic = p.topics.last;
      await p.toggleTopicCompleted(fieldTopic.id);
      await p.setBranch('ingilizce');
      expect(p.topics.any((t) => t.id == fieldTopic.id), isFalse);
      await p.setBranch('sinif');
      expect(p.topics.firstWhere((t) => t.id == fieldTopic.id).isCompleted, isTrue);
    });
  });

  test('models round-trip through toMap/fromMap', () {
    final s = StudySessionModel(
      id: '1', lessonName: 'Tarih', durationMinutes: 25,
      mode: StudyMode.stopwatch, createdAt: DateTime(2026, 1, 1),
    );
    expect(StudySessionModel.fromMap(s.toMap()).mode, StudyMode.stopwatch);
    expect(StudySessionModel.fromMap(s.toMap()).activity, StudyActivity.topic);
    // Sessions saved before the activity field: questions > 0 means a question session.
    final legacy = {...s.toMap()}..remove('activity');
    expect(StudySessionModel.fromMap({...legacy, 'solvedQuestions': 5}).activity, StudyActivity.questions);
    expect(StudySessionModel.fromMap({...legacy, 'solvedQuestions': 0}).activity, StudyActivity.topic);

    final e = ExamModel(
      id: 'e', title: 'Deneme 1', date: DateTime(2026, 1, 1),
      branchResults: {'Tarih': const BranchResult(correct: 10, wrong: 4, blank: 1)},
    );
    expect(ExamModel.fromMap(e.toMap()).branchResults['Tarih']!.net, 9);

    final t = const TopicModel(id: 'x', lessonName: 'a', topicName: 'b')
        .complete(DateTime(2026, 1, 1, 15));
    expect(TopicModel.fromMap(t.toMap()).review30Date, DateTime(2026, 1, 31));

    final a = AgendaModel(id: 'a', title: 't', date: DateTime(2026, 1, 1), googleEventId: 'g');
    expect(AgendaModel.fromMap(a.toMap()).googleEventId, 'g');
    expect(a.copyWith(clearGoogleEventId: true).googleEventId, isNull);
  });

  test('addSession adds minutes to topic; deleteSession takes them back', () async {
    final p = await newProvider();
    final topic = p.topics.first;
    await p.addSession(
      lessonName: topic.lessonName, topicId: topic.id, topicName: topic.topicName,
      durationMinutes: 25, mode: StudyMode.pomodoro,
      activity: StudyActivity.questions, solvedQuestions: 10,
    );
    // A topic-study session never carries a question count.
    await p.addSession(
      lessonName: 'Tarih', durationMinutes: 0, mode: StudyMode.pomodoro, solvedQuestions: 7,
    );
    expect(p.sessions.last.solvedQuestions, 0);
    await p.deleteSession(p.sessions.last.id);
    await p.addSession(lessonName: 'Tarih', durationMinutes: 40, mode: StudyMode.stopwatch);

    expect(p.totalStudyMinutes, 65);
    expect(p.topics.first.totalMinutes, 25);
    expect(p.sessionsOn(DateTime.now()).length, 2);
    expect(p.minutesByLesson.keys.first, 'Tarih');

    await p.deleteSession(p.sessions.firstWhere((s) => s.topicId == topic.id).id);
    expect(p.topics.first.totalMinutes, 0);
    expect(p.totalStudyMinutes, 40);
  });

  test('exams, notes and agenda CRUD persist', () async {
    final p = await newProvider();
    await p.saveExam(ExamModel(id: 'e1', title: 'A', date: DateTime(2026, 1, 1)));
    await p.saveExam(ExamModel(id: 'e2', title: 'B', date: DateTime(2026, 2, 1)));
    await p.saveExam(ExamModel(id: 'e1', title: 'A2', date: DateTime(2026, 1, 1)));
    expect(p.exams.map((e) => e.title), ['B', 'A2']); // newest first, updated in place

    await p.saveNote(NoteModel(id: 'n1', lessonName: 'Tarih', title: 'x', createdAt: DateTime(2026, 1, 2)));
    await p.saveNote(NoteModel(id: 'n2', title: 'y', isPinned: true, createdAt: DateTime(2026, 1, 1)));
    expect(p.notesIn(NoteStatus.active).first.id, 'n2'); // pinned first

    final day = DateTime(2026, 3, 3);
    await p.saveAgenda(AgendaModel(id: 'a1', title: 'öğle', date: day, startTime: '13:00'));
    await p.saveAgenda(AgendaModel(id: 'a2', title: 'sabah', date: day, startTime: '08:00'));
    expect(p.agendaOn(day).map((a) => a.id), ['a2', 'a1']);
    await p.toggleAgendaCompleted('a1');

    final reloaded = AppProvider(LocalStorage(await SharedPreferences.getInstance()));
    expect(reloaded.exams.length, 2);
    expect(reloaded.notes.length, 2);
    expect(reloaded.agendaOn(day).last.isCompleted, isTrue);

    await p.deleteExam('e1');
    await p.deleteNoteForever('n1');
    expect(await p.deleteAgenda('a1'), isNull);
    expect(p.exams.length, 1);
    expect(p.notes.length, 1);
    expect(p.agenda.length, 1);
  });

  group('notes', () {
    test('older notes are read with their photo, lesson and critical flag', () {
      final n = NoteModel.fromMap({
        'id': 'old', 'lessonName': 'Tarih', 'title': 'Lozan', 'content': 'madde',
        'localImagePath': '/x.jpg', 'isCritical': true, 'createdAt': '2026-01-01T10:00:00.000',
      });
      expect(n.imagePaths, ['/x.jpg']);
      expect(n.isPinned, isTrue);
      expect(n.lessonName, 'Tarih');
      expect(n.status, NoteStatus.active);
      expect(NoteModel.fromMap({'id': 'g', 'lessonName': '', 'createdAt': '2026-01-01T10:00:00.000'}).lessonName, isNull);

      final list = NoteModel(
        id: 'l', isChecklist: true, createdAt: DateTime(2026),
        checklist: const [ChecklistItem(id: 'a', text: 'süt', done: true)],
      );
      final back = NoteModel.fromMap(list.toMap());
      expect(back.checklist.single.done, isTrue);
      expect(back.isEmpty, isFalse);
      expect(NoteModel(id: 'e', isChecklist: true, createdAt: DateTime(2026)).isEmpty, isTrue);
    });

    test('archive, trash, restore and 30-day purge', () async {
      final p = await newProvider();
      await p.saveNote(NoteModel(id: 'a', title: 'a', createdAt: DateTime(2026, 1, 1)));
      await p.saveNote(NoteModel(id: 'b', title: 'b', createdAt: DateTime(2026, 1, 2)));
      await p.setNoteStatus('a', NoteStatus.archived);
      expect(p.notesIn(NoteStatus.active).map((n) => n.id), ['b']);
      expect(p.notesIn(NoteStatus.archived).single.id, 'a');

      await p.setNoteStatus('b', NoteStatus.trashed);
      expect(p.noteById('b')!.trashedAt, isNotNull);
      await p.purgeExpiredTrash(DateTime.now().add(const Duration(days: 29)));
      expect(p.noteById('b'), isNotNull); // still within 30 days
      await p.setNoteStatus('b', NoteStatus.active);
      expect(p.noteById('b')!.trashedAt, isNull);

      await p.setNoteStatus('b', NoteStatus.trashed);
      await p.purgeExpiredTrash(DateTime.now().add(const Duration(days: 31)));
      expect(p.noteById('b'), isNull);
    });

    test('drag & drop reorders and adopts the target pin state', () async {
      final p = await newProvider();
      for (final (i, id) in ['n1', 'n2', 'n3', 'n4'].indexed) {
        // Newer notes come first by default: n4, n3, n2, n1.
        await p.saveNote(NoteModel(id: id, title: id, createdAt: DateTime(2026, 1, 1 + i)));
      }
      List<String> order() => p.notesIn(NoteStatus.active).map((n) => n.id).toList();
      expect(order(), ['n4', 'n3', 'n2', 'n1']);
      await p.moveNote('n4', 'n2'); // moving down: lands after the target
      expect(order(), ['n3', 'n2', 'n4', 'n1']);
      await p.moveNote('n1', 'n3'); // moving up: lands before the target
      expect(order(), ['n1', 'n3', 'n2', 'n4']);

      await p.toggleNotePinned('n2');
      expect(order().first, 'n2');
      await p.moveNote('n4', 'n2'); // dropped on a pinned note -> pinned too
      expect(p.noteById('n4')!.isPinned, isTrue);
      expect(order().take(2).toSet(), {'n2', 'n4'});

      final reloaded = AppProvider(LocalStorage(await SharedPreferences.getInstance()));
      expect(reloaded.notesIn(NoteStatus.active).map((n) => n.id), order());
    });
  });

  test('exam stats: lesson averages and weak topic frequency', () {
    ExamModel exam(String id, int day, Map<String, BranchResult> r, List<String> weak) =>
        ExamModel(id: id, title: id, date: DateTime(2026, 1, day), branchResults: r, weakTopicIds: weak);
    final stats = ExamStats([
      exam('b', 2, {'Tarih': const BranchResult(correct: 8), 'Coğrafya': const BranchResult(correct: 2)}, ['t1', 't2']),
      exam('a', 1, {'Tarih': const BranchResult(correct: 4, wrong: 4)}, ['t1', 't1']),
    ]);
    expect(stats.exams.first.id, 'a'); // chronological
    final tarih = stats.lessonStats.first;
    expect(tarih.lesson, 'Tarih');
    expect(tarih.averageNet, 5.5); // (3 + 8) / 2
    expect(tarih.lastNet, 8);
    expect(stats.lessonStats.last.lesson, 'Coğrafya');
    expect(stats.weakTopicFrequency.first, isA<MapEntry<String, int>>()
        .having((e) => e.key, 'key', 't1')
        .having((e) => e.value, 'count', 2)); // duplicates in one exam count once
    final t = ExamStats.totals(stats.exams.last);
    expect((t.correct, t.wrong, t.blank), (10, 0, 0));
  });

  test('branch catalogue: 17 ÖABT fields, unique keys and lesson keys', () {
    final branches = AgsCurriculum.fieldBranches;
    expect(branches.where((b) => b.category == BranchCategory.oabt).length, 17);
    expect(branches.where((b) => b.category == BranchCategory.language).length, 11);
    expect(branches.map((b) => b.key).toSet().length, branches.length);
    final lessonKeys = [
      ...AgsCurriculum.commonLessons.map((l) => l.key),
      for (final b in branches) ...b.lessons.map((l) => l.key),
    ];
    expect(lessonKeys.toSet().length, lessonKeys.length); // topic ids never collide
    expect(AgsCurriculum.tryBranch('yok'), isNull);
  });

  test('official AGS 2026 distribution: 80 questions, weights add up', () {
    final ags = AgsCurriculum.commonLessons;
    expect(ags.map((l) => l.questions!).reduce((a, b) => a + b), AgsCurriculum.agsQuestions);
    expect(ags.map((l) => l.share!).reduce((a, b) => a + b), 100);
    for (final l in ags) {
      expect(l.questions, closeTo(l.share! * 80 / 100, 0.5), reason: l.name);
    }
    expect(ags.firstWhere((l) => l.key == 'egitim').topics.length, 11);
    expect(ags.firstWhere((l) => l.key == 'mevzuat').topics.map((t) => t.name),
        contains('7528 sayılı Öğretmenlik Mesleği Kanunu'));
  });

  test('every ÖABT field: weights total 100% and 50 questions', () {
    for (final b in AgsCurriculum.fieldBranches.where((b) => b.category == BranchCategory.oabt)) {
      var total = 0.0;
      for (final l in b.lessons) {
        final weighted = l.topics.where((t) => t.weight != null).toList();
        total += weighted.isEmpty ? l.share! : weighted.fold(0.0, (s, t) => s + t.weight!);
      }
      expect(total, closeTo(100, 0.001), reason: b.name);
      expect(b.lessons.fold(0, (s, l) => s + (l.questions ?? 0)), 50, reason: b.name);
      expect(b.oabtSections.fold(0, (s, x) => s + x.questions), 50, reason: b.name);
    }
    expect(AgsCurriculum.branchByKey('din').oabtSections.length, 3); // scored by subtest
    expect(AgsCurriculum.examSections('fizik').length, 7); // 6 AGS + ÖABT
    expect(AgsCurriculum.examSections('ingilizce').length, 6); // YDS is a separate exam
  });

  test('topic ids are unique and name based', () {
    final ids = <String>{};
    for (final l in [...AgsCurriculum.commonLessons, for (final b in AgsCurriculum.fieldBranches) ...b.lessons]) {
      for (var i = 0; i < l.topics.length; i++) {
        expect(ids.add(l.topicId(i)), isTrue, reason: l.topicId(i));
      }
    }
    expect(CurriculumLesson.slug('Çağdaş Türk ve Dünya Tarihi'), 'cagdas_turk_ve_dunya_tarihi');
    expect(CurriculumLesson.slug('İnsan Hakları Hukuku'), 'insan_haklari_hukuku');
  });

  test('legacy index-based progress and old default date are migrated', () async {
    final p = await newProvider({
      'topics': '[{"id":"sozel_0","lessonName":"Sözel Yetenek","topicName":"Sözcükte Anlam","isCompleted":true,'
          '"completedAt":"2026-01-01T00:00:00.000","review7Date":"2026-01-08T00:00:00.000","review7Done":false,'
          '"review30Date":"2026-01-31T00:00:00.000","review30Done":false,"totalMinutes":45}]',
      'exam_date': AppConstants.legacyDefaultExamDate.toIso8601String(),
    });
    final t = p.topics.firstWhere((t) => t.topicName == 'Sözcükte Anlam');
    expect(t.id, 'sozel_sozcukte_anlam');
    expect(t.isCompleted, isTrue);
    expect(t.totalMinutes, 45);
    expect(p.examDate, AppConstants.defaultExamDate);
    expect(AppConstants.defaultExamDate, DateTime(2027, 5, 8, 10, 15));
  });

  test('profile persists, syncs to a new device and is cleared on sign-out', () async {
    final db = <String, Map<String, Map<String, dynamic>>>{};
    late FakeCloud cloud;
    final p = await newProvider({}, (uid) => cloud = FakeCloud(uid, db));
    await p.setCloudUser('u1');
    expect(p.profile, isNull);
    await p.saveProfile(
      UserProfile(fullName: 'Ali Veli', status: CandidateStatus.graduate, dailyGoalMinutes: 90, createdAt: DateTime(2026)),
      branchKey: 'tarih_ogr',
    );
    expect(cloud.settings['profile'], isA<Map>());
    expect(AppProvider(LocalStorage(await SharedPreferences.getInstance())).profile?.fullName, 'Ali Veli');

    // A fresh device signing into the same account adopts the profile.
    final settings = cloud.settings;
    final other = await newProvider({}, (uid) => FakeCloud(uid, db)..settings = settings);
    await other.setCloudUser('u1');
    expect(other.profile?.firstName, 'Ali');
    expect(other.branchKey, 'tarih_ogr');

    await other.saveExam(ExamModel(id: 'x', title: 'X', date: DateTime(2026)));
    await other.clearUserData();
    expect(other.profile, isNull);
    expect(other.exams, isEmpty);
    expect(other.isCloudLinked, isFalse);
  });

  test('study streak and recent days', () async {
    final now = DateTime(2026, 3, 10, 20);
    String s(int day, int min) =>
        '{"id":"$day","lessonName":"Tarih","durationMinutes":$min,"mode":"pomodoro","createdAt":"2026-03-${day.toString().padLeft(2, '0')}T10:00:00.000"}';
    final p = await newProvider({'study_sessions': '[${s(10, 30)},${s(9, 20)},${s(8, 10)},${s(6, 50)}]'});
    expect(p.studyStreak(now), 3);
    expect(p.studyStreak(DateTime(2026, 3, 11, 9)), 3); // today empty: streak still alive
    expect(p.studyStreak(DateTime(2026, 3, 12, 9)), 0);
    final week = p.recentDays(7, now);
    expect(week.length, 7);
    expect(week.last.minutes, 30);
    expect(week.map((d) => d.minutes).reduce((a, b) => a + b), 110);
  });

  test('calendar sync without sign-in saves locally and warns', () async {
    final p = await newProvider();
    final warning = await p.saveAgenda(
      AgendaModel(id: 'a', title: 't', date: DateTime(2026, 1, 1), syncToGoogleCalendar: true),
    );
    expect(warning, contains('giriş'));
    expect(p.agenda.length, 1);
  });

  group('cloud sync', () {
    test('first link merges local and cloud (local wins), then uploads', () async {
      final db = <String, Map<String, Map<String, dynamic>>>{
        'exams': {
          'remote': ExamModel(id: 'remote', title: 'R', date: DateTime(2026, 1, 1)).toMap(),
          'both': ExamModel(id: 'both', title: 'cloud', date: DateTime(2026, 1, 1)).toMap(),
        },
      };
      final p = await newProvider({}, (uid) => FakeCloud(uid, db));
      await p.saveExam(ExamModel(id: 'both', title: 'local', date: DateTime(2026, 1, 1)));
      await p.saveExam(ExamModel(id: 'mine', title: 'M', date: DateTime(2026, 1, 1)));

      await p.setCloudUser('u1');
      expect(p.syncError, isNull);
      expect(p.exams.map((e) => e.id).toSet(), {'remote', 'both', 'mine'});
      expect(p.exams.firstWhere((e) => e.id == 'both').title, 'local');
      expect(db['exams']!.keys.toSet(), {'remote', 'both', 'mine'});
      expect(db['exams']!['both']!['title'], 'local');
    });

    test('later syncs treat cloud as authoritative (applies remote deletions)', () async {
      final db = <String, Map<String, Map<String, dynamic>>>{};
      final p = await newProvider({}, (uid) => FakeCloud(uid, db));
      await p.setCloudUser('u1');
      await p.saveExam(ExamModel(id: 'x', title: 'X', date: DateTime(2026, 1, 1)));
      expect(db['exams']!.containsKey('x'), isTrue); // mirrored on write

      db['exams']!.remove('x'); // deleted on another device
      await p.syncNow();
      expect(p.exams, isEmpty);
    });

    test('offline sync never wipes local data', () async {
      final db = <String, Map<String, Map<String, dynamic>>>{};
      late FakeCloud cloud;
      final p = await newProvider({}, (uid) => cloud = FakeCloud(uid, db));
      await p.setCloudUser('u1');
      await p.saveExam(ExamModel(id: 'x', title: 'X', date: DateTime(2026, 1, 1)));

      cloud.offline = true;
      await p.syncNow();
      expect(p.syncError, isNotNull);
      expect(p.exams.length, 1);
    });

    test('signing out unlinks; next sign-in merges again', () async {
      final db = <String, Map<String, Map<String, dynamic>>>{};
      final p = await newProvider({}, (uid) => FakeCloud(uid, db));
      await p.setCloudUser('u1');
      await p.setCloudUser(null);
      expect(p.isCloudLinked, isFalse);
      await p.saveExam(ExamModel(id: 'offline', title: 'O', date: DateTime(2026, 1, 1)));
      expect(db['exams'] ?? {}, isEmpty); // not mirrored while signed out
      await p.setCloudUser('u1');
      expect(p.exams.length, 1); // kept via merge, not wiped
      expect(db['exams']!.containsKey('offline'), isTrue);
    });
  });

  group('timer', () {
    test('pomodoro finishes work phase and moves to rest', () {
      var now = DateTime(2026, 1, 1, 10);
      final timer = StudyTimerController(clock: () => now);
      TimerPhase? finished;
      var sawNaturalFinish = false;
      timer.onPhaseFinished = (f) => finished = f;
      timer.addListener(() => sawNaturalFinish |= timer.isFinishingNaturally);

      timer.start();
      now = now.add(const Duration(minutes: 10));
      timer.pause();
      expect(timer.elapsed, const Duration(minutes: 10));
      now = now.add(const Duration(hours: 1)); // paused time doesn't count
      expect(timer.remaining, const Duration(minutes: 15));
      expect(sawNaturalFinish, isFalse);

      timer.start();
      now = now.add(const Duration(minutes: 15));
      timer.tick();
      expect(finished, TimerPhase.work);
      expect(sawNaturalFinish, isTrue);
      expect(timer.isFinishingNaturally, isFalse);
      expect(timer.phase, TimerPhase.rest);
      expect(timer.hasProgress, isFalse);
      timer.dispose();
    });

    test('stopwatch never auto-finishes; settings locked while running', () {
      var now = DateTime(2026, 1, 1, 10);
      final timer = StudyTimerController(clock: () => now)..setMode(StudyMode.stopwatch);
      timer.start();
      timer.setMode(StudyMode.pomodoro);
      now = now.add(const Duration(hours: 2));
      timer.tick();
      expect(timer.mode, StudyMode.stopwatch);
      expect(timer.elapsed.inMinutes, 120);
      timer.reset();
      expect(timer.hasProgress, isFalse);
      timer.dispose();
    });
  });

  group('widgets', () {
    testWidgets('dashboard renders countdown, stats and account button', (tester) async {
      final p = await newProvider({
        'study_sessions':
            '[{"id":"1","lessonName":"Tarih","durationMinutes":90,"mode":"pomodoro","createdAt":"2026-01-01T10:00:00.000"}]',
      });
      await pumpApp(tester, p);
      expect(find.text('Gün'), findsOneWidget);
      expect(find.text('1 sa 30 dk'), findsWidgets);
      expect(find.text('Bugünkü Tekrarlar'), findsOneWidget);

      expect(find.text('Bu Hafta'), findsOneWidget);
      expect(find.text('Bugünkü Hedef'), findsOneWidget);

      await tester.tap(find.byTooltip('Profilim'));
      await tester.pumpAndSettle();
      expect(find.text('Yerel mod'), findsOneWidget);
    });

    testWidgets('gate: profile form is required, then the app opens', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final p = await newProvider();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: p),
          ChangeNotifierProvider(create: (_) => AuthService(firebaseReady: false)),
        ],
        child: const MaterialApp(home: AuthGate()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Hoş geldin! 👋'), findsOneWidget);

      // Submitting empty shows validation and does not enter the app.
      await tester.tap(find.text('Başlayalım 🚀'));
      await tester.pumpAndSettle();
      expect(find.text('Ad soyad zorunludur.'), findsOneWidget);
      expect(find.text('Durumunu seç.'), findsOneWidget);
      expect(find.text('Öğretmenlik alanını seç.'), findsOneWidget);
      expect(p.profile, isNull);

      await tester.enterText(find.byType(TextFormField).first, 'Ayşe Yılmaz');
      await tester.tap(find.text('Mezun'));
      await tester.tap(find.text('Alanını seç'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'fizik');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fizik Öğretmenliği'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Başlayalım 🚀'));
      await tester.pumpAndSettle();

      expect(p.profile?.fullName, 'Ayşe Yılmaz');
      expect(p.branchKey, 'fizik');
      expect(p.topics.any((t) => t.lessonName == 'ÖABT – Fizik'), isTrue);
      expect(find.byType(HomeShell), findsOneWidget); // in the app now
      expect(find.textContaining('Ayşe 👋'), findsOneWidget); // greeting uses the name
    });

    testWidgets('save dialog asks questions vs topic first', (tester) async {
      SaveSessionResult? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => result = await showSaveSessionDialog(c, minutes: 25, subject: 'Tarih'),
            child: const Text('aç'),
          ),
        ),
      ));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing); // no count until "questions" is chosen
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(result, isNull); // save disabled without a choice

      await tester.tap(find.text('Soru çözdüm'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(result, (save: true, activity: StudyActivity.questions, solvedQuestions: 12));

      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Konu çalıştım'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(result, (save: true, activity: StudyActivity.topic, solvedQuestions: 0));
    });

    testWidgets('pomodoro tab and topics from the panel', (tester) async {
      final p = await newProvider();
      await pumpApp(tester, p);

      await tester.tap(find.text('Pomodoro').last);
      await tester.pump();
      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('Başlamak için aşağıdan bir ders seçin.'), findsOneWidget);

      // Topics live on the panel as a preview card that opens the full screen.
      expect(find.text('Konular'), findsNothing); // no longer a tab
      await tester.tap(find.text('Panel').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Tüm konuları aç'), 300);
      expect(find.text('Sözel Yetenek'), findsWidgets); // lesson progress peeks
      await tester.tap(find.text('Tüm konuları aç'));
      await tester.pumpAndSettle();
      expect(find.text('Konular'), findsOneWidget);
      await tester.tap(find.text('Tarih').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Osmanlı Öncesi Türk Devletleri Tarihi'));
      await tester.pumpAndSettle();
      expect(
        p.topics.firstWhere((t) => t.id == 'tarih_osmanli_oncesi_turk_devletleri_tarihi').isCompleted,
        isTrue,
      );
    });

    testWidgets('add an exam through the editor', (tester) async {
      final p = await newProvider();
      await pumpApp(tester, p);
      await tester.tap(find.text('Denemeler').last);
      await tester.pumpAndSettle();
      expect(find.text('Deneme Takibi'), findsOneWidget); // empty state

      await tester.tap(find.text('İlk Denemeni Ekle'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '10'); // Sözel (15 soru): Doğru
      await tester.enterText(fields.at(2), '4'); // Yanlış
      await tester.pumpAndSettle();
      expect(find.text('9.00'), findsOneWidget); // live total net
      expect(find.text('14 / 15 soru'), findsOneWidget);
      await tester.enterText(fields.at(3), '5'); // 10 + 4 + 5 > 15 questions
      await tester.pumpAndSettle();
      expect(find.text('Bu testte 15 soru var; toplam 19 girildi.'), findsOneWidget);
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(p.exams, isEmpty); // blocked
      await tester.enterText(fields.at(3), '');
      await tester.pumpAndSettle();
      expect(find.text('Net: 9.00'), findsOneWidget); // lesson net
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(p.exams.single.totalNet, 9);
      expect(find.text('Deneme Geçmişi'), findsOneWidget);
      expect(find.text('Ders Bazlı Performans'), findsOneWidget);
      expect(find.text('9.0'), findsOneWidget); // net bubble
    });

    testWidgets('add an agenda item and a note', (tester) async {
      final p = await newProvider();
      await pumpApp(tester, p);
      await tester.tap(find.text('Ajanda').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Ajandaya ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tarih tekrarı');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(p.agenda.single.title, 'Tarih tekrarı');
      expect(find.text('Tarih tekrarı'), findsOneWidget);

    });

    testWidgets('notes: quick note autosaves, checklist, archive with undo', (tester) async {
      final p = await newProvider();
      await pumpApp(tester, p);
      await tester.tap(find.text('Notlar').last);
      await tester.pumpAndSettle();
      expect(find.text('İlk notunu al'), findsOneWidget);

      // A note is saved just by leaving the editor; no lesson needed.
      await tester.tap(find.text('Bir not al…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Başlık'), 'Lozan maddeleri');
      await tester.enterText(find.widgetWithText(TextField, 'Not al…'), 'Boğazlar\nKapitülasyonlar');
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(p.notes.single.title, 'Lozan maddeleri');
      expect(p.notes.single.lessonName, isNull);
      expect(find.text('Lozan maddeleri'), findsOneWidget);

      // An empty new note is dropped.
      await tester.tap(find.text('Yeni not'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(p.notes.length, 1);

      // Text turns into a checklist line by line.
      await tester.tap(find.text('Lozan maddeleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Yapılacaklar listesi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('1 tamamlanan madde'), findsOneWidget);
      await tester.tap(find.byTooltip('Arşivle'));
      await tester.pumpAndSettle();
      final note = p.notes.single;
      expect(note.isChecklist, isTrue);
      expect(note.checklist.map((i) => (i.text, i.done)), [('Kapitülasyonlar', false), ('Boğazlar', true)]);
      expect(note.status, NoteStatus.archived);
      expect(find.text('Not arşivlendi'), findsOneWidget);

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(p.notes.single.status, NoteStatus.active);
    });
  });
}
