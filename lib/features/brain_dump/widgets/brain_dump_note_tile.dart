import 'package:flutter/material.dart';

import '../../../core/models/note_model.dart';
import '../../../core/theme/ui_kit.dart';

/// An interactive triage card for an extracted Note or fleeting idea.
/// Shows content snippet, tags, and allows one-tap conversion to a Task.
class BrainDumpNoteTile extends StatelessWidget {
  final NoteItem note;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback? onConvertToTask;

  const BrainDumpNoteTile({
    super.key,
    required this.note,
    required this.selected,
    required this.onSelectedChanged,
    this.onConvertToTask,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: selected
            ? (isDark ? const Color(0xFF1F1E32) : Colors.white)
            : (isDark ? Colors.white.withAlpha(6) : Colors.black.withAlpha(4)),
        border: Border.all(
          color: selected
              ? kElectricAmber.withAlpha(isDark ? 90 : 70)
              : (isDark
                    ? Colors.white.withAlpha(15)
                    : Colors.black.withAlpha(10)),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: kElectricAmber.withAlpha(isDark ? 30 : 20),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selection circle
          GestureDetector(
            onTap: () => onSelectedChanged(!selected),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2, right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? kElectricAmber : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? kElectricAmber
                      : (isDark ? Colors.white38 : Colors.black26),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Color(0xFF0F0F1E),
                    )
                  : null,
            ),
          ),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white38 : Colors.black38),
                    decoration: selected ? null : TextDecoration.lineThrough,
                    letterSpacing: -0.2,
                  ),
                ),
                if (note.content.isNotEmpty && note.content != note.title) ...[
                  const SizedBox(height: 4),
                  Text(
                    note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: selected
                          ? (isDark ? Colors.white70 : Colors.black54)
                          : (isDark ? Colors.white24 : Colors.black26),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: note.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: kElectricAmber.withAlpha(isDark ? 30 : 20),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: kElectricAmber,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Convert to Task action button
          if (onConvertToTask != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Convert to Task',
              icon: Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              onPressed: onConvertToTask,
            ),
        ],
      ),
    );
  }
}
