import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/goal_model.dart';
import 'package:autoplanner_ai/core/models/memory_entry_model.dart';
import 'package:autoplanner_ai/core/models/note_model.dart';
import 'package:autoplanner_ai/core/models/project_model.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/services/contextual_synthesis_service.dart';

void main() {
  late ContextualSynthesisService service;
  final now = DateTime(2099, 8, 1);

  setUp(() {
    service = ContextualSynthesisService();
  });

  group('ContextualSynthesisService Knowledge Graph Traversal', () {
    test('resolves direct goal and project associations', () {
      final goal = GoalItem(
        id: 'g_q4',
        title: 'Launch Q4 Milestone',
        description: 'Complete quarterly objectives',
        createdAt: now,
        updatedAt: now,
        deadline: now.add(const Duration(days: 30)),
      );

      final project = ProjectItem(
        id: 'p_sec',
        title: 'Security Hardening V2',
        parentGoalId: 'g_q4',
        createdAt: now,
        updatedAt: now,
      );

      final task = TaskItem(
        id: 't_audit',
        title: 'Run Pentest Audit',
        startTime: now,
        linkedGoalId: 'g_q4',
        linkedProjectId: 'p_sec',
      );

      final context = service.synthesizeContext(
        task: task,
        allGoals: [goal],
        allProjects: [project],
      );

      expect(context.goal?.id, 'g_q4');
      expect(context.project?.id, 'p_sec');
      expect(context.contextBadges, contains('🎯 Launch Q4 Milestone'));
      expect(context.contextBadges, contains('📁 Security Hardening V2'));
      expect(context.alignmentScore, greaterThanOrEqualTo(0.7));
    });

    test('resolves transitive goal via project parentGoalId', () {
      final goal = GoalItem(
        id: 'g_transitive',
        title: 'Master Flutter Architecture',
        description: 'Deep dive into clean architecture',
        createdAt: now,
        updatedAt: now,
        deadline: now.add(const Duration(days: 60)),
      );

      final project = ProjectItem(
        id: 'p_arch',
        title: 'AutoPlanner Personal OS',
        parentGoalId: 'g_transitive',
        createdAt: now,
        updatedAt: now,
      );

      // Task has NO explicit linkedGoalId, only linkedProjectId
      final task = TaskItem(
        id: 't_refactor',
        title: 'Refactor Dependency Graph',
        startTime: now,
        linkedProjectId: 'p_arch',
      );

      final context = service.synthesizeContext(
        task: task,
        allGoals: [goal],
        allProjects: [project],
      );

      expect(context.project?.id, 'p_arch');
      expect(context.goal?.id, 'g_transitive');
      expect(context.contextBadges, contains('🎯 Master Flutter Architecture'));
    });

    test('links notes by ID, note backlink, and shared tags', () {
      final noteDirect = NoteItem(
        id: 'n_direct',
        title: 'Meeting Notes: Architecture Review',
        content: 'Action items from discussion',
        createdAt: now,
        updatedAt: now,
      );

      final noteBacklinked = NoteItem(
        id: 'n_backlinked',
        title: 'Follow-up Details',
        content: 'Specs for implementation',
        linkedTaskIds: ['t_impl'],
        createdAt: now,
        updatedAt: now,
      );

      final noteSharedTag = NoteItem(
        id: 'n_tag',
        title: 'Database Schema Reference',
        content: 'Index specifications',
        tags: ['backend', 'database'],
        createdAt: now,
        updatedAt: now,
      );

      final task = TaskItem(
        id: 't_impl',
        title: 'Implement Database Migrations',
        startTime: now,
        linkedNoteIds: ['n_direct'],
        tags: ['database'],
      );

      final context = service.synthesizeContext(
        task: task,
        allNotes: [noteDirect, noteBacklinked, noteSharedTag],
      );

      expect(context.relatedNotes, hasLength(3));
      expect(context.contextBadges.any((b) => b.contains('3 notes')), isTrue);
    });

    test('synthesizes relevant AI memories by tag and keyword overlap', () {
      final memoryTag = MemoryEntry(
        id: 'm1',
        content: 'User achieves highest focus with binaural soundscapes.',
        sourceType: 'preference',
        createdAt: now,
        tags: ['focus', 'routine'],
      );

      final memoryKeyword = MemoryEntry(
        id: 'm2',
        content: 'Refactoring tasks consistently take 25% longer than estimated.',
        sourceType: 'pattern',
        createdAt: now,
        tags: ['analytics'],
      );

      final unrelatedMemory = MemoryEntry(
        id: 'm3',
        content: 'User drinks black coffee at 7 AM.',
        sourceType: 'habit',
        createdAt: now,
        tags: ['diet'],
      );

      final task = TaskItem(
        id: 't_refactor',
        title: 'Refactoring Storage Layers',
        startTime: now,
        tags: ['focus'],
      );

      final context = service.synthesizeContext(
        task: task,
        allMemories: [memoryTag, memoryKeyword, unrelatedMemory],
      );

      expect(context.relevantMemories, containsAll([memoryTag, memoryKeyword]));
      expect(context.relevantMemories.contains(unrelatedMemory), isFalse);
    });
  });
}
