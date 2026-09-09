# AutoPlanner AI

> **AI-powered daily planner for Android & iOS** — turn a stream-of-consciousness brain dump into a fully scheduled, priority-scored day in seconds.

**Version:** 1.1.0 · **Flutter SDK:** `^3.8.1` · **Dart SDK:** `^3.8.1` · **AI Model:** Gemini 2.5 Flash

---

## Architecture

For a detailed breakdown of the app's structural design, unified startup lifecycle, deterministic scheduling algorithm, and offline-first data flows, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Features

### Core

- **Brain Dump** — paste or speak anything on your mind; AI classifies it into tasks, notes, and long-term memories in real time with streaming output
- **AI Task Parser** — natural language → structured tasks with start time, realistic duration, and priority (Low / Medium / High / Urgent)
- **AI Output Validation** — strict schema and domain validation boundary (`AIValidator`) preventing malformed or out-of-bounds LLM outputs from polluting state
- **Plan My Day** — one-tap AI enrichment pass re-scores all pending tasks, estimates durations, then a deterministic scheduling engine packs them into your work window with zero conflicts
- **Day Planner** — drag-reorder, inline complete/delete, and tap-to-edit any task (title, priority, time, duration, note)
- **Goals & Projects** — structure your life's ambition by linking tasks, notes, and events directly to larger objectives and project containers
- **Notes** — rich editor with AI-generated summaries, auto-tags, and action-item extraction directly into the planner
- **Note ↔ Task Linking** — link notes to tasks (and vice versa) via a picker UI; related items surface in both the note editor and task detail sheet
- **Global Search** — find anything quickly across tasks, notes, calendar events, goals, and projects
- **Memory** — persistent AI memory extracted from your tasks, notes, and brain dumps; automatically fed back as context on future AI calls
- **Calendar** — visual day/week timeline synced with task changes in real time
- **Dashboard** — daily insight card powered by AI, token usage meter, streak tracker
- **Analytics** — 3-tab insights (overview, trends, tags) with `fl_chart` visualisations + AI weekly review
- **Onboarding** — animated splash screen + guided walkthrough on first launch
- **Settings** — theme picker, work schedule, biometric lock, API key management, mock AI toggle, profile editor

### Proactive AI Rescheduling

When the app comes to the foreground the scheduler checks for overdue tasks (missed start time by > 5 minutes). If one is found, Gemini picks the best free slot from the remaining work window and surfaces a dismissable amber banner at the top of the planner.

### Integrations

- **Google Calendar** — bidirectional sync via Google Calendar REST API v3 with OAuth sign-in, official `syncToken` incremental change-tracking, etag-based conflict detection, and background periodic sync via Workmanager
- **Offline AI Queue** — persistent queue backed by encrypted Hive storage; catches operations when offline or when network errors occur and drains automatically on reconnect with exponential backoff and retry bounds
- **Notifications** — timezone-aware local reminders 10 minutes before each task via `flutter_local_notifications`
- **Home Screen Widget** — top-3 upcoming tasks + completion stats pushed to Android/iOS home widget
- **Background Sync** — Workmanager periodic task (1 hr) for calendar sync when connected
- **Crash Reporting & Diagnostics** — Sentry integration logs Flutter errors and isolate exceptions

### AI Capabilities

- `parseTasks` — natural language → structured `TaskItem` list with strict bounds checking
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
| State | Riverpod (`NotifierProvider`, `Provider`, root `ProviderContainer`) |
| Persistence | Hive — AES-256 encrypted via OS keychain key with safe corruption recovery |
| Startup | `AppBootstrapper` unified initialization orchestrator |
| AI | Google Gemini 2.5 Flash (`google_generative_ai`) with streaming support |
| Scheduling | Custom pure-Dart greedy slot-packer (`SchedulerService` with `clock` abstraction) |
| Calendar Sync | Google Calendar REST API v3 (`syncToken` incremental sync + OAuth) |
| Background | `workmanager` periodic tasks (Android/iOS) |
| Notifications | `flutter_local_notifications` + `timezone` |
| Charts | `fl_chart` (analytics trends, tag distributions) |
| Voice Input | `speech_to_text` (Brain Dump dictation) |
| Diagnostics | `sentry_flutter` |
| Security | `flutter_secure_storage` + `local_auth` (biometrics) |

---

## Security

- **Hive encrypted at rest** — a 32-byte AES key is generated on first install and stored in the Android Keystore / iOS Secure Enclave via `flutter_secure_storage`. All boxes use `HiveAesCipher`.
- **Corrupted box recovery** — if a box fails decryption or encounters file corruption, a timestamped `.corrupt.<timestamp>.bak` file is created before the box is cleanly re-opened, preventing unrecoverable data destruction.
- **API key in OS keychain** — the user's Gemini API key is stored via `flutter_secure_storage`, never written to Hive or bundled assets. Google OAuth tokens are also persisted in the secure keychain.
- **Biometric lock** — optional fingerprint / Face ID gate on cold launch and every time the app resumes from background. Falls back to device PIN/pattern.
- **Prompt injection mitigation** — all user-supplied strings are sanitised (triple-quote sequences neutralised, null bytes stripped) before being interpolated into AI prompts.

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
| `SENTRY_DSN` | (optional) | Sentry DSN for crash reporting |

---

## Project Structure

```text
lib/
├── main.dart                          # App entry point, delegates to AppBootstrapper
├── app_shell.dart                     # Bottom nav shell + Brain Dump FAB
│
├── core/
│   ├── ai/                            # AI layer, token tracking, AIValidator, guard
│   ├── bootstrap/                     # AppBootstrapper unified startup sequence
│   ├── config/                        # Env and constants
│   ├── diagnostics/                   # AppMonitor and Sentry CrashReporter
│   ├── models/                        # Hive models (Tasks, Notes, Goals, Projects, Calendar)
│   ├── providers/                     # Centralized Riverpod providers
│   ├── theme/                         # App themes & UI kits
│   └── widgets/                       # ErrorBoundary and shared core widgets
│
├── features/
│   ├── analytics/                     # Insights, charts, AI weekly reviews
│   ├── brain_dump/                    # Voice/text stream processing
│   ├── calendar/                      # Timeline visualization
│   ├── dashboard/                     # Home view with daily insights
│   ├── goals/                         # Goal tracking & detail view
│   ├── memory/                        # AI knowledge graph browser
│   ├── notes/                         # Rich notes with task linking
│   ├── onboarding/                    # Splash screen & welcome flow
│   ├── planner/                       # Deterministic scheduler & task reordering
│   ├── projects/                      # Project management views
│   ├── search/                        # Unified global search interface
│   └── settings/                      # Preferences, theme, connections
│
└── services/
    ├── ai_service.dart                # Sanitized AI calling with exponential back-off
    ├── app_monitor_service.dart       # Event & error monitoring
    ├── calendar_sync_service.dart     # Bidirectional Google sync engine with syncTokens
    ├── memory_service.dart            # Encrypted persistent memory layer
    ├── offline_ai_queue.dart          # Persistent offline request queue & dispatcher
    ├── scheduler_service.dart         # Pure-Dart deterministic time packer with clock
    └── ...                            # (Auth, Notification, Backup, Key Management, etc.)
```

---

## Testing & Quality

Automated tests and quality checks run via GitHub Actions (`.github/workflows/ci.yml`) on every pull request and push to `main` and `develop`:

```bash
# Run static analysis
flutter analyze lib test --fatal-infos

# Run full test suite (402 tests)
flutter test

# Run scheduler behavioral tests with clock abstraction
flutter test test/scheduler_service_test.dart

# Build verification
flutter build apk --debug
```

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

---

## License

MIT
