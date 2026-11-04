import 'model_utils.dart';

/// Where the candidate currently stands.
enum CandidateStatus {
  student('Son sınıf öğrencisi'),
  graduate('Mezun'),
  pedagogicalFormation('Pedagojik formasyon'),
  teacher('Öğretmen (atama/kurum değişikliği)');

  const CandidateStatus(this.label);

  final String label;
}

/// Profile the user fills in after signing in. The selected teaching field is
/// stored separately (AppProvider.branchKey) because the curriculum depends on it.
class UserProfile {
  final String fullName;
  final CandidateStatus status;
  final int dailyGoalMinutes;
  final String? university;
  final double? targetScore;
  final DateTime createdAt;

  const UserProfile({
    required this.fullName,
    required this.status,
    required this.dailyGoalMinutes,
    this.university,
    this.targetScore,
    required this.createdAt,
  });

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  /// "Faruk Atak" → "FA".
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    return parts.length == 1 ? first.toUpperCase() : (first + parts.last[0]).toUpperCase();
  }

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'status': status.name,
        'dailyGoalMinutes': dailyGoalMinutes,
        'university': university,
        'targetScore': targetScore,
        'createdAt': dateToString(createdAt),
      };

  /// Returns null for missing/invalid data, which sends the user back to the
  /// profile form instead of crashing.
  static UserProfile? tryFromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final name = (map['fullName'] as String?)?.trim() ?? '';
    final status = CandidateStatus.values.asNameMap()[map['status']];
    final goal = (map['dailyGoalMinutes'] as num?)?.toInt() ?? 0;
    if (name.isEmpty || status == null || goal <= 0) return null;
    return UserProfile(
      fullName: name,
      status: status,
      dailyGoalMinutes: goal,
      university: (map['university'] as String?)?.trim().isEmpty ?? true ? null : map['university'] as String,
      targetScore: (map['targetScore'] as num?)?.toDouble(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }
}
