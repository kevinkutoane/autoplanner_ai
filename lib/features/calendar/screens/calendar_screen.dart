import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/ui_kit.dart';
import '../../calendar/controllers/calendar_controller.dart';
import '../../../core/models/calendar_event_model.dart';
import '../../../core/providers/providers.dart';
import '../widgets/timeline_view.dart';
import '../../../core/utils/date_utils.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with TickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  bool _showTimeline = false;
  bool _syncing = false;
  late final AnimationController _monthAC;
  late final Animation<double> _monthFade;

  @override
  void initState() {
    super.initState();
    _monthAC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _monthFade = CurvedAnimation(parent: _monthAC, curve: Curves.easeOut);
    _monthAC.forward();
  }

  @override
  void dispose() {
    _monthAC.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) {
    _monthAC.reverse().then((_) {
      setState(
        () => _focusedMonth = DateTime(
          _focusedMonth.year,
          _focusedMonth.month + delta,
        ),
      );
      _monthAC.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(calendarControllerProvider);
    final calCtrl = ref.read(calendarControllerProvider.notifier);
    final syncConflicts = calCtrl.syncConflicts;

    final dayEvents =
        events.where((e) => isSameDay(e.startTime, _selectedDate)).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _GlowFab(onTap: () => _showAddDialog(context, ref)),
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
                    colors: [kDark0, Color(0xFF0E1535)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _IconBtn(
                            icon: Icons.chevron_left_rounded,
                            onTap: () => _changeMonth(-1),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FadeTransition(
                              opacity: _monthFade,
                              child: Text(
                                DateFormat('MMMM yyyy').format(_focusedMonth),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ),
                          _IconBtn(
                            icon: Icons.chevron_right_rounded,
                            onTap: () => _changeMonth(1),
                          ),
                          const SizedBox(width: 8),
                          _IconBtn(
                            icon: Icons.today_rounded,
                            onTap: () {
                              setState(() {
                                _selectedDate = DateTime.now();
                                _focusedMonth = DateTime.now();
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          // Timeline / grid toggle
                          _IconBtn(
                            icon: _showTimeline
                                ? Icons.calendar_view_month_rounded
                                : Icons.view_timeline_rounded,
                            onTap: () =>
                                setState(() => _showTimeline = !_showTimeline),
                          ),
                          const SizedBox(width: 4),
                          // Sync button with conflict badge
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _IconBtn(
                                icon: _syncing
                                    ? Icons.sync_rounded
                                    : Icons.cloud_sync_outlined,
                                onTap: _syncing ? null : () => _triggerSync(),
                              ),
                              if (syncConflicts.isNotEmpty)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: kCoral,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _MiniCalendar(
                        focusedMonth: _focusedMonth,
                        selectedDate: _selectedDate,
                        events: events,
                        onDateSelected: (d) =>
                            setState(() => _selectedDate = d),
                      ),
                    ],
                  ),
                ),
              ),

              // Selected date label
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Stagger(
                    index: 0,
                    child: BodySectionHeader(
                      title: _formatDayLabel(_selectedDate),
                      trailing: '${dayEvents.length}',
                    ),
                  ),
                ),
              ),

              // Events — timeline or list
              if (_showTimeline)
                SliverFillRemaining(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    child: TimelineView(
                      selectedDate: _selectedDate,
                      events: dayEvents,
                      onEventTap: (ev) {
                        if (ev.syncStatus == 'conflict') {
                          _showConflictDialog(context, ref, ev);
                        } else {
                          _showEditDialog(context, ref, ev);
                        }
                      },
                    ),
                  ),
                )
              else if (dayEvents.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Stagger(
                      index: 1,
                      child: EmptyState(
                        icon: Icons.calendar_today_rounded,
                        message: 'Nothing scheduled. Tap + to add an event!',
                      ),
                    ),
                  ),
                )
              else if (!_showTimeline)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((ctx, i) {
                      final ev = dayEvents[i];
                      return Stagger(
                        index: i + 1,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _EventTile(
                            event: ev,
                            onEdit: () => ev.syncStatus == 'conflict'
                                ? _showConflictDialog(context, ref, ev)
                                : _showEditDialog(context, ref, ev),
                            onDelete: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete event?'),
                                  content: const Text(
                                    'This event will be permanently removed.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: Color(0xFFFF4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                ref
                                    .read(calendarControllerProvider.notifier)
                                    .deleteEvent(ev.id);
                              }
                            },
                          ),
                        ),
                      );
                    }, childCount: dayEvents.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDayLabel(DateTime d) {
    final now = DateTime.now();
    if (isSameDay(d, now)) return 'Today';
    if (isSameDay(d, now.add(const Duration(days: 1)))) return 'Tomorrow';
    if (isSameDay(d, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }

    return DateFormat('EEEE, MMM d').format(d);
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _AddEventDialog(
        initialDate: _selectedDate,
        onAdd: (ev) =>
            ref.read(calendarControllerProvider.notifier).addEvent(ev),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) {
    showDialog(
      context: context,
      builder: (_) => _AddEventDialog(
        initialDate: _selectedDate,
        initialEvent: event,
        onAdd: (ev) =>
            ref.read(calendarControllerProvider.notifier).updateEvent(ev),
      ),
    );
  }

  void _showConflictDialog(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C3A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: kCoral, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Sync Conflict',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Text(
            '"${event.title}" was modified both locally and in Google Calendar.\n\nWhich version do you want to keep?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                ref
                    .read(calendarControllerProvider.notifier)
                    .resolveConflictKeepRemote(event);
              },
              child: const Text('Keep Remote', style: TextStyle(color: kCyan)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kCoral,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(calendarControllerProvider.notifier)
                    .resolveConflictKeepLocal(event);
              },
              child: const Text('Keep Local'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onRefresh() => _triggerSync();

  Future<void> _triggerSync() async {
    final settings = ref.read(settingsProvider);
    if (!settings.isGoogleCalendarConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect Google Calendar in Settings first.'),
        ),
      );
      return;
    }
    setState(() => _syncing = true);
    final syncSvc = ref.read(calendarSyncServiceProvider);
    final result = await syncSvc.incrementalSync();
    if (!mounted) return;
    setState(() => _syncing = false);
    final msg = result.hasError
        ? 'Sync failed: ${result.error}'
        : 'Synced — ↓${result.pulled} pulled, ↑${result.pushed} pushed';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    ref.invalidate(calendarControllerProvider);
  }
}

// ── Mini calendar ────────────────────────────────────────────────────────────
class _MiniCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onDateSelected;

  const _MiniCalendar({
    required this.focusedMonth,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    ).day;
    final startWeekday = firstOfMonth.weekday % 7; // 0=Sun
    final now = DateTime.now();

    final cells = startWeekday + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        // day-of-week labels
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        // grid
        for (var row = 0; row < rows; row++) ...[
          Row(
            children: List.generate(7, (col) {
              final index = row * 7 + col;
              final dayNum = index - startWeekday + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox());
              }
              final d = DateTime(focusedMonth.year, focusedMonth.month, dayNum);
              final isSelected = isSameDay(d, selectedDate);
              final isToday = isSameDay(d, now);
              final hasEvents = events.any((e) => isSameDay(e.startTime, d));

              return Expanded(
                child: GestureDetector(
                  onTap: () => onDateSelected(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(2),
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: isSelected ? kGradientMain : null,
                      color: isSelected
                          ? null
                          : isToday
                          ? Colors.white.withAlpha(22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected
                          ? Border.all(color: kCyan.withAlpha(120), width: 1)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday || isSelected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isToday ? kCyan : Colors.white70),
                          ),
                        ),
                        if (hasEvents && !isSelected)
                          Positioned(
                            bottom: 3,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: kCoral,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 2),
        ],
      ],
    );
  }
}

// ── Event tile ────────────────────────────────────────────────────────────────
class _EventTile extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _EventTile({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConflict = event.syncStatus == 'conflict';
    return GestureDetector(
      onTap: onEdit,
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: isConflict ? null : kGradientTeal,
                  color: isConflict ? kCoral : null,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isConflict) ...[
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 14,
                                    color: kCoral,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    event.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: kCyan,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${DateFormat('h:mm a').format(event.startTime)} – ${DateFormat('h:mm a').format(event.endTime)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF7C7C8A),
                                  ),
                                ),
                              ],
                            ),
                            if (event.description?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                event.description!,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: isDark
                                      ? Colors.white54
                                      : const Color(0xFF9090A0),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Edit event',
                        child: GestureDetector(
                          onTap: onEdit,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: isDark
                                  ? Colors.white54
                                  : kIndigo.withAlpha(180),
                            ),
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Delete event',
                        child: GestureDetector(
                          onTap: onDelete,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: isDark
                                  ? Colors.white38
                                  : const Color(0xFFFF6B6B),
                            ),
                          ),
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

// ── Add event dialog ─────────────────────────────────────────────────────────
class _AddEventDialog extends StatefulWidget {
  final DateTime initialDate;
  final CalendarEvent? initialEvent;
  final ValueChanged<CalendarEvent> onAdd;
  const _AddEventDialog({
    required this.initialDate,
    this.initialEvent,
    required this.onAdd,
  });
  @override
  State<_AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<_AddEventDialog>
    with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    final ev = widget.initialEvent;
    if (ev != null) {
      _titleCtrl.text = ev.title;
      _descCtrl.text = ev.description ?? '';
      _start = ev.startTime;
      _end = ev.endTime;
    } else {
      _start = widget.initialDate.copyWith(hour: 9, minute: 0, second: 0);
      _end = _start.add(const Duration(hours: 1));
    }
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scale = CurvedAnimation(parent: _ac, curve: Curves.elasticOut);
    _ac.forward();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _ac.dispose();
    super.dispose();
  }

  Future<void> _pickTime(BuildContext ctx, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.fromDateTime(isStart ? _start : _end),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = _start.copyWith(hour: picked.hour, minute: picked.minute);
        if (_end.isBefore(_start)) _end = _start.add(const Duration(hours: 1));
      } else {
        _end = _end.copyWith(hour: picked.hour, minute: picked.minute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScaleTransition(
      scale: _scale,
      child: AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C3A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => kGradientTeal.createShader(b),
              child: Icon(
                widget.initialEvent != null
                    ? Icons.edit_rounded
                    : Icons.calendar_month_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.initialEvent != null ? 'Edit Event' : 'New Event',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassField(
                controller: _titleCtrl,
                label: 'Title',
                hintText: 'Event title',
              ),
              const SizedBox(height: 10),
              GlassField(
                controller: _descCtrl,
                label: 'Description',
                hintText: 'Description (optional)',
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _TimeBox(
                      label: 'Start',
                      time: _start,
                      onTap: () => _pickTime(context, isStart: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeBox(
                      label: 'End',
                      time: _end,
                      onTap: () => _pickTime(context, isStart: false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          GhostBtn(label: 'Cancel', onTap: () => Navigator.pop(context)),
          const SizedBox(width: 8),
          GradBtn(
            label: widget.initialEvent != null ? 'Save' : 'Add Event',
            icon: widget.initialEvent != null
                ? Icons.check_rounded
                : Icons.add_rounded,
            gradient: kGradientTeal,
            onTap: () {
              final title = _titleCtrl.text.trim();
              if (title.isEmpty) return;
              if (!_end.isAfter(_start)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('End time must be after start time.'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              widget.onAdd(
                CalendarEvent(
                  id:
                      widget.initialEvent?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  title: title,
                  description: _descCtrl.text.trim().isEmpty
                      ? null
                      : _descCtrl.text.trim(),
                  startTime: _start,
                  endTime: _end,
                ),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  final DateTime time;
  final VoidCallback onTap;
  const _TimeBox({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withAlpha(18)
              : Colors.black.withAlpha(7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('h:mm a').format(time),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kCyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Icon button ───────────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext _) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
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
      label: 'Add event',
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: kGradientTeal,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kCyan.withAlpha(120),
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
