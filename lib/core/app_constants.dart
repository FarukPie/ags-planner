class AppConstants {
  AppConstants._();

  static const appTitle = 'AGS Çalışma Asistanı';

  /// 2027-MEB-AGS (ÖSYM 2027 Yılı Sınav Takvimi, 28.10.2026).
  /// Session times come with the exam guide; 10.15 is ÖSYM's usual AGS start.
  static final defaultExamDate = DateTime(2027, 5, 8, 10, 15);

  /// 2027-MEB-AGS-ÖABT is held the next day (09.05.2027).
  static final officialOabtDate = DateTime(2027, 5, 9, 10, 15);

  /// Earlier releases defaulted to this placeholder; migrated to the official date.
  static final legacyDefaultExamDate = DateTime(2027, 7, 11, 10, 15);

  /// Official 2027 MEB-AGS milestones (ÖSYM 2027 takvimi).
  static final officialMilestones = <({String label, DateTime date})>[
    (label: 'Başvurular başlıyor', date: DateTime(2027, 3, 19)),
    (label: 'Başvurular bitiyor', date: DateTime(2027, 3, 29, 23, 59)),
    (label: 'Geç başvuru günü', date: DateTime(2027, 4, 6)),
    (label: 'AGS', date: defaultExamDate),
    (label: 'ÖABT', date: officialOabtDate),
    (label: 'Sonuçlar açıklanıyor', date: DateTime(2027, 6, 11)),
  ];

  static const defaultBranchKey = 'sinif';

  /// Firebase user ids (opaque, not personal data) that get the 1-minute
  /// pomodoro/rest option for testing.
  static const testerUids = {'N0W1kLTrzuZfVQf3Z4MmXWdOSvz1'};
}

/// SharedPreferences keys. Values are JSON so they mirror Firestore documents.
class StorageKeys {
  StorageKeys._();

  static const examDate = 'exam_date';
  static const branchKey = 'branch_key';
  static const themeMode = 'theme_mode'; // device-only, not synced
  static const profile = 'profile';
  static const topics = 'topics';
  static const sessions = 'study_sessions';
  static const exams = 'exams';
  static const notes = 'notes';
  static const agenda = 'agenda';

  /// Uid whose data was last merged with this device's local data.
  static const syncedUid = 'synced_uid';

  /// Collections mirrored to Firestore (`users/{uid}/{key}`).
  static const syncedCollections = [topics, sessions, exams, notes, agenda];
}
