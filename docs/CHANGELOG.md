# Changelog

All notable changes to AutoPlanner AI are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

## [2.3.1] — 2026-09-18

### Production Readiness & Engineering Stabilisation (Release Candidate — Conditional)

- **Offline AI Queue Hardening & Collision Safety (`OfflineAIQueue`)**:
  - Bound `OfflineAIQueue` securely inside the application's AES-256 encryption boundary (`HiveAesCipher`) via `SecureKeyService`.
  - Certified at-least-once lifecycle (`enqueue` -> `persist` -> `restart/reload` -> `dispatch` -> `execute` -> `acknowledge`).
  - Added bounded retry enforcement: requests failing 5 times are marked `isPermanentFailure: true` and retained diagnostically instead of infinite retries or silent drops.
  - Added fast permanent failure for non-retriable exceptions (`UnsupportedError`).
  - Hardened request ID deduplication using UUID v4 suffix (`${method}_${timestamp}_${uuid}`) to eliminate collision vulnerability under rapid intra-millisecond submissions.
  - Guarded against concurrent overlapping drains using atomic future completers and active pending checks.
- **Hive Recovery Safety Invariant Certification (`AppBootstrapper.openBoxSafe`)**:
  - Certified 4 distinct fault classes in `test/hive_recovery_test.dart`:
    1. *Storage / Filesystem error*: rethrows cleanly, never deletes data.
    2. *Encryption key mismatch*: throws `HiveKeyMismatchException`, preserves user data intact, never deletes or quarantines.
    3. *Programming / configuration error*: rethrows without deleting data.
    4. *Genuine file corruption*: creates verified diagnostic backup copy (`.corrupt.<ts>.bak`), verifies byte length, and only then quarantines and recreates box.
- **Universal Scheduler Invariant Certification (`test/scheduler_invariants_test.dart`)**:
  - Certified all hard invariants across 21 scheduler invariant and boundary tests: hard earliest start (`start >= earliestStart`), hard latest finish (`end <= latestFinish` or unplaced), deadline warnings, work-window policy with documented same-day extension (`isToday && now.isAfter(workEnd)` extends to `23:59`), non-overlap with 10-minute buffers, immovable fixed tasks, historical completed tasks preservation, DAG prerequisite ordering, past-time protection, determinism, idempotence, overload handling, DAG circular cycle safety, task splitting duration conservation, and clock time-of-day determinism.
- **Clock Abstraction Standardization (`package:clock`)**:
  - Audited scheduling-sensitive boundaries and converted `RescheduleService.checkOverdue` to `clock.now()`.
- **Toolchain & CI Alignment**:
  - Upgraded GitHub Actions CI toolchain (`.github/workflows/ci.yml`) to Java 21, resolving JVM compatibility mismatch with Gradle 8.12.
  - Aligned project release metadata across `pubspec.yaml`, `README.md`, `docs/README.md`, and documentation to `2.3.1+1`.
  - Configured Codecov upload step with `${{ secrets.CODECOV_TOKEN }}` as non-blocking telemetry alongside local `flutter test --coverage` quality gate.
  - Verified clean static analysis with `--fatal-infos` (zero issues) and clean debug APK build (`flutter build apk --debug`).
- **Engineering Registers & Known Debt**:
  - Created `docs/PRODUCTION_READINESS.md` containing full empirical verification matrix across build, quality, security, scheduler, calendar, offline queue, and reliability (classified as `RELEASE CANDIDATE — CONDITIONAL` pending real-device QA).
  - Created `docs/ARCHITECTURE_DEBT.md` establishing a formal register of non-blocking architectural debt, including Android toolchain future-support warnings (Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 / Actions Java v4).
- **Test Suite Scale**:
  - Expanded test suite to **529 passing automated tests across 34 test files** with 100% pass rate.

---

## [2.3.0] — 2026-09-18

### Navigation Dock Overhaul, Signature Screen Themes, Voice Simulator & AI Coach Guardrails

- **Ergonomic 5-Slot Navigation Dock (`_GlassNavBar`) & More Features Sheet**:
  - Re-architected bottom navigation from a cramped tab row and overlapping floating action button into an ergonomic 5-slot balanced floating glass dock (`_GlassNavBar`).
  - Elevated central action button (`_DockedBrainDumpButton`) with multi-color neon gradient glow (`kGradientNeonSunset`), prominent scale animation, and immediate Brain Dump 2.0 launch.
  - Eliminated the floating action button (FAB) overlap/collision that obscured bottom navigation items.
  - Redesigned "More Features" modal into an organized 4x2 responsive frosted-glass sheet (`_GlassMoreSheet`) housing Goals, Projects, Memory, Notes, Analytics, Settings, Omnibar, and Help with dedicated color-coded glowing badges.
  - Resolved Dashboard header layout overflow on narrow screens with `Flexible` greeting wrappers, `FittedBox` date scaling, and compact 36x36 frosted glass action buttons.
- **Distinct Signature Screen Palettes & Glowing Headers (`ui_kit.dart`)**:
  - Defined curated high-vibrancy screen gradient tokens in `ui_kit.dart`:
    - `kGradientPlanner` (Indigo & Violet)
    - `kGradientCalendar` (Teal & Cyan)
    - `kGradientMemory` (Amber & Rose)
    - `kGradientNotes` (Emerald & Teal)
    - `kGradientProjects` (Pink & Rose)
    - `kGradientAnalytics` (Violet & Cyan)
    - `kGradientSettings` (Slate & Indigo)
    - `kGradientNeonSunset` (Rose & Amber)
  - Upgraded headers across all major screens with signature gradient accents, glowing iconography badges, and cohesive visual hierarchy.
- **AI Coach Persona, Strict Productivity Scope & Conversational UI (`AiCoachScreen`)**:
  - Enforced strict productivity domain guardrails in `AIService.chatWithCoach`: bounded advice exclusively to time management, daily planning, circadian energy balance, focus habits, and motivation, politely redirecting non-productivity topics back to user workflow.
  - Eliminated raw JSON response leakage in `MockAIProvider` with dedicated coach simulation returning structured, readable markdown advice.
  - Added fallback response sanitizer (`_cleanMessageContent`) in `AiCoachScreen` to strip accidental raw task JSON and format structured tasks as clean conversational bullets.
  - Added visual avatars: glowing bot avatar with a cyan aura for the AI Coach, and a distinct user profile badge.
  - Added inline animated pulsing 3-dot wave typing indicator (`_TypingBubble`) rendering while the AI is generating responses.
- **Microphone Permissions & Voice Dictation Simulator (`BrainDumpSheet`)**:
  - Configured Android runtime permissions in `AndroidManifest.xml`: `RECORD_AUDIO`, `BLUETOOTH`, `BLUETOOTH_CONNECT`, and query declaration for `android.speech.RecognitionService`.
  - Implemented runtime permission request flow with informative permission-denied dialog providing one-tap guidance to device settings.
  - Integrated Emulator Voice Dictation Simulator: detects when hardware speech recognition is unavailable (e.g. in Android Emulator or desktop environments) and presents a simulation dialog with streaming audio wave inputs (`_simulateVoiceDictation`) that feeds realistic thoughts directly into the 32-bar visualizer and 4-pillar cognitive parser.
- **Test Suite & Stability**:
  - 100% test pass rate across all 503 automated unit, widget, and integration tests (`flutter test`).
  - Zero errors or warnings in `flutter analyze`.

---

## [2.2.0] — 2026-09-18

### Onboarding Capabilities & Help Screen Guide Modernization

- **Flagship Onboarding Walkthrough (`OnboardingScreen`)**:
  - Expanded from 4 static slides to 6 rich, vibrantly stylized capability pages showcasing modern flagship features:
    1. *Brain Dump 2.0 Studio*: 32-band reactive audio waveform equalizer, 4-pillar extraction (Tasks, Goals, Notes, Memories), triage studio & one-tap calendar gap packing.
    2. *Autonomous Scheduling*: Deterministic constraint solver, DAG prerequisite dependencies, split subtasks, buffer intervals, and proactive rescheduling.
    3. *Daily Rituals & Routines*: Morning Kickoff with "The Big 3" priority commitments, Evening Shutdown with rollover triaging, and automated reminders.
    4. *Circadian Focus & Micro-Wins*: Chronotype energy matching, radial countdown flow timer, ambient soundscapes, distraction scratchpad, and micro-break prompts.
    5. *Mastery Ranks & Streaks*: 10 progression tiers (Novice to Grandmaster), streak multipliers, automated Streak Shield, and 20+ unlockable achievement badges.
    6. *Living Memory & Privacy*: Cross-session memory auto-synthesis, 100% on-device AES-256 encrypted Hive storage, hardware Secure Enclave key protection.
  - Dynamically tuned `_OnboardOrbPainter` with 7 ambient glowing gradient palettes transitioning smoothly between pages.
- **Modernized In-App Help & Guide (`HelpScreen`)**:
  - Re-architected "What is AutoPlanner AI?" to articulate the complete autonomous personal productivity architecture.
  - Redesigned "How It Works" into a comprehensive 5-Stage Daily Productivity Lifecycle (Morning Kickoff → Brain Dump 2.0 → Autonomous Scheduling → Immersive Focus → Evening Shutdown & Memory).
  - Expanded Feature Guide to 11 deep-dive expandable tiles covering Brain Dump 2.0, Autonomous Scheduling, Proactive Rescheduling, Daily Rituals, Focus & Circadian engine, Gamification & Streaks, Living Memory, Notifications & Streak Shield, Goals & Projects, Calendar Sync, and On-Device Privacy.
  - Added essential FAQ accordions explaining Streak Shield protection, Circadian Chronotype energy matching, 4-pillar Brain Dump extraction, and DAG task dependencies.
- **Verification & Test Suite**:
  - Added automated widget tests for `HelpScreen` header, lifecycle sections, feature tiles, and interactive expansion toggles (`test/widget_test.dart`).
  - Zero lint warnings in `flutter analyze`.

---

## [2.1.0] — 2026-09-18

### Flagship Notifications, Settings Hub & Profile Studio Upgrade

- **Notification Engine & Smart Alerts**:
  - Differentiated alert channels: Urgent Alerts (`autoplanner_urgent`, `Importance.max`) for Priority 3 critical tasks and urgent notes; Timed Task Reminders (`autoplanner_tasks`, `Importance.high`) for scheduled work; Daily Rituals (`autoplanner_rituals`).
  - Configurable reminder lead times: Quick-selection chips for `5m`, `10m`, `15m`, and `30m` before task start.
  - Smart task reminder filter: User toggle to alert on "Crucial Tasks Only (High/Urgent)" vs all scheduled tasks, preventing notification fatigue.
  - Evening Shutdown ritual reminders (`scheduleEveningShutdown`) at customizable time (default 17:30).
  - Streak Shield alert (`scheduleStreakShield`) firing at 20:00 to protect active streaks from breaking.
  - Independent toggles for notification sound and vibration.
- **Modern Settings Hub (`SettingsScreen`)**:
  - `_NotificationCenterCard`: Unified control room for task reminders, crucial filter, lead-time chips, morning kickoff & evening shutdown time pickers, and streak shield.
  - `_ProductivityPersonaCard`: Chronotype selector (`🌅 Early Bird`, `⚖️ Balanced`, `🌙 Night Owl`), Daily Deep Work Target (`1h`, `1.5h`, `2h`, `3h`), and AI Coach Persona selector (`⚡ Direct & Sharp`, `🎯 Strategic & Balanced`, `🌱 Empathetic & Supportive`).
  - `_SensoryPreferencesCard`: Global toggles for subtle haptic feedback and achievement confetti celebrations.
- **Flagship Profile Studio (`ProfileScreen`)**:
  - `_GamificationMasteryHero`: Dynamic Level & Rank title, live animated XP progress bar with remaining XP to next tier, and streak pill with live XP multiplier badge (e.g. `🔥 5d • 1.5x`).
  - `_ProductivityPersonaCard`: Circadian chronotype badge, daily focus goal target ring, and personal mantra/motto banner with custom quotation styling.
  - `ProfileEditDialog`: Expanded avatar presets (16 curated emojis including `🦁`, `🧘`, `🏆`, `💎`), and personal motto/mantra editor with immediate live preview.
- **Test & Analysis Validation**:
  - 100% test pass rate across 501 unit and widget tests (`test/notification_settings_test.dart` added).
  - `flutter analyze` passing with 0 warnings/errors.

---

## [2.0.0-preview] — 2026-09-18

### Next-Gen Operating System & Brain Dump 2.0 Flagship Upgrade

- **Flagship Brain Dump 2.0 Experience**:
  - `AudioWaveformVisualizer`: 9-bar reactive frequency equalizer reacting live to microphone sound levels with harmonic sine wave rendering.
  - Deep Cognitive 4-Pillar Extraction: Parses Tasks, Notes, Goals, and Memories in a single unified pass.
  - Smart Gap-Aware Auto-Scheduling: Intelligently packs extracted tasks into upcoming open calendar windows without collisions or past-time placement.
  - Interactive Triage Studio: `BrainDumpTaskTile` with inline duration chips (`15m`, `30m`, `45m`, `60m`), priority cycling, and conversion to Notes. `BrainDumpNoteTile` with tags preview.
  - Cognitive Clarity Score banner and atomic +50 XP declutter bonus.
  - High-vibrancy glowing `_BrainDumpFab` in bottom navigation.
- **Multi-Agent Routines & Automated Rituals**:
  - `RoutineService`: Morning Kickoff ("The Big 3" priority selection and focus hour calculation) and Evening Shutdown (velocity metrics, task triaging, and memory reflections).
  - `DailyRitualCard`: Context-aware banner on Dashboard alternating morning/evening rituals.
- **Context-Aware Smart Engine & Dynamic Recommendations**:
  - `ContextAwareService`: Circadian energy phases (Deep Work, Operational, Cooldown).
  - Real-time calendar gap detector and `MicroWinsCard` for single-tap quick flow.
- **Gamification, Streaks & Flow State Rewards Engine**:
  - `GamificationService` with local-first AES-encrypted `gamificationBox`.
  - 10 progression tiers (Novice Planner to Grandmaster of Time).
  - Scaling streak multipliers ($1.0\times$ up to $2.0\times$).
  - Live milestone badges catalog, `LevelUpDialog` celebration, and `AchievementsSheet` trophy showcase.
- **UI Vibrancy Design System Overhaul**:
  - High-vibrancy design tokens (`kNeonViolet`, `kNeonCyan`, `kElectricAmber`, `kSunsetRose`, `kUltraEmerald`).
  - Glassmorphic components (`VibrantGlassCard`, `GlowBadge`, `AnimatedXpBar`, `PulsingAuraAvatar`).

---

## [1.4.0] — 2026-09-18

### Phase 1.4: AI Command Omnibar & Immersive Focus Experience

- **AI Command Omnibar (Cmd+K / Spotlight)**:
  - Global spotlight modal with keyboard shortcut support (`Cmd+K` on macOS, `Ctrl+K` on Windows/Linux) and Dashboard header trigger.
  - Natural language scheduling actions: `shift` (push/pull tasks after a time threshold), `clearWindow` (evacuate conflicting tasks), `quickAdd` (rapid task creation with duration/priority), `findFit` (find tasks under X minutes), and `startFocus` (instant focus session).
  - Safety boundary: `CommandPreview` generates an actionable preview card showing old vs new timestamps with confirm/cancel before applying schedule mutations.
  - Instant heuristic parser for offline execution + LLM structured JSON completion for complex instructions.
- **Immersive Focus Mode Engine**:
  - Fullscreen distraction-free focus screen (`FocusModeScreen`) with animated radial countdown timer.
  - Pause/resume controls, on-the-fly flow extensions (+5m, +15m), and distraction scratchpad sheet.
  - 60fps custom canvas confetti celebration emitter with tactile haptic feedback.
  - Dynamic actual time spent tracking automatically saved into `TaskItem.actualDurationMinutes`.
- **"What Should I Do Now?" Smart Action Hero Card**:
  - Evaluates active focus session, current time, upcoming task window, user energy levels, and priority.
  - Embedded prominently on Dashboard with instant "Start Focus" CTA.
- **Tactile Sensory Feedback**:
  - Coordinated haptic impact on task completion, duration chips, and command execution.

---

## [1.3.0] — 2026-09-18

### Phase 1.3: Personal Intelligence & Duration Learning

- **Duration Variance Learning Engine**:
  - Created `DurationLearningService` tracking historical ratio $\text{actualDuration} / \text{estimatedDuration}$ clamped to $[0.5, 2.5]$.
  - Aggregates rolling average multipliers per category/tag to counteract human planning fallacies.
- **Dynamic Scheduler Duration Calibration**:
  - Injected learned multipliers into `SchedulerService.scheduleDayWithDetails()` to dynamically expand/compress task durations before slot placement.
  - Added explainability factor (`Duration calibrated from Xm to Ym (+Z% history)`) in placement rationales.
- **Productivity Health & Planning Debt UI**:
  - Built `ProductivityHealthCard` embedded in Analytics and Dashboard.
  - Displays Schedule Accuracy Index (SAI) percentage, Planning Debt minutes, and over/under estimation trends.
- **Domain & Schema Backward Compatibility**:
  - Expanded `TaskItem` Hive adapter with fields 23–25 (`actualDurationMinutes`, `completedAt`, `focusSessionsCount`) with default fallbacks for older boxes.

## [1.2.0] — 2026-09-17

### Phase 1.2: Smart Scheduling Engine & UI Integration

- **Task Constraints & Domain Expansion**: Added Hive fields 12–22 to `TaskItem` (`deadline`, `earliestStart`, `latestFinish`, `isFixed`, `energyLevel`, `preferredTimeOfDay`, `splittable`, `preferredBlockMinutes`, `dependsOnTaskIds`, `linkedProjectId`, `parentTaskId`) with complete backward compatibility.
- **Task Dependencies Directed Acyclic Graph (DAG)**: Created `DependencyGraphService` with Kahn's algorithm for topological sorting and cycle detection, guaranteeing dependent tasks start strictly after prerequisite tasks finish.
- **Task Splitting Engine**: Decomposes long tasks (`splittable == true`) into discrete focus blocks with restorative transition breaks.
- **Immovable Anchors**: Fixed tasks (`isFixed: true`) anchor their specified time slot, causing other tasks to schedule around them.
- **Multi-Factor Planning Score**: Optimized candidate slot selection considering priority, deadline urgency, goal alignment, energy level, preferred time of day, and context switching.
- **Schedule Explainability**: Introduced `ScheduleResult`, `TaskPlacementRationale`, and `ScheduleWarning` providing transparent factor breakdowns for every scheduled task.

#### Phase 1.2 UI Integration (2026-09-17)
- **Advanced Scheduling Panel**: Added collapsible "Advanced scheduling ›" `ExpansionTile` to the Task Edit sheet exposing all Phase 1.2 constraint fields: deadline date-time picker, earliest start / latest finish pickers, fixed time slot toggle (📌), energy level chip selector (🔋/⚡/🔥), preferred time of day chips (🌅/☀️/🌙), and allow-splitting toggle with configurable block size. Shows an "Active" badge when any constraint is set.
- **`scheduleDayWithDetails` Integration**: "Plan My Day" flow now calls `SchedulerService.scheduleDayWithDetails` instead of the legacy `scheduleDay` wrapper, fully activating the multi-factor DAG-aware scheduler.
- **Schedule Warning Banner**: Dismissible amber banner displayed after planning when `ScheduleWarning` entries are present, with per-code icons (deadline exceeded 🔴, no slot available 🟠, cycle detected 🔵) and unplaced task count.
- **"Why Here?" Rationale Sheet**: Each task card displays an ℹ️ icon (after AI scheduling) that opens a `_ScheduleRationaleSheet` bottom sheet showing assigned time, planning score progress bar, and the full factor list used by the multi-factor scorer.
- **`scheduleRationaleProvider`**: New Riverpod `NotifierProvider<Map<String, TaskPlacementRationale>>` in `providers.dart` persists rationale across widget rebuilds, cleanly bridging `_PlanMyDaySheetState` → `_TaskRow` without prop-drilling.

---

## [1.1.0] — 2026-09-09 (Current Approved Baseline)

### Phase 1.1: Reliability & Hardening

#### Group A — Reliability & Safety
- **Offline AI Queue Dispatcher**: Intercepts AI requests when offline or upon network errors, persists them in encrypted Hive storage, and automatically drains on reconnect with exponential backoff and max 5 retry attempts. Permanent failures prevent retry loops.
- **Google Calendar Incremental Sync**: Full implementation of Google Calendar REST API v3 `syncToken` flow with pagination support, atomic token persistence, deleted event removal (`status == 'cancelled'`), and 410 Gone full-resync recovery.
- **Safe Hive Recovery with Backups**: Corrupted Hive boxes or encryption mismatches trigger a timestamped forensic backup (`.corrupt.<timestamp>.bak`) before resetting the box, ensuring user data is never silently destroyed.
- **AI Structured-Output Validation**: Introduced `AIValidator` domain and schema boundary. Strictly enforces task priority bounds (0–3), duration bounds (15–480 min), `HH:mm` time formatting, and non-empty titles.

#### Group B — Testability & Startup Architecture
- **Clock Abstraction & Scheduler Tests**: Promoted `clock: ^1.1.3` to direct dependency. Replaced `DateTime.now()` with `clock.now()` in `SchedulerService` boundaries. Added 16 deterministic behavioral tests across morning, mid-day, near end-of-day, post-work-hours extension (23:59), blocked calendar days, and occupied intervals.
- **AppBootstrapper Startup Consolidation**: Created `AppBootstrapper` (`lib/core/bootstrap/app_bootstrapper.dart`) consolidating 200+ lines of raw init logic into a single deterministic sequence returning root `ProviderContainer`. Refactored `main.dart` while preserving the background Workmanager `callbackDispatcher` isolate.

#### Group C — Quality & Documentation
- **CI Quality Gate**: Configured GitHub Actions workflow (`.github/workflows/ci.yml`) enforcing Java 17 setup, formatting checks, static analysis with `--fatal-infos`, full test suite execution with coverage, and debug APK build verification.
- **Documentation Updates**: Updated `docs/README.md` and `docs/ARCHITECTURE.md` to reflect the hardened architecture, startup lifecycle, and testing models.

---

## [1.0.0] — 2026-05-27

### Initial Production Release

#### Core Features
- AI-powered task scheduling with Gemini API integration
- Natural-language Brain Dump — capture tasks and let AI organise them
- Daily planner with drag-and-drop rescheduling
- Goal tracking with milestone decomposition
- Notes with AI summarisation
- Projects workspace for multi-task groupings
- Weekly review and analytics dashboard
- Morning briefing — daily AI summary at a configurable time
- Offline AI queue — requests queued when offline and drained on reconnect

#### Platform & Infrastructure
- Hive local persistence (no cloud dependency by default)
- Google Calendar two-way sync
- Google Sign-In OAuth
- Biometric app lock (Face ID / fingerprint)
- Local push notifications with exact-alarm scheduling
- Android home-screen widget (today's task count)
- Encrypted backup / restore (export to file, import from file)
- Token usage tracker with configurable daily cap

#### Quality
- 364 unit tests, 0 analyzer issues
- ProGuard minification + resource shrinking on Android release builds
- Dart obfuscation with split debug symbols on release builds
- ErrorBoundary wired at app root for graceful crash recovery
- Connectivity banner for offline awareness
