import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/memory_entry_model.dart';
import '../controllers/memory_controller.dart';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  String _searchQuery = '';
  String? _selectedTag;
  String? _selectedSourceType;

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(memoryControllerProvider.notifier);
    final allMemories = ref.watch(memoryControllerProvider);
    final allTags = controller.allTags;
    final tagCounts = controller.tagCounts;

    List<MemoryEntry> filteredMemories = allMemories;

    if (_searchQuery.isNotEmpty) {
      filteredMemories = controller.searchMemories(_searchQuery);
    }
    if (_selectedTag != null) {
      filteredMemories = filteredMemories
          .where((m) => m.tags.contains(_selectedTag))
          .toList();
    }
    if (_selectedSourceType != null) {
      filteredMemories = filteredMemories
          .where((m) => m.sourceType == _selectedSourceType)
          .toList();
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── Header ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.headerGradient,
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Memory',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.psychology,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '${allMemories.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search memories...',
                        hintStyle:
                            TextStyle(color: Colors.white.withAlpha(120)),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.white.withAlpha(150)),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Source Type Filter ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _selectedSourceType == null,
                      onTap: () =>
                          setState(() => _selectedSourceType = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Tasks',
                      icon: Icons.task_alt,
                      selected: _selectedSourceType == 'task',
                      onTap: () =>
                          setState(() => _selectedSourceType = 'task'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Notes',
                      icon: Icons.note_alt,
                      selected: _selectedSourceType == 'note',
                      onTap: () =>
                          setState(() => _selectedSourceType = 'note'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Calendar',
                      icon: Icons.calendar_month,
                      selected: _selectedSourceType == 'calendar',
                      onTap: () =>
                          setState(() => _selectedSourceType = 'calendar'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Tag Cloud ──────────────────────────────────────────
          if (allTags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: allTags.take(15).map((tag) {
                    final isSelected = _selectedTag == tag;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTag = isSelected ? null : tag;
                        });
                      },
                      child: Chip(
                        label: Text(
                          '#$tag (${tagCounts[tag] ?? 0})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                        backgroundColor: isSelected
                            ? AppTheme.accentIndigo
                            : null,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // ─── Memories List ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                '${filteredMemories.length} memor${filteredMemories.length == 1 ? 'y' : 'ies'}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          if (filteredMemories.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.psychology,
                        size: 48, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text(
                      'No memories yet.\nComplete tasks or write notes to build your memory.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final memory = filteredMemories[index];
                  return _MemoryTile(
                    memory: memory,
                    onDelete: () {
                      ref
                          .read(memoryControllerProvider.notifier)
                          .deleteMemory(memory.id);
                    },
                  );
                },
                childCount: filteredMemories.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentIndigo : Colors.grey.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : AppTheme.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  final MemoryEntry memory;
  final VoidCallback onDelete;

  const _MemoryTile({required this.memory, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _sourceIcon(memory.sourceType),
                    size: 18,
                    color: _sourceColor(memory.sourceType),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    memory.sourceType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _sourceColor(memory.sourceType),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d, h:mm a').format(memory.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.close,
                        size: 16, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                memory.content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (memory.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: memory.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentIndigo.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.accentIndigo,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (memory.relevanceScore > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.trending_up,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Relevance: ${(memory.relevanceScore * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _sourceIcon(String sourceType) {
    switch (sourceType) {
      case 'task':
        return Icons.task_alt;
      case 'note':
        return Icons.note_alt;
      case 'calendar':
        return Icons.calendar_month;
      default:
        return Icons.psychology;
    }
  }

  Color _sourceColor(String sourceType) {
    switch (sourceType) {
      case 'task':
        return AppTheme.accentCyan;
      case 'note':
        return AppTheme.accentIndigo;
      case 'calendar':
        return AppTheme.accentOrange;
      default:
        return AppTheme.textSecondary;
    }
  }
}
