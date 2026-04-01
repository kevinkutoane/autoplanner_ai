# AutoPlanner AI

> **AI-powered daily planner for Android & iOS** — turn a stream-of-consciousness brain dump into a fully scheduled, priority-scored day in seconds.

**Version:** 1.0.0+1 · **Flutter SDK:** `^3.8.1` · **Dart SDK:** `^3.8.1` · **AI Model:** Gemini 2.5 Flash

---

## Features

### Core

- **Brain Dump** — paste or speak anything on your mind; AI classifies it into tasks, notes, and long-term memories in real time with streaming output
- **AI Task Parser** — natural language → structured tasks with start time, realistic duration, and priority (Low / Medium / High / Urgent)
- **Plan My Day** — one-tap AI enrichment pass re-scores all pending tasks, estimates durations, then a deterministic scheduling engine packs them into your work window with zero conflicts
- **Day Planner** — drag-reorder, inline complete/delete, and tap-to-edit any task (title, priority, time, duration, note)
- **Notes** — rich editor with AI-generated summaries, auto-tags, and action-item extraction directly into the planner
- **Note ↔ Task Linking** — link notes to tasks (and vice versa) via a picker UI; related items surface in both the note editor and task detail sheet
- **Memory** — persistent AI memory extracted from your tasks, notes, and brain dumps; automatically fed back as context on future AI calls
- **Calendar** — visual day/week timeline synced with task changes in real time
- **Dashboard** — daily insight card powered by AI, token usage meter, streak tracker
- **Analytics** — 3-tab insights (overview, trends, tags) with `fl_chart` visualisations + AI weekly review
- **Onboarding** — animated splash screen + guided walkthrough on first launch
- **Settings** — theme picker, work schedule, biometric lock, API key management, mock AI toggle, profile editor

### Proactive AI Rescheduling

When the app comes to the foreground the scheduler checks for overdue tasks (missed start time by > 5 minutes). If one is found, Gemini picks the best free slot from the remaining work window and surfaces a dismissable amber banner at the top of the planner:

- **Auto-detect** — triggers on `AppLifecycleState.resumed` and on cold start (post-frame)
- **Slot computation** — `SchedulerService.freeSlots()` returns up to 6 non-overlapping `DateTime` candidates, blocking both existing tasks and Google Calendar events
- **AI slot selection** — `AIService.suggestReschedule()` sends the task details, slot list, and top-5 memory entries to Gemini; returns the optimal `DateTime`
- **Banner UI** — amber dismissable card in the planner (`_OverdueBanner`); Accept applies the move and reschedules the notification; Dismiss suppresses the banner for the session
- **Manual reschedule sheet** — context-menu action on any task also opens a slot picker pre-populated with `freeSlots()` results; tap a slot to move the task instantly

### Integrations

- **Google Calendar** — bidirectional sync via Google Calendar REST API v3 with OAuth sign-in, etag-based conflict detection, and background periodic sync via Workmanager
- **Microsoft Outlook / Office 365** — MSAL sign-in (`msal_flutter`) requesting `Calendars.ReadWrite + offline_access`; silent token restore on startup; access tokens persisted in the OS keychain
- **Notifications** — timezone-aware local reminders 10 minutes before each task via `flutter_local_notifications`
- **Home Screen Widget** — top-3 upcoming tasks + completion stats pushed to Android/iOS home widget
- **Background Sync** — Workmanager periodic task (1 hr) for calendar sync when connected
- **Firebase** — optional Firebase core initialisation (graceful no-op when `google-services.json` is absent); structured for future Cloud Firestore / Cloud Functions expansion

### AI Capabilities

- `parseTasks` — natural language → structured `TaskItem` list
- `planDay` — AI enrichment: re-score priority + estimate durations
- `suggestReschedule` — picks the best free slot for a missed task using task context + Gemini reasoning
- `brainDump` — streaming classification into tasks, notes, and memories
- `summarizeNote` — generate concise note summaries
- `generateTags` — auto-tag notes and tasks
- `extractActionItems` — pull tasks from note content
- `generateDailyInsight` — AI-powered dashboard insight card
- `extractMemoryFromContext` — surface notable patterns for the memory system
- `extractPatterns` — analyse a batch of tasks/notes for behavioural patterns
- `suggestTasks` — proactively suggest next tasks based on context
- `weeklyReview` — AI-generated markdown productivity review

---

## Tech Stack

| Layer | Technology |
| --- | --- |
| UI | Flutter 3 + Material 3 (custom brand palette, animated orb backgrounds) |
| State | Riverpod (`StateNotifierProvider`) |
| Persistence | Hive — AES-256 encrypted via OS keychain key |
| AI | Google Gemini 2.5 Flash (`google_generative_ai`) with streaming support |
| Scheduling | Custom pure-Dart greedy slot-packer (`SchedulerService`) |
| Calendar Sync | Google Calendar REST API v3 (`http` + `google_sign_in`) |
| Outlook Sync | Microsoft MSAL (`msal_flutter`) — OAuth device flow |
| Background | `workmanager` periodic tasks (Android/iOS) |
| Notifications | `flutter_local_notifications` + `timezone` |
| Charts | `fl_chart` (analytics trends, tag distributions) |
| Voice Input | `speech_to_text` (Brain Dump dictation) |
| Widgets | `home_widget` (Android/iOS home screen widget) |
| Security | `flutter_secure_storage` + `local_auth` (biometrics) |
| Architecture | Feature-first with shared `core/` layer |

---

## Security

- **Hive encrypted at rest** — a 32-byte AES key is generated on first install and stored in the Android Keystore / iOS Secure Enclave via `flutter_secure_storage`. All boxes (tasks, notes, calendar, memory, settings, AI logs) use `HiveAesCipher`.
- **API key in OS keychain** — the user's Gemini API key is stored via `flutter_secure_storage`, never written to Hive or bundled assets. Google and Microsoft OAuth tokens are also persisted in the secure keychain.
- **Biometric lock** — optional fingerprint / Face ID gate on cold launch and every time the app resumes from background. Falls back to device PIN/pattern.
- **Prompt injection mitigation** — all user-supplied strings are sanitised (triple-quote sequences neutralised, null bytes stripped) before being interpolated into AI prompts.
- **Graceful degradation** — all platform-specific initialisations (Firebase, Workmanager, notifications) are wrapped in try/catch so the app starts cleanly on any platform.

---

## Getting Started

### Prerequisites

- Flutter `>=3.3.0`
- Dart `>=3.0.0`
- A [Google AI Studio](https://aistudio.google.com) API key (free tier works)

### Run

```bash
git clone https://github.com/kevinkutoane/autoplanner_ai.git
cd autoplanner_ai
cp .env.example .env          # add your GEMINI_API_KEY
flutter pub get
flutter run
```

On first launch the onboarding walkthrough introduces the app. Add or update your Gemini API key anytime via **Settings → AI Settings → Gemini API key**. Enable **Mock AI** to develop without burning tokens.

### Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `GEMINI_API_KEY` | (optional) | Google AI Studio API key — enter here **or** in **Settings → AI Settings** |
| `ENV` | `prod` | Environment: `dev` / `staging` / `prod` |
| `USE_MOCK_AI` | `false` | Use canned AI responses (no API calls) |
| `ENABLE_AI_LOGGING` | `true` | Log AI requests/responses |
| `ENABLE_TOKEN_TRACKING` | `true` | Track token usage per call |
| `MAX_TOKENS_PER_DAY` | `100000` | Daily token budget |

### Microsoft Outlook (optional)

1. Register an application in [Azure App Registrations](https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/RegisteredApps) with **Accounts in any organizational directory and personal Microsoft accounts**.
2. Add the redirect URI `msauth://<package>/<base64-sha1>` for Android and `msauth.<bundle_id>://auth` for iOS.
3. Replace `YOUR_AZURE_CLIENT_ID` in `lib/services/msal_auth_service.dart` with your Application (client) ID.
4. In **Settings → Integrations**, tap **Connect Outlook** to sign in.

---

## Project Structure

```text
lib/
├── main.dart                          # App entry, init chain (Hive, Firebase, Workmanager, notifications, recurring-task hydration)
├── app_shell.dart                     # 7-screen bottom nav + Brain Dump FAB, biometric lock-on-resume, proactive reschedule trigger
│
├── core/
│   ├── ai/
│   │   ├── ai_provider.dart           # Abstract AIProvider + AIResponse model
│   │   ├── gemini_provider.dart       # Gemini 2.5 Flash implementation
│   │   ├── mock_ai_provider.dart      # Canned-response mock for offline dev
│   │   ├── token_tracker.dart         # Persistent token usage logging + daily limits
│   │   └── token_tracker.g.dart       # Generated Hive adapter for AILogEntry
│   ├── config/
│   │   └── env_config.dart            # .env loader via flutter_dotenv
│   ├── models/
│   │   ├── task_model.dart            # TaskItem (typeId 0): priority, tags, recurrence, linkedNoteIds
│   │   ├── note_model.dart            # NoteItem (typeId 1): summary, tags, linkedTaskIds
│   │   ├── calendar_event_model.dart  # CalendarEvent (typeId 2): sync fields, etag
│   │   ├── memory_entry_model.dart    # MemoryEntry (typeId 3): relevance, access count
│   │   └── *.g.dart                   # Generated Hive adapters (null-safe reads)
│   ├── providers/
│   │   └── providers.dart             # Centralized Riverpod providers (incl. rescheduleSuggestionProvider)
│   └── theme/
│       ├── app_theme.dart             # Light/dark Material 3 themes
│       └── ui_kit.dart                # Animated orb background, gradient header, brand palette
│
├── features/
│   ├── analytics/
│   │   └── screens/
│   │       ├── analytics_screen.dart      # 3-tab insights (overview, trends, tags) with fl_chart
│   │       └── weekly_review_screen.dart  # AI-generated weekly productivity review
│   ├── brain_dump/
│   │   └── brain_dump_sheet.dart          # Voice/text → AI streaming parse into tasks + notes + memories
│   ├── calendar/
│   │   ├── controllers/
│   │   │   └── calendar_controller.dart   # CalendarEvent CRUD, sync trigger, conflict resolution
│   │   ├── screens/
│   │   │   └── calendar_screen.dart       # Day/week calendar view
│   │   └── widgets/
│   │       └── timeline_view.dart         # Timeline visualisation widget
│   ├── dashboard/
│   │   └── screens/
│   │       └── dashboard_screen.dart      # Home screen with AI daily insight
│   ├── memory/
│   │   ├── controllers/
│   │   │   └── memory_controller.dart     # Memory CRUD + search/filter/tag stats
│   │   └── screens/
│   │       └── memory_screen.dart         # Memory browser
│   ├── notes/
│   │   ├── controllers/
│   │   │   └── note_controller.dart       # Note CRUD + AI summarise/tag/extract
│   │   └── screens/
│   │       ├── notes_screen.dart          # Note list with search/pin/filter
│   │       └── note_editor_screen.dart    # Rich note editor with task-link picker
│   ├── onboarding/
│   │   └── screens/
│   │       ├── splash_screen.dart         # Animated splash with settings preload
│   │       └── onboarding_screen.dart     # Guided first-run walkthrough
│   ├── planner/
│   │   ├── controllers/
│   │   │   └── task_controller.dart       # Task CRUD, Plan My Day, notification scheduling, recurring expansion
│   │   └── screens/
│   │       └── planner_screen.dart        # Day planner: drag-reorder, _OverdueBanner, reschedule sheet
│   └── settings/
│       ├── controllers/
│       │   └── settings_controller.dart   # Settings persistence, Google/Outlook toggles
│       ├── models/
│       │   └── app_settings_model.dart    # AppSettings: workStartHour, workHoursPerDay, recurrence defaults
│       └── screens/
│           ├── settings_screen.dart       # Full settings UI
│           └── profile_screen.dart        # Profile editor
│
└── services/
    ├── ai_service.dart            # Unified AI layer (retry, streaming, all AI methods incl. suggestReschedule)
    ├── backup_service.dart        # Export / import encrypted Hive snapshots
    ├── biometric_service.dart     # local_auth wrapper (fingerprint / Face ID / PIN)
    ├── calendar_sync_service.dart # Bidirectional Google Calendar sync (full, incremental, push)
    ├── conflict_detector.dart     # Time-overlap + sync-status conflict detection
    ├── google_auth_service.dart   # Google Sign-In + OAuth token management
    ├── home_widget_service.dart   # Android/iOS home screen widget data push
    ├── memory_service.dart        # Encrypted Hive memory CRUD with search/filter
    ├── msal_auth_service.dart     # Microsoft (Outlook/O365) MSAL sign-in + silent token refresh
    ├── notification_service.dart  # Scheduled task reminders (10 min before start)
    ├── reschedule_service.dart    # Proactive overdue-task detection + AI slot selection
    ├── scheduler_service.dart     # Deterministic greedy slot-packer + freeSlots() helper
    └── secure_key_service.dart    # OS keychain: Gemini key, Hive AES key, Google/Microsoft tokens
```

---

## Testing

### Running the test suite

```bash
flutter test
```

All tests are pure Dart unit tests — no device, emulator, or Firebase connection required. The full suite runs in CI without any platform plugins active.

### Test coverage

| File | What is covered |
| --- | --- |
| `test/task_model_test.dart` | `TaskItem` constructor defaults, `copyWith` (including sentinel null-clear), `priorityLabel` mapping |
| `test/note_model_test.dart` | `NoteItem` constructor defaults, `copyWith`, pin/tag/link mutations |
| `test/calendar_event_model_test.dart` | `CalendarEvent` constructor defaults, explicit values for all 15 fields, `copyWith` across all sync/time fields |
| `test/memory_entry_model_test.dart` | `MemoryEntry` constructor defaults, explicit values (all 5 sourceTypes), `copyWith`, immutability |
| `test/app_settings_model_test.dart` | `AppSettings.defaults()` for all 20 fields, `copyWith` mutations, Hive key constant completeness |
| `test/env_config_test.dart` | `EnvConfig.fromDotEnv` defaults + explicit ENV / key / flag parsing, invalid `MAX_TOKENS_PER_DAY` fallback |
| `test/conflict_detector_test.dart` | Time-overlap detection (empty, single, partial, back-to-back, sequential, multi-pair), all-day exclusion, sync-status conflict filtering |
| `test/scheduler_service_test.dart` | `scheduleDay` — empty input, single task, priority ordering, completed-task immutability, buffer gap, full-window cutoff, explicit durations |
| `test/reschedule_service_test.dart` | `freeSlots` — empty day, task-blocked, calendar-blocked, nearly-full day, non-overlapping slots; `RescheduleSuggestion.proposedEndTime` with and without `endTime` |
| `test/ai_service_test.dart` | Prompt-injection sanitization, `parseTasks` / `generateTags` / `extractActionItems` / `summarizeNote` / `brainDump` / `generateDailyInsight` via `MockAIProvider` |
| `test/token_tracker_test.dart` | `todayTokens` accumulation, `isOverLimit` / `guardRateLimit` threshold, `remainingTokens` clamping, `todayCallCount`, `todayAvgLatency`, `usageHistory` day-key structure |
| `test/memory_service_test.dart` | `addMemory` / `allMemories` sort order, `recentMemories` limit, `contextMemories` relevance ranking, `searchMemories` case-insensitive keyword/tag search, `getByTag`, `reinforceMemory` boost, `decayStaleMemories` threshold |
| `test/backup_service_test.dart` | Round-trip JSON serialisation for `TaskItem`, `NoteItem`, `CalendarEvent`, and `MemoryEntry`; null-optional-field preservation; full envelope structure |
| `test/widget_test.dart` | Stateless widget smoke tests: `GlassCard`, `SectionLabel`, `EmptyState` |

### Testing philosophy

- **No Hive in most tests** — model tests operate on plain Dart objects; only `token_tracker_test.dart` and `memory_service_test.dart` open a real Hive box in `Directory.systemTemp`, cleaned up in `tearDown`.
- **No Flutter engine** — non-widget tests run in `dart test` mode without pumping the widget tree.
- **MockAIProvider** — `AIService` tests use canned deterministic responses so the full AI method surface is covered without live network calls.
- **Fixed dates** — tests that involve scheduling use `DateTime(2099, ...)` or `DateTime(2025, ...)` to decouple results from `DateTime.now()`.

---

## Architecture Notes

### AI Layer

All AI calls go through `AIService`, which sits on top of an `AIProvider` abstraction. Swapping the underlying model (Gemini → OpenAI → local) requires no changes to feature code. A `MockAIProvider` returns canned responses for offline development.

`AIService` methods sanitise user input and use exponential back-off retry (1 s → 2 s → 4 s). Token usage is tracked per call via `TokenTracker` with configurable daily limits.

Every AI method follows the same internal pattern: `_withRetry()` → prompt construction with `_sanitize()` → model call → `_tracker.log()` → parse response.

### Scheduling Algorithm

`SchedulerService.scheduleDay` is AI-free and deterministic:

1. Separate completed tasks (treated as immovable occupied blocks)
2. Sort pending tasks by priority descending
3. Greedy forward scan: find the first free slot ≥ task duration, place it, advance cursor + 10-min buffer
4. If scheduling today and past work-start, the cursor begins at the next rounded quarter-hour to avoid placing tasks in the past

`SchedulerService.freeSlots` is a complementary method used by the proactive rescheduler and the manual reschedule sheet:

- Accepts `busyTasks: List<TaskItem>` and `calendarBlocks: List<CalendarEvent>` as block sources
- Returns up to `count` (default 6) `DateTime` start-points within the work window
- Skips all-day calendar events

### Proactive Rescheduling Flow

```text
App resumes (AppLifecycleState.resumed) or cold start
  → RescheduleService.checkOverdue()
      → SchedulerService.freeSlots()     # compute candidates
      → AIService.suggestReschedule()    # Gemini picks best slot
      → rescheduleSuggestionProvider ← RescheduleSuggestion
  → _OverdueBanner rebuilds in PlannerScreen
      Accept → TaskController.updateTask() + NotificationService.schedule()
      Dismiss → clears provider, suppresses for session
```

### Note ↔ Task Linking

- `NoteItem.linkedTaskIds: List<String>` and `TaskItem.linkedNoteIds: List<String>` form a bidirectional M:N relationship.
- The note editor exposes a **Link Task** picker; the task detail sheet shows a **Linked Notes** chip row.
- Link/unlink operations update both sides atomically via their respective controllers.

### Google Calendar Sync

`CalendarSyncService` provides bidirectional sync with Google Calendar:

- **Full sync** — pulls all events within a 3-month window, reconciles with local Hive data
- **Incremental sync** — pulls only events modified in the last 7 days
- **Push** — creates or updates individual events on Google Calendar
- **Conflict detection** — etag-based diffing flags events as `'conflict'` when local and remote diverge
- **Background sync** — Workmanager registers a periodic task (1 hr) to run incremental sync when connected

### Microsoft Outlook Sync

`MsalAuthService` wraps `msal_flutter` v2:

- `tryRestoreSession()` — called on app start; performs a silent token refresh using tokens stored in the OS keychain
- `signIn()` — launches the interactive MSAL browser flow
- `signOut()` — revokes tokens and clears keychain entries
- Access tokens are stored via `SecureKeyService.saveMsalTokens()` so they survive app restarts

### Recurring Tasks

On startup, `TaskController` expands any recurring `TaskItem` records that have no future occurrence scheduled. Recurrence rules (`daily`, `weekly`, `monthly`) are stored on the task model and processed before the first UI frame renders.

### Data Flow — "Plan My Day"

```text
User taps "Plan My Day"
  → AIService.planDay()            # AI scores + estimates durations
  → SchedulerService.scheduleDay() # Deterministic time placement
  → TaskController.updateTask()    # Persisted to Hive (encrypted)
  → Riverpod rebuilds UI
```

### Navigation

The app uses a 7-screen bottom navigation bar:

| Tab | Screen | Description |
| --- | --- | --- |
| Home | `DashboardScreen` | AI daily insight, quick stats |
| Plan | `PlannerScreen` | Day planner, Plan My Day, overdue banner |
| Notes | `NotesScreen` | Note list, AI summarise/tag |
| Calendar | `CalendarScreen` | Day/week timeline view |
| Memory | `MemoryScreen` | Persistent AI memory browser |
| Insights | `AnalyticsScreen` | Charts, trends, weekly review |
| Settings | `SettingsScreen` | All configuration |

A floating action button opens the **Brain Dump** modal sheet from any screen.

---

## Riverpod Providers

| Provider | Type | Description |
| --- | --- | --- |
| `taskControllerProvider` | `StateNotifierProvider` | Task CRUD + planner logic |
| `noteControllerProvider` | `StateNotifierProvider` | Note CRUD + AI actions |
| `calendarControllerProvider` | `StateNotifierProvider` | Calendar events + sync |
| `memoryControllerProvider` | `StateNotifierProvider` | Memory entries + search |
| `settingsControllerProvider` | `StateNotifierProvider` | App settings persistence |
| `aiServiceProvider` | `Provider` | Singleton `AIService` |
| `schedulerServiceProvider` | `Provider` | Singleton `SchedulerService` |
| `rescheduleServiceProvider` | `Provider` | Singleton `RescheduleService` |
| `rescheduleSuggestionProvider` | `StateProvider<RescheduleSuggestion?>` | Current pending reschedule suggestion |
| `msalAuthServiceProvider` | `Provider` | Singleton `MsalAuthService` |
| `themeProvider` | `StateProvider` | Current `ThemeMode` |
| `tokenTrackerProvider` | `Provider` | Singleton `TokenTracker` |

---

## Dependencies

### Production

| Package | Version | Purpose |
| --- | --- | --- |
| `hive` / `hive_flutter` | ^2.2.3 | Encrypted local NoSQL storage |
| `flutter_riverpod` | ^2.6.1 | State management |
| `google_generative_ai` | ^0.4.7 | Gemini AI SDK |
| `flutter_dotenv` | ^5.2.1 | .env file loading |
| `flutter_secure_storage` | ^9.2.2 | OS keychain (API keys, encryption key, tokens) |
| `local_auth` | ^2.3.0 | Biometric / device-credential unlock |
| `speech_to_text` | ^7.0.0 | Voice input for Brain Dump |
| `fl_chart` | ^0.70.2 | Analytics charts |
| `flutter_local_notifications` | ^18.0.1 | Scheduled task reminders |
| `home_widget` | ^0.7.0 | Android/iOS home screen widget |
| `google_sign_in` | ^6.2.2 | Google OAuth (Calendar scope) |
| `googleapis` | ^13.2.0 | Google Calendar REST API typed client |
| `http` | ^1.2.2 | HTTP client for Calendar REST calls |
| `workmanager` | ^0.9.0 | Background periodic sync |
| `msal_flutter` | ^2.0.1 | Microsoft (Outlook/O365) MSAL authentication |
| `uuid` | ^4.5.1 | UUID generation |
| `intl` | ^0.20.2 | Date/number formatting |
| `timezone` | ^0.9.4 | Timezone-aware scheduling |
| `permission_handler` | ^11.3.1 | Runtime permissions |
| `path_provider` | ^2.1.5 | File system paths |
| `share_plus` | ^12.0.1 | Share / export data |
| `file_picker` | ^10.3.10 | Import data from device storage |
| `flutter_staggered_animations` | ^1.0.0 | List entry animations |

### Dev

| Package | Version | Purpose |
| --- | --- | --- |
| `flutter_lints` | ^5.0.0 | Lint rules |
| `hive_generator` | ^2.0.0 | Hive adapter codegen |
| `build_runner` | ^2.4.13 | Code generation |

---

## Performance Optimizations

| Optimization | Detail |
| --- | --- |
| **Cached daily token tallies** | `TokenTracker` maintains in-memory `_cachedTokens`, `_cachedCalls`, `_cachedLatencySum`. Cache is built once per calendar day and updated inline on each `log()` call — avoids O(n) box scan on every `todayTokens` access. |
| **Static ThemeData** | `AppTheme.lightTheme` and `AppTheme.darkTheme` are `static final` — `ThemeData` is constructed once and reused across all rebuilds. |
| **Shared date utility** | `isSameDay()` is a single top-level function in `core/utils/date_utils.dart`, replacing 4 duplicate private copies. |
| **Riverpod keepAlive** | `dailyInsightProvider` uses `ref.keepAlive()` so the AI insight call happens exactly once per session. |
| **Quarter-hour cursor rounding** | `SchedulerService` rounds the scheduling cursor to the next 15-minute boundary, reducing slot fragmentation. |
| **Lazy box opens** | Background isolate (`callbackDispatcher`) only opens the boxes it needs, keeping memory usage minimal. |

---

## Hive Data Schema

All boxes are AES-256 encrypted with a key stored in the OS keychain (`flutter_secure_storage`).

| Box Name | TypeId | Model | Key Fields |
| --- | --- | --- | --- |
| `tasksBox` | 0 | `TaskItem` | id, title, startTime, endTime, priority (0–3), tags, isCompleted, linkedNoteIds, recurrence, recurrenceDays |
| `notesBox` | 1 | `NoteItem` | id, title, content, summary, tags, createdAt, updatedAt, linkedTaskIds, isPinned |
| `calendarBox` | 2 | `CalendarEvent` | id, title, description, startTime, endTime, source, linkedTaskId, colorValue, isAllDay, syncStatus, googleEventId, etag, lastSyncedAt |
| `memoryBox` | 3 | `MemoryEntry` | id, content, sourceType, sourceId, tags, createdAt, relevanceScore, accessCount |
| `settingsBox` | — | `AppSettings` (manual) | 20+ keys for work schedule, theme, biometric lock, Google/Outlook toggle, etc. |
| `aiLogsBox` | 10 | `AILogEntry` | id, model, action, promptTokens, completionTokens, latencyMs, timestamp, success |

---

## Build & Release Checklist

### Android

1. Generate a production upload keystore:

   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties` (git-ignored):

   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=<path-to-upload-keystore.jks>
   ```

3. Populate `GEMINI_API_KEY` in `.env` (or instruct users to enter it in Settings).
4. Build the release bundle:

   ```bash
   flutter build appbundle --release
   ```

   Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Set Team and Bundle Identifier under **Signing & Capabilities**.
3. Build the archive:

   ```bash
   flutter build ipa --release
   ```

4. Upload via **Xcode → Distribute App** or **Transporter**.

### Environment Notes

- `.env` ships inside the APK/IPA (listed under `pubspec.yaml` assets) with `GEMINI_API_KEY=` blank. The user enters their own key via **Settings → AI Settings**.
- `ENV=prod` is the default in `.env` so the app title reads "AutoPlanner AI" (not "[DEV]").
- `AZURE_CLIENT_ID` must be populated before Outlook connect will work. If not shipping with Outlook, the Connect button can be hidden by leaving the client ID empty — the service gracefully no-ops.

---

## License

MIT
