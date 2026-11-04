import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Notes no longer take photos. Earlier versions copied picked photos into
/// `<app documents>/note_images`; nothing references them any more, so this
/// removes that folder to give the space back. Safe to call on every start.
class LegacyNotePhotos {
  LegacyNotePhotos._();

  static Future<void> deleteAll() async {
    if (kIsWeb) return;
    try {
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/note_images');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('LegacyNotePhotos: could not clean up: $e');
    }
  }
}
