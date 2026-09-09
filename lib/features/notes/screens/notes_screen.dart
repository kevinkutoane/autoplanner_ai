import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/ui_kit.dart';
import '../../../core/models/note_model.dart';
import '../controllers/note_controller.dart';
import 'note_detail_screen.dart';

class NoteSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final _noteSearchProvider = NotifierProvider<NoteSearchNotifier, String>(
  NoteSearchNotifier.new,
);

class NoteTagFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final _noteTagFilterProvider = NotifierProvider<NoteTagFilterNotifier, String?>(
  NoteTagFilterNotifier.new,
);

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allNotes = ref.watch(noteControllerProvider);
    final searchQuery = ref.watch(_noteSearchProvider).toLowerCase();
    final tagFilter = ref.watch(_noteTagFilterProvider);
    final noteCtrl = ref.read(noteControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTags = noteCtrl.allTags;

    // Apply filters
    var notes = allNotes;
    if (searchQuery.isNotEmpty) {
      notes = noteCtrl.search(searchQuery);
    }
    if (tagFilter != null) {
      notes = notes
          .where(
            (n) =>
                n.tags.any((t) => t.toLowerCase() == tagFilter.toLowerCase()),
          )
          .toList();
    }

    final pinned = notes.where((n) => n.isPinned).toList();
    final unpinned = notes.where((n) => !n.isPinned).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ΓöÇΓöÇ Header ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
              GradientHeader(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notes',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${allNotes.length} note${allNotes.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      onPressed: () => _showAddNoteDialog(context, ref),
                    ),
                  ],
                ),
              ),

              // ΓöÇΓöÇ Search bar ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: GlassField(
                  label: 'Search',
                  hintText: 'Search notesΓÇª',
                  icon: Icons.search_rounded,
                  onChanged: (v) =>
                      ref.read(_noteSearchProvider.notifier).set(v),
                ),
              ),

              if (allTags.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GlassChip(
                          label: 'All',
                          selected: tagFilter == null,
                          onTap: () => ref
                              .read(_noteTagFilterProvider.notifier)
                              .set(null),
                        ),
                      ),
                      ...allTags.map(
                        (tag) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GlassChip(
                            label: tag,
                            selected: tagFilter == tag,
                            onTap: () => ref
                                .read(_noteTagFilterProvider.notifier)
                                .set(tagFilter == tag ? null : tag),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ΓöÇΓöÇ Notes list ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
              Expanded(
                child: notes.isEmpty
                    ? EmptyState(
                        icon: Icons.sticky_note_2_outlined,
                        message: searchQuery.isNotEmpty || tagFilter != null
                            ? 'No matching notes ΓÇö try a different search or filter'
                            : 'No notes yet ΓÇö tap + to create your first note',
                      )
                    : AnimationLimiter(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          children: [
                            // Pinned section
                            if (pinned.isNotEmpty) ...[
                              const SectionLabel(
                                icon: Icons.push_pin_rounded,
                                label: 'Pinned',
                              ),
                              const SizedBox(height: 8),
                              ...pinned.asMap().entries.map(
                                (e) => AnimationConfiguration.staggeredList(
                                  position: e.key,
                                  duration: const Duration(milliseconds: 350),
                                  child: SlideAnimation(
                                    verticalOffset: 30,
                                    child: FadeInAnimation(
                                      child: _NoteCard(
                                        note: e.value,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Unpinned section
                            if (unpinned.isNotEmpty) ...[
                              if (pinned.isNotEmpty)
                                const SectionLabel(
                                  icon: Icons.notes_rounded,
                                  label: 'Others',
                                ),
                              const SizedBox(height: 8),
                              ...unpinned.asMap().entries.map(
                                (e) => AnimationConfiguration.staggeredList(
                                  position: e.key + pinned.length,
                                  duration: const Duration(milliseconds: 350),
                                  child: SlideAnimation(
                                    verticalOffset: 30,
                                    child: FadeInAnimation(
                                      child: _NoteCard(
                                        note: e.value,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

  void _showAddNoteDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? kDark1 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'New Note',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : kDark0,
          ),
        ),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: isDark ? Colors.white : kDark0),
          decoration: InputDecoration(
            hintText: 'Note titleΓÇª',
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
            label: 'Create',
            onTap: () {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              ref
                  .read(noteControllerProvider.notifier)
                  .createNote(title: title);
              Navigator.pop(ctx);
              // Open the new note for editing
              final notes = ref.read(noteControllerProvider);
              if (notes.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoteDetailScreen(noteId: notes.first.id),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── Note card ─────────────────────────────────────────────────────────────────
class _NoteCard extends ConsumerWidget {
  final NoteItem note;
  final bool isDark;
  const _NoteCard({required this.note, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat.yMMMd().format(note.updatedAt);
    final preview = note.content.isNotEmpty
        ? note.content.length > 120
              ? '${note.content.substring(0, 120)}ΓÇª'
              : note.content
        : 'No content yet';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: note.id)),
        ),
        onLongPress: () => _showContextMenu(context, ref),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: kAmber,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      note.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : kDark0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                note.summary ?? preview,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: note.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: kIndigo.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              color: kIndigo,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (note.linkedTaskIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 14,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${note.linkedTaskIds.length} linked task${note.linkedTaskIds.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    final noteCtrl = ref.read(noteControllerProvider.notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: isDark ? kDark1.withAlpha(220) : Colors.white.withAlpha(240),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    note.isPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    color: kAmber,
                  ),
                  title: Text(note.isPinned ? 'Unpin' : 'Pin to top'),
                  onTap: () {
                    noteCtrl.togglePin(note.id);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: kCoral,
                  ),
                  title: const Text('Delete'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context, ref);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('"${note.title}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(noteControllerProvider.notifier).removeNote(note.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: kCoral)),
          ),
        ],
      ),
    );
  }
}
