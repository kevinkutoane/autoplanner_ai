/// Deterministic, platform-compatible notification ID generator.
///
/// ### Architecture & Partitioning Strategy:
/// Operating system notification managers (Android `NotificationManager`, iOS
/// `UNUserNotificationCenter`) require notification IDs to be 32-bit signed
/// integers (`[-2^31, 2^31 - 1]`).
///
/// To mathematically prevent cross-type collisions between notifications, the
/// 31-bit positive integer space (`[0, 0x7FFFFFFF]`, 0 to 2,147,483,647) is
/// partitioned into disjoint domains using a 4-bit domain tag:
///
/// - **Domain 0** (`0` to `134,217,727`): Reserved for Fixed System Notifications
///   (Morning Briefing: 9000, Evening Shutdown: 9001, Streak Shield: 9002, Test: 9099).
/// - **Domain 1** (`134,217,728` to `268,435,455`): Task Timed Reminders (`1 << 27`).
/// - **Domain 2** (`268,435,456` to `402,653,183`): Task Urgent Alerts (`2 << 27`).
/// - **Domain 3** (`402,653,184` to `536,870,911`): Note Timed Reminders (`3 << 27`).
/// - **Domain 4** (`536,870,912` to `671,088,639`): Note Urgent Alerts (`4 << 27`).
/// - **Domain 5** (`671,088,640` to `805,306,367`): Goal Deadline Reminders (`5 << 27`).
///
/// ### Mathematical Guarantees:
/// - **Zero Cross-Type Collisions**: By construction, domain ranges are strictly
///   disjoint. A Task Reminder and a Task Urgent Alert for the same task ID can
///   never produce the same integer ID.
/// - **Platform Compatibility**: The maximum allocated ID is 805,306,367, which is
///   strictly less than `0x7FFFFFFF` (2,147,483,647). All generated IDs are positive
///   and fit within Android's Java `int` and iOS's notification request identifiers.
/// - **Deterministic Hashing**: Rather than relying on `String.hashCode` (which Dart's
///   language specification does not guarantee to be stable across runtime launches),
///   entity IDs are hashed using a 32-bit FNV-1a non-cryptographic hash. This
///   guarantees 100% determinism across app restarts, foreground, and background execution.
///
/// ### Residual Risk & Intra-Domain Uniqueness:
/// Within each domain, entity IDs are allocated into 2^27 = 134,217,728 slots.
/// Hash-based allocation does not guarantee mathematical uniqueness within a single
/// domain for an infinite set of strings (Pigeonhole Principle). However, for realistic
/// local planner workloads (N <= 1,000 active entities), the collision probability is
/// less than 0.37% (1 - e^(-1000^2 / (2 * 2^27))), and cross-type collisions are 0.00%.
class NotificationIdGenerator {
  const NotificationIdGenerator._();

  // Fixed system notification IDs
  static const int briefingId = 9000;
  static const int shutdownId = 9001;
  static const int streakShieldId = 9002;
  static const int testNotificationId = 9099;

  // Domain tags (high bits)
  static const int _domainTaskReminder = 1;
  static const int _domainTaskUrgent = 2;
  static const int _domainNoteReminder = 3;
  static const int _domainNoteUrgent = 4;
  static const int _domainGoalDeadline = 5;

  static const int _entropyBits = 27;
  static const int _payloadMask =
      (1 << _entropyBits) - 1; // 0x07FFFFFF (134,217,727)

  /// Deterministic 32-bit FNV-1a hash of a UTF-16 string.
  static int fnv1a32(String input) {
    var hash = 0x811c9dc5; // 32-bit offset basis (2166136261)
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF; // 32-bit FNV prime
    }
    return hash;
  }

  static int _computeId(int domain, String entityId) {
    final hash = fnv1a32(entityId);
    final payload = hash & _payloadMask;
    return (domain << _entropyBits) | payload;
  }

  /// Notification ID for a timed task reminder.
  static int taskReminder(String taskId) =>
      _computeId(_domainTaskReminder, taskId);

  /// Notification ID for an immediate task urgent alert.
  static int taskUrgent(String taskId) => _computeId(_domainTaskUrgent, taskId);

  /// Notification ID for a timed note reminder.
  static int noteReminder(String noteId) =>
      _computeId(_domainNoteReminder, noteId);

  /// Notification ID for an immediate note urgent alert.
  static int noteUrgent(String noteId) => _computeId(_domainNoteUrgent, noteId);

  /// Notification ID for a goal deadline reminder.
  static int goalDeadline(String goalId) =>
      _computeId(_domainGoalDeadline, goalId);

  // ── Legacy ID computation (for backward-compatible cancellation) ─────────

  /// Legacy ID formula for task reminders prior to Phase 1B.4.
  static int legacyTaskReminder(String taskId) => taskId.hashCode;

  /// Legacy ID formula for note reminders prior to Phase 1B.4.
  static int legacyNoteReminder(String noteId) => 'note_$noteId'.hashCode;

  /// Legacy ID formula for goal reminders prior to Phase 1B.4.
  static int legacyGoalDeadline(String goalId) => goalId.hashCode + 1000000;
}
