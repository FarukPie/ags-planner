import 'package:cloud_firestore/cloud_firestore.dart';

/// Thin Firestore wrapper. Layout: `users/{uid}` holds settings fields and one
/// subcollection per data type, documents keyed by the item's `id`.
///
/// Firestore's own offline persistence queues writes while offline, so callers
/// fire-and-forget writes and never block the UI on the network.
class CloudSyncService {
  CloudSyncService(this.uid);

  final String uid;

  DocumentReference<Map<String, dynamic>> get _user =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  Future<void> upsert(String collection, Map<String, dynamic> data) =>
      _user.collection(collection).doc(data['id'] as String).set(data);

  Future<void> delete(String collection, String id) =>
      _user.collection(collection).doc(id).delete();

  /// True when every queued write reached the server within [timeout].
  Future<bool> flushPendingWrites(Duration timeout) async {
    try {
      await FirebaseFirestore.instance.waitForPendingWrites().timeout(timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setSettings(Map<String, dynamic> settings) =>
      _user.set(settings, SetOptions(merge: true));

  /// Server settings, or null if the server could not be reached.
  Future<Map<String, dynamic>?> getSettings() async {
    final snap = await _user.get();
    return snap.metadata.isFromCache ? null : snap.data() ?? {};
  }

  /// Server documents of [collection], or null if the result came only from
  /// the local cache (offline). Callers must not treat null as "empty":
  /// replacing local data with a cache miss would lose data.
  Future<List<Map<String, dynamic>>?> pullAll(String collection) async {
    final snap = await _user.collection(collection).get();
    if (snap.metadata.isFromCache) return null;
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Queues many writes in batches (Firestore limit: 500 ops per batch).
  /// Commits are not awaited: offline they would wait for the network.
  void pushAll(String collection, List<Map<String, dynamic>> items, void Function(Object) onError) {
    final ref = _user.collection(collection);
    for (var i = 0; i < items.length; i += 450) {
      final batch = FirebaseFirestore.instance.batch();
      for (final item in items.skip(i).take(450)) {
        batch.set(ref.doc(item['id'] as String), item);
      }
      batch.commit().catchError(onError);
    }
  }
}
