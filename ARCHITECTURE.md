# AutoPlanner AI Architecture

This document provides a high-level overview of the structural and architectural design of AutoPlanner AI.

## Core Architectural Principles

- **Feature-First Organization:** The codebase is split into `features/` (e.g., planner, notes, calendar, goals, projects, search) and `core/` (shared models, UI kits, AI providers). This ensures modularity.
- **State Management:** Riverpod (`StateNotifierProvider` and `FutureProvider`) is used throughout the app for predictable, reactive UI state.
- **Local-First Persistence:** Hive handles all storage, wrapped in AES-256 encryption. The app works fully offline and syncs/resolves when online.
- **Service Locator Pattern:** Centralised providers in `lib/core/providers/providers.dart` act as a strongly-typed service locator without needing `get_it`.

---

## AI Layer

All AI calls route through `AIService`, which abstracts the underlying `AIProvider` (e.g., `GeminiProvider` or `MockAIProvider`). 

- **Mocking & Offline:** `MockAIProvider` returns canned deterministic responses to enable local development without burning tokens.
- **Offline AI Queue:** `OfflineAIQueue` intercepts AI requests made when the device is disconnected. It serialises arguments to disk and processes them when connectivity is restored.
- **Token Tracking:** Token usage is tracked per call via `TokenTracker` with configurable daily limits. It caches tallies in-memory to prevent repeated O(n) box scans.
- **Security:** Prompt sanitization neutralises triple-quote sequences and null bytes to mitigate prompt injection.

---

## Core Systems & Flows

### Scheduling Algorithm

`SchedulerService.scheduleDay` is an AI-free, pure-Dart deterministic engine:

1. **Immovable Blocks:** Completed tasks are treated as immovable blocks.
2. **Prioritization:** Pending tasks are sorted by priority (Urgent > High > Medium > Low).
3. **Greedy Forward Scan:** The engine scans for the first free slot ≥ the task's duration, places it, and advances the cursor with a 10-minute buffer.
4. **Rounding:** The cursor rounds to the nearest quarter-hour boundary to prevent fragmentation.

### Proactive Rescheduling Flow

```text
App resumes (AppLifecycleState.resumed) or cold start
  → RescheduleService.checkOverdue()
      → SchedulerService.freeSlots()     # computes non-overlapping candidates
      → AIService.suggestReschedule()    # Gemini picks the best slot
      → rescheduleSuggestionProvider ← RescheduleSuggestion
  → _OverdueBanner rebuilds in PlannerScreen
      Accept → TaskController.updateTask() + NotificationService.schedule()
      Dismiss → clears provider, suppresses for session
```

### Relational Linking

The app uses bidirectional references rather than join tables (NoSQL style):
- **Notes ↔ Tasks:** `NoteItem.linkedTaskIds` and `TaskItem.linkedNoteIds`.
- **Goals & Projects:** Features like `GoalItem` and `ProjectItem` also support linked entities.
Link/unlink operations update both sides atomically via their respective Riverpod controllers.

### Google Calendar Sync

`CalendarSyncService` handles bidirectional sync via Google Calendar REST API v3:
- **Full Sync:** Pulls events across a 3-month window to reconcile with local Hive data.
- **Incremental Sync:** Pulls only modified events based on sync tokens.
- **Conflict Detection:** Etag-based diffing. Conflicting events are flagged for user resolution.
- **Background Sync:** Workmanager runs incremental syncs hourly when connected.

### Diagnostics and Crash Reporting

`AppMonitorService` and `SentryCrashReporter` track application health:
- Automatically logs Flutter errors and fatal isolates exceptions.
- Tracks start-up warnings or missing configurations.
- Persists events to an `appEventsBox` (Hive typeId 11).

---

## Data Flow — "Plan My Day"

```text
User taps "Plan My Day"
  → AIService.planDay()            # AI scores + estimates durations
  → SchedulerService.scheduleDay() # Deterministic time placement
  → TaskController.updateTask()    # Persisted to Hive (encrypted)
  → Riverpod rebuilds UI
```

---

## Hive Data Schema

All boxes are AES-256 encrypted. The encryption key is generated on first launch and securely stored in the OS keychain (`flutter_secure_storage`).

| Box Name | TypeId | Model | Key Fields |
| --- | --- | --- | --- |
| `tasksBox` | 0 | `TaskItem` | id, title, startTime, endTime, priority, tags, isCompleted, linkedNoteIds, recurrence |
| `notesBox` | 1 | `NoteItem` | id, title, content, summary, tags, createdAt, linkedTaskIds, isPinned |
| `calendarBox` | 2 | `CalendarEvent` | id, title, startTime, endTime, source, etag, syncStatus |
| `memoryBox` | 3 | `MemoryEntry` | id, content, sourceType, sourceId, tags, relevanceScore |
| `goalsBox` | 4 | `GoalItem` | id, title, description, targetDate, isCompleted, progress, linkedTaskIds |
| `projectsBox`| 5 | `ProjectItem` | id, name, description, status, deadlines, linkedTaskIds |
| `settingsBox` | — | `AppSettings` | (Manual map) work schedule, theme, biometric lock, etc. |
| `aiLogsBox` | 10 | `AILogEntry` | id, model, promptTokens, completionTokens, latencyMs, timestamp, success |
| `appEventsBox`| 11 | `AppEvent` | id, type, description, timestamp, stackTrace |

---

## Performance Optimizations

- **Static ThemeData:** Light/dark themes are parsed statically to avoid rebuilding objects across frames.
- **Shared Utilities:** Repetitive date comparisons are centralized (e.g. `isSameDay`).
- **Riverpod `keepAlive`:** Certain heavy operations (like AI insight daily loads) are kept alive to fire exactly once per session.
- **Lazy Box Initialization:** Background isolates (like `callbackDispatcher` for Workmanager) selectively open only the boxes required for the background task, reducing memory overhead.
