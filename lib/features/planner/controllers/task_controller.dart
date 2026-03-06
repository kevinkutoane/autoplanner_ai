import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/memory_entry_model.dart';
import '../../../core/providers/providers.dart';
import '../../../services/ai_service.dart';
import '../../memory/controllers/memory_controller.dart';
import '../../calendar/controllers/calendar_controller.dart';

const _uuid = Uuid();

class TaskController extends StateNotifier<List<TaskItem>> {
  Box<TaskItem>? _box;
  final AIService _aiService;
  final MemoryController _memoryCtrl;
  final CalendarController _calendarCtrl;

  TaskController({
    required AIService aiService,
    required MemoryController memoryCtrl,
    required CalendarController calendarCtrl,
  }) : _aiService = aiService,
       _memoryCtrl = memoryCtrl,
       _calendarCtrl = calendarCtrl,
       super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox<TaskItem>('tasksBox');
    _refreshState();
  }

  List<TaskItem> get todayTasks {
    final now = DateTime.now();
    return state.where((task) {
      return task.startTime.year == now.year &&
          task.startTime.month == now.month &&
          task.startTime.day == now.day;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<TaskItem> get completedTasks =>
      state.where((t) => t.isCompleted).toList();

  List<TaskItem> get pendingTasks =>
      state.where((t) => !t.isCompleted).toList();

  double get completionRate {
    if (todayTasks.isEmpty) return 0;
    return todayTasks.where((t) => t.isCompleted).length / todayTasks.length;
  }

  void addTask(TaskItem task) {
    if (_box == null) return;
    _box!.put(task.id, task);
    _refreshState();
    _calendarCtrl.syncTasksToCalendar(state);
    _createTaskMemory(task, 'created');
  }

  void removeTask(String id) {
    if (_box == null) return;
    _box!.delete(id);
    _refreshState();
    _calendarCtrl.syncTasksToCalendar(state);
  }

  void updateTask(TaskItem task) {
    if (_box == null) return;
    final oldTask = _box!.get(task.id);
    _box!.put(task.id, task);
    _refreshState();
    _calendarCtrl.syncTasksToCalendar(state);
    if (oldTask != null && !oldTask.isCompleted && task.isCompleted) {
      _createTaskMemory(task, 'completed');
    }
  }

  void toggleComplete(String taskId) {
    final task = state.firstWhere((t) => t.id == taskId);
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    updateTask(updated);
  }

  void clearAll() {
    if (_box == null) return;
    _box!.clear();
    state = [];
  }

  /// Saves a reordered list of tasks in-place without triggering AI memory extraction.
  void reorderTasks(List<TaskItem> tasks) {
    if (_box == null) return;
    _box!.clear();
    for (final task in tasks) {
      _box!.put(task.id, task);
    }
    _refreshState();
    _calendarCtrl.syncTasksToCalendar(state);
  }

  void _refreshState() {
    state = _box!.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  void _createTaskMemory(TaskItem task, String action) async {
    try {
      final ctx =
          'Task "$action": "${task.title}" at ${task.startTime.hour}:${task.startTime.minute.toString().padLeft(2, '0')} [${task.priorityLabel}] tags: ${task.tags.join(', ')}';
      final memoryContent = await _aiService.extractMemoryFromContext(
        ctx,
        'task',
      );
      if (memoryContent != null) {
        _memoryCtrl.addMemory(
          MemoryEntry(
            id: _uuid.v4(),
            content: memoryContent,
            sourceType: 'task',
            sourceId: task.id,
            tags: task.tags,
            createdAt: DateTime.now(),
            relevanceScore: task.priority / 3.0,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Memory creation failed: $e');
    }
  }
}

final taskControllerProvider =
    StateNotifierProvider<TaskController, List<TaskItem>>((ref) {
      return TaskController(
        aiService: ref.watch(aiServiceProvider),
        memoryCtrl: ref.watch(memoryControllerProvider.notifier),
        calendarCtrl: ref.watch(calendarControllerProvider.notifier),
      );
    });
