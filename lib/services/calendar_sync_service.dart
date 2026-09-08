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
  final http.Client _client;

  CalendarSyncService({
    required GoogleAuthService googleAuth,
    http.Client? client,
  })  : _googleAuth = googleAuth,
        _client = client ?? http.Client();

  Box<CalendarEvent> get _box => Hive.box<CalendarEvent>('calendarBox');

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Full initial sync: pull all events from Google (from 3 months ago), reconcile with local,
  /// and obtain a new sync token.
  Future<SyncResult> fullSync() async {
    if (!_googleAuth.isConnected) {
      return const SyncResult(error: 'Not connected to Google Calendar.');
    }
    try {
      final token = await _googleAuth.getAccessToken();
      if (token == null) {
        return const SyncResult(error: 'Could not obtain access token.');
      }
      final fetchResult = await _pullAll(token);
      final pushed = await _pushPending(token);
      
      if (fetchResult.nextSyncToken != null) {
        final settingsBox = Hive.box<dynamic>('settingsBox');
        await settingsBox.put('google_calendar_sync_token', fetchResult.nextSyncToken);
      }
      
      return SyncResult(pulled: fetchResult.count, pushed: pushed);
    } catch (e) {
      if (kDebugMode) debugPrint('CalendarSync.fullSync error: $e');
      return SyncResult(error: e.toString());
    }
  }

  /// Incremental sync: uses Google Calendar's syncToken mechanism to efficiently pull changes.
  Future<SyncResult> incrementalSync() async {
    if (!_googleAuth.isConnected) {
      return const SyncResult(error: 'Not connected to Google Calendar.');
    }
    try {
      final settingsBox = Hive.box<dynamic>('settingsBox');
      final syncToken = settingsBox.get('google_calendar_sync_token') as String?;
      
      if (syncToken == null) {
        // Fallback to full sync if no token is available
        return await fullSync();
      }

      final token = await _googleAuth.getAccessToken();
      if (token == null) {
        return const SyncResult(error: 'Could not obtain access token.');
      }
      
      final fetchResult = await _pullWithSyncToken(token, syncToken);
      final pushed = await _pushPending(token);
      
      if (fetchResult.nextSyncToken != null) {
        await settingsBox.put('google_calendar_sync_token', fetchResult.nextSyncToken);
      }
      
      return SyncResult(pulled: fetchResult.count, pushed: pushed);
    } on _SyncTokenInvalidatedException {
      if (kDebugMode) debugPrint('CalendarSync.incrementalSync: Sync token invalidated (410). Doing full sync.');
      final settingsBox = Hive.box<dynamic>('settingsBox');
      await settingsBox.delete('google_calendar_sync_token');
      return fullSync();
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

  Future<_FetchResult> _pullAll(String token) async {
    final now = DateTime.now();
    // Start pulling events from 3 months ago (or beginning of that month)
    final timeMin = DateTime(now.year, now.month - 3, 1).toUtc().toIso8601String();

    final uri = Uri.parse(
      '$_baseUrl/calendars/$_calendarId/events'
      '?timeMin=${Uri.encodeComponent(timeMin)}'
      '&singleEvents=true'
      '&orderBy=startTime'
      '&maxResults=500',
    );
    return _fetchAndStore(token, uri);
  }

  Future<_FetchResult> _pullWithSyncToken(String token, String syncToken) async {
    final uri = Uri.parse(
      '$_baseUrl/calendars/$_calendarId/events'
      '?syncToken=${Uri.encodeComponent(syncToken)}'
      '&maxResults=200',
    );
    return _fetchAndStore(token, uri);
  }

  Future<_FetchResult> _fetchAndStore(String token, Uri uri) async {
    int count = 0;
    String? pageToken;
    String? nextSyncToken;
    
    // Store all raw items first to ensure we completely fetch before processing.
    // If the network fails partway, we throw, and don't persist nextSyncToken.
    final allItems = <Map<String, dynamic>>[];
    
    do {
      final pageUri = pageToken != null
          ? uri.replace(
              queryParameters: {...uri.queryParameters, 'pageToken': pageToken},
            )
          : uri;

      final response = await _client.get(
        pageUri,
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 410) {
        throw _SyncTokenInvalidatedException();
      }
      if (response.statusCode != 200) {
        throw Exception(
          'Google Calendar API error ${response.statusCode}: ${response.body}',
        );
      }
      
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>?) ?? [];
      
      for (final item in items) {
        allItems.add(item as Map<String, dynamic>);
      }
      
      pageToken = data['nextPageToken'] as String?;
      nextSyncToken = data['nextSyncToken'] as String?;
    } while (pageToken != null);
    
    // Completely paginated fetch finished. Process all changes.
    for (final item in allItems) {
      _storeGoogleEvent(item);
      count++;
    }
    
    return _FetchResult(count, nextSyncToken);
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

    if (item['status'] == 'cancelled') {
      if (!isNew) {
        _box.delete(existing.id);
      }
      return;
    }

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
    final response = await _client.post(
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
    final response = await _client.put(
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

class _FetchResult {
  final int count;
  final String? nextSyncToken;
  const _FetchResult(this.count, this.nextSyncToken);
}

class _SyncTokenInvalidatedException implements Exception {}
