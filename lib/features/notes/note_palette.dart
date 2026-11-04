import 'package:flutter/material.dart';

/// Soft note colors that fit the app's violet/blue theme, with a matching
/// tone for dark mode. Index 0 is "no color" (the theme's card color).
class NotePalette {
  NotePalette._();

  static const _colors = <({String name, Color light, Color dark, Color dot})>[
    (name: 'Varsayılan', light: Color(0xFFFFFFFF), dark: Color(0xFF1F1D2B), dot: Color(0xFFFFFFFF)),
    (name: 'Lavanta', light: Color(0xFFEFE8FF), dark: Color(0xFF342A57), dot: Color(0xFF9B7BFF)),
    (name: 'Gökyüzü', light: Color(0xFFE2EDFF), dark: Color(0xFF1F3459), dot: Color(0xFF4F8DFD)),
    (name: 'Turkuaz', light: Color(0xFFD9F6F1), dark: Color(0xFF17433D), dot: Color(0xFF22C7B8)),
    (name: 'Nane', light: Color(0xFFE2F7E6), dark: Color(0xFF1F4128), dot: Color(0xFF3FC380)),
    (name: 'Limon', light: Color(0xFFFFF5D1), dark: Color(0xFF4A3F1A), dot: Color(0xFFFFC23D)),
    (name: 'Şeftali', light: Color(0xFFFFE6DA), dark: Color(0xFF52301F), dot: Color(0xFFFF8A5B)),
    (name: 'Gül', light: Color(0xFFFFE1EE), dark: Color(0xFF4F2438), dot: Color(0xFFFF6FAE)),
  ];

  static int get length => _colors.length;

  static String name(int i) => _colors[_safe(i)].name;

  /// Swatch shown in the color picker.
  static Color dot(int i) => _colors[_safe(i)].dot;

  /// Background for a note card / the editor; null = use the theme default.
  static Color? background(BuildContext context, int i) {
    if (_safe(i) == 0) return null;
    final c = _colors[_safe(i)];
    return Theme.of(context).brightness == Brightness.dark ? c.dark : c.light;
  }

  static int _safe(int i) => i >= 0 && i < _colors.length ? i : 0;
}
