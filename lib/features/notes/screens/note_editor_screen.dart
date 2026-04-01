import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';
import '../../notes/controllers/note_controller.dart';
import '../../../core/models/note_model.dart';
import '../../planner/controllers/task_controller.dart';
import '../../../core/models/task_model.dart';

const _uuid = Uuid();

class NoteEditorScreen extends ConsumerStatefulWidget {
  final NoteItem? note;
  const NoteEditorScreen({super.key, this.note});
  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final AnimationController _entryAC;
  late final Animation<Offset> _entrySlide;

  bool _isNew = true;
  bool _summarizing = false;
  String? _summaryText;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _isNew = widget.note == null;
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.note?.content ?? '');
    _tags = List<String>.from(widget.note?.tags ?? []);
    _summaryText = widget.note?.summary;

    _entryAC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryAC, curve: Curves.easeOutCubic));
    _entryAC.forward();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _entryAC.dispose();
    super.dispose();
  }

  Future<void> _summarize() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) return;
    setState(() => _summarizing = true);
    try {
      final ai = ref.read(aiServiceProvider);
      final summary = await ai.summarizeNote(content);
      final tags = await ai.generateTags(content);
      if (mounted) {
        setState(() {
          _summaryText = summary;
          _tags = tags;
          _summarizing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }

    if (_isNew) {
      ref
          .read(noteControllerProvider.notifier)
          .addNote(
            NoteItem(
              id: _uuid.v4(),
              title: title.isEmpty ? 'Untitled' : title,
              content: content,
              summary: _summaryText,
              tags: _tags,
              isPinned: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
    } else {
      ref
          .read(noteControllerProvider.notifier)
          .updateNote(
            widget.note!.copyWith(
              title: title.isEmpty ? 'Untitled' : title,
              content: content,
              summary: _summaryText,
              tags: _tags,
              updatedAt: DateTime.now(),
            ),
          );
    }
    Navigator.pop(context);
  }

  bool _hasChanges() {
    if (_isNew) {
      return _titleCtrl.text.trim().isNotEmpty ||
          _contentCtrl.text.trim().isNotEmpty;
    }
    return _titleCtrl.text.trim() != (widget.note?.title ?? '') ||
        _contentCtrl.text.trim() != (widget.note?.content ?? '');
  }

  Future<void> _mayPop() async {
    if (!_hasChanges()) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: kCoral)),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _mayPop();
      },
      child: Scaffold(
        backgroundColor: isDark ? kDark0 : Colors.white,
        body: SlideTransition(
          position: _entrySlide,
          child: Column(
            children: [
              // ── Top bar ──────────────────────────────────────────────
              SafeArea(
                bottom: false,
                child: Container(
                  color: isDark ? null : Colors.white,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      _IconBtn(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: _mayPop,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _titleCtrl,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? kLight0 : kDark0,
                            letterSpacing: -0.4,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Title',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black45,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      _IconBtn(
                        icon: Icons.check_rounded,
                        onTap: _save,
                        gradient: kGradientMain,
                      ),
                    ],
                  ),
                ),
              ),

              Divider(
                color: isDark ? Colors.white10 : Colors.black.withAlpha(12),
                height: 1,
              ),

              // ── Content area ─────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _contentCtrl,
                        maxLines: null,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.65,
                          color: isDark ? Colors.white.withAlpha(220) : kDark0,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write something...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black45,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),

                      // ── AI Summary block ─────────────────────────────
                      if (_summaryText != null) ...[
                        const SizedBox(height: 20),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ShaderMask(
                                    shaderCallback: (b) =>
                                        kGradientTeal.createShader(b),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'AI Summary',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _summaryText = null),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _summaryText!,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF5A5A6A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Tags ─────────────────────────────────────────
                      if (_tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags
                              .map(
                                (t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kIndigo.withAlpha(isDark ? 40 : 20),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '#$t',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: kIndigo,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],

                      // ── Linked Tasks ─────────────────────────────
                      if (widget.note != null) ...[
                        const SizedBox(height: 16),
                        _LinkedTasksSection(note: widget.note!),
                      ],

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              // ── Bottom toolbar ───────────────────────────────────────
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? kDark1 : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withAlpha(20),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      GhostBtn(
                        label: _summarizing ? 'Analyzing...' : 'AI Summarize',
                        icon: _summarizing ? null : Icons.auto_awesome_rounded,
                        onTap: _summarizing ? null : _summarize,
                      ),
                      const Spacer(),
                      if (_summarizing)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kIndigo,
                          ),
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
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final LinearGradient? gradient;
  const _IconBtn({required this.icon, required this.onTap, this.gradient});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null
              ? (isDark ? Colors.white12 : Colors.black.withAlpha(10))
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: gradient != null ? Colors.white : null,
        ),
      ),
    );
  }
}

// ── Linked Tasks section ──────────────────────────────────────────────────────

class _LinkedTasksSection extends ConsumerWidget {
  final NoteItem note;
  const _LinkedTasksSection({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTasks = ref.watch(taskControllerProvider);
    final linkedIds = note.linkedTaskIds;

    void _unlink(String taskId) {
      ref.read(noteControllerProvider.notifier).unlinkTask(note.id, taskId);
      ref.read(taskControllerProvider.notifier).unlinkNote(taskId, note.id);
    }

    Future<void> _showAddDialog() async {
      final available = allTasks
          .where((t) => !linkedIds.contains(t.id) && !t.isCompleted)
          .toList();
      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No unlinked tasks available.')),
        );
        return;
      }
      final chosen = await showDialog<TaskItem>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Link a task'),
          children: available
              .map(
                (t) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, t),
                  child: Text(t.title, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
        ),
      );
      if (chosen != null) {
        ref.read(noteControllerProvider.notifier).linkTask(note.id, chosen.id);
        ref.read(taskControllerProvider.notifier).linkNote(chosen.id, note.id);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Linked Tasks',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : kDark0,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _showAddDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (linkedIds.isEmpty)
          Text(
            'No linked tasks',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: linkedIds.map((id) {
              final task = allTasks.where((t) => t.id == id).firstOrNull;
              final label = task?.title ?? 'Unknown';
              return Chip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => _unlink(id),
                backgroundColor: kCyan.withAlpha(isDark ? 40 : 20),
                side: BorderSide(color: kCyan.withAlpha(80)),
                labelStyle: const TextStyle(color: kCyan),
                deleteIconColor: kCyan,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
      ],
    );
  }
}
