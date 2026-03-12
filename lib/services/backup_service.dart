import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/models/task_model.dart';
import '../core/models/note_model.dart';
import '../core/models/calendar_event_model.dart';
import '../core/models/memory_entry_model.dart';

/// Summary returned after a successful import so the UI can confirm counts.
class BackupImportResult {
  final int tasks;
  final int notes;
  final int memories;
  final int calendarEvents;

  const BackupImportResult({
    required this.tasks,
    required this.notes,
    required this.memories,
    required this.calendarEvents,
  });

  int get total => tasks + notes + memories + calendarEvents;
}

/// Handles full-data export to JSON and import from JSON for backup/restore.
/// Uses the OS share sheet for export and the system file picker for import.
class BackupService {
  static const int _version = 1;

  // ── Export ───────────────────────────────────────────────────────────────

  Future<void> exportToFile() async {
    final payload = <String, dynamic>{
      'version': _version,
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': Hive.box<TaskItem>('tasksBox').values.map(_taskToMap).toList(),
      'notes': Hive.box<NoteItem>('notesBox').values.map(_noteToMap).toList(),
      'memories':
          Hive.box<MemoryEntry>('memoryBox').values.map(_memoryToMap).toList(),
      'calendarEvents': Hive.box<CalendarEvent>('calendarBox')
          .values
          .map(_calEventToMap)
          .toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/autoplanner_backup_$stamp.json');
    await file.writeAsString(json, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'AutoPlanner AI Backup',
      text: 'AutoPlanner AI — full data backup',
    );
  }

  // ── Import ───────────────────────────────────────────────────────────────

  Future<BackupImportResult?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final bytes = result.files.first.bytes;
    if (bytes == null) throw const FormatException('Could not read file data');

    final jsonStr = utf8.decode(bytes);
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Invalid backup file — not valid JSON');
    }

    final version = data['version'] as int? ?? 0;
    if (version != _version) {
      throw FormatException('Unsupported backup version: $version');
    }

    final rawTasks = (data['tasks'] as List?) ?? [];
    final rawNotes = (data['notes'] as List?) ?? [];
    final rawMemories = (data['memories'] as List?) ?? [];
    final rawEvents = (data['calendarEvents'] as List?) ?? [];

    final tasksBox = Hive.box<TaskItem>('tasksBox');
    for (final t in rawTasks) {
      try {
        final item = _taskFromMap(t as Map<String, dynamic>);
        await tasksBox.put(item.id, item);
      } catch (e) {
        if (kDebugMode) debugPrint('Skipping malformed task: $e');
      }
    }

    final notesBox = Hive.box<NoteItem>('notesBox');
    for (final n in rawNotes) {
      try {
        final item = _noteFromMap(n as Map<String, dynamic>);
        await notesBox.put(item.id, item);
      } catch (e) {
        if (kDebugMode) debugPrint('Skipping malformed note: $e');
      }
    }

    final memoryBox = Hive.box<MemoryEntry>('memoryBox');
    for (final m in rawMemories) {
      try {
        final item = _memoryFromMap(m as Map<String, dynamic>);
        await memoryBox.put(item.id, item);
      } catch (e) {
        if (kDebugMode) debugPrint('Skipping malformed memory: $e');
      }
    }

    final calendarBox = Hive.box<CalendarEvent>('calendarBox');
    for (final e in rawEvents) {
      try {
        final item = _calEventFromMap(e as Map<String, dynamic>);
        await calendarBox.put(item.id, item);
      } catch (e) {
        if (kDebugMode) debugPrint('Skipping malformed calendar event: $e');
      }
    }

    return BackupImportResult(
      tasks: rawTasks.length,
      notes: rawNotes.length,
      memories: rawMemories.length,
      calendarEvents: rawEvents.length,
    );
  }

  // ── Serialisation helpers ─────────────────────────────────────────────────

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
        endTime:
            m['endTime'] != null ? DateTime.parse(m['endTime'] as String) : null,
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
}
