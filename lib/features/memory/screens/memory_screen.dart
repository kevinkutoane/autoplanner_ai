import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/ui_kit.dart';
import '../../memory/controllers/memory_controller.dart';
import '../../../core/models/memory_entry_model.dart';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});
  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedType;
  String? _selectedTag;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const _typeLabels = {
    'task': 'Tasks',
    'note': 'Notes',
    'calendar': 'Calendar',
    'insight': 'Insights',
  };

  IconData _sourceIcon(String t) {
    switch (t) {
      case 'task':
        return Icons.task_alt_rounded;
      case 'note':
        return Icons.sticky_note_2_rounded;
      case 'calendar':
        return Icons.calendar_month_rounded;
      default:
        return Icons.psychology_rounded;
    }
  }

  Color _sourceColor(String t) {
    switch (t) {
      case 'task':
        return kIndigo;
      case 'note':
        return kCoral;
      case 'calendar':
        return kCyan;
      default:
        return kAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(memoryControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allTags = memories.expand((m) => m.tags).toSet().toList();

    final filtered = memories.where((m) {
      final matchQ =
          _query.isEmpty ||
          m.content.toLowerCase().contains(_query.toLowerCase());
      final matchT = _selectedType == null || m.sourceType == _selectedType;
      final matchTag = _selectedTag == null || m.tags.contains(_selectedTag);
      return matchQ && matchT && matchTag;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        subtle: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: GradientHeader(
                gradient: LinearGradient(
                  colors: [kDark0, const Color(0xFF0A1A2E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => kGradientTeal.createShader(b),
                          child: const Icon(
                            Icons.psychology_rounded,
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Memory',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withAlpha(35),
                            ),
                          ),
                          child: Text(
                            '${filtered.length} entries',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
                              hintText: 'Search memories...',
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

            // Source type filter
            SliverToBoxAdapter(
              child: Stagger(
                index: 0,
                child: SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    children: [
                      _SourceChip(
                        label: 'All',
                        icon: Icons.grid_view_rounded,
                        color: kIndigo,
                        selected: _selectedType == null,
                        onTap: () => setState(() => _selectedType = null),
                      ),
                      ..._typeLabels.entries.map(
                        (e) => _SourceChip(
                          label: e.value,
                          icon: _sourceIcon(e.key),
                          color: _sourceColor(e.key),
                          selected: _selectedType == e.key,
                          onTap: () => setState(
                            () => _selectedType = _selectedType == e.key
                                ? null
                                : e.key,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tag cloud
            if (allTags.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Stagger(
                    index: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: allTags
                            .map(
                              (t) => GestureDetector(
                                onTap: () => setState(
                                  () => _selectedTag = _selectedTag == t
                                      ? null
                                      : t,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: _selectedTag == t
                                        ? kGradientTeal
                                        : null,
                                    color: _selectedTag == t
                                        ? null
                                        : (isDark
                                              ? Colors.white.withAlpha(15)
                                              : Colors.black.withAlpha(7)),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _selectedTag == t
                                          ? Colors.transparent
                                          : (isDark
                                                ? Colors.white24
                                                : Colors.black12),
                                    ),
                                  ),
                                  child: Text(
                                    '#$t',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedTag == t
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white70
                                                : const Color(0xFF4A5568)),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),

            // Memory list
            if (filtered.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Stagger(
                    index: 2,
                    child: EmptyState(
                      icon: Icons.psychology_rounded,
                      message:
                          'No memories found. AI will learn from your tasks and notes!',
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((ctx, i) {
                    final m = filtered[i];
                    return Stagger(
                      index: i + 2,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MemoryTile(
                          memory: m,
                          icon: _sourceIcon(m.sourceType),
                          color: _sourceColor(m.sourceType),
                        ),
                      ),
                    );
                  }, childCount: filtered.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Memory tile ──────────────────────────────────────────────────────────────
class _MemoryTile extends ConsumerWidget {
  final MemoryEntry memory;
  final IconData icon;
  final Color color;
  const _MemoryTile({
    required this.memory,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withAlpha(isDark ? 40 : 25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 14, color: color),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatDate(memory.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => ref
                              .read(memoryControllerProvider.notifier)
                              .deleteMemory(memory.id),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      memory.content,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: isDark ? Colors.white.withAlpha(210) : kDark0,
                      ),
                    ),
                    if (memory.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: memory.tags
                            .take(4)
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withAlpha(isDark ? 35 : 20),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '#$t',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: color,
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
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ── Source chip ──────────────────────────────────────────────────────────────
class _SourceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _SourceChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color
              : (isDark
                    ? Colors.white.withAlpha(15)
                    : Colors.black.withAlpha(7)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (isDark ? Colors.white24 : Colors.black12),
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withAlpha(80), blurRadius: 10)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white60 : const Color(0xFF6B6B7A)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF4A4A5A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
