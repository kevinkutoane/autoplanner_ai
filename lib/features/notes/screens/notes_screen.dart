import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/ui_kit.dart';
import '../../notes/controllers/note_controller.dart';
import '../../../core/models/note_model.dart';
import 'note_editor_screen.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});
  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedTag;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() =>
      Future.delayed(const Duration(milliseconds: 400));

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(noteControllerProvider);

    final allTags = notes.expand((n) => n.tags).toSet().toList();
    final filtered = notes.where((n) {
      final matchQ =
          _query.isEmpty ||
          n.title.toLowerCase().contains(_query.toLowerCase()) ||
          n.content.toLowerCase().contains(_query.toLowerCase());
      final matchT = _selectedTag == null || n.tags.contains(_selectedTag);
      return matchQ && matchT;
    }).toList();

    final pinned = filtered.where((n) => n.isPinned).toList();
    final unpinned = filtered.where((n) => !n.isPinned).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _GlowFab(
        onTap: () => Navigator.push(context, _route(const NoteEditorScreen())),
      ),
      body: OrbBackground(
        subtle: true,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: GradientHeader(
                  gradient: LinearGradient(
                    colors: [kDark0, const Color(0xFF1F1035)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // search
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(18),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withAlpha(35),
                              ),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) => setState(() => _query = v),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search notes...',
                                hintStyle: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                                suffixIcon: _query.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          _searchCtrl.clear();
                                          setState(() => _query = '');
                                        },
                                        child: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white54,
                                          size: 20,
                                        ),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tag chips
              if (allTags.isNotEmpty)
                SliverToBoxAdapter(
                  child: Stagger(
                    index: 0,
                    child: SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        children: [
                          _TagChip(
                            label: 'All',
                            selected: _selectedTag == null,
                            onTap: () => setState(() => _selectedTag = null),
                          ),
                          ...allTags.map(
                            (tag) => _TagChip(
                              label: tag,
                              selected: _selectedTag == tag,
                              onTap: () => setState(
                                () => _selectedTag = _selectedTag == tag
                                    ? null
                                    : tag,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Pinned
              if (pinned.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Stagger(
                      index: 1,
                      child: const BodySectionHeader(title: 'Pinned'),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Stagger(
                        index: i + 2,
                        child: _NoteCard(
                          note: pinned[i],
                          onTap: () => Navigator.push(
                            ctx,
                            _route(NoteEditorScreen(note: pinned[i])),
                          ),
                        ),
                      ),
                      childCount: pinned.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.1,
                        ),
                  ),
                ),
              ],

              // All notes / Other notes
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Stagger(
                    index: pinned.isEmpty ? 1 : pinned.length + 2,
                    child: BodySectionHeader(
                      title: pinned.isEmpty ? 'All Notes' : 'Other Notes',
                      trailing: '${filtered.length}',
                    ),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Stagger(
                      index: 99,
                      child: EmptyState(
                        icon: Icons.sticky_note_2_rounded,
                        message: 'No notes found. Tap + to create your first!',
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((ctx, i) {
                      final n = unpinned[i];
                      return Stagger(
                        index: i + pinned.length + 3,
                        child: _NoteCard(
                          note: n,
                          onTap: () => Navigator.push(
                            ctx,
                            _route(NoteEditorScreen(note: n)),
                          ),
                        ),
                      );
                    }, childCount: unpinned.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.1,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  PageRoute<T> _route<T>(Widget page) => PageRouteBuilder(
    pageBuilder: (_, a, __) => page,
    transitionsBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

// ── Note card ───────────────────────────────────────────────────────────────
class _NoteCard extends ConsumerWidget {
  final NoteItem note;
  final VoidCallback onTap;
  const _NoteCard({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _NoteActions(
            note: note,
            onPin: () {
              Navigator.pop(context);
              ref.read(noteControllerProvider.notifier).togglePin(note.id);
            },
            onDelete: () {
              Navigator.pop(context);
              showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete note?'),
                  content: const Text('This note will be permanently deleted.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Color(0xFFFF4444)),
                      ),
                    ),
                  ],
                ),
              ).then((confirmed) {
                if (confirmed == true) {
                  ref.read(noteControllerProvider.notifier).deleteNote(note.id);
                }
              });
            },
          ),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (note.isPinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 13,
                      color: kCoral,
                    ),
                  ),
                Expanded(
                  child: Text(
                    note.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                note.summary ?? note.content,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark ? Colors.white60 : const Color(0xFF6B6B7A),
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: note.tags
                    .take(2)
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: kIndigo.withAlpha(isDark ? 40 : 20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 9,
                            color: kIndigo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tag chip ────────────────────────────────────────────────────────────────
class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? kGradientMain : null,
          color: selected
              ? null
              : Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withAlpha(15)
              : Colors.black.withAlpha(8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Theme.of(context).brightness == Brightness.dark
                ? Colors.white24
                : Colors.black12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : const Color(0xFF4A4A5A),
          ),
        ),
      ),
    );
  }
}

// ── Note actions bottom sheet ────────────────────────────────────────────────
class _NoteActions extends StatelessWidget {
  final NoteItem note;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  const _NoteActions({
    required this.note,
    required this.onPin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(16),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionTile(
              icon: note.isPinned
                  ? Icons.push_pin_outlined
                  : Icons.push_pin_rounded,
              label: note.isPinned ? 'Unpin' : 'Pin',
              color: kCoral,
              onTap: onPin,
            ),
            Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: const Color(0xFFFF4444),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

// ── Glow FAB ────────────────────────────────────────────────────────────────
class _GlowFab extends StatefulWidget {
  final VoidCallback onTap;
  const _GlowFab({required this.onTap});
  @override
  State<_GlowFab> createState() => _GlowFabState();
}

class _GlowFabState extends State<_GlowFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) =>
        Transform.scale(scale: 1.0 + 0.04 * _c.value, child: child),
    child: Semantics(
      button: true,
      label: 'Add note',
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: kGradientMain,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kIndigo.withAlpha(120),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    ),
  ),
  );
}
