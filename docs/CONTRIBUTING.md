# Contributing to AutoPlanner AI

Thank you for contributing to AutoPlanner AI! This guide details everything you need to set up your local development environment, adhere to core architectural guidelines, run tests, and submit high-quality contributions.

---

## 1. Development Setup

### Prerequisites
- **Flutter SDK**: `>=3.8.1` (tested with 3.8.1 / 3.47.2 channel)
- **Dart SDK**: `>=3.8.1`
- **JDK**: Java 17 (required for Android Gradle builds)
- **Google AI Studio Key**: Optional for local development; you can toggle `USE_MOCK_AI=true`.

### Initial Setup

```bash
# 1. Clone repository
git clone https://github.com/kevinkutoane/autoplanner_ai.git
cd autoplanner_ai

# 2. Configure environment
cp .env.example .env

# 3. Install Flutter dependencies
flutter pub get

# 4. Run static analysis
flutter analyze lib test --fatal-infos

# 5. Run test suite
flutter test
```

### Mock AI vs. Real Gemini AI
To develop offline or without consuming Gemini API tokens:
- Set `USE_MOCK_AI=true` in your `.env` file, or
- Enable **Mock AI** inside the app via **Settings → AI Settings → Mock AI**.
`MockAIProvider` provides deterministic canned responses for task parsing, day planning, and note summaries.

---

## 2. Core Architectural Principles

When modifying or adding code, adhere strictly to our architectural rules:

1. **Deterministic Scheduling Engine**:
   - **Never call `DateTime.now()` directly in scheduling boundaries.** Always use `clock.now()` from `package:clock` so all scheduling decisions remain 100% deterministically testable across all time horizons.
   - All temporal constraints (`deadline`, `earliestStart`, `latestFinish`, `isFixed`) must be respected by `SchedulerService.scheduleDayWithDetails`.
   - Directed Acyclic Graph (DAG) dependencies must route through `DependencyGraphService`. Never allow circular dependencies to stall or crash the planner.

2. **Centralized Riverpod Providers**:
   - Every shared service, controller, or persistent provider resides in `lib/core/providers/providers.dart`.
   - Do not define ad-hoc global providers scattered across arbitrary feature directories.

3. **Domain Boundary & AI Output Validation**:
   - All raw text from LLMs must pass through `AIValidator` before being persisted or applied to application state.
   - Enforce domain boundaries: priority must be 0–3, duration 15–480 minutes, valid `HH:mm` format, non-empty titles.
   - Sanitise prompt strings (strip null bytes and mitigate prompt injections) before sending to Gemini.

4. **Encrypted Local Storage (Hive)**:
   - All Hive boxes are AES-256 encrypted at rest using keys derived from the OS Keychain / Secure Storage.
   - When introducing new fields to existing models (`TaskItem`, `NoteItem`, etc.), append them with new `@HiveField(n)` indexes with default fallback values in constructors to preserve backward compatibility.
   - Never remove or re-index existing `@HiveField` numbers.

5. **Safe Startup Lifecycle**:
   - All initialization routines (Hive registration, key derivation, services, Workmanager dispatcher) are coordinated by `AppBootstrapper.init()`.

---

## 3. Testing & Verification

Every pull request must pass the automated CI pipeline. Before pushing changes, verify locally:

```bash
# 1. Format code according to Dart conventions
dart format --output=none --set-exit-if-changed .

# 2. Run static analysis (must report zero issues)
flutter analyze --fatal-infos

# 3. Run the full test suite
flutter test

# 4. Run targeted scheduler tests
flutter test test/scheduler_service_test.dart test/dependency_graph_service_test.dart
```

### Writing New Tests
- **Unit Tests**: Place in `test/` mirroring the `lib/` structure (e.g. `test/dependency_graph_service_test.dart`).
- **Scheduler Behavioral Tests**: Use `withClock(Clock.fixed(customTime), () { ... })` to verify scheduling behavior across boundary conditions (morning, midday, post-work-hours extension, weekends).
- **Mocking**: Use mock providers (`MockAIProvider`) rather than live network calls in unit tests.

---

## 4. Documentation & Changelog

- If your change introduces new features, updates schemas, or modifies workflows, update:
  - `docs/ARCHITECTURE.md` (if structural or lifecycle changes are made)
  - `docs/ROADMAP.md` (if milestone progress is affected)
  - `docs/CHANGELOG.md` (under `## [Unreleased]`, following Keep a Changelog conventions)
  - `README.md` (if top-level developer instructions or capabilities change)

---

## 5. Pull Request Checklist

Before submitting a pull request, ensure:
- [ ] Code is formatted with `dart format .`
- [ ] `flutter analyze --fatal-infos` produces **zero** issues (no errors, no warnings, no infos)
- [ ] `flutter test` passes all tests (currently 503/503 passing)
- [ ] New code is covered by automated unit/integration tests
- [ ] `docs/CHANGELOG.md` is updated
- [ ] Commit messages are clear and follow conventional commit syntax (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`).
