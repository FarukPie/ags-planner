import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline-first local persistence (JSON in SharedPreferences).
/// Works with no Firebase configuration at all.
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  /// Reads a list of maps. Corrupt data is logged and treated as empty
  /// rather than crashing the app on startup.
  List<Map<String, dynamic>> getMaps(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('LocalStorage: could not decode "$key": $e');
      return [];
    }
  }

  Future<void> setMaps(String key, Iterable<Map<String, dynamic>> maps) =>
      _prefs.setString(key, jsonEncode(maps.toList()));
}
