import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:autoplanner_ai/services/calendar_sync_service.dart';
import 'package:autoplanner_ai/services/google_auth_service.dart';
import 'package:autoplanner_ai/core/models/calendar_event_model.dart';

class MockGoogleAuthService extends GoogleAuthService {
  final bool connected;
  final String? token;

  MockGoogleAuthService({this.connected = true, this.token = 'fake_token'});

  @override
  bool get isConnected => connected;

  @override
  Future<String?> getAccessToken() async => token;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockGoogleAuthService authService;
  late Box<CalendarEvent> calendarBox;
  late Box<dynamic> settingsBox;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('cal_sync_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CalendarEventAdapter());
    }
    calendarBox = await Hive.openBox<CalendarEvent>('calendarBox');
    settingsBox = await Hive.openBox<dynamic>('settingsBox');
    authService = MockGoogleAuthService();
  });

  tearDown(() async {
    await Hive.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('incrementalSync executes full sync when no syncToken exists', () async {
    bool didFullSync = false;
    final client = MockClient((request) async {
      // It should call with timeMin (full sync)
      if (request.url.query.contains('timeMin=')) {
        didFullSync = true;
      }
      return http.Response(
        jsonEncode({'items': [], 'nextSyncToken': 'new_sync_token_123'}),
        200,
      );
    });

    final service = CalendarSyncService(
      googleAuth: authService,
      client: client,
    );

    final result = await service.incrementalSync();

    expect(result.hasError, isFalse);
    expect(didFullSync, isTrue);
    expect(
      settingsBox.get('google_calendar_sync_token'),
      equals('new_sync_token_123'),
    );
  });

  test(
    'incrementalSync uses syncToken and persists new token on success',
    () async {
      await settingsBox.put('google_calendar_sync_token', 'old_sync_token');

      bool usedSyncToken = false;
      final client = MockClient((request) async {
        if (request.url.query.contains('syncToken=old_sync_token')) {
          usedSyncToken = true;
        }
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'ext1',
                'status': 'confirmed',
                'summary': 'Test Event',
                'start': {'dateTime': '2026-04-21T10:00:00Z'},
                'end': {'dateTime': '2026-04-21T11:00:00Z'},
              },
            ],
            'nextSyncToken': 'new_sync_token_456',
          }),
          200,
        );
      });

      final service = CalendarSyncService(
        googleAuth: authService,
        client: client,
      );
      final result = await service.incrementalSync();

      expect(result.hasError, isFalse);
      expect(result.pulled, equals(1));
      expect(usedSyncToken, isTrue);
      expect(
        settingsBox.get('google_calendar_sync_token'),
        equals('new_sync_token_456'),
      );

      // Check that event was stored
      expect(calendarBox.length, equals(1));
      expect(calendarBox.values.first.title, equals('Test Event'));
    },
  );

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
        return http.Response(
          jsonEncode({'items': [], 'nextSyncToken': 'fresh_sync_token'}),
          200,
        );
      }
    });

    final service = CalendarSyncService(
      googleAuth: authService,
      client: client,
    );
    final result = await service.incrementalSync();

    expect(result.hasError, isFalse);
    expect(callCount, equals(2)); // Tried incremental, then full sync
    expect(
      settingsBox.get('google_calendar_sync_token'),
      equals('fresh_sync_token'),
    );
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
      return http.Response(
        jsonEncode({
          'items': [
            {'id': 'ext_del_123', 'status': 'cancelled'},
          ],
          'nextSyncToken': 'token_next',
        }),
        200,
      );
    });

    final service = CalendarSyncService(
      googleAuth: authService,
      client: client,
    );
    await service.incrementalSync();

    // Event should be deleted locally
    expect(calendarBox.length, equals(0));
  });

  test('syncToken is not persisted if pagination fails midway', () async {
    await settingsBox.put('google_calendar_sync_token', 'start_token');

    final client = MockClient((request) async {
      if (!request.url.query.contains('pageToken=')) {
        // First page success
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'item1',
                'status': 'confirmed',
                'start': {'date': '2026-04-21'},
                'end': {'date': '2026-04-21'},
              },
            ],
            'nextPageToken': 'page2',
          }),
          200,
        );
      } else {
        // Second page fails
        return http.Response('Internal Error', 500);
      }
    });

    final service = CalendarSyncService(
      googleAuth: authService,
      client: client,
    );
    final result = await service.incrementalSync();

    // Sync fails
    expect(result.hasError, isTrue);
    // Box remains unmodified because it threw before storing anything
    expect(calendarBox.length, equals(0));
    // Old sync token should be retained
    expect(
      settingsBox.get('google_calendar_sync_token'),
      equals('start_token'),
    );
  });

  test(
    'incrementalSync returns error when not connected and preserves syncToken',
    () async {
      await settingsBox.put('google_calendar_sync_token', 'saved_token_123');
      final disconnectedAuth = MockGoogleAuthService(connected: false);
      final service = CalendarSyncService(googleAuth: disconnectedAuth);

      final result = await service.incrementalSync();

      expect(result.hasError, isTrue);
      expect(result.error, contains('Not connected'));
      expect(
        settingsBox.get('google_calendar_sync_token'),
        equals('saved_token_123'),
      );
    },
  );

  test(
    'fullSync returns error when access token is null and preserves syncToken',
    () async {
      await settingsBox.put('google_calendar_sync_token', 'saved_token_456');
      final nullTokenAuth = MockGoogleAuthService(connected: true, token: null);
      final service = CalendarSyncService(googleAuth: nullTokenAuth);

      final result = await service.fullSync();

      expect(result.hasError, isTrue);
      expect(result.error, contains('Could not obtain access token'));
      expect(
        settingsBox.get('google_calendar_sync_token'),
        equals('saved_token_456'),
      );
    },
  );

  test(
    'bidirectional sync pushes pending local events and pulls remote events',
    () async {
      await settingsBox.put('google_calendar_sync_token', 'sync_token_bi');

      // Local event ready to push
      final localEvent = CalendarEvent(
        id: 'local_push_1',
        title: 'Local Event To Push',
        startTime: DateTime(2026, 4, 21, 9, 0),
        endTime: DateTime(2026, 4, 21, 10, 0),
        syncStatus: 'pending_push',
      );
      await calendarBox.put(localEvent.id, localEvent);

      bool pushCalled = false;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.contains('/events')) {
          pushCalled = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['summary'], equals('Local Event To Push'));
          return http.Response(
            jsonEncode({
              'id': 'google_created_123',
              'etag': 'etag_created_123',
              'summary': 'Local Event To Push',
            }),
            201,
          );
        }
        if (request.method == 'GET' && request.url.path.contains('/events')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'remote_event_789',
                  'etag': 'etag_remote_789',
                  'summary': 'Remote Event Pulled',
                  'start': {'dateTime': '2026-04-21T14:00:00Z'},
                  'end': {'dateTime': '2026-04-21T15:00:00Z'},
                },
              ],
              'nextSyncToken': 'new_sync_token_bi_complete',
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = CalendarSyncService(
        googleAuth: authService,
        client: client,
      );
      final result = await service.incrementalSync();

      expect(result.hasError, isFalse);
      expect(result.pushed, equals(1));
      expect(result.pulled, equals(1));
      expect(pushCalled, isTrue);
      expect(
        settingsBox.get('google_calendar_sync_token'),
        equals('new_sync_token_bi_complete'),
      );

      // Pushed event updated to synced
      final pushedLocal = calendarBox.get('local_push_1')!;
      expect(pushedLocal.syncStatus, equals('synced'));
      expect(pushedLocal.externalId, equals('google_created_123'));
      expect(pushedLocal.etag, equals('etag_created_123'));

      // Pulled event present
      final pulledEvents = calendarBox.values.where(
        (e) => e.externalId == 'remote_event_789',
      );
      expect(pulledEvents.length, equals(1));
      expect(pulledEvents.first.title, equals('Remote Event Pulled'));
      expect(pulledEvents.first.syncStatus, equals('synced'));
    },
  );

  test(
    'incrementalSync detects conflict when local pending_push event diverged remotely',
    () async {
      await settingsBox.put(
        'google_calendar_sync_token',
        'sync_token_conflict',
      );

      // Local event that was modified locally while having an existing externalId
      final conflictedEvent = CalendarEvent(
        id: 'local_conflict_1',
        title: 'Locally Modified Event',
        startTime: DateTime(2026, 4, 21, 9, 0),
        endTime: DateTime(2026, 4, 21, 10, 0),
        externalId: 'ext_conflict_123',
        etag: 'old_etag_1',
        syncStatus: 'pending_push',
      );
      await calendarBox.put(conflictedEvent.id, conflictedEvent);

      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.contains('/events')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'ext_conflict_123',
                  'etag': 'newer_remote_etag_2', // Remote etag changed!
                  'summary': 'Remotely Modified Summary',
                  'start': {'dateTime': '2026-04-21T09:00:00Z'},
                  'end': {'dateTime': '2026-04-21T10:00:00Z'},
                },
              ],
              'nextSyncToken': 'sync_token_after_conflict',
            }),
            200,
          );
        }
        return http.Response(jsonEncode({}), 200);
      });

      final service = CalendarSyncService(
        googleAuth: authService,
        client: client,
      );
      final result = await service.incrementalSync();

      expect(result.hasError, isFalse);
      final current = calendarBox.get('local_conflict_1')!;
      expect(current.syncStatus, equals('conflict'));
      expect(
        current.title,
        equals('Locally Modified Event'),
      ); // Preserves local title
      expect(current.etag, equals('newer_remote_etag_2'));
    },
  );
}
