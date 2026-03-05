import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/note_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../planner/controllers/task_controller.dart';
import '../controllers/note_controller.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;

  const NoteEditorScreen({super.key, this.noteId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isNew = true;
  bool _processing = false;
  String? _summary;
  List<String> _tags = [];
  DateTime? _originalCreatedAt;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();

    if (widget.noteId != null) {
      _isNew = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notes = ref.read(noteControllerProvider);
        final note = notes.firstWhere((n) => n.id == widget.noteId);
        _titleController.text = note.title;
        _contentController.text = note.content;
        setState(() {
          _summary = note.summary;
          _tags = List.from(note.tags);
          _originalCreatedAt = note.createdAt;
        });
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) return;

    final now = DateTime.now();
    final note = NoteItem(
      id: widget.noteId ?? const Uuid().v4(),
      title: title.isEmpty ? 'Untitled Note' : title,
      content: content,
      summary: _summary,
      tags: _tags,
      createdAt: _isNew ? now : (_originalCreatedAt ?? now),
      updatedAt: now,
    );

    if (_isNew) {
      await ref.read(noteControllerProvider.notifier).addNote(note);
    } else {
      await ref.read(noteControllerProvider.notifier).updateNote(note);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _summarizeWithAI() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _processing = true);
    try {
      final aiService = ref.read(aiServiceProvider);
      final results = await Future.wait([
        aiService.summarizeNote(content),
        aiService.generateTags('${_titleController.text}\n$content'),
      ]);

      setState(() {
        _summary = results[0] as String?;
        final newTags = results[1] as List<String>;
        if (newTags.isNotEmpty) _tags = newTags;
        _processing = false;
      });
    } catch (e) {
      setState(() => _processing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('AI processing failed')));
      }
    }
  }

  Future<void> _extractTasks() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _processing = true);
    try {
      final aiService = ref.read(aiServiceProvider);
      final tasks = await aiService.extractActionItems(content);

      if (tasks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No actionable items found')),
          );
        }
      } else {
        if (mounted) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Found ${tasks.length} action items'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tasks.length,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.task_alt,
                        color: AppTheme.priorityColor(task.priority),
                      ),
                      title: Text(task.title),
                      subtitle: Text(
                        '${task.startTime.hour}:${task.startTime.minute.toString().padLeft(2, '0')} - ${task.priorityLabel}',
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Add to Plan'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            for (final task in tasks) {
              ref.read(taskControllerProvider.notifier).addTask(task);
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${tasks.length} tasks added to your plan!'),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task extraction failed')));
      }
    } finally {
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New Note' : 'Edit Note'),
        actions: [
          if (_processing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'AI Summarize & Tag',
              onPressed: _summarizeWithAI,
            ),
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Extract Tasks',
              onPressed: _extractTasks,
            ),
          ],
          IconButton(icon: const Icon(Icons.check), onPressed: _saveNote),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'Note title...',
                border: InputBorder.none,
                filled: false,
              ),
            ),

            const Divider(),

            // AI Summary
            if (_summary != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accentIndigo.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accentIndigo.withAlpha(40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: AppTheme.accentIndigo,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'AI Summary',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentIndigo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _summary!,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Tags
            if (_tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text('#$tag'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() => _tags.remove(tag));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Content
            TextField(
              controller: _contentController,
              maxLines: null,
              minLines: 15,
              style: const TextStyle(fontSize: 16, height: 1.6),
              decoration: const InputDecoration(
                hintText:
                    'Start writing...\n\nUse the AI button to auto-summarize and tag your note.',
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
