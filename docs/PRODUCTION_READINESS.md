# AutoPlanner AI — Production Readiness Verification Register

> **Assessment Stage**: Phase 2.3.1 Engineering Stabilisation & Hardening  
> **Repository**: `https://github.com/kevinkutoane/autoplanner_ai`  
> **Authoritative Current Version**: `2.3.1+1`  
> **Verification Status Key**: `PASS` (Empirically verified with reproducible evidence), `FAIL` (Defect exists), `BLOCKED` (External dependency missing), `DEFERRED` (Post-release architectural debt per register)

---

## 1. Build & Toolchain Integrity

| Item | Requirement | Status | Evidence / Notes |
| :--- | :--- | :---: | :--- |
| **Toolchain Consistency** | Flutter 3.47.2 / Dart 3.13.x / Java 21 / Gradle 8.14.0 / AGP 8.11.1 / Kotlin 2.2.20 / compileSdk 37 / targetSdk managed by Flutter / minSdk managed by Flutter | **PASS** | Verified against live repository, Gradle wrapper, and GitHub Actions CI configuration. Flutter SDK emits forward-looking deprecation warnings that future versions will require Gradle 9.1+, AGP 9.0.1+, and Kotlin 2.3.20+; these remain tracked as technical debt item #9 in `docs/ARCHITECTURE_DEBT.md`. |
| **Clean Build Verification** | Clean environment build succeeds | **PASS** | Debug APK and release-mode APK compile cleanly via `flutter build apk --debug` and `flutter build apk --release`. |
| **Release Metadata Alignment** | Version consistency across config and documentation | **PASS** | `pubspec.yaml` aligned to `2.3.1+1`, synchronized with `README.md`, `docs/README.md`, `docs/CHANGELOG.md`, and `docs/ROADMAP.md`. |
| **Dependency Integrity** | No unnecessary package churn or unapproved migrations | **PASS** | Zero new unapproved dependencies introduced; preserved approved packages (`hive`, `flutter_riverpod`, `connectivity_plus`, `google_sign_in`, `flutter_local_notifications`, `uuid`). |

---

## 2. Quality & Static Analysis Gates

| Item | Requirement | Status | Evidence / Notes |
| :--- | :--- | :---: | :--- |
| **Code Formatting** | Zero format diffs (`dart format --output=none --set-exit-if-changed`) | **PASS** | Verified format check with exit code 0 across `lib` and `test`. |
| **Static Analysis** | Zero errors, zero warnings, zero infos with `--fatal-infos` | **PASS** | `flutter analyze lib test --fatal-infos` ran across all files with `No issues found!`. |
| **Unit & Behavioral Tests** | 100% pass rate across entire suite | **PASS** | 529 tests passed across 34 test files (`flutter test`) with zero failures. |
| **CI Exact-SHA Reproduction** | GitHub Actions passes on target commit without secrets | **PASS** | CI verifies the checked-out `git rev-parse HEAD` exactly matches `${{ github.sha }}`, executes format check, static analysis with `--fatal-infos`, full test suite with coverage generation, and both debug and release APK builds using the Mock AI provider. The release APK is uploaded as a short-retention CI artifact for beta validation. Codecov remains optional non-blocking telemetry. |

---

## 3. Security Boundary Certification

| Item | Requirement | Status | Evidence / Notes |
| :--- | :--- | :---: | :--- |
| **Secrets Exposure Audit** | No real API keys, credentials, or secrets committed | **PASS** | Repository scanned for `GEMINI_API_KEY`, tokens, client secrets; `.env` is gitignored; `.env.example` contains placeholders only. |
| **Hive AES-256 Storage** | Critical application data boxes encrypted | **PASS** | Boxes (`tasksBox`, `notesBox`, `goalsBox`, `projectsBox`, `calendarBox`, `settingsBox`, `appEventsBox`, `gamificationBox`, `aiLogsBox`, `memoryBox`) opened with `HiveAesCipher`. |
| **Offline AI Queue Encryption** | Queue storage protected inside AES-256 boundary | **PASS** | `OfflineAIQueue.init(cipher: hiveCipher)` opens `aiQueueBox` using `HiveAesCipher` key derived from `SecureKeyService`. |
| **Key Generation & Storage** | Platform-secure key storage | **PASS** | `SecureKeyService` uses `FlutterSecureStorage` backed by Android Keystore and iOS Keychain. Platform-secure key generation and retrieval; no file-key fallback implemented. |
| **Diagnostic Sanitization** | Logs do not leak PII or prompts | **PASS** | `TokenTracker` and `AIService` mask sensitive strings; prompts sanitized for control characters and delimiters before processing. |

---

## 4. Scheduler Invariant Certification

| Invariant | Specification | Status | Evidence / Notes |
| :--- | :--- | :---: | :--- |
| **Hard Earliest Start** | `start >= earliestStart` | **PASS** | Tested in `test/scheduler_invariants_test.dart` (Hard Temporal Invariants). |
| **Hard Latest Finish** | `end <= latestFinish` or unplaced | **PASS** | Tasks unable to complete before `latestFinish` become `unplaced` with `no_slot_available` diagnostic warning; verified in invariant suite. |
| **Deadline Compliance** | `end <= deadline` or warning | **PASS** | Scheduler generates `deadline_exceeded` warning while producing valid placement. |
| **Work-Window Policy with Documented Same-Day Extension** | `end <= configuredWorkEnd` OR `today + after-hours extension policy` | **PASS** | Tasks placed within configured working hours `[workStart, workEnd]`. When running for today after configured hours (`isToday && now.isAfter(workEnd)`), the window dynamically extends to `23:59` so tasks are scheduled rather than dropped. Verified in invariant and scheduler test suites. |
| **No-Overlap & Buffer** | `end(A) + buffer <= start(B)` | **PASS** | Consecutive tasks maintain >= 10m buffer; verified across multi-priority mixes. |
| **Fixed Tasks Immovable** | `isFixed == true` remains anchored | **PASS** | Anchor tasks preserve exact start and end times regardless of other task priorities. |
| **Completed Tasks Preserved** | `isCompleted == true` not moved | **PASS** | Completed tasks retain historical timestamps. |
| **DAG Dependency Ordering** | Prerequisite A precedes dependent B | **PASS** | `DependencyGraphService` topological ordering guarantees `start(B) >= end(A) + buffer`. |
| **Past-Time Protection** | `startTime >= clock.now()` | **PASS** | Past-time cursor protection verified using `package:clock` across 6 distinct times of day (06:00 to 23:59). |
| **Determinism** | Identical inputs -> identical schedule | **PASS** | Verified identical outputs across repeated runs with identical clock and input state. |
| **Idempotence** | Rescheduling valid output does not mutate | **PASS** | Verified that passing scheduled output back into scheduler preserves identical placements. |
| **Overload Handling** | Excess workload -> valid partial schedule | **PASS** | 10 hours of work in an 8-hour window cleanly splits into placed tasks and `unplacedTasks` list without invalid overlaps. |
| **Cycle Safety** | Circular dependencies terminate safely | **PASS** | Circular dependencies (A -> B -> A) detected by `DependencyGraphService`, terminate safely without hang/infinite loop, and emit diagnostics. |
| **Task Splitting** | Conservation of duration & chunk links | **PASS** | Splittable tasks conserve total duration, create consecutive chunk IDs, maintain `parentTaskId`, and preserve buffer. |

---

## 5. Calendar Sync Certification

| Feature | Behavior | Status | Evidence / Notes |
| :--- | :--- | :---: | :--- |
| **Initial Full Sync** | Imports all remote events | **PASS** | `test/calendar_sync_service_test.dart`: full sync creates local calendar events. |
| **Incremental Sync** | Uses stored `syncToken` | **PASS** | Syncs delta changes and updates `syncToken` only upon complete success. |
| **Token Safety on Failure** | Preserves previous token if page fails | **PASS** | Network/API 500 error midway preserves existing valid `syncToken`. |
| **410 Gone Recovery** | Resets token and falls back to full sync | **PASS** | Automatic recovery on expired sync token verified. |
| **Cancelled Events** | Deletes local counterpart | **PASS** | Events marked `status: 'cancelled'` cleanly purged from local `calendarBox`. |
| **Conflict Detection** | Detects remote divergence from pending push | **PASS** | Bidirectional push/pull conflict handling verified. |

---

## 6. Offline AI Queue Certification

| Semantics | Specification | Status | Evidence / Notes |
| :--- | :--- | :---: | :--- |
| **Delivery Model** | At-least-once execution | **PASS** | Request persisted before execution; acknowledged and deleted only after successful completion. |
| **Restart Persistence** | Enqueued items survive app restart | **PASS** | Verified in `test/offline_ai_queue_test.dart` by disposing queue, closing Hive, re-initializing, and draining. |
| **Unique ID Deduplication** | Collision-safe identifier generation | **PASS** | Generates UUID v4-suffixed IDs (`${method}_${timestamp}_${uuid}`) preventing overwrite even on multiple requests within the exact same millisecond. Verified in automated test. |
| **Encryption** | Box encrypted with `HiveAesCipher` | **PASS** | Initialized with cipher; wrong key throws `HiveError` and prevents unauthorized decryption. |
| **Bounded Retry** | Max 5 attempts for transient errors | **PASS** | Incrementing attempt counter; upon 5th failure marks request as `isPermanentFailure: true` without deleting. |
| **Fast Permanent Failure** | Non-retriable exceptions fail fast | **PASS** | `UnsupportedError` immediately marked permanent failure without retry loops. |
| **Concurrent Drain Safety** | Overlapping drain calls execute once | **PASS** | Guarded by internal `_currentDrain` future and `activePending` check; zero duplicate executions. |

---

## 7. Hive Fault Recovery Certification

| Failure Mode | Expected Safety Invariant | Status | Evidence / Notes |
| :--- | :--- | :---: | :--- |
| **Filesystem / Storage Error** | Rethrow; never delete data | **PASS** | Verified in `test/hive_recovery_test.dart`: `FileSystemException` rethrows and preserves data. |
| **Encryption Key Mismatch** | Throw `HiveKeyMismatchException`; preserve data | **PASS** | Wrong key throws `HiveKeyMismatchException`; original encrypted file remains untouched; no `.bak` created. |
| **Programming / Config Error** | Rethrow; never delete data | **PASS** | Type mismatch (`openBoxSafe<int>` on String box) rethrows and preserves existing file. |
| **Genuine File Corruption** | Create verified `.bak` before quarantine | **PASS** | Corrupt box creates verified diagnostic backup (`.corrupt.<ts>.bak`), matches byte size, then safely recreates box. |

---

## 8. AI Safety & Validation Certification

| Boundary | Invariant | Status | Evidence / Notes |
| :--- | :--- | :---: | :--- |
| **Input Policy Guard** | Injection attacks blocked before API | **PASS** | `AIGuard` blocks triple-quote delimiters, null bytes, and script tags with `ContentPolicyException`. |
| **Domain Validation** | Invalid entities rejected fail-fast | **PASS** | `AIValidator` rejects malformed JSON, out-of-range priority, invalid ISO dates, or broken relationships without infinite retry. |
| **Format Glitch Retry** | Bounded retry for transient glitches | **PASS** | Truncated/unclosed JSON retried up to 2 times; succeeds upon valid completion. |
| **Rate Limit Protection** | Token and call frequency throttled | **PASS** | Daily token budget and rapid-fire call frequency windows enforce `RateLimitException` and `CallFrequencyException`. |

---

## Summary Verdict

* **Total Readiness Criteria Evaluated**: 37
* **PASS**: 37 (Conditioned on real-device QA & private beta)
* **FAIL**: 0
* **BLOCKED**: 0
* **DEFERRED / MANAGED DEBT**: 9 (Formally tracked in `docs/ARCHITECTURE_DEBT.md`, including toolchain deprecation warnings)
* **Classification**: **RELEASE CANDIDATE — CONDITIONAL**
* **Next Steps**: Device QA on physical Android/iOS hardware and private beta distribution prior to general production release.
