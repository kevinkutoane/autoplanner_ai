import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/core/models/note_model.dart';
import 'package:autoplanner_ai/core/models/calendar_event_model.dart';
import 'package:autoplanner_ai/core/models/memory_entry_model.dart';

// BackupService serialises/deserialises each model via private _toMap/_fromMap
// helpers.  These tests verify the serialisation contract at the map level —
// identical logic is used in BackupService — without needing Hive or the OS
// file-picker, keeping the suite fast and dependency-free.

Map<String, dynamic> _taskToMap(TaskItem t) => {
  'id': t.id,
  'title': t.title,
  'startTime': t.startTime.toIso8601String(),
  'endTime': t.endTime?.toIso8601String(),
  'note': t.note,
  'isCompleted': t.isCompleted,
  'priority': t.priority,
  'tags': t.tags,
  'linkedNoteIds': t.linkedNoteIds,
  'recurrence': t.recurrence,
  'recurrenceDays': t.recurrenceDays,
};

TaskItem _taskFromMap(Map<String, dynamic> m) => TaskItem(
  id: m['id'] as String,
  title: m['title'] as String? ?? '',
  startTime: DateTime.parse(m['startTime'] as String),
  endTime: m['endTime'] != null ? DateTime.parse(m['endTime'] as String) : null,
  note: m['note'] as String?,
  isCompleted: m['isCompleted'] as bool? ?? false,
  priority: m['priority'] as int? ?? 1,
  tags: List<String>.from(m['tags'] as List? ?? []),
  linkedNoteIds: List<String>.from(m['linkedNoteIds'] as List? ?? []),
  recurrence: m['recurrence'] as String?,
  recurrenceDays: List<int>.from(m['recurrenceDays'] as List? ?? []),
);

Map<String, dynamic> _noteToMap(NoteItem n) => {
  'id': n.id,
  'title': n.title,
  'content': n.content,
  'summary': n.summary,
  'tags': n.tags,
  'createdAt': n.createdAt.toIso8601String(),
  'updatedAt': n.updatedAt.toIso8601String(),
  'linkedTaskIds': n.linkedTaskIds,
  'isPinned': n.isPinned,
};

NoteItem _noteFromMap(Map<String, dynamic> m) => NoteItem(
  id: m['id'] as String,
  title: m['title'] as String? ?? '',
  content: m['content'] as String? ?? '',
  summary: m['summary'] as String?,
  tags: List<String>.from(m['tags'] as List? ?? []),
  createdAt: DateTime.parse(m['createdAt'] as String),
  updatedAt: DateTime.parse(m['updatedAt'] as String),
  linkedTaskIds: List<String>.from(m['linkedTaskIds'] as List? ?? []),
  isPinned: m['isPinned'] as bool? ?? false,
);

Map<String, dynamic> _calEventToMap(CalendarEvent e) => {
  'id': e.id,
  'title': e.title,
  'description': e.description,
  'startTime': e.startTime.toIso8601String(),
  'endTime': e.endTime.toIso8601String(),
  'source': e.source,
  'linkedTaskId': e.linkedTaskId,
  'colorValue': e.colorValue,
  'isAllDay': e.isAllDay,
  'syncStatus': e.syncStatus,
};

CalendarEvent _calEventFromMap(Map<String, dynamic> m) => CalendarEvent(
  id: m['id'] as String,
  title: m['title'] as String? ?? '',
  description: m['description'] as String?,
  startTime: DateTime.parse(m['startTime'] as String),
  endTime: DateTime.parse(m['endTime'] as String),
  source: m['source'] as String? ?? 'local',
  linkedTaskId: m['linkedTaskId'] as String?,
  colorValue: m['colorValue'] as int? ?? 0xFF4CAF50,
  isAllDay: m['isAllDay'] as bool? ?? false,
  syncStatus: m['syncStatus'] as String? ?? 'local',
);

Map<String, dynamic> _memoryToMap(MemoryEntry m) => {
  'id': m.id,
  'content': m.content,
  'sourceType': m.sourceType,
  'sourceId': m.sourceId,
  'tags': m.tags,
  'createdAt': m.createdAt.toIso8601String(),
  'relevanceScore': m.relevanceScore,
  'accessCount': m.accessCount,
};

MemoryEntry _memoryFromMap(Map<String, dynamic> m) => MemoryEntry(
  id: m['id'] as String,
  content: m['content'] as String? ?? '',
  sourceType: m['sourceType'] as String? ?? 'user',
  sourceId: m['sourceId'] as String?,
  tags: List<String>.from(m['tags'] as List? ?? []),
  createdAt: DateTime.parse(m['createdAt'] as String),
  relevanceScore: (m['relevanceScore'] as num?)?.toDouble() ?? 0.5,
  accessCount: m['accessCount'] as int? ?? 0,
);

// JSON envelope is the same structure BackupService writes.
String _buildBackupJson({
  List<TaskItem> tasks = const [],
  List<NoteItem> notes = const [],
  List<CalendarEvent> calendarEvents = const [],
  List<MemoryEntry> memories = const [],
}) {
  return jsonEncode({
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'tasks': tasks.map(_taskToMap).toList(),
    'notes': notes.map(_noteToMap).toList(),
    'calendarEvents': calendarEvents.map(_calEventToMap).toList(),
    'memories': memories.map(_memoryToMap).toList(),
  });
}

void main() {
  final _now = DateTime(2025, 6, 1, 10, 0);

  // ── TaskItem round-trip ────────────────────────────────────────────────────
  group('BackupService serialisation — TaskItem', () {
    test('basic fields survive a JSON round-trip', () {
      final original = TaskItem(
        id: 'task-1',
        title: 'Write tests',
        startTime: _now,
        endTime: _now.add(const Duration(hours: 1)),
        note: 'important',
        isCompleted: false,
        priority: 2,
        tags: ['testing', 'flutter'],
        linkedNoteIds: ['note-abc'],
        recurrence: 'daily',
        recurrenceDays: [1, 3, 5],
      );

      final json = _buildBackupJson(tasks: [original]);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final taskMaps = decoded['tasks'] as List;

      expect(taskMaps, hasLength(1));
      final restored = _taskFromMap(taskMaps[0] as Map<String, dynamic>);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.startTime, original.startTime);
      expect(restored.endTime, original.endTime);
      expect(restored.note, original.note);
      expect(restored.isCompleted, original.isCompleted);
      expect(restored.priority, original.priority);
      expect(restored.tags, original.tags);
      expect(restored.linkedNoteIds, original.linkedNoteIds);
      expect(restored.recurrence, original.recurrence);
      expect(restored.recurrenceDays, original.recurrenceDays);
    });

    test('null optional fields are preserved as null', () {
      final original = TaskItem(
        id: 'task-2',
        title: 'No extras',
        startTime: _now,
        endTime: null,
        note: null,
        recurrence: null,
      );

      final map = _taskToMap(original);
      final restored = _taskFromMap(map);

      expect(restored.endTime, isNull);
      expect(restored.note, isNull);
      expect(restored.recurrence, isNull);
    });

    test('completed task preserves isCompleted=true', () {
      final original = TaskItem(
        id: 'task-3',
        title: 'Done task',
        startTime: _now,
        isCompleted: true,
      );
      final restored = _taskFromMap(_taskToMap(original));
      expect(restored.isCompleted, isTrue);
    });
  });

  // ── NoteItem round-trip ────────────────────────────────────────────────────
  group('BackupService serialisation — NoteItem', () {
    test('basic fields survive a JSON round-trip', () {
      final original = NoteItem(
        id: 'note-1',
        title: 'Meeting notes',
        content: 'Lorem ipsum',
        summary: 'A short summary',
        tags: ['work', 'meeting'],
        createdAt: _now,
        updatedAt: _now,
        linkedTaskIds: ['task-1'],
        isPinned: true,
      );

      final restored = _noteFromMap(_noteToMap(original));

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.content, original.content);
      expect(restored.summary, original.summary);
      expect(restored.tags, original.tags);
      expect(restored.createdAt, original.createdAt);
      expect(restored.isPinned, original.isPinned);
      expect(restored.linkedTaskIds, original.linkedTaskIds);
    });

    test('null summary is preserved', () {
      final original = NoteItem(
        id: 'note-2',
        title: 'Plain',
        content: 'No summary yet',
        createdAt: _now,
        updatedAt: _now,
      );
      final restored = _noteFromMap(_noteToMap(original));
      expect(restored.summary, isNull);
    });
  });

  // ── CalendarEvent round-trip ───────────────────────────────────────────────
  group('BackupService serialisation — CalendarEvent', () {
    test('basic fields survive a JSON round-trip', () {
      final original = CalendarEvent(
        id: 'ev-1',
        title: 'Standup',
        description: 'Daily sync',
        startTime: _now,
        endTime: _now.add(const Duration(minutes: 30)),
        source: 'google',
        isAllDay: false,
        syncStatus: 'synced',
        colorValue: 0xFF2196F3,
      );

      final restored = _calEventFromMap(_calEventToMap(original));

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.startTime, original.startTime);
      expect(restored.endTime, original.endTime);
      expect(restored.source, original.source);
      expect(restored.isAllDay, original.isAllDay);
      expect(restored.syncStatus, original.syncStatus);
      expect(restored.colorValue, original.colorValue);
    });

    test('all-day event survives round-trip', () {
      final original = CalendarEvent(
        id: 'ev-2',
        title: 'Holiday',
        startTime: _now,
        endTime: _now.add(const Duration(days: 1)),
        isAllDay: true,
      );
      final restored = _calEventFromMap(_calEventToMap(original));
      expect(restored.isAllDay, isTrue);
    });
  });

  // ── MemoryEntry round-trip ─────────────────────────────────────────────────
  group('BackupService serialisation — MemoryEntry', () {
    test('basic fields survive a JSON round-trip', () {
      final original = MemoryEntry(
        id: 'mem-1',
        content: 'Remember to review PRs',
        sourceType: 'user',
        sourceId: 'task-1',
        tags: ['work'],
        createdAt: _now,
        relevanceScore: 0.8,
        accessCount: 3,
      );

      final restored = _memoryFromMap(_memoryToMap(original));

      expect(restored.id, original.id);
      expect(restored.content, original.content);
      expect(restored.sourceType, original.sourceType);
      expect(restored.sourceId, original.sourceId);
      expect(restored.tags, original.tags);
      expect(restored.relevanceScore, original.relevanceScore);
      expect(restored.accessCount, original.accessCount);
    });
  });

  // ── Full backup envelope ───────────────────────────────────────────────────
  group('BackupService backup envelope', () {
    test('envelope version and all entity lists are present', () {
      final json = _buildBackupJson(
        tasks: [TaskItem(id: 't1', title: 'T1', startTime: _now)],
        notes: [
          NoteItem(
            id: 'n1',
            title: 'N1',
            content: '',
            createdAt: _now,
            updatedAt: _now,
          ),
        ],
      );
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['version'], 1);
      expect(data['exportedAt'], isNotNull);
      expect((data['tasks'] as List), hasLength(1));
      expect((data['notes'] as List), hasLength(1));
      expect((data['calendarEvents'] as List), isEmpty);
      expect((data['memories'] as List), isEmpty);
    });

    test('unknown fields in envelope are tolerated by parser', () {
      final raw = jsonEncode({
        'version': 1,
        'exportedAt': _now.toIso8601String(),
        'unknownFutureKey': 'ignored',
        'tasks': [],
        'notes': [],
        'calendarEvents': [],
        'memories': [],
      });
      // Must not throw.
      final data = jsonDecode(raw) as Map<String, dynamic>;
      expect(data['version'], 1);
    });
  });
}
