import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/ui_kit.dart';
import '../../focus/screens/focus_mode_screen.dart';
import '../../planner/controllers/task_controller.dart';

/// Opens the global AI Command Omnibar spotlight overlay.
Future<void> showCommandPalette(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss Command Palette',
    barrierColor: Colors.black.withAlpha(160),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, anim1, anim2) => const CommandPaletteModal(),
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.06),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class CommandPaletteModal extends ConsumerStatefulWidget {
  const CommandPaletteModal({super.key});

  @override
  ConsumerState<CommandPaletteModal> createState() =>
      _CommandPaletteModalState();
}

class _CommandPaletteModalState extends ConsumerState<CommandPaletteModal>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isProcessing = false;
  CommandPreview? _preview;
  String? _errorMessage;
  String? _successMessage;

  final List<String> _quickSuggestions = const [
    '⏩ Push afternoon by 30m',
    '⏱️ What fits in 20m?',
    '🧹 Clear 2pm - 4pm',
    '🧘 Start focus session',
    '➕ Add Team Sync at 3pm',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    HapticFeedback.selectionClick();
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _successMessage = null;
      _preview = null;
    });

    try {
      final tasks = ref.read(taskControllerProvider);
      final ai = ref.read(aiServiceProvider);
      final command = await ai.parseScheduleCommand(
        query: trimmed,
        currentTasks: tasks,
      );

      final executor = ref.read(commandExecutorServiceProvider);
      final preview = executor.generatePreview(command, tasks);

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _preview = preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to analyze command: $e';
      });
    }
  }

  Future<void> _confirmApply(CommandPreview preview) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isProcessing = true;
    });

    final executor = ref.read(commandExecutorServiceProvider);
    final taskController = ref.read(taskControllerProvider.notifier);

    final result = await executor.execute(
      preview: preview,
      taskController: taskController,
    );

    if (!mounted) return;

    if (result.success) {
      HapticFeedback.lightImpact();
      setState(() {
        _isProcessing = false;
        _successMessage = result.message;
      });

      // If command was startFocus, navigate directly to focus mode!
      if (preview.command.type == ScheduleCommandType.startFocus &&
          result.focusTask != null) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FocusModeScreen(task: result.focusTask!),
          ),
        );
        return;
      }

      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      setState(() {
        _isProcessing = false;
        _errorMessage = result.message;
      });
    }
  }

  void _onSuggestionTap(String suggestion) {
    // Strip leading emoji
    final cleaned = suggestion.replaceAll(RegExp(r'^[^\w]+'), '').trim();
    _textCtrl.text = cleaned;
    _textCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: cleaned.length),
    );
    _handleSubmit(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Center(
        child: Container(
          width: 640,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(40)
                  : Colors.black.withAlpha(20),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 140 : 60),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: kIndigo.withAlpha(isDark ? 60 : 30),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Material(
                color: isDark
                    ? const Color(0xFF141724).withAlpha(240)
                    : Colors.white.withAlpha(245),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search Bar Header
                    _buildInputBar(isDark),

                    if (_isProcessing) ...[
                      const LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(kIndigo),
                        minHeight: 2.5,
                      ),
                    ],

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_successMessage != null) ...[
                              _buildSuccessBanner(isDark),
                            ] else if (_errorMessage != null) ...[
                              _buildErrorBanner(isDark),
                            ] else if (_preview != null) ...[
                              _buildPreviewCard(isDark, _preview!),
                            ] else ...[
                              _buildSuggestions(isDark),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(20)
                : Colors.black.withAlpha(15),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kIndigo, kCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              focusNode: _focusNode,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText:
                    'Type a command (e.g. "Push afternoon by 30 mins")...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: _handleSubmit,
            ),
          ),
          if (_textCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _textCtrl.clear();
                setState(() {
                  _preview = null;
                  _errorMessage = null;
                  _successMessage = null;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(16)
                  : Colors.black.withAlpha(10),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(25)
                    : Colors.black.withAlpha(15),
              ),
            ),
            child: Text(
              'ESC',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white60 : Colors.black54,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          child: Text(
            'QUICK ACTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickSuggestions.map((s) {
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _onSuggestionTap(s),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(14)
                      : Colors.black.withAlpha(8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withAlpha(24)
                        : Colors.black.withAlpha(14),
                  ),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kIndigo.withAlpha(isDark ? 20 : 12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kIndigo.withAlpha(40)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.tips_and_updates_rounded,
                color: kIndigo,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tip: Press Enter or tap any suggestion to preview schedule mutations before confirming.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(bool isDark, CommandPreview preview) {
    final type = preview.command.type;
    Color accentColor;
    String badgeTitle;
    IconData badgeIcon;

    switch (type) {
      case ScheduleCommandType.shift:
        accentColor = const Color(0xFFF39C12);
        badgeTitle = 'SHIFT SCHEDULE';
        badgeIcon = Icons.fast_forward_rounded;
        break;
      case ScheduleCommandType.clearWindow:
        accentColor = const Color(0xFFE74C3C);
        badgeTitle = 'CLEAR WINDOW';
        badgeIcon = Icons.event_busy_rounded;
        break;
      case ScheduleCommandType.quickAdd:
        accentColor = kCyan;
        badgeTitle = 'QUICK ADD';
        badgeIcon = Icons.add_task_rounded;
        break;
      case ScheduleCommandType.findFit:
        accentColor = kCyan;
        badgeTitle = 'AVAILABLE TASKS';
        badgeIcon = Icons.timer_outlined;
        break;
      case ScheduleCommandType.startFocus:
        accentColor = kIndigo;
        badgeTitle = 'FOCUS SESSION';
        badgeIcon = Icons.self_improvement_rounded;
        break;
      case ScheduleCommandType.unknown:
        accentColor = Colors.grey;
        badgeTitle = 'UNRECOGNIZED';
        badgeIcon = Icons.help_outline_rounded;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withAlpha(70)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badgeIcon, size: 13, color: accentColor),
                  const SizedBox(width: 5),
                  Text(
                    badgeTitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Action Preview',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          preview.summary,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 14),

        // Shifts list
        if (preview.shifts.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(8)
                  : Colors.black.withAlpha(5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(16)
                    : Colors.black.withAlpha(10),
              ),
            ),
            child: Column(
              children: preview.shifts.map((s) {
                final startFmt = DateFormat.jm().format(s.originalStart);
                final newStartFmt = DateFormat.jm().format(s.newStart);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.task.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$startFmt → ',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        newStartFmt,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Fitting tasks list
        if (preview.fittingTasks.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(8)
                  : Colors.black.withAlpha(5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: preview.fittingTasks.take(4).map((task) {
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 0,
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    '${task.durationMinutes} mins',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FocusModeScreen(task: task),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Start Focus',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Action confirmation buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (preview.command.type != ScheduleCommandType.findFit &&
                preview.command.type != ScheduleCommandType.unknown)
              ElevatedButton.icon(
                onPressed: () => _confirmApply(preview),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kIndigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text(
                  preview.command.type == ScheduleCommandType.startFocus
                      ? 'Launch Focus'
                      : 'Confirm & Apply',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCyan.withAlpha(isDark ? 25 : 18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCyan.withAlpha(70)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: kCyan, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _successMessage!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withAlpha(isDark ? 25 : 18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withAlpha(70)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
