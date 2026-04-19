import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/note_model.dart';
import '../../../core/theme/ui_kit.dart';
import '../controllers/note_controller.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notes = ref.watch(notesControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        subtle: true,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(isDark: isDark),
              const SizedBox(height: 8),
              Expanded(
                child: notes.isEmpty
                    ? _EmptyState(isDark: isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: notes.length,
                        itemBuilder: (_, i) {
                          final note = notes[i];
                          return Dismissible(
                            key: ValueKey(note.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: kCoral.withAlpha(40),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete_outline_rounded,
                                  color: kCoral, size: 24),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete note?'),
                                  content: Text(
                                      '"${note.title}" will be permanently removed.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete',
                                          style: TextStyle(color: kCoral)),
                                    ),
                                  ],
                                ),
                              ) ?? false;
                            },
                            onDismissed: (_) {
                              ref
                                  .read(notesControllerProvider.notifier)
                                  .removeNote(note.id);
                            },
                            child: _NoteCard(
                              note: note,
                              isDark: isDark,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _AddNoteFab(isDark: isDark),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isDark;
  const _Header({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (r) => kGradientMain.createShader(r),
            child: const Icon(Icons.sticky_note_2_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 10),
          Text(
            'Notes',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : kDark0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Note card ────────────────────────────────────────────────────────────────

class _NoteCard extends ConsumerWidget {
  final NoteItem note;
  final bool isDark;
  const _NoteCard({required this.note, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onLongPress: () => _confirmDelete(context, ref),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(18)
                    : Colors.white.withAlpha(200),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: note.isUrgent
                      ? kCoral.withAlpha(160)
                      : (isDark
                          ? Colors.white.withAlpha(25)
                          : Colors.white.withAlpha(180)),
                  width: note.isUrgent ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : kDark0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (note.isUrgent)
                        _Badge(
                            label: 'Urgent', color: kCoral, isDark: isDark),
                      if (note.isPinned) ...[
                        const SizedBox(width: 4),
                        _Badge(
                            label: 'Pinned', color: kIndigo, isDark: isDark),
                      ],
                    ],
                  ),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white60
                            : Colors.black54,
                      ),
                    ),
                  ],
                  if (note.reminderAt != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.alarm_rounded,
                            size: 12,
                            color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 4),
                        Text(
                          _formatReminder(note.reminderAt!),
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _IconAction(
                        icon: note.isPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        color: note.isPinned ? kIndigo : Colors.grey,
                        onTap: () => ref
                            .read(notesControllerProvider.notifier)
                            .togglePin(note.id),
                      ),
                      const SizedBox(width: 8),
                      _IconAction(
                        icon: note.isUrgent
                            ? Icons.warning_rounded
                            : Icons.warning_amber_outlined,
                        color: note.isUrgent ? kCoral : Colors.grey,
                        onTap: () => ref
                            .read(notesControllerProvider.notifier)
                            .toggleUrgent(note.id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatReminder(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.isNegative) return 'Past';
    if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _confirmDelete(BuildContext ctx, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('"${note.title}" will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: kCoral))),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(notesControllerProvider.notifier).removeNote(note.id);
    }
  }
}

// ── Small badge ───────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  const _Badge(
      {required this.label, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

// ── Icon action button ────────────────────────────────────────────────────────

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconAction(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (r) => kGradientMain.createShader(r),
            child: const Icon(Icons.sticky_note_2_outlined,
                size: 64, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'No notes yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to jot something down',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

// ── FAB ────────────────────────────────────────────────────────────────────────

class _AddNoteFab extends ConsumerWidget {
  final bool isDark;
  const _AddNoteFab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      heroTag: 'notes_fab',
      onPressed: () => _showCreateSheet(context, ref),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kIndigo, kCyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kIndigo.withAlpha(80),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateNoteSheet(isDark: isDark, ref: ref),
    );
  }
}

// ── Create note bottom sheet ───────────────────────────────────────────────────

class _CreateNoteSheet extends StatefulWidget {
  final bool isDark;
  final WidgetRef ref;
  const _CreateNoteSheet({required this.isDark, required this.ref});

  @override
  State<_CreateNoteSheet> createState() => _CreateNoteSheetState();
}

class _CreateNoteSheetState extends State<_CreateNoteSheet> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _isUrgent = false;
  bool _isPinned = false;
  DateTime? _reminderAt;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.black.withAlpha(180)
                : Colors.white.withAlpha(220),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'New Note',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : kDark0,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                style: TextStyle(
                    color: widget.isDark ? Colors.white : kDark0),
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: TextStyle(
                      color: widget.isDark
                          ? Colors.white38
                          : Colors.black38),
                  filled: true,
                  fillColor: widget.isDark
                      ? Colors.white.withAlpha(12)
                      : Colors.black.withAlpha(6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contentCtrl,
                maxLines: 4,
                style: TextStyle(
                    color: widget.isDark ? Colors.white : kDark0),
                decoration: InputDecoration(
                  hintText: 'Write your note here…',
                  hintStyle: TextStyle(
                      color: widget.isDark
                          ? Colors.white38
                          : Colors.black38),
                  filled: true,
                  fillColor: widget.isDark
                      ? Colors.white.withAlpha(12)
                      : Colors.black.withAlpha(6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ToggleChip(
                    label: 'Urgent',
                    icon: Icons.warning_rounded,
                    active: _isUrgent,
                    activeColor: kCoral,
                    isDark: widget.isDark,
                    onTap: () => setState(() => _isUrgent = !_isUrgent),
                  ),
                  const SizedBox(width: 8),
                  _ToggleChip(
                    label: 'Pin',
                    icon: Icons.push_pin_rounded,
                    active: _isPinned,
                    activeColor: kIndigo,
                    isDark: widget.isDark,
                    onTap: () => setState(() => _isPinned = !_isPinned),
                  ),
                  const SizedBox(width: 8),
                  _ToggleChip(
                    label: _reminderAt != null
                        ? '${_reminderAt!.day}/${_reminderAt!.month}'
                        : 'Remind',
                    icon: Icons.alarm_rounded,
                    active: _reminderAt != null,
                    activeColor: kCyan,
                    isDark: widget.isDark,
                    onTap: _pickReminder,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kIndigo, kCyan],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Save Note',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _reminderAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    widget.ref.read(notesControllerProvider.notifier).createNote(
          title: title,
          content: _contentCtrl.text.trim(),
          isPinned: _isPinned,
          isUrgent: _isUrgent,
          reminderAt: _reminderAt,
        );
    Navigator.pop(context);
  }
}

// ── Toggle chip ────────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withAlpha(40)
              : (isDark
                  ? Colors.white.withAlpha(12)
                  : Colors.black.withAlpha(8)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? activeColor.withAlpha(120) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: active
                    ? activeColor
                    : (isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active
                    ? activeColor
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
