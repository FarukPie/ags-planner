/// Shared (de)serialization helpers. Dates are stored as ISO-8601 strings so
/// the same maps work for SharedPreferences (JSON) and Cloud Firestore.
DateTime? parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String? dateToString(DateTime? value) => value?.toIso8601String();
