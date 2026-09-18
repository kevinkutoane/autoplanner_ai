# AutoPlanner AI — Complete Architecture Map & System Design

This document provides a comprehensive blueprint of the system architecture, component dependencies, and runtime data flows of AutoPlanner AI.

---

## 🏛️ End-to-End System Architecture Map

```text
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                       PRESENTATION LAYER (FLUTTER)                                      │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│  DashboardScreen   PlannerScreen   FocusHubScreen   AiCoachScreen   CalendarScreen   NotesScreen   Goals│
│         │                │                │                │               │              │          │  │
│         ▼                ▼                ▼                ▼               ▼              ▼          ▼  │
│  [DailyRitualCard] [GradientHeader] [MicroWinsCard] [AuraAvatar]    [GradientHead] [GradientHead][Rings]│
│  [LevelUpDialog]   [WhyHereSheet]   [FocusTimer]    [TypingBubble]  [DayTimeline]  [ActionItems] [Link] │
│                                                                                                         │
│  FLAGSHIP ENGINES & NAVIGATION ARCHITECTURE:                                                            │
│  • _GlassNavBar: 5-slot balanced floating dock [Dashboard, Planner, Center Brain Dump, Focus, Coach]    │
│  • _DockedBrainDumpButton: Elevated center action button with neon sunset glow & instant triage modal    │
│  • _GlassMoreSheet: 4x2 responsive frosted-glass grid [Goals, Projects, Memory, Notes, Analytics, etc.] │
│  • BrainDumpSheet: AudioWaveformVisualizer (32-bar EQ) + Voice Dictation + Emulator Voice Simulator     │
│  • AiCoachScreen: Strict productivity guardrails + Bot & User avatars + Animated 3-dot wave typing      │
│  • CommandOmnibar: Spotlight palette (Cmd+K) with interactive CommandPreview & mutation guards          │
│  • RitualSheets: MorningKickoffSheet (Big 3) & EveningShutdownSheet (Task triaging & memory reflection) │
│  • OnboardingScreen: 6 capability slides + reactive ambient orbs + hardware key configuration           │
│  • HelpScreen: 5-stage daily lifecycle, 11 expandable capability deep dives, and rich interactive FAQs │
└────────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                     │ Riverpod ref.watch / ref.read
                                                     ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    APPLICATION STATE LAYER (RIVERPOD)                                   │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│  • TaskController         (Notifier<List<TaskItem>>)      → CRUD, goal linking, duration tracking      │
│  • NoteController         (Notifier<List<NoteItem>>)      → CRUD, task bidirectional linking           │
│  • GoalController         (Notifier<List<GoalItem>>)      → Multi-step progress calculation            │
│  • CalendarController     (Notifier<List<CalendarEvent>>) → Real-time Google Calendar events sync      │
│  • FocusController        (Notifier<FocusSessionState>)   → Countdown timer, actual focus logging      │
│  • GamificationNotifier   (Notifier<GamificationProfile>) → XP multipliers, 10 ranks, badge catalog    │
│  • MemoryController       (Notifier<List<MemoryEntry>>)   → AI memory query, relevance score decay     │
│  • SettingsController     (Notifier<AppSettings>)         → Dark/Light, work hours, biometric gate     │
└────────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                     │ Service Invocations
                                                     ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 DOMAIN & INTELLIGENCE SERVICES LAYER                                    │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│  • RoutineService          → Dynamic Morning Briefing (Big 3 prioritization) & Evening Shutdown triaging│
│  • ContextAwareService     → Circadian energy modeling & calendar gap detection for Micro-Wins          │
│  • SchedulerService        → Constraint solver, multi-factor scoring function, split focus blocks       │
│  • DependencyGraphService  → Kahn's DAG topological sort & cycle resolution for task dependencies     │
│  • DurationLearningService → Past duration variance learning & category multiplier calibration          │
│  • RescheduleService       → Proactive detection of overdue items with smart slot recommendations       │
│  • GamificationService     → Streak tracking, level progression, XP calculations, badge evaluations     │
│  • CalendarSyncService     → Google Calendar REST API v3 incremental syncToken & etag diffing           │
│  • NotificationService     → Timezone-aware local scheduled task reminders and morning briefings        │
└────────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                     │ Safe Delegation
                                                     ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    AI ABSTRACTION & SAFETY BOUNDARY                                     │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│  • AIService          → Chat, Brain Dump, Schedule Commands, Day Planning, Memory Extraction           │
│  • AIGuard            → Input sanitization, call throttling, prompt-injection defense                  │
│  • AIValidator        → Enforces JSON schemas, duration clamps (15-480m), priority ranges (0-3)        │
│  • TokenTracker       → Daily token usage caps, in-memory caching, latency recording                    │
│  • OfflineAIQueue     → Encrypted persistent queue with exponential backoff for offline resilience      │
│  • GeminiProvider     → Google Gemini 2.5 Flash API connector (streaming + complete)                    │
│  • MockAIProvider     → Deterministic offline simulation for tests and token-free development           │
└────────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                     │ AES-256 Encrypted Read/Write
                                                     ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 LOCAL-FIRST PERSISTENCE LAYER (HIVE)                                    │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│  All boxes encrypted with device-unique AES-256 key from OS Keychain (Keystore / Secure Enclave)        │
│                                                                                                         │
│  [tasksBox]        [notesBox]       [goalsBox]       [calendarBox]      [memoryBox]     [projectsBox]   │
│  (TaskItem)        (NoteItem)       (GoalItem)       (CalendarEvent)    (MemoryEntry)   (ProjectItem)   │
│                                                                                                         │
│  [gamificationBox] [settingsBox]    [aiLogsBox]      [appEventsBox]     [offlineAIQueueBox]             │
│  (Profile/Badges)  (AppSettings)    (AILogEntry)     (Diagnostics)      (QueuedAIRequest)               │
│                                                                                                         │
│  Safe Quarantine & Corruption Recovery: .corrupt.<timestamp>.bak backup before clean box re-creation    │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Unified Startup Lifecycle (`AppBootstrapper`)

The application starts deterministically through `AppBootstrapper.init()` before the widget tree mounts:

```text
main()
  → WidgetsFlutterBinding.ensureInitialized()
  → AppBootstrapper.init(callbackDispatcher: callbackDispatcher)
      1. Load .env (with fallback to .env.example) and populate appConfig
      2. Register Workmanager background tasks (hourly calendarSyncTask)
      3. Hive.initFlutter() & register all 8 TypeAdapters
      4. Derive AES-256 encryption key from OS Keychain (SecureKeyService)
      5. Pre-open encrypted boxes with safe corruption backup (openBoxSafe<T>):
         - tasksBox, notesBox, goalsBox, projectsBox, calendarBox
         - settingsBox, appEventsBox, gamificationBox
      6. Initialize services:
         - TokenTracker (loads daily token tallies)
         - MemoryService (runs memory decay on stale items)
         - NotificationService (initializes notification channels)
      7. Restore Google OAuth session & schedule morning briefing
      8. Assemble ProviderContainer with AppProviderObserver and service overrides
      9. Initialize OfflineAIQueue (drains any pending requests from last session)
  → Wrap AutoPlannerApp in UncontrolledProviderScope & ErrorBoundary
  → AppBootstrapper.crashReporter.runApp()
```

---

## 🧩 Core Operating System Subsystems

### 1. Multi-Agent Routines & Automated Rituals (`RoutineService`)
- **Morning Kickoff Ritual**:
  - Automatically assesses today's calendar commitments and rollover incomplete tasks.
  - Heuristically and intelligently selects **"The Big 3"** high-impact priorities.
  - Computes available focus hours: $\text{availableMinutes} = \text{totalWorkMinutes} - \text{meetingMinutes}$.
  - Launches [`MorningKickoffSheet`](../lib/features/dashboard/widgets/morning_kickoff_sheet.dart) with sunrise gradient hero and one-tap plan activation (+50 XP).
- **Evening Shutdown Ritual**:
  - Evaluates daily completion velocity, deep work minutes logged, and incomplete items.
  - Launches [`EveningShutdownSheet`](../lib/features/dashboard/widgets/evening_shutdown_sheet.dart) offering one-tap task triaging (*Move to Tomorrow*, *Send to Backlog*, or *Discard*).
  - Prompts a 1-line evening reflection, permanently stored in `memoryBox` tagged `#reflection`.
- **Dynamic Dashboard Presence**:
  - [`DailyRitualCard`](../lib/features/dashboard/widgets/daily_ritual_card.dart) dynamically alternates between Morning Kickoff (before noon) and Evening Shutdown (after 5:00 PM).

### 2. Context-Aware Smart Engine & Dynamic Recommendations (`ContextAwareService`)
- **Circadian Energy Modeling**:
  - **Morning Phase (06:00 – 12:00)**: Peak Deep Work. Highest priority and complex focus tasks recommended.
  - **Afternoon Phase (12:00 – 17:00)**: Operational & Collaborative. Standups, admin, emails, and syncs.
  - **Evening Phase (17:00 – 23:00)**: Cooldown & Reflection. Low-energy tasks, planning, and mental shutdowns.
- **Calendar Gap Detection**:
  - Scans upcoming calendar events in real time to locate 10–60 minute open gaps.
  - Matches candidate pending tasks that comfortably fit inside the open window.
- **Micro-Wins Delivery**:
  - [`MicroWinsCard`](../lib/features/focus/widgets/micro_wins_card.dart) presents bite-sized tasks with a single-tap "Quick Flow" launcher directly entering Focus Mode.

### 3. Gamification, Streaks & Flow State Rewards Engine (`GamificationService`)
- **Profile & Progression Model**:
  - Encrypted persistence in `gamificationBox`.
  - **10 Progression Tiers**: From *Novice Planner (Lvl 1)* to *Grandmaster of Time (Lvl 10)*.
  - **Streak Multipliers**: Rewards daily consistency with scaling multipliers ($1.0\times$ up to $2.0\times$).
- **Rewards Matrix**:
  - Completing standard task: **+50 XP** (+30 for High priority, +20 for finishing under estimate).
  - Deep work focus session: **+10 XP** per 10 minutes focused.
  - Morning Kickoff & Evening Shutdown: **+50 XP** each.
  - Mental Declutter (Brain Dump): **+50 XP**.
- **Badge Showcase**:
  - Milestone badges evaluated live: `early_bird`, `deep_diver`, `streak_hero`, `streak_titan`, `inbox_zero`, `zen_master`, `time_oracle`.
  - Celebrated with [`LevelUpDialog`](../lib/features/dashboard/widgets/level_up_dialog.dart) full-screen confetti and [`AchievementsSheet`](../lib/features/coach/widgets/achievements_sheet.dart) trophy showcase.

### 4. Brain Dump 2.0 Flagship Experience
- **Sensory Voice Studio & Dictation Permissions**:
  - [`AudioWaveformVisualizer`](../lib/features/brain_dump/widgets/audio_waveform_visualizer.dart): 32-bar reactive frequency equalizer that responds in real-time to microphone sound levels with animated harmonic sine-waves.
  - Dual-mode voice dictation and free-form text input with Thought Starter quick chips.
  - **Android Audio Permissions**: Explicit `RECORD_AUDIO`, `BLUETOOTH`, and `BLUETOOTH_CONNECT` declarations plus package visibility query for `android.speech.RecognitionService` in `AndroidManifest.xml`.
  - **Runtime Permission Handling**: Proactively requests microphone access upon first tap; displays an informative recovery dialog directing to system App Settings if permissions were previously denied.
  - **Emulator Voice Dictation Simulator**: In environments lacking speech recognition hardware (e.g. Android Emulators, headless CI, or desktop testing), detects hardware unavailability and offers an interactive voice simulator with streaming simulated audio (`_simulateVoiceDictation`) that feeds realistic thoughts directly into the 32-bar visualizer and cognitive parser.
- **Deep Cognitive 4-Pillar Extraction**:
  - Extracts actionable **Tasks** (with start time, duration, priority, tags, energy level).
  - Extracts **Notes & Ideas** (saved directly to `notesBox` with `#braindump`).
  - Extracts **Goals** (auto-linked to extracted tasks).
  - Extracts **Memories** (retained in long-term memory context).
- **Smart Gap-Aware Auto-Scheduling**:
  - Evaluates current time of day (`DateTime.now()`) and scans upcoming calendar events.
  - Sequentially packs tasks into feasible upcoming open windows (e.g. `✓ Scheduled for 14:30`) without overlapping existing meetings or scheduling tasks in the past.
- **Interactive Live Triage**:
  - [`BrainDumpTaskTile`](../lib/features/brain_dump/widgets/brain_dump_task_tile.dart) with instant duration selector chips (`15m`, `30m`, `45m`, `60m`), priority cycling, and one-tap conversion to Note.
  - [`BrainDumpNoteTile`](../lib/features/brain_dump/widgets/brain_dump_note_tile.dart) with tags preview and one-tap conversion to Task.

### 5. AI Coach Persona, Strict Productivity Guardrails & Conversational UI
- **Strict Domain Scope Guardrails (`AIService.chatWithCoach`)**:
  - Persona is strictly bounded to personal productivity, scheduling, task execution, habit formation, circadian energy, and motivation.
  - Automatically evaluates input topics; off-topic questions (trivia, general knowledge, non-productivity inquiries) are politely redirected back to daily goals.
  - Enforces pure, human-readable Markdown formatting, strictly suppressing raw JSON schemas or internal task data structures.
- **Mock & Fallback Safety Layers**:
  - `MockAIProvider` features dedicated coach intelligence returning structured, actionable markdown advice.
  - `AiCoachScreen` includes `_cleanMessageContent` parser fallback to cleanly scrub any accidental raw JSON data into friendly bullet points.
- **Conversational Presentation**:
  - Visual identity: Glowing bot avatar with a cyan halo for the AI Coach, paired with the user's customized profile badge.
  - `_TypingBubble`: Animated pulsing 3-dot wave indicator displaying real-time cognitive activity while the coach formulates responses.
  - Trophy and milestone showcase integrated via [`AchievementsSheet`](../lib/features/coach/widgets/achievements_sheet.dart).

### 6. Intelligent Constraint-Based Scheduling Engine (`SchedulerService`)
- **Deterministic Pure-Dart Solver**: Operates with `package:clock` (`clock.now()`) for testability.
- **Directed Acyclic Graph (DAG) Resolution (`DependencyGraphService`)**:
  - Topologically sorts tasks by dependencies (`dependsOnTaskIds`).
  - Breaks circular dependencies safely via Kahn's algorithm with diagnostic warnings.
- **Multi-Factor Planning Score Function**:
  $$\text{Score}(T, S) = W_p \cdot P(T) + W_d \cdot U(T, S) + W_g \cdot G(T) + W_e \cdot E(T, S) - C(T, S_{\text{prev}})$$
  - Priority score $P(T)$, Deadline urgency escalation $U(T, S)$, Goal alignment $G(T)$, Circadian energy fit $E(T, S)$, and Context-switching penalty $C(T, S_{\text{prev}})$.
- **Task Splitting Engine**: Large tasks (`splittable: true`) decompose into sequential chunks linked by `parentTaskId` with restorative buffer breaks.
- **Explainability & Diagnostics**: Generates a transparent rationale sheet explaining "Why Here?" for every scheduled task.

### 7. Duration Variance Learning & Auto-Calibration (`DurationLearningService`)
- Learns personal completion tendencies from historical records:
  $$\text{multiplier} = \text{clamp}_{0.5}^{2.5}\left(\frac{\text{actualDurationMinutes}}{\text{estimatedMinutes}}\right)$$
- Aggregates rolling average multipliers per category and injects calibrated duration estimates into `SchedulerService`.
- Quantifies Schedule Accuracy Index (SAI) and accumulates planning debt metrics.

### 8. Flagship Notification Engine, Settings Hub & Profile Studio
- **Multi-Tier Notification Engine (`NotificationService`)**:
  - Differentiated Android notification channels:
    - `autoplanner_urgent` (`Importance.max`, `Priority.max`): Critical priority-3 tasks, immediate notes alerts, and streak shield warnings.
    - `autoplanner_tasks` (`Importance.high`, `Priority.high`): Scheduled task alerts with user-configured lead times.
    - `autoplanner_briefing` & `autoplanner_rituals`: Morning kickoff and evening shutdown daily alarms.
  - Granular Task Filtering: Smart toggle for "Crucial Tasks Only (High/Urgent)" vs all tasks.
  - Configurable Lead Times: Choice of `5m`, `10m`, `15m`, or `30m` ahead of scheduled start.
  - Streak Shield: Evening alert at 20:00 protecting active streaks.
- **Modern Settings Hub (`SettingsScreen`)**:
  - Notification Center Card: Complete control over alerts, lead times, and ritual timers.
  - Productivity Persona Card: Circadian chronotype (`early_bird`, `balanced`, `night_owl`), daily deep work goals (`60m` to `180m`), and AI coach persona styles (`direct`, `balanced`, `empathetic`).
  - Sensory & Celebrations Card: Haptic feedback and achievement confetti celebration toggles.
- **Flagship Profile Studio (`ProfileScreen`)**:
  - Gamification Mastery Hero: Real-time Level, Rank title, XP progress bar, lifetime stats, and streak multipliers.
  - Productivity Identity Card: Badges reflecting chronotype, focus goal, and persona with custom motto banner.
  - Profile Edit Dialog: Expanded avatar presets (16 curated emojis) and live motto/mantra editing.

### 9. Navigation Dock Architecture & Ergonomics (`AppShell`)
- **Balanced 5-Slot Floating Glass Dock (`_GlassNavBar`)**:
  - Balanced ergonomic layout: `Dashboard`, `Planner`, `[Center Action]`, `Focus`, and `AI Coach`.
  - Floating frosted pill with ambient drop shadow and blur (`BackdropFilter`), eliminating bottom tab crowding.
  - **Docked Brain Dump 2.0 Hero Button (`_DockedBrainDumpButton`)**:
    - Central elevated action button with multi-color neon glow (`kGradientNeonSunset`).
    - Eliminates the floating action button (FAB) collision that previously obscured navigation controls.
- **Responsive 4x2 "More Features" Glass Sheet (`_GlassMoreSheet`)**:
  - Accessible via top-bar actions across screens, housing secondary features in a clean 4x2 responsive grid:
    - Goals (`#EC4899`), Projects (`#8B5CF6`), Memory (`#F59E0B`), Notes (`#10B981`)
    - Analytics (`#06B6D4`), Settings (`#64748B`), Omnibar (`#6366F1`), Help (`#14B8A6`)
  - Frosted glass container with high-contrast icon badges and direct navigation routing.

---

## 🗄️ Hive Data Schema

All boxes are AES-256 encrypted using an encryption key stored in the OS Keychain (`flutter_secure_storage`).

| Box Name | TypeId | Model | Description |
| --- | --- | --- | --- |
| `tasksBox` | 0 | `TaskItem` | Tasks with constraints, dependencies, duration tracking, energy levels |
| `notesBox` | 1 | `NoteItem` | Notes, summaries, action items, tags, bidirectional task links |
| `calendarBox` | 2 | `CalendarEvent` | Synced Google Calendar events with `syncToken` and `etag` diffing |
| `memoryBox` | 3 | `MemoryEntry` | AI long-term memories, user habits, behavioral rules, reflections |
| `goalsBox` | 4 | `GoalItem` | Aspirational milestones, target dates, completion progress rings |
| `projectsBox`| 5 | `ProjectItem` | Project containers grouping tasks and deadlines |
| `gamificationBox` | — | `GamificationProfile` | XP points, levels (1-10), active/longest streaks, unlocked badge IDs |
| `settingsBox` | — | `AppSettings` | Work hours, theme, morning briefing, biometrics, sync state |
| `aiLogsBox` | 10 | `AILogEntry` | Token usage logs, model names, prompt/completion token tallies |
| `appEventsBox`| 11 | `AppEvent` | Application telemetry, errors, recovery events |
| `offlineAIQueueBox` | — | `QueuedAIRequest` | Persistent FIFO queue for offline AI operations |

---

## 🎨 High-Vibrancy UI Design System (`ui_kit.dart`)

The app uses a curated, high-vibrancy design language engineered for sensory engagement and clarity:

- **Vibrant Color Palette**:
  - `kNeonViolet` (`#8B5CF6`) & `kNeonCyan` (`#06B6D4`): Primary brand aura.
  - `kElectricAmber` (`#F59E0B`): Energy indicators and note chips.
  - `kSunsetRose` (`#F43F5E`): Urgency flags and evening shutdown twilight.
  - `kUltraEmerald` (`#10B981`): Success indicators and completion badges.
- **Signature Screen Gradient Palettes**:
  - `kGradientPlanner`: Deep Indigo (`#4338CA`) to Neon Violet (`#7C3AED`) — dynamic task scheduling.
  - `kGradientCalendar`: Rich Teal (`#0F766E`) to Neon Cyan (`#06B6D4`) — temporal timeline clarity.
  - `kGradientMemory`: Electric Amber (`#D97706`) to Sunset Rose (`#E11D48`) — long-term neural recall.
  - `kGradientNotes`: Ultra Emerald (`#059669`) to Mint Teal (`#0D9488`) — creative thought studio.
  - `kGradientProjects`: Vivid Pink (`#DB2777`) to Sunset Rose (`#E11D48`) — ambitious milestone tracking.
  - `kGradientAnalytics`: Neon Violet (`#7C3AED`) to Vivid Sky (`#0284C7`) — telemetry and performance insights.
  - `kGradientSettings`: Slate Blue (`#334155`) to Indigo (`#4F46E5`) — device control room.
  - `kGradientNeonSunset`: High-vibrancy Coral to Gold — heroic Brain Dump action triggers.
- **Glassmorphism & Micro-Animations**:
  - `VibrantGlassCard`: Frosted glass with colored rim glow, ambient depth, and touch feedback.
  - `GlowBadge`: Glowing status pill with pulsing live dot.
  - `AnimatedXpBar`: Shimmering progress bar with elastic easing.
  - `PulsingAuraAvatar`: Breathing aura halo for the AI Coach.
  - `_TypingBubble`: Animated pulsing 3-dot wave indicator showing active AI reasoning.
