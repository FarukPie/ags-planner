import 'package:flutter/material.dart';

import 'ags_curriculum_data.dart';
import 'app_theme.dart';

/// Icon + color for a lesson, so a lesson looks the same on every screen.
class LessonStyle {
  final IconData icon;
  final Color color;

  const LessonStyle(this.icon, this.color);

  /// AGS subtests (also matches names used by older app versions).
  static const _agsByKeyword = <String, LessonStyle>{
    'Sözel': LessonStyle(Icons.menu_book_rounded, Color(0xFF7B5CFA)),
    'Sayısal': LessonStyle(Icons.calculate_rounded, Color(0xFF4F7DF9)),
    'Tarih': LessonStyle(Icons.account_balance_rounded, Color(0xFFFF7A59)),
    'Coğrafya': LessonStyle(Icons.public_rounded, Color(0xFF00B8A9)),
    'Eğitim': LessonStyle(Icons.school_rounded, Color(0xFFFFB648)),
    'Mevzuat': LessonStyle(Icons.gavel_rounded, Color(0xFFE85D9E)),
  };

  static const _oabt = LessonStyle(Icons.workspace_premium_rounded, Color(0xFFFF7A59));

  static LessonStyle of(String lessonName) {
    // Field lessons ("ÖABT – …", "YDS – …") take their field's look, so e.g.
    // "ÖABT – Tarih" is not confused with the AGS Tarih subtest.
    if (lessonName.startsWith('ÖABT') || lessonName.startsWith('YDS') || lessonName.startsWith('Alan')) {
      if (lessonName == 'ÖABT') return _oabt;
      for (final b in AgsCurriculum.fieldBranches) {
        if (b.lessons.any((l) => l.name == lessonName)) return LessonStyle(b.icon, b.color);
      }
    } else {
      for (final e in _agsByKeyword.entries) {
        if (lessonName.contains(e.key)) return e.value;
      }
    }
    final palette = AppTheme.lessonPalette;
    final color = palette[lessonName.codeUnits.fold(0, (a, b) => a + b) % palette.length];
    return LessonStyle(Icons.workspace_premium_rounded, color);
  }
}
