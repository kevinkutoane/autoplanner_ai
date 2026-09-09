import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/models/task_model.dart';
import '../core/models/goal_model.dart';
import '../core/models/project_model.dart';
import '../core/models/calendar_event_model.dart';
import '../core/models/memory_entry_model.dart';
import '../core/models/note_model.dart';

/// Summary returned after a successful import so the UI can confirm counts.
class BackupImportResult {
  /// Number of [TaskItem] records written to `tasksBox`.
  final int tasks;

  /// Number of [GoalItem] records written to `goalsBox`.
  final int goals;

  /// Number of [ProjectItem] records written to `projectsBox`.
  final int projects;

  /// Number of [MemoryEntry] records written to `memoryBox`.
  final int memories;

  /// Number of [CalendarEvent] records written to `calendarBox`.
  final int calendarEvents;

  /// Number of [NoteItem] records written to `notesBox`.
  final int notes;

  const BackupImportResult({
    required this.tasks,
    required this.goals,
    required this.projects,
    required this.memories,
    required this.calendarEvents,
    this.notes = 0,
  });

  /// Total items imported across all collections.
  int get total => tasks + goals + projects + memories + calendarEvents + notes;
}

/// Handles full-data export to JSON and import from JSON for backup/restore.
/// Uses the OS share sheet for export and the system file picker for import.
class BackupService {
  static const int _version = 1;

  // ── Export ───────────────────────────────────────────────────────────────
  /// Serialises all Hive data to a pretty-printed JSON file and shares it
  /// via the OS share sheet (Android share / iOS share extension).
  ///
  /// The JSON envelope contains a `version` integer so future versions of the
  /// app can detect and migrate older backup formats on import.
  ///
  /// Throws if any Hive box is not open or if the temporary file cannot be
  /// written to the cache directory.
  Future<void> exportToFile() async {
    final payload = <String, dynamic>{
      'version': _version,
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': Hive.box<TaskItem>('tasksBox').values.map(_taskToMap).toList(),
      'goals': Hive.box<GoalItem>('goalsBox').values.map(_goalToMap).toList(),
      'projects': Hive.box<ProjectItem>(
        'projectsBox',
      ).values.map(_projectToMap).toList(),
      'memories': Hive.box<MemoryEntry>(
        'memoryBox',
      ).values.map(_memoryToMap).toList(),
      'calendarEvents': Hive.box<CalendarEvent>(
        'calendarBox',
      ).values.map(_calEventToMap).toList(),
      'notes': Hive.box<NoteItem>('notesBox').values.map(_noteToMap).toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/autoplanner_backup_$stamp.json');
    await file.writeAsString(json, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'AutoPlanner AI Backup',
        text: 'AutoPlanner AI — full data backup',
      ),
    );
  }

  // ── Import ───────────────────────────────────────────────────────────────
  /// Opens the system file picker filtered to `.json` files, reads the
  /// selected backup, and writes all records into their respective Hive boxes.
  ///
  /// Malformed individual records are silently skipped (a debug-mode message
  /// is printed) so a single corrupt entry does not abort the entire import.
  ///
  /// Returns `null` when the user cancels the file picker.
  /// Throws [FormatException] when the file is not valid JSON or uses an
  /// unsupported backup version.
  Future<BackupImportResult?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;

    final path = result.files.first.path;
    if (path == null) throw const FormatException('Could not read file path');
    final bytes = await File(path).readAsBytes();
    if (bytes.isEmpty) throw const FormatException('Could not read file data');

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
    final rawGoals = (data['goals'] as List?) ?? [];
    final rawProjects = (data['projects'] as List?) ?? [];
    final rawMemories = (data['memories'] as List?) ?? [];
    final rawEvents = (data['calendarEvents'] as List?) ?? [];
    final rawNotes = (data['notes'] as List?) ?? [];

    final tasksBox = Hive.box<TaskItem>('tasksBox');
    for (final t in rawTasks) {
      try {
        final item = _taskFromMap(t as Map<String, dynamic>);
        await tasksBox.put(item.id, item);
      } catch (e) {
        if (kDebugMode) debugPrint('Skipping malformed task: $e');
      }
    }

    final goalsBox = Hive.box<GoalItem>('goalsBox');
    for (final g in rawGoals) {
      try {
        final item = _goalFromMap(g as Map<String, dynamic>);
        await goalsBox.put(item.id, item);
      } catch (e) {
        if (kDebugMode) debugPrint('Skipping malformed goal: $e');
      }
    }

    final projectsBox = Hive.box<ProjectItem>('projectsBox');
    for (final p in rawProjects) {
      try {
        final item = _projectFromMap(p as Map<String, dynamic>);
        await projectsBox.put(item.id, item);
      } catch (e) {
        if (kDebugMode) debugPrint('Skipping malformed project: $e');
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

    final notesBox = Hive.box<NoteItem>('notesBox');
    for (final n in rawNotes) {
      try {
        final item = _noteFromMap(n as Map<String, dynamic>);
        await notesBox.put(item.id, item);
      } catch (e) {
        if (kDebugMode) debugPrint('Skipping malformed note: $e');
      }
    }

    return BackupImportResult(
      tasks: rawTasks.length,
      goals: rawGoals.length,
      projects: rawProjects.length,
      memories: rawMemories.length,
      calendarEvents: rawEvents.length,
      notes: rawNotes.length,
    );
  }

  // ── Serialisation helpers ─────────────────────────────────────────────────
  /// Converts a [TaskItem] to a plain JSON-compatible map for backup export.
  Map<String, dynamic> _taskToMap(TaskItem t) => {
    'id': t.id,
    'title': t.title,
    'startTime': t.startTime.toIso8601String(),
    'endTime': t.endTime?.toIso8601String(),
    'note': t.note,
    'isCompleted': t.isCompleted,
    'priority': t.priority,
    'tags': t.tags,
    // ignore: deprecated_member_use_from_same_package
    'linkedNoteIds': t.linkedNoteIds,
    'recurrence': t.recurrence,
    'recurrenceDays': t.recurrenceDays,
    'linkedGoalId': t.linkedGoalId,
  };

  TaskItem _taskFromMap(Map<String, dynamic> m) => TaskItem(
    id: m['id'] as String,
    title: m['title'] as String? ?? '',
    startTime: DateTime.parse(m['startTime'] as String),
    endTime: m['endTime'] != null
        ? DateTime.parse(m['endTime'] as String)
        : null,
    note: m['note'] as String?,
    isCompleted: m['isCompleted'] as bool? ?? false,
    priority: m['priority'] as int? ?? 1,
    tags: List<String>.from(m['tags'] as List? ?? []),
    linkedNoteIds: List<String>.from(m['linkedNoteIds'] as List? ?? []),
    recurrence: m['recurrence'] as String?,
    recurrenceDays: List<int>.from(m['recurrenceDays'] as List? ?? []),
    linkedGoalId: m['linkedGoalId'] as String?,
  );

  Map<String, dynamic> _goalToMap(GoalItem g) => {
    'id': g.id,
    'title': g.title,
    'description': g.description,
    'emoji': g.emoji,
    'deadline': g.deadline?.toIso8601String(),
    'isCompleted': g.isCompleted,
    'isArchived': g.isArchived,
    'color': g.color,
    'linkedTaskIds': g.linkedTaskIds,
    'createdAt': g.createdAt.toIso8601String(),
    'updatedAt': g.updatedAt.toIso8601String(),
  };

  GoalItem _goalFromMap(Map<String, dynamic> m) {
    final now = DateTime.now();
    return GoalItem(
      id: m['id'] as String,
      title: m['title'] as String? ?? '',
      description: m['description'] as String? ?? '',
      emoji: m['emoji'] as String? ?? '🎯',
      deadline: m['deadline'] != null
          ? DateTime.parse(m['deadline'] as String)
          : null,
      isCompleted: m['isCompleted'] as bool? ?? false,
      isArchived: m['isArchived'] as bool? ?? false,
      color: m['color'] as int? ?? 0xFF6C63FF,
      linkedTaskIds: List<String>.from(m['linkedTaskIds'] as List? ?? []),
      createdAt: m['createdAt'] != null
          ? DateTime.parse(m['createdAt'] as String)
          : now,
      updatedAt: m['updatedAt'] != null
          ? DateTime.parse(m['updatedAt'] as String)
          : now,
    );
  }

  Map<String, dynamic> _projectToMap(ProjectItem p) => {
    'id': p.id,
    'title': p.title,
    'description': p.description,
    'parentGoalId': p.parentGoalId,
    'isCompleted': p.isCompleted,
    'linkedTaskIds': p.linkedTaskIds,
    'createdAt': p.createdAt.toIso8601String(),
    'updatedAt': p.updatedAt.toIso8601String(),
  };

  ProjectItem _projectFromMap(Map<String, dynamic> m) {
    final now = DateTime.now();
    return ProjectItem(
      id: m['id'] as String,
      title: m['title'] as String? ?? '',
      description: m['description'] as String? ?? '',
      parentGoalId: m['parentGoalId'] as String?,
      isCompleted: m['isCompleted'] as bool? ?? false,
      linkedTaskIds: List<String>.from(m['linkedTaskIds'] as List? ?? []),
      createdAt: m['createdAt'] != null
          ? DateTime.parse(m['createdAt'] as String)
          : now,
      updatedAt: m['updatedAt'] != null
          ? DateTime.parse(m['updatedAt'] as String)
          : now,
    );
  }

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

  // ── Notes serialisation ──────────────────────────────────────────────────
  Map<String, dynamic> _noteToMap(NoteItem n) => {
    'id': n.id,
    'title': n.title,
    'content': n.content,
    'tags': n.tags,
    'isPinned': n.isPinned,
    'summary': n.summary,
    'linkedTaskIds': n.linkedTaskIds,
    'createdAt': n.createdAt.toIso8601String(),
    'updatedAt': n.updatedAt.toIso8601String(),
  };

  NoteItem _noteFromMap(Map<String, dynamic> m) {
    final now = DateTime.now();
    return NoteItem(
      id: m['id'] as String,
      title: m['title'] as String? ?? '',
      content: m['content'] as String? ?? '',
      tags: List<String>.from(m['tags'] as List? ?? []),
      isPinned: m['isPinned'] as bool? ?? false,
      summary: m['summary'] as String?,
      linkedTaskIds: List<String>.from(m['linkedTaskIds'] as List? ?? []),
      createdAt: m['createdAt'] != null
          ? DateTime.parse(m['createdAt'] as String)
          : now,
      updatedAt: m['updatedAt'] != null
          ? DateTime.parse(m['updatedAt'] as String)
          : now,
    );
  }
}
