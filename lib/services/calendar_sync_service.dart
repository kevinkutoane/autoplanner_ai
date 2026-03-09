import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../core/models/calendar_event_model.dart';
import 'google_auth_service.dart';

/// Result from a sync operation.
class SyncResult {
  final int pulled;
  final int pushed;
  final int conflicts;
  final String? error;
  const SyncResult({
    this.pulled = 0,
    this.pushed = 0,
    this.conflicts = 0,
    this.error,
  });
  bool get hasError => error != null;
}

/// Bidirectional sync between local Hive calendar and Google Calendar.
///
/// Sync lifecycle per event:
///   'local'        — created locally, never pushed
///   'pending_push' — modified locally, needs push
///   'synced'       — in sync with provider
///   'conflict'     — local and remote diverged
class CalendarSyncService {
  static const _uuid = Uuid();
  static const _baseUrl = 'https://www.googleapis.com/calendar/v3';
  static const _calendarId = 'primary';

  final GoogleAuthService _googleAuth;

  CalendarSyncService({required GoogleAuthService googleAuth})
    : _googleAuth = googleAuth;

  Box<CalendarEvent> get _box => Hive.box<CalendarEvent>('calendarBox');

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Full initial sync: pull all events from Google, reconcile with local.
  Future<SyncResult> fullSync() async {
    if (!_googleAuth.isConnected) {
      return const SyncResult(error: 'Not connected to Google Calendar.');
    }
    try {
      final token = await _googleAuth.getAccessToken();
      if (token == null) {
        return const SyncResult(error: 'Could not obtain access token.');
      }
      final pulled = await _pullAll(token);
      final pushed = await _pushPending(token);
      return SyncResult(pulled: pulled, pushed: pushed);
    } catch (e) {
      if (kDebugMode) debugPrint('CalendarSync.fullSync error: $e');
      return SyncResult(error: e.toString());
    }
  }

  /// Incremental sync: only pull events changed since last sync.
  Future<SyncResult> incrementalSync() async {
    if (!_googleAuth.isConnected) {
      return const SyncResult(error: 'Not connected to Google Calendar.');
    }
    try {
      final token = await _googleAuth.getAccessToken();
      if (token == null) {
        return const SyncResult(error: 'Could not obtain access token.');
      }
      // Pull events modified in the past 7 days (simple delta heuristic).
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final pulled = await _pullSince(token, cutoff);
      final pushed = await _pushPending(token);
      return SyncResult(pulled: pulled, pushed: pushed);
    } catch (e) {
      if (kDebugMode) debugPrint('CalendarSync.incrementalSync error: $e');
      return SyncResult(error: e.toString());
    }
  }

  /// Push a single local event to Google Calendar.
  Future<bool> pushEvent(CalendarEvent event) async {
    final token = await _googleAuth.getAccessToken();
    if (token == null) return false;
    try {
      if (event.externalId != null) {
        await _updateGoogleEvent(token, event);
      } else {
        await _createGoogleEvent(token, event);
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('CalendarSync.pushEvent error: $e');
      return false;
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  Future<int> _pullAll(String token) async {
    final now = DateTime.now();
    final timeMin = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
    final timeMax = DateTime(
      now.year,
      now.month + 3,
      0,
    ).toUtc().toIso8601String();

    final uri = Uri.parse(
      '$_baseUrl/calendars/$_calendarId/events'
      '?timeMin=${Uri.encodeComponent(timeMin)}'
      '&timeMax=${Uri.encodeComponent(timeMax)}'
      '&singleEvents=true'
      '&orderBy=startTime'
      '&maxResults=500',
    );
    return _fetchAndStore(token, uri);
  }

  Future<int> _pullSince(String token, DateTime since) async {
    final timeMin = since.toUtc().toIso8601String();
    final uri = Uri.parse(
      '$_baseUrl/calendars/$_calendarId/events'
      '?timeMin=${Uri.encodeComponent(timeMin)}'
      '&singleEvents=true'
      '&orderBy=updated'
      '&maxResults=200',
    );
    return _fetchAndStore(token, uri);
  }

  Future<int> _fetchAndStore(String token, Uri uri) async {
    int count = 0;
    String? pageToken;
    do {
      final pageUri = pageToken != null
          ? uri.replace(
              queryParameters: {...uri.queryParameters, 'pageToken': pageToken},
            )
          : uri;

      final response = await http.get(
        pageUri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception(
          'Google Calendar API error ${response.statusCode}: ${response.body}',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>?) ?? [];
      for (final item in items) {
        _storeGoogleEvent(item as Map<String, dynamic>);
        count++;
      }
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);
    return count;
  }

  void _storeGoogleEvent(Map<String, dynamic> item) {
    final externalId = item['id'] as String;
    final etag = item['etag'] as String?;

    // Check if we already have this event locally.
    final existing = _box.values.firstWhere(
      (e) => e.externalId == externalId,
      orElse: () => CalendarEvent(
        id: _uuid.v4(),
        title: '',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      ),
    );

    final isNew = existing.externalId == null;

    final startRaw = item['start'] as Map<String, dynamic>?;
    final endRaw = item['end'] as Map<String, dynamic>?;
    final isAllDay = startRaw?.containsKey('date') ?? false;

    DateTime parseTime(Map<String, dynamic>? raw) {
      if (raw == null) return DateTime.now();
      final str = (raw['dateTime'] ?? raw['date']) as String?;
      if (str == null) return DateTime.now();
      return DateTime.tryParse(str) ?? DateTime.now();
    }

    // If local is pending_push, flag as conflict instead of overwriting.
    if (!isNew &&
        existing.syncStatus == 'pending_push' &&
        existing.etag != etag) {
      existing
        ..syncStatus = 'conflict'
        ..etag = etag
        ..save();
      return;
    }

    final updated = existing.copyWith(
      title: (item['summary'] as String?) ?? '(no title)',
      description: item['description'] as String?,
      startTime: parseTime(startRaw),
      endTime: parseTime(endRaw),
      source: 'google',
      externalId: externalId,
      externalCalendarId: item['organizer']?['email'] as String?,
      syncStatus: 'synced',
      etag: etag,
      lastSyncedAt: DateTime.now(),
      isAllDay: isAllDay,
    );

    if (isNew) {
      _box.put(updated.id, updated);
    } else {
      existing
        ..title = updated.title
        ..description = updated.description
        ..startTime = updated.startTime
        ..endTime = updated.endTime
        ..source = 'google'
        ..externalId = updated.externalId
        ..externalCalendarId = updated.externalCalendarId
        ..syncStatus = 'synced'
        ..etag = updated.etag
        ..lastSyncedAt = updated.lastSyncedAt
        ..isAllDay = updated.isAllDay
        ..save();
    }
  }

  Future<int> _pushPending(String token) async {
    final pending = _box.values
        .where((e) => e.syncStatus == 'pending_push')
        .toList();
    int count = 0;
    for (final event in pending) {
      try {
        if (event.externalId != null) {
          await _updateGoogleEvent(token, event);
        } else {
          await _createGoogleEvent(token, event);
        }
        count++;
      } catch (e) {
        if (kDebugMode) debugPrint('Push failed for ${event.id}: $e');
      }
    }
    return count;
  }

  Future<void> _createGoogleEvent(String token, CalendarEvent event) async {
    final body = _eventToGoogleJson(event);
    final response = await http.post(
      Uri.parse('$_baseUrl/calendars/$_calendarId/events'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      event
        ..externalId = data['id'] as String?
        ..etag = data['etag'] as String?
        ..syncStatus = 'synced'
        ..lastSyncedAt = DateTime.now()
        ..source = 'google'
        ..save();
    } else {
      throw Exception(
        'Create event failed ${response.statusCode}: ${response.body}',
      );
    }
  }

  Future<void> _updateGoogleEvent(String token, CalendarEvent event) async {
    final body = _eventToGoogleJson(event);
    final response = await http.put(
      Uri.parse('$_baseUrl/calendars/$_calendarId/events/${event.externalId}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      event
        ..etag = data['etag'] as String?
        ..syncStatus = 'synced'
        ..lastSyncedAt = DateTime.now()
        ..save();
    } else {
      throw Exception(
        'Update event failed ${response.statusCode}: ${response.body}',
      );
    }
  }

  Map<String, dynamic> _eventToGoogleJson(CalendarEvent event) {
    if (event.isAllDay) {
      final dateStr =
          '${event.startTime.year.toString().padLeft(4, '0')}-'
          '${event.startTime.month.toString().padLeft(2, '0')}-'
          '${event.startTime.day.toString().padLeft(2, '0')}';
      return {
        'summary': event.title,
        if (event.description != null) 'description': event.description,
        'start': {'date': dateStr},
        'end': {'date': dateStr},
      };
    }
    return {
      'summary': event.title,
      if (event.description != null) 'description': event.description,
      'start': {'dateTime': event.startTime.toUtc().toIso8601String()},
      'end': {'dateTime': event.endTime.toUtc().toIso8601String()},
    };
  }
}
