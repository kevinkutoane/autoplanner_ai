import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:autoplanner_ai/services/calendar_sync_service.dart';
import 'package:autoplanner_ai/services/google_auth_service.dart';
import 'package:autoplanner_ai/core/models/calendar_event_model.dart';

class MockGoogleAuthService extends GoogleAuthService {
  @override
  bool get isConnected => true;

  @override
  Future<String?> getAccessToken() async => 'fake_token';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGoogleAuthService authService;
  late Box<CalendarEvent> calendarBox;
  late Box<dynamic> settingsBox;

  setUp(() async {
    Hive.init('test_hive_calendar');
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CalendarEventAdapter());
    }
    calendarBox = await Hive.openBox<CalendarEvent>('calendarBox');
    settingsBox = await Hive.openBox<dynamic>('settingsBox');
    authService = MockGoogleAuthService();
  });

  tearDown(() async {
    await calendarBox.clear();
    await settingsBox.clear();
    await Hive.deleteBoxFromDisk('calendarBox');
    await Hive.deleteBoxFromDisk('settingsBox');
    await Hive.close();
  });

  test('incrementalSync executes full sync when no syncToken exists', () async {
    bool didFullSync = false;
    final client = MockClient((request) async {
      // It should call with timeMin (full sync)
      if (request.url.query.contains('timeMin=')) {
        didFullSync = true;
      }
      return http.Response(jsonEncode({
        'items': [],
        'nextSyncToken': 'new_sync_token_123',
      }), 200);
    });

    final service = CalendarSyncService(
      googleAuth: authService,
      client: client,
    );

    final result = await service.incrementalSync();
    
    expect(result.hasError, isFalse);
    expect(didFullSync, isTrue);
    expect(settingsBox.get('google_calendar_sync_token'), equals('new_sync_token_123'));
  });

  test('incrementalSync uses syncToken and persists new token on success', () async {
    await settingsBox.put('google_calendar_sync_token', 'old_sync_token');
    
    bool usedSyncToken = false;
    final client = MockClient((request) async {
      if (request.url.query.contains('syncToken=old_sync_token')) {
        usedSyncToken = true;
      }
      return http.Response(jsonEncode({
        'items': [
          {
            'id': 'ext1',
            'status': 'confirmed',
            'summary': 'Test Event',
            'start': {'dateTime': '2026-04-21T10:00:00Z'},
            'end': {'dateTime': '2026-04-21T11:00:00Z'},
          }
        ],
        'nextSyncToken': 'new_sync_token_456',
      }), 200);
    });

    final service = CalendarSyncService(googleAuth: authService, client: client);
    final result = await service.incrementalSync();

    expect(result.hasError, isFalse);
    expect(result.pulled, equals(1));
    expect(usedSyncToken, isTrue);
    expect(settingsBox.get('google_calendar_sync_token'), equals('new_sync_token_456'));
    
    // Check that event was stored
    expect(calendarBox.length, equals(1));
    expect(calendarBox.values.first.title, equals('Test Event'));
  });

  test('incrementalSync falls back to full sync on 410 Gone', () async {
    await settingsBox.put('google_calendar_sync_token', 'invalid_sync_token');
    
    int callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      if (callCount == 1) {
        // Return 410 Gone for incremental request
        return http.Response('Gone', 410);
      } else {
        // Return success for fallback full request
        return http.Response(jsonEncode({
          'items': [],
          'nextSyncToken': 'fresh_sync_token',
        }), 200);
      }
    });

    final service = CalendarSyncService(googleAuth: authService, client: client);
    final result = await service.incrementalSync();

    expect(result.hasError, isFalse);
    expect(callCount, equals(2)); // Tried incremental, then full sync
    expect(settingsBox.get('google_calendar_sync_token'), equals('fresh_sync_token'));
  });

  test('cancelled events delete local counterparts', () async {
    // Add existing event
    final existingEvent = CalendarEvent(
      id: 'local1',
      title: 'To Be Deleted',
      startTime: DateTime.now(),
      endTime: DateTime.now(),
      externalId: 'ext_del_123',
    );
    await calendarBox.put(existingEvent.id, existingEvent);
    expect(calendarBox.length, equals(1));

    await settingsBox.put('google_calendar_sync_token', 'valid_token');

    final client = MockClient((request) async {
      return http.Response(jsonEncode({
        'items': [
          {
            'id': 'ext_del_123',
            'status': 'cancelled',
          }
        ],
        'nextSyncToken': 'token_next',
      }), 200);
    });

    final service = CalendarSyncService(googleAuth: authService, client: client);
    await service.incrementalSync();

    // Event should be deleted locally
    expect(calendarBox.length, equals(0));
  });

  test('syncToken is not persisted if pagination fails midway', () async {
    await settingsBox.put('google_calendar_sync_token', 'start_token');
    
    final client = MockClient((request) async {
      if (!request.url.query.contains('pageToken=')) {
        // First page success
        return http.Response(jsonEncode({
          'items': [
            {'id': 'item1', 'status': 'confirmed', 'start': {'date': '2026-04-21'}, 'end': {'date': '2026-04-21'}}
          ],
          'nextPageToken': 'page2',
        }), 200);
      } else {
        // Second page fails
        return http.Response('Internal Error', 500);
      }
    });

    final service = CalendarSyncService(googleAuth: authService, client: client);
    final result = await service.incrementalSync();

    // Sync fails
    expect(result.hasError, isTrue);
    // Box remains unmodified because it threw before storing anything
    expect(calendarBox.length, equals(0));
    // Old sync token should be retained
    expect(settingsBox.get('google_calendar_sync_token'), equals('start_token'));
  });
}
