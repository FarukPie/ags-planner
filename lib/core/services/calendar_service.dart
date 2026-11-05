import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:http/http.dart' as http;

import '../../models/agenda_model.dart';

/// Mirrors agenda items into the user's primary Google Calendar.
class CalendarService {
  static const scopes = [CalendarApi.calendarEventsScope];

  /// Creates or updates the event and returns its Google event id.
  Future<String> upsertEvent(AgendaModel item) => _withApi((api) async {
        final event = _toEvent(item);
        final saved = item.googleEventId == null
            ? await api.events.insert(event, 'primary')
            : await api.events.update(event, 'primary', item.googleEventId!);
        return saved.id!;
      });

  Future<void> deleteEvent(String eventId) =>
      _withApi((api) => api.events.delete('primary', eventId));

  Future<T> _withApi<T>(Future<T> Function(CalendarApi api) run) async {
    Map<String, String>? headers;
    try {
      headers = await GoogleSignIn.instance.authorizationClient
          .authorizationHeaders(scopes, promptIfNecessary: true);
    } on GoogleSignInException catch (e) {
      debugPrint('Calendar authorization failed: ${e.code} ${e.description}');
      throw const CalendarAccessDenied();
    }
    if (headers == null) throw const CalendarAccessDenied();
    final client = _HeaderClient(headers);
    try {
      return await run(CalendarApi(client));
    } on DetailedApiRequestError catch (e) {
      if (e.status == 401 || e.status == 403) throw const CalendarAccessDenied();
      rethrow;
    } finally {
      client.close();
    }
  }

  Event _toEvent(AgendaModel item) {
    final day = DateTime(item.date.year, item.date.month, item.date.day);
    final start = _at(day, item.startTime);
    if (start == null) {
      // All-day event: end date is exclusive.
      return Event(
        summary: item.title,
        start: EventDateTime(date: day),
        end: EventDateTime(date: day.add(const Duration(days: 1))),
      );
    }
    var end = _at(day, item.endTime);
    if (end == null || !end.isAfter(start)) end = start.add(const Duration(hours: 1));
    return Event(
      summary: item.title,
      start: EventDateTime(dateTime: start),
      end: EventDateTime(dateTime: end),
    );
  }

  DateTime? _at(DateTime day, String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }
}

/// The user (or Google, for an account the app isn't cleared for yet)
/// refused Calendar access.
class CalendarAccessDenied implements Exception {
  const CalendarAccessDenied();

  @override
  String toString() => 'Google Takvim izni verilmedi. Takvim erişimine izin verip tekrar dene.';
}

class _HeaderClient extends http.BaseClient {
  _HeaderClient(this._headers);

  final Map<String, String> _headers;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
