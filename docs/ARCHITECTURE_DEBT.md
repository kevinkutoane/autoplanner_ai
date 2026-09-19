# AutoPlanner AI — Architectural Debt Register

This register documents known architectural debt, design trade-offs, and structural limitations identified during the Phase 2.3.1 Production Readiness & Engineering Stabilisation audit.

> **Policy**: Recording an item here explicitly acknowledges it as **non-blocking for Release Candidate**, but prioritised for post-2.3 refactoring. Items are **not** marked resolved merely by being documented. Feature development was frozen to protect release stability rather than executing speculative rewrites.

---

## 1. AIService God Object

* **Category**: Single Responsibility Principle / Modularity
* **Problem**: `lib/services/ai_service.dart` exceeds 1,200 lines and contains prompt engineering, response parsing, validation, fallback handling, retry policy, and command parsing for multiple distinct functional domains (`parseTasks`, `brainDump`, `generateTags`, `summarizeNote`, `suggestReschedule`, `generateDailyInsight`, `planDay`, `extractMemoryFromContext`, `extractPatterns`, `parseScheduleCommand`).
* **Impact**: High cognitive load for maintainers; tight coupling between unrelated AI capabilities; difficult to mock single features independently.
* **Risk**: High risk of regression when modifying shared retry or fallback logic; merge conflicts across feature teams.
* **Future Direction**: Decompose into domain-scoped sub-services behind a lightweight facade:
  - `TaskParsingAIService`
  - `BrainDumpAIService`
  - `CoachingAIService`
  - `RescheduleAIService`
  - `CommandParsingAIService`
* **Why Deferred**: Core AI validation, prompt guards, and retry bounds were fully hardened and covered by 38 automated tests. Refactoring class hierarchies now would introduce regression risk without improving release correctness.

---

## 2. AppBootstrapper Monolith

* **Category**: Startup Orchestration / Separation of Concerns
* **Problem**: `lib/core/bootstrap/app_bootstrapper.dart` handles environment variable loading, Hive initialization, 10 TypeAdapter registrations, secure key generation, safe box opening with diagnostic backup, notification service startup, morning briefing restoration, Google Auth session restoration, ProviderContainer creation, and offline queue initialization.
* **Impact**: Startup sequence is hard to isolate in unit tests without extensive mocking. Differences between foreground startup and background Workmanager startup require careful guards.
* **Risk**: Accidental addition of UI-dependent plugins to the bootstrapper could crash background isolates.
* **Future Direction**: Split into modular initialization steps (`StorageInitializer`, `SecurityInitializer`, `ServiceInitializer`, `BackgroundIsolateBootstrapper`) coordinated by a declarative startup pipeline.
* **Why Deferred**: Deterministic startup ordering and safe box opening (`openBoxSafe`) were audited, certified, and proven across 4 failure modes in automated tests.

---

## 3. Centralized `providers.dart` Service Locator

* **Category**: Dependency Injection / State Architecture
* **Problem**: `lib/core/providers/providers.dart` defines over 30 Riverpod providers and StateNotifiers in a single global file. Several providers access singletons directly (e.g. `Hive.box`, `NotificationService()`, `AIService()`).
* **Impact**: Hidden dependency graph; harder to substitute fakes in widget tests without overriding multiple global providers.
* **Risk**: Low in production, but increases test setup boilerplate and accidental cross-feature leakage.
* **Future Direction**: Co-locate feature providers within their respective feature directories (`features/focus/providers/`, `features/planner/providers/`) and use formal constructor injection for services.
* **Why Deferred**: App state behavior is stable and all Riverpod notifiers pass current test suites. Migrating DI patterns violates the strict Phase 2.3.1 scope rule.

---

## 4. Giant UI Screen Widgets

* **Category**: UI Architecture / Maintainability
* **Problem**: Several primary screen widgets exceed recommended size limits and mix presentation with business orchestration:
  - `lib/features/coach/screens/ai_coach_screen.dart` (~1,400 lines)
  - `lib/features/dashboard/screens/dashboard_screen.dart` (~1,000 lines)
  - `lib/features/planner/screens/planner_screen.dart` (~800 lines)
* **Impact**: Rebuilding larger widget trees than necessary; difficulty in unit-testing UI presentation state without full widget harness.
* **Risk**: Accidental UI regressions during cosmetic edits; maintenance burden.
* **Future Direction**: Extract atomic components, decompose sheets and modals into dedicated widget files, and isolate view-models using Riverpod `select`.
* **Why Deferred**: The user interface was stabilised and verified on emulator; redesigns or structural UI refactors are strictly out of scope for stabilisation.

---

## 5. UI Layer Mixed with Persistence & Orchestration

* **Category**: Layering / Clean Architecture
* **Problem**: Certain screens and bottom sheets directly call Hive boxes or service methods (`saveTask`, `addMemory`, `updateSettings`) rather than dispatching through unified controllers or domain repositories.
* **Impact**: Inconsistent offline queue bypass if UI directly touches low-level storage; duplicated error handling across sheets.
* **Risk**: Edge-case data inconsistencies if state and disk get out of sync during unhandled UI exceptions.
* **Future Direction**: Implement formal Repository pattern (`TaskRepository`, `MemoryRepository`, `SettingsRepository`) mediating between Riverpod controllers, Hive local storage, and remote services.
* **Why Deferred**: All user flows function reliably and data mutations are safeguarded by Hive transactions. Repository extraction is a Phase 3.0 architectural initiative.

---

## 6. Hard-Coded Scheduler Multi-Factor Scoring Policy

* **Category**: Algorithm Flexibility / Configuration
* **Problem**: `SchedulerService._scoreSlot` uses hard-coded weight constants for scoring candidate slots (e.g., priority weights 1.5, energy alignment weights 1.2, fragmentation penalty -0.8).
* **Impact**: Users or machine-learning models cannot adjust scheduling personality without code modifications.
* **Risk**: Minimal risk to correctness (invariants remain strictly enforced), but prevents user customization of scheduling strategy.
* **Future Direction**: Introduce `SchedulerScoringPolicy` configuration class allowing custom weights, energy profiles, and heuristic tuning.
* **Why Deferred**: The current scoring produces deterministic, high-quality schedules that pass all invariant certifications.

---

## 7. Direct Hive Key-Value Storage vs. Relational/Indexed Engine

* **Category**: Storage Engine Architecture
* **Problem**: Hive stores records as serialized binary blobs. Complex filtering (e.g. finding tasks by tag, date range, and status) requires in-memory scanning of all box entries (`box.values.where(...)`).
* **Impact**: Acceptable for current data scale (< 5,000 tasks/notes), but could cause memory overhead over years of heavy usage.
* **Risk**: High migration risk if attempted prematurely without schema versioning and data migration tooling.
* **Future Direction**: Evaluate SQLite / Drift with encrypted SQLCipher or stay on Hive with secondary indexing maps if memory remains within bounds.
* **Why Deferred**: Explicitly banned in Phase 2.3.1 instructions ("Do not implement: Hive -> SQLite migration").

---

## 8. Absence of Cloud AI Gateway & Cross-Device Synchronization

* **Category**: Infrastructure / Multi-Device Scalability
* **Problem**: AI calls communicate directly with Google Gemini API using local API keys stored in encrypted device storage; task data is strictly local to the device.
* **Impact**: No cross-device sync between phone and tablet/web; user must supply or configure API credentials.
* **Risk**: Users switching devices cannot access tasks unless using manual JSON/encrypted file backup.
* **Future Direction**: Dedicated backend gateway with token rate-limiting, user accounts, and end-to-end encrypted synchronization.
* **Why Deferred**: Explicitly out of scope for Phase 2.3.1 client-first release candidate.

---

## 9. Android Toolchain Forward Compatibility Warnings (Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20)

* **Category**: Build System & Toolchain Maintenance
* **Problem**: Build and CI logs emit forward-looking toolchain deprecation warnings:
  - Flutter SDK warns that future releases will require minimum versions higher than Gradle 8.14, AGP 8.11.1, and Kotlin 2.2.20 (e.g. Gradle 9.1+, AGP 9.0.1+, Kotlin 2.3.20+).
* **Impact**: Zero impact on current builds (clean build exit 0 in local environments and GitHub Actions CI). However, subsequent Flutter framework major upgrades will enforce these minimum requirements.
* **Risk**: Upgrading Gradle, AGP, or Kotlin now risks introducing plugin incompatibilities, breaking changes in Android Gradle Plugin extensions, or JVM bytecode mismatches right before Release Candidate tagging.
* **Future Direction**: Perform a coordinated toolchain migration in Phase 3.0 on a dedicated build-verification branch once upstream Flutter plugins validate compatibility with AGP 9 and Gradle 9.
* **Why Deferred**: Restraint is preserved per principal-engineer review to protect the proven, green CI baseline and prevent unforced dependency churn during release candidate stabilisation.
