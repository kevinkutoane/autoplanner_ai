# Changelog

All notable changes to AutoPlanner AI are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased / In-Tree Preview — Subject to Approval Gate]

### Phase 1.2: Smart Scheduling Engine

- **Task Constraints & Domain Expansion**: Added Hive fields 12–22 to `TaskItem` (`deadline`, `earliestStart`, `latestFinish`, `isFixed`, `energyLevel`, `preferredTimeOfDay`, `splittable`, `preferredBlockMinutes`, `dependsOnTaskIds`, `linkedProjectId`, `parentTaskId`) with complete backward compatibility.
- **Task Dependencies Directed Acyclic Graph (DAG)**: Created `DependencyGraphService` with Kahn's algorithm for topological sorting and cycle detection, guaranteeing dependent tasks start strictly after prerequisite tasks finish.
- **Task Splitting Engine**: Decomposes long tasks (`splittable == true`) into discrete focus blocks with restorative transition breaks.
- **Immovable Anchors**: Fixed tasks (`isFixed: true`) anchor their specified time slot, causing other tasks to schedule around them.
- **Multi-Factor Planning Score**: Optimized candidate slot selection considering priority, deadline urgency, goal alignment, energy level, preferred time of day, and context switching.
- **Schedule Explainability**: Introduced `ScheduleResult`, `TaskPlacementRationale`, and `ScheduleWarning` providing transparent factor breakdowns for every scheduled task.

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
