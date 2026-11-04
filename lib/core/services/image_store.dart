import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Note photos. Picked images are copied into the app documents directory,
/// because image_picker's own files live in a cache the OS may clear.
/// Not supported on web (no local file system).
class ImageStore {
  ImageStore._();

  static bool get isSupported => !kIsWeb;

  /// Returns the stored file path, or null if the user cancelled.
  static Future<String?> pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/note_images');
    await dir.create(recursive: true);
    final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
    final target = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await File(picked.path).copy(target);
    return target;
  }

  static Future<void> delete(String? path) async {
    if (path == null || !isSupported) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('ImageStore: could not delete $path: $e');
    }
  }
}
