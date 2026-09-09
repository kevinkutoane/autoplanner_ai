# AutoPlanner AI Architecture

This document provides a high-level overview of the structural and architectural design of AutoPlanner AI.

## Core Architectural Principles

- **Feature-First Organization:** The codebase is split into `features/` (e.g., planner, notes, calendar, goals, projects, search) and `core/` (shared models, UI kits, AI providers, bootstrap). This ensures modularity.
- **State Management:** Riverpod (`NotifierProvider` and `Provider`) is used throughout the app for predictable, reactive UI state.
- **Unified Bootstrapping:** `AppBootstrapper` coordinates all app initialization deterministically (environment, Hive, services, background tasks) and constructs the root Riverpod `ProviderContainer`.
- **Local-First Persistence:** Hive handles all storage, wrapped in AES-256 encryption. Corrupted boxes trigger timestamped backups (`.corrupt.<timestamp>.bak`) before clean re-initialization.
- **Service Locator Pattern:** Centralised providers in `lib/core/providers/providers.dart` act as a strongly-typed service locator without needing `get_it`.

---

## Application Startup Lifecycle

```text
main()
  → WidgetsFlutterBinding.ensureInitialized()
  → AppBootstrapper.init(callbackDispatcher: callbackDispatcher)
      1. Load .env (with fallback to .env.example) and populate appConfig
      2. Register Workmanager background tasks (periodic calendar sync)
      3. Hive.initFlutter() & register all 8 TypeAdapters
      4. Derive AES-256 encryption key from OS Keychain (SecureKeyService)
      5. Pre-open encrypted boxes with safe corruption backup (openBoxSafe<T>)
      6. Initialize services (TokenTracker, MemoryService decay, NotificationService)
      7. Restore Google OAuth session & schedule morning briefing
      8. Assemble ProviderContainer with AppProviderObserver and service overrides
      9. Initialize OfflineAIQueue
  → Wrap AutoPlannerApp in UncontrolledProviderScope & ErrorBoundary
  → AppBootstrapper.crashReporter.runApp()
```

### Background Workmanager Isolate
The top-level `@pragma('vm:entry-point') void callbackDispatcher()` runs independently in a background isolate with no shared memory. It initializes its own Hive instance, registers the `CalendarEventAdapter`, retrieves the keychain encryption key, and performs incremental calendar syncs on scheduled intervals.

---

## AI Layer & Validation Boundary

All AI calls route through `AIService`, which abstracts the underlying `AIProvider` (e.g., `GeminiProvider` or `MockAIProvider`). 

- **Mocking & Offline:** `MockAIProvider` returns canned deterministic responses to enable local development without burning tokens.
- **Structured Output Validation:** `AIValidator` acts as a strict schema and domain boundary. It strips markdown code fences, parses clean JSON, and enforces domain invariants:
  - Task priority bounded between `0` and `3`.
  - Task durations bounded between `15` and `480` minutes.
  - Start times verified against `HH:mm` format.
  - Non-empty titles enforced.
  - Malformed AI outputs throw `AIValidationException`, safely discarding invalid items without crashing the app state.
- **Offline AI Queue:** `OfflineAIQueue` intercepts AI operations when offline or when network errors occur:
  - Enqueues requests to an encrypted Hive box (`offlineAIQueueBox`).
  - Automatically drains queue when connectivity is restored.
  - Routes operations directly to `AIService` methods (`parseTasks`, `planDay`, `brainDump`, etc.).
  - Tracks retry attempts (max 5) with exponential backoff and marks permanent failures safely.
- **Token Tracking:** Token usage is tracked per call via `TokenTracker` with configurable daily limits. It caches tallies in-memory to prevent repeated O(n) box scans.
- **Security:** Prompt sanitization neutralises triple-quote sequences and null bytes to mitigate prompt injection.

---

## Core Systems & Flows

### Deterministic Scheduling Algorithm

`SchedulerService.scheduleDay` is an AI-free, pure-Dart deterministic engine:

1. **Clock Abstraction:** Uses `package:clock` (`clock.now()`) to enable 100% deterministic testing without hardcoded wall-clock time dependencies.
2. **Immovable Blocks:** Completed tasks and external calendar events are treated as immovable blocks.
3. **Prioritization:** Pending tasks are sorted by priority (Urgent > High > Medium > Low).
4. **Greedy Forward Scan:** The engine scans for the first free slot ≥ the task's duration, places it, and advances the cursor with a 10-minute buffer.
5. **Slot Rounding & Breathing Room:** When scheduling for today, the initial cursor starts from the next rounded slot boundary with breathing room to prevent scheduling in the past.
6. **End-of-Day Extension:** When scheduling after normal work hours on the current day, the scheduling window automatically extends to 23:59.

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
- **Goals & Projects:** `GoalItem` and `ProjectItem` also support linked entities.
Link/unlink operations update both sides atomically via their respective Riverpod controllers.

### Google Calendar Incremental Sync

`CalendarSyncService` handles bidirectional sync via Google Calendar REST API v3:
- **Full Sync:** Pulls events across a 3-month window and retrieves an initial `nextSyncToken`.
- **Incremental Sync:** Supplies `syncToken` to fetch only modified or cancelled events since the last sync.
- **Pagination Safety:** `nextSyncToken` is persisted to Hive only after all pages are retrieved successfully. Intermediate failures keep the previous token unchanged.
- **410 Gone Recovery:** If a sync token expires, the service automatically clears the invalid token and triggers a fresh full sync.
- **Conflict Detection:** Etag-based diffing prevents overwriting concurrent edits.
- **Background Sync:** Workmanager runs incremental syncs hourly when connected.

### Diagnostics and Crash Reporting

`AppMonitorService` and `CrashReporter` (`SentryCrashReporter` or `NoOpCrashReporter`) track application health:
- Automatically logs Flutter errors and fatal isolates exceptions.
- Tracks start-up warnings or missing configurations.
- Persists events to an `appEventsBox` (Hive typeId 11).

---

## Data Flow — "Plan My Day"

```text
User taps "Plan My Day"
  → AIService.planDay()            # AI scores + estimates durations
  → AIValidator.validateTaskDomain() # Validates task bounds & fields
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
| `settingsBox` | — | `AppSettings` | (Manual map) work schedule, theme, biometric lock, sync tokens, etc. |
| `aiLogsBox` | 10 | `AILogEntry` | id, model, promptTokens, completionTokens, latencyMs, timestamp, success |
| `appEventsBox`| 11 | `AppEvent` | id, type, description, timestamp, stackTrace |
| `offlineAIQueueBox` | — | `QueuedAIRequest` | (Manual map) id, method, argsJson, queuedAt, attempts, lastError |
