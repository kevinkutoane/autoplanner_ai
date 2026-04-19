import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/ui_kit.dart';
import '../../planner/controllers/task_controller.dart';
import '../../notes/controllers/note_controller.dart';
import '../../goals/controllers/goal_controller.dart';

enum _Filter { all, tasks, notes, goals }

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = _ctrl.text.trim().toLowerCase();

    // ── Gather results ───────────────────────────────────────────────────────
    final results = <_SearchResult>[];

    if (query.isNotEmpty) {
      if (_filter == _Filter.all || _filter == _Filter.tasks) {
        for (final t in ref.watch(taskControllerProvider)) {
          if (t.title.toLowerCase().contains(query) ||
              t.tags.any((tag) => tag.toLowerCase().contains(query))) {
            results.add(_SearchResult(
              type: _Filter.tasks,
              icon: Icons.task_alt_rounded,
              title: t.title,
              subtitle: t.tags.isEmpty ? 'No tags' : t.tags.join(', '),
              color: kIndigo,
            ));
          }
        }
      }

      if (_filter == _Filter.all || _filter == _Filter.notes) {
        for (final n in ref.watch(notesControllerProvider)) {
          if (n.title.toLowerCase().contains(query) ||
              n.content.toLowerCase().contains(query)) {
            results.add(_SearchResult(
              type: _Filter.notes,
              icon: Icons.sticky_note_2_rounded,
              title: n.title,
              subtitle: n.content.isEmpty ? 'No content' : n.content,
              color: kCyan,
            ));
          }
        }
      }

      if (_filter == _Filter.all || _filter == _Filter.goals) {
        for (final g in ref.watch(goalControllerProvider)) {
          if (g.title.toLowerCase().contains(query) ||
              g.description.toLowerCase().contains(query)) {
            results.add(_SearchResult(
              type: _Filter.goals,
              icon: Icons.flag_rounded,
              title: g.title,
              subtitle: g.description.isEmpty ? 'No description' : g.description,
              color: kCoral,
            ));
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        subtle: true,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          color: isDark ? Colors.white : kDark0,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search tasks, notes, goals…',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          border: InputBorder.none,
                          suffixIcon: _ctrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 20),
                                  onPressed: () {
                                    _ctrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Filter chips ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: _Filter.values.map((f) {
                    final active = _filter == f;
                    final label = f.name[0].toUpperCase() + f.name.substring(1);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: active ? kGradientMain : null,
                            color: active
                                ? null
                                : (isDark
                                    ? Colors.white.withAlpha(12)
                                    : Colors.black.withAlpha(8)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? Colors.transparent
                                  : (isDark
                                      ? Colors.white.withAlpha(30)
                                      : Colors.black.withAlpha(20)),
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  active ? FontWeight.w600 : FontWeight.w500,
                              color: active
                                  ? Colors.white
                                  : (isDark ? Colors.white60 : Colors.black54),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 4),

              // ── Results ──────────────────────────────────────────────
              Expanded(
                child: query.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShaderMask(
                              shaderCallback: (r) =>
                                  kGradientMain.createShader(r),
                              child: const Icon(Icons.search_rounded,
                                  size: 56, color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Start typing to search',
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      )
                    : results.isEmpty
                        ? Center(
                            child: Text(
                              'No results for "$query"',
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final r = results[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: r.color.withAlpha(30),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(r.icon,
                                            size: 18, color: r.color),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.title,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : kDark0,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              r.subtitle,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.black45,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResult {
  final _Filter type;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SearchResult({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}
