# AutoPlanner AI

> **AI-powered daily planner for Android & iOS** — turn a stream-of-consciousness brain dump into a fully scheduled, priority-scored day in seconds.

**Version:** 2.3.0 · **Flutter SDK:** `^3.8.1` · **Dart SDK:** `^3.8.1` · **AI Model:** Gemini 2.5 Flash

---

## Documentation Directory

| Document | Description |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Complete system architecture map, runtime data flows, AI safety boundary, and Hive schema |
| [PHASE_1_2_SPEC.md](PHASE_1_2_SPEC.md) | Technical specification & delivery verification for the Smart Scheduling Engine |
| [ROADMAP.md](ROADMAP.md) | Multi-phase strategic product and architectural roadmap from 1.1 to 2.3+ |
| [CHANGELOG.md](CHANGELOG.md) | Detailed release notes, breaking changes, and migration history |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Developer guide, coding standards, test execution, and pull request checklist |

---

## Features

### ⚓ Ergonomic 5-Slot Dock & 4x2 Feature Sheet
- **Balanced Floating Glass Dock (`_GlassNavBar`)**: Ergonomic 5-slot navigation bar (`Dashboard`, `Planner`, `[Center Action]`, `Focus`, `AI Coach`) rendered as a floating frosted glass pill, eliminating bottom bar crowding.
- **Docked Brain Dump 2.0 Hero Action (`_DockedBrainDumpButton`)**: Elevated central button with multi-color neon sunset gradient glow (`kGradientNeonSunset`), tactile spring animation, and zero FAB overlap collisions.
- **Responsive 4x2 More Features Grid (`_GlassMoreSheet`)**: Frosted modal sheet housing secondary modules (Goals, Projects, Memory, Notes, Analytics, Settings, Omnibar, Help) with color-coded glowing badges.
- **Adaptive Dashboard Header**: Responsive layout with `Flexible` greeting wrappers and `FittedBox` date scaling to ensure zero header overflow across all screen sizes.

### 🎨 Signature Screen Palettes & Glowing Headers
- **Curated Screen Gradients**: Distinct gradient color ways in `ui_kit.dart` giving each screen a memorable, unmistakable aesthetic:
  - `kGradientPlanner` (Indigo & Violet) — task scheduling and temporal order.
  - `kGradientCalendar` (Teal & Cyan) — event timeline clarity.
  - `kGradientMemory` (Amber & Rose) — neural recall and reflection.
  - `kGradientNotes` (Emerald & Teal) — creative ideation studio.
  - `kGradientProjects` (Pink & Rose) — ambitious multi-step goals.
  - `kGradientAnalytics` (Violet & Cyan) — telemetry and performance trends.
  - `kGradientSettings` (Slate & Indigo) — device control room.
- **Glowing Iconography Badges**: Header badges with ambient glow rings matching each screen's signature palette.

### 🤖 AI Coach Persona, Strict Guardrails & Typing Wave
- **Strict Productivity Scope**: Grounded exclusively in time management, scheduling, focus habits, circadian energy balance, and motivation. Off-topic queries are gracefully redirected to daily goals.
- **Clean Markdown Enforcement**: Complete suppression of raw JSON or internal task schema leakage, backed by fallback sanitization in `_cleanMessageContent`.
- **Interactive Visuals**: Glowing bot avatar with a cyan aura for the AI Coach, paired with the user's customizable profile badge.
- **Animated 3-Dot Wave Typing Indicator (`_TypingBubble`)**: Inline pulsing wave indicator conveying live reasoning while the coach generates advice.

### 🎙️ Brain Dump Voice Dictation & Emulator Simulator
- **Android Microphone Permissions**: Runtime permission requests for `RECORD_AUDIO` and Bluetooth audio, backed by explicit `RecognitionService` queries in `AndroidManifest.xml`.
- **Permission Recovery Flow**: Friendly guidance modal directing the user to system settings if permissions were denied.
- **Emulator Voice Dictation Simulator**: In environments without speech recognition hardware (e.g. Android Emulators, headless/desktop testing), streams simulated voice input (`_simulateVoiceDictation`) that directly powers the 32-bar reactive equalizer and 4-pillar cognitive parser.

### 🔔 Flagship Notification Center & Smart Reminders
- **Differentiated Alert Channels**: Priority 3 critical tasks and urgent notes route to `autoplanner_urgent` (`Importance.max`) with heads-up prominence, while scheduled tasks route to `autoplanner_tasks` (`Importance.high`).
- **Configurable Lead Times**: Quick-select reminder lead time chips (`5m`, `10m`, `15m`, `30m` before task start).
- **Crucial Tasks Filter**: Toggle between alerting on all tasks or strictly crucial (High & Urgent) items to eliminate alert fatigue.
- **Daily Ritual Alarms**: Timed reminders for Morning Kickoff and Evening Shutdown wrap-ups with dedicated time pickers.
- **Streak Shield Protection**: Evening alert at 20:00 warning the user if their active planning streak is at risk.

### 👤 Modern Profile Studio & Settings Hub
- **Gamification Mastery Hero**: Real-time Level and Rank title, glowing XP progress bar, total earned XP, and active streak multiplier badge (`🔥 5d • 1.5x`).
- **Productivity Persona Card**: Displays circadian chronotype (`🌅 Early Bird`, `⚖️ Balanced`, `🌙 Night Owl`), daily deep work focus targets (`1h` to `3h`), and AI coach persona styles (`Direct & Sharp`, `Strategic & Balanced`, `Empathetic`).
- **Personal Mantra & Motto**: Custom quotation banner embedded on Profile and editable via `ProfileEditDialog`.
- **Sensory & Haptic Controls**: Toggles for tactile micro-vibration feedback on interactive events and achievement celebration confetti.

### 👑 Flagship Brain Dump 2.0
- **Fluid Sensory Voice Studio**: Dynamic 9-bar reactive frequency equalizer (`AudioWaveformVisualizer`) that animates in real-time to microphone sound levels with harmonic sine wave rendering.
- **4-Pillar Cognitive Extraction**: Parses stream-of-consciousness thoughts into **Tasks**, **Notes** (saved directly to `notesBox` with `#braindump`), **Goals** (auto-linked to tasks), and **Memories**.
- **Smart Gap-Aware Auto-Scheduling**: Automatically packs newly extracted tasks into upcoming open calendar windows without collisions or past-time placement.
- **Interactive Live Triage Canvas**: Inline duration selector chips (`15m`, `30m`, `45m`, `60m`), priority cycling, schedule fit status badges, and one-tap conversion between Tasks and Notes.
- **Cognitive Clarity Rewards**: Mental declutter score banner with atomic multi-box persistence and instant **+50 XP** bonus.

### 🌅 Multi-Agent Routines & Automated Rituals
- **Morning Kickoff Ritual**: Sunrise sheet analyzing yesterday's rollover items, calendar commitments, and dynamically isolating **"The Big 3"** high-impact priorities (+50 XP).
- **Evening Shutdown Ritual**: Twilight sheet offering one-tap task triaging (*Tomorrow*, *Backlog*, *Discard*), completion velocity analytics, and 1-line memory reflection (+50 XP).
- **DailyRitualCard**: Context-aware banner on the Dashboard that smoothly alternates between Morning Kickoff and Evening Shutdown.

### 🧠 Context-Aware Smart Engine & Dynamic Recommendations
- **Circadian Energy Phases**: Dynamically shifts between Peak Deep Work (morning), Operational & Collaborative (afternoon), and Cooldown & Reflection (evening).
- **Calendar Gap Detection & Micro-Wins**: Identifies 10–60 minute open windows before meetings and suggests matching quick-win tasks with a single-tap "Quick Flow" launcher.

### 🏆 Gamification & Flow State Rewards Engine
- **10 Progression Tiers**: From *Novice Planner (Lvl 1)* to *Grandmaster of Time (Lvl 10)*.
- **Streak Multipliers**: Rewards daily consistency with scaling XP multipliers ($1.0\times$ up to $2.0\times$).
- **Milestone Badges**: Live tracking for `early_bird`, `deep_diver`, `streak_hero`, `streak_titan`, `inbox_zero`, `zen_master`, and `time_oracle`.
- **Celebration Dialogs**: Physics-driven fullscreen particle confetti upon leveling up and a dedicated trophy showcase in AI Coach.

### 🎨 High-Vibrancy UI Design System
- **Curated High-Vibrancy Palette**: Neon Violet, Neon Cyan, Electric Amber, Sunset Rose, and Ultra Emerald.
- **Modern Glassmorphic Components**: `VibrantGlassCard` with rim glow, `GlowBadge` with pulsing status dots, `AnimatedXpBar`, and `PulsingAuraAvatar`.

### 🧩 Core Productivity & Intelligent Scheduling Engine
- **Smart Constraint-Based Scheduler** — multi-factor deterministic engine evaluating priority, deadline urgency, goal alignment, energy levels, preferred time of day, and context switching with zero overlapping conflicts
- **Task Dependencies DAG** — declare task dependencies; Kahn's topological sort guarantees dependent tasks start strictly after prerequisites finish with automatic cycle breaking
- **Task Splitting** — long tasks decomposed into manageable focus blocks with automatic restorative transition breaks
- **Schedule Explainability ("Why Here?")** — tap any scheduled task to view transparent factor breakdown and planning score bar
- **Schedule Diagnostics & Warnings** — amber warning banner flags deadline misses, unplaced tasks, or dependency cycles
- **Day Planner** — drag-reorder, inline complete/delete, and tap-to-edit any task with an Advanced Scheduling panel (deadlines, earliest start, latest finish, fixed anchors, energy & time-of-day chips)
- **Goals & Projects** — structure your life's ambition by linking tasks, notes, and events directly to larger objectives and project containers
- **Notes** — rich editor with AI-generated summaries, auto-tags, and action-item extraction directly into the planner
- **Note ↔ Task Linking** — link notes to tasks (and vice versa) via a picker UI; related items surface in both the note editor and task detail sheet
- **Global Search** — find anything quickly across tasks, notes, calendar events, goals, and projects
- **Memory** — persistent AI memory extracted from your tasks, notes, and brain dumps; automatically fed back as context on future AI calls
- **Calendar** — visual day/week timeline synced with task changes in real time
- **Dashboard** — daily insight card powered by AI, token usage meter, streak tracker
- **Analytics** — 3-tab insights (overview, trends, tags) with `fl_chart` visualisations + AI weekly review
- **Flagship Onboarding Walkthrough** — 6 rich capability slides highlighting Brain Dump 2.0, DAG autonomous scheduling, Daily Rituals, Circadian Focus, Gamification Mastery, and Living Memory with ambient dynamic glowing orbs
- **Comprehensive In-App Help & Guide** — 5-stage daily productivity lifecycle diagram, 11 expandable capability deep dives, and rich interactive FAQs
- **Settings & Profile Studio** — notification center, chronotype and productivity persona selector, haptic/sensory preferences, theme picker, biometric lock, API key management, mock AI toggle, and profile editor

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

# Run full test suite (449 tests across 24 suites)
flutter test

# Run scheduler behavioral and constraint tests
flutter test test/scheduler_service_test.dart test/dependency_graph_service_test.dart

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
