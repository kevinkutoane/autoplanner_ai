import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/note_controller.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _searchQuery = '';
  String? _selectedTag;

  @override
  Widget build(BuildContext context) {
    final allNotes = ref.watch(noteControllerProvider);

    // Apply filters
    var notes = allNotes;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      notes = notes.where((n) {
        return n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q) ||
            n.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }
    if (_selectedTag != null) {
      notes = notes.where((n) => n.tags.contains(_selectedTag)).toList();
    }

    // Separate pinned and unpinned
    final pinnedNotes = notes.where((n) => n.isPinned).toList();
    final unpinnedNotes = notes.where((n) => !n.isPinned).toList();

    // Collect all tags for filter chips
    final allTags = <String>{};
    for (final note in allNotes) {
      allTags.addAll(note.tags);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('NoteStack AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: _NoteSearchDelegate(ref));
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Tag filter chips
          if (allTags.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _selectedTag == null,
                      onSelected: (_) => setState(() => _selectedTag = null),
                    ),
                  ),
                  ...allTags.map((tag) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag),
                        selected: _selectedTag == tag,
                        onSelected: (selected) {
                          setState(() {
                            _selectedTag = selected ? tag : null;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Notes list
          Expanded(
            child: notes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.note_add,
                          size: 64,
                          color: AppTheme.textSecondary.withAlpha(80),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No notes yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Capture your ideas, meeting notes,\nand thoughts with AI assistance',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (pinnedNotes.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'PINNED',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        ...pinnedNotes.map(
                          (note) => NoteCard(
                            note: note,
                            onTap: () => _openEditor(note.id),
                            onPin: () => ref
                                .read(noteControllerProvider.notifier)
                                .togglePin(note.id),
                            onDelete: () => ref
                                .read(noteControllerProvider.notifier)
                                .deleteNote(note.id),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (unpinnedNotes.isNotEmpty) ...[
                        if (pinnedNotes.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'ALL NOTES',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ...unpinnedNotes.map(
                          (note) => NoteCard(
                            note: note,
                            onTap: () => _openEditor(note.id),
                            onPin: () => ref
                                .read(noteControllerProvider.notifier)
                                .togglePin(note.id),
                            onDelete: () => ref
                                .read(noteControllerProvider.notifier)
                                .deleteNote(note.id),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openEditor(String? noteId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteEditorScreen(noteId: noteId)),
    );
  }
}

class _NoteSearchDelegate extends SearchDelegate<String?> {
  final WidgetRef ref;

  _NoteSearchDelegate(this.ref);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearch();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearch();

  Widget _buildSearch() {
    final notes = ref.read(noteControllerProvider);
    final q = query.toLowerCase();
    final filtered = notes.where((n) {
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q) ||
          n.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final note = filtered[index];
        return ListTile(
          title: Text(note.title),
          subtitle: Text(
            note.summary ?? note.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            DateFormat('MMM d').format(note.updatedAt),
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          onTap: () {
            close(context, note.id);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoteEditorScreen(noteId: note.id),
              ),
            );
          },
        );
      },
    );
  }
}
