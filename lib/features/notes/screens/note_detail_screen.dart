import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/ui_kit.dart';
import '../../../core/ai/ai_guard.dart';
import '../../../core/providers/providers.dart';
import '../../../core/models/note_model.dart';
import '../../planner/controllers/task_controller.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  final String noteId;
  const NoteDetailScreen({super.key, required this.noteId});

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  bool _hasUnsavedChanges = false;
  bool _summarising = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _contentCtrl = TextEditingController();
    // Populate after the first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNote());
  }

  void _loadNote() {
    final note = _findNote();
    if (note == null) return;
    _titleCtrl.text = note.title;
    _contentCtrl.text = note.content;
  }

  NoteItem? _findNote() {
    final notes = ref.read(noteControllerProvider);
    final matches = notes.where((n) => n.id == widget.noteId);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  void dispose() {
    // Auto-save on exit
    _save();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final note = _findNote();
    if (note == null) return;
    final newTitle = _titleCtrl.text.trim();
    final newContent = _contentCtrl.text.trim();
    if (newTitle.isEmpty && newContent.isEmpty) return;
    if (newTitle == note.title && newContent == note.content) return;
    ref
        .read(noteControllerProvider.notifier)
        .updateNote(
          note.copyWith(
            title: newTitle.isNotEmpty ? newTitle : note.title,
            content: newContent,
          ),
        );
    _hasUnsavedChanges = false;
  }

  Future<void> _generateSummary() async {
    final note = _findNote();
    if (note == null) return;
    // Save current content first
    _save();
    setState(() => _summarising = true);
    try {
      final ai = ref.read(aiServiceProvider);
      final content = _contentCtrl.text.trim();
      if (content.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add some content first')),
          );
        }
        return;
      }
      final summary = await ai.summarizeNote(content);
      if (summary != null && summary.isNotEmpty) {
        ref.read(noteControllerProvider.notifier).setSummary(note.id, summary);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Summary generated ✓')));
        }
      }
    } on ContentPolicyException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.reason),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on CallFrequencyException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Summary failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _summarising = false);
    }
  }

  void _showAddTagDialog() {
    final tagCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? kDark1 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Tag',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : kDark0,
          ),
        ),
        content: TextField(
          controller: tagCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: isDark ? Colors.white : kDark0),
          decoration: InputDecoration(
            hintText: 'Tag name…',
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            ),
          ),
          GradBtn(
            label: 'Add',
            onTap: () {
              final tag = tagCtrl.text.trim();
              if (tag.isEmpty) return;
              ref
                  .read(noteControllerProvider.notifier)
                  .addTag(widget.noteId, tag);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showLinkTaskSheet() {
    final tasks = ref.read(taskControllerProvider);
    final note = _findNote();
    if (note == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: isDark ? kDark1.withAlpha(220) : Colors.white.withAlpha(240),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Link to Task',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : kDark0,
                    ),
                  ),
                ),
                if (tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No tasks available'),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: tasks.length,
                      itemBuilder: (_, i) {
                        final task = tasks[i];
                        final isLinked = note.linkedTaskIds.contains(task.id);
                        return ListTile(
                          leading: Icon(
                            isLinked
                                ? Icons.link_rounded
                                : Icons.link_off_rounded,
                            color: isLinked ? kIndigo : Colors.grey,
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              color: isDark ? Colors.white : kDark0,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat.yMMMd().format(task.startTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          trailing: isLinked
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: kCyan,
                                )
                              : null,
                          onTap: () {
                            final noteCtrl = ref.read(
                              noteControllerProvider.notifier,
                            );
                            if (isLinked) {
                              noteCtrl.unlinkTask(widget.noteId, task.id);
                            } else {
                              noteCtrl.linkTask(widget.noteId, task.id);
                            }
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final note = ref
        .watch(noteControllerProvider)
        .where((n) => n.id == widget.noteId);
    if (note.isEmpty) {
      return Scaffold(
        body: OrbBackground(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: kCoral),
                const SizedBox(height: 12),
                const Text('Note not found'),
                const SizedBox(height: 12),
                GhostBtn(label: 'Go back', onTap: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      );
    }

    final n = note.first;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat.yMMMd().add_jm().format(n.updatedAt);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        subtle: true,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: isDark ? Colors.white : kDark0,
                      ),
                      onPressed: () {
                        _save();
                        Navigator.pop(context);
                      },
                    ),
                    const Spacer(),
                    if (_hasUnsavedChanges)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: kAmber,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        n.isPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        color: n.isPinned
                            ? kAmber
                            : (isDark ? Colors.white54 : Colors.black45),
                      ),
                      onPressed: () => ref
                          .read(noteControllerProvider.notifier)
                          .togglePin(n.id),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: isDark ? Colors.white : kDark0,
                      ),
                      onSelected: (v) {
                        switch (v) {
                          case 'summary':
                            _generateSummary();
                          case 'tag':
                            _showAddTagDialog();
                          case 'link':
                            _showLinkTaskSheet();
                          case 'delete':
                            _confirmDelete();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'summary',
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('AI Summary'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'tag',
                          child: Row(
                            children: [
                              Icon(Icons.label_outline_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Add Tag'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'link',
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Link Task'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: kCoral,
                              ),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: kCoral)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Content ─────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextField(
                        controller: _titleCtrl,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : kDark0,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Note title',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) =>
                            setState(() => _hasUnsavedChanges = true),
                      ),

                      // Date
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                      ),

                      // Tags
                      if (n.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: n.tags
                              .map(
                                (tag) => GlassChip(
                                  label: tag,
                                  selected: false,
                                  trailing: Icons.close_rounded,
                                  onTap: () => ref
                                      .read(noteControllerProvider.notifier)
                                      .removeTag(n.id, tag),
                                ),
                              )
                              .toList(),
                        ),
                      ],

                      // AI Summary
                      if (n.summary != null && n.summary!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                    color: kIndigo,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'AI Summary',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: kIndigo,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                n.summary!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_summarising)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Content editor
                      TextField(
                        controller: _contentCtrl,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white.withAlpha(200) : kDark0,
                          height: 1.6,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Start writing…',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                        minLines: 15,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) =>
                            setState(() => _hasUnsavedChanges = true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(noteControllerProvider.notifier)
                  .removeNote(widget.noteId);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: kCoral)),
          ),
        ],
      ),
    );
  }
}
