import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/note_model.dart';
import '../../../core/models/memory_entry_model.dart';
import '../../../core/providers/providers.dart';
import '../../../services/ai_service.dart';
import '../../memory/controllers/memory_controller.dart';

const _uuid = Uuid();

class NoteController extends StateNotifier<List<NoteItem>> {
  Box<NoteItem>? _box;
  final AIService _aiService;
  final MemoryController _memoryCtrl;

  NoteController({
    required AIService aiService,
    required MemoryController memoryCtrl,
  }) : _aiService = aiService,
       _memoryCtrl = memoryCtrl,
       super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox<NoteItem>('notesBox');
    state = _box!.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<NoteItem> get pinnedNotes => state.where((n) => n.isPinned).toList();

  List<NoteItem> get recentNotes => state.take(10).toList();

  List<NoteItem> searchNotes(String query) {
    final q = query.toLowerCase();
    return state.where((n) {
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q) ||
          n.tags.any((t) => t.toLowerCase().contains(q)) ||
          (n.summary?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> addNote(NoteItem note) async {
    if (_box == null) return;
    await _box!.put(note.id, note);
    _refreshState();
    // Only run background AI if the editor didn't already produce a summary
    if (note.summary == null || note.summary!.isEmpty) {
      _processNoteWithAI(note);
    }
  }

  Future<void> updateNote(NoteItem note) async {
    if (_box == null) return;
    final updated = note.copyWith(updatedAt: DateTime.now());
    await _box!.put(updated.id, updated);
    _refreshState();
  }

  Future<void> deleteNote(String id) async {
    if (_box == null) return;
    await _box!.delete(id);
    _refreshState();
  }

  Future<void> togglePin(String noteId) async {
    final note = state.firstWhere((n) => n.id == noteId);
    final updated = note.copyWith(isPinned: !note.isPinned);
    await updateNote(updated);
  }

  Future<void> _processNoteWithAI(NoteItem note) async {
    try {
      final results = await Future.wait([
        _aiService.summarizeNote(note.content),
        _aiService.generateTags('${note.title}\n${note.content}'),
      ]);

      final summary = results[0] as String?;
      final tags = results[1] as List<String>;

      if (summary != null || tags.isNotEmpty) {
        final updated = note.copyWith(
          summary: summary ?? note.summary,
          tags: tags.isNotEmpty ? tags : note.tags,
          updatedAt: DateTime.now(),
        );
        await _box!.put(updated.id, updated);
        _refreshState();
      }

      final memoryContent = await _aiService.extractMemoryFromContext(
        '${note.title}: ${note.content}',
        'note',
      );
      if (memoryContent != null) {
        _memoryCtrl.addMemory(
          MemoryEntry(
            id: _uuid.v4(),
            content: memoryContent,
            sourceType: 'note',
            sourceId: note.id,
            tags: tags,
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Note AI processing failed: $e');
    }
  }

  Future<void> reprocessNote(String noteId) async {
    final note = state.firstWhere((n) => n.id == noteId);
    await _processNoteWithAI(note);
  }

  void _refreshState() {
    state = _box!.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}

final noteControllerProvider =
    StateNotifierProvider<NoteController, List<NoteItem>>((ref) {
      return NoteController(
        aiService: ref.watch(aiServiceProvider),
        memoryCtrl: ref.watch(memoryControllerProvider.notifier),
      );
    });
