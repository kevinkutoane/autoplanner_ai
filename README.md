# AutoPlanner AI

> **AI-powered daily planner for Android & iOS** — turn a stream-of-consciousness brain dump into a fully scheduled, priority-scored day in seconds.

[![Flutter](https://img.shields.io/badge/Flutter-%5E3.8.1-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%5E3.8.1-0175C2?logo=dart)](https://dart.dev)
[![AI Engine](https://img.shields.io/badge/AI-Gemini%202.5%20Flash-4285F4?logo=google)](https://aistudio.google.com)
[![Tests](https://img.shields.io/badge/Tests-449%20Passing-brightgreen)](test/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Version:** 1.2.0 · **Target Platforms:** Android & iOS · **State:** Riverpod · **Persistence:** Encrypted Hive (AES-256)

---

## 📚 Documentation Directory

Explore the technical and architectural documentation:

| Document | Purpose |
| --- | --- |
| 🏗️ [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Structural overview, unified startup lifecycle, constraint scheduling engine, and data flows |
| 📋 [PHASE_1_2_SPEC.md](docs/PHASE_1_2_SPEC.md) | Technical specification and verification details for the Smart Scheduling Engine |
| 🗺️ [ROADMAP.md](docs/ROADMAP.md) | Strategic product & engineering roadmap from Phase 1.1 to 2.0 |
| 📜 [CHANGELOG.md](docs/CHANGELOG.md) | Full release notes and historical change record |
| 🤝 [CONTRIBUTING.md](docs/CONTRIBUTING.md) | Developer guidelines, coding standards, test instructions, and PR checklist |

---

## ✨ Features

### Core Productivity
- **🧠 Brain Dump** — paste or speak anything on your mind; AI classifies it into tasks, notes, and long-term memories in real time with streaming output.
- **⚡ AI Task Parser** — natural language → structured tasks with start time, realistic duration, and priority (Low / Medium / High / Urgent).
- **🛡️ AI Output Validation** — strict schema and domain validation boundary (`AIValidator`) preventing malformed or out-of-bounds LLM outputs from polluting state.
- **🎯 Goals & Projects** — structure your life's ambition by linking tasks, notes, and events directly to larger objectives and project containers.
- **📝 Notes with Action Items** — rich editor with AI-generated summaries, auto-tags, and action-item extraction directly into the planner.
- **🔗 Relational Linking** — bidirectional links between tasks and notes surfaced directly in task sheets and note editors.
- **🔍 Global Search** — lightning-fast search across tasks, notes, calendar events, goals, and projects.
- **💡 Memory System** — persistent AI memory extracted from your tasks, notes, and brain dumps; automatically fed back as context on future AI calls.
- **📅 Calendar Timeline** — visual day/week timeline synced with task changes in real time.
- **📊 Analytics & Dashboard** — daily AI insight card, token usage meter, streak tracker, and 3-tab insights with `fl_chart` visualisations + weekly AI review.

### 🧩 Intelligent Scheduling Engine (Phase 1.2)
- **Multi-Factor Planning Score**: Deterministic slot-evaluation factoring priority, deadline urgency (exponential escalation), goal alignment, energy level, preferred time of day, and context switching penalties.
- **Directed Acyclic Graph (DAG) Task Dependencies**: Tasks declare dependencies (`dependsOnTaskIds`); Kahn's algorithm resolves topological order and safely breaks cycles with diagnostics.
- **Task Splitting Engine**: Large focus tasks (`splittable: true`) break down into configurable blocks with restorative buffer breaks.
- **Hard Temporal Constraints**: Full support for deadlines, earliest start times, latest finish times, and fixed time anchors (`isFixed`).
- **Explainable Planning ("Why Here?")**: Interactive inspection sheet displaying planning score progress and transparent factor reasoning for every scheduled item.
- **Proactive Rescheduling**: Detects overdue tasks upon app resume and suggests optimal replacement slots from the remaining work window.

### 🌐 Integrations & Offline Resilience
- **Google Calendar Sync** — bidirectional sync via Google Calendar REST API v3 with OAuth sign-in, official `syncToken` incremental change-tracking, etag-based conflict detection, and background periodic sync via Workmanager.
- **Offline AI Queue** — persistent queue backed by encrypted Hive storage; catches operations when offline or when network errors occur and drains automatically on reconnect with exponential backoff.
- **Notifications** — timezone-aware local reminders 10 minutes before each task via `flutter_local_notifications`.
- **Home Screen Widget** — top-3 upcoming tasks + completion stats pushed to Android/iOS home widget.
- **Crash Reporting & Diagnostics** — Sentry integration logs Flutter errors and isolate exceptions.

---

## 🛠️ Tech Stack

| Layer | Technology |
| --- | --- |
| **UI** | Flutter 3 + Material 3 (custom brand palette, animated orb backgrounds) |
| **State** | Riverpod (`NotifierProvider`, `Provider`, root `ProviderContainer`) |
| **Persistence** | Hive — AES-256 encrypted via OS keychain key with safe corruption recovery |
| **Startup** | `AppBootstrapper` unified initialization orchestrator |
| **AI** | Google Gemini 2.5 Flash (`google_generative_ai`) with streaming support |
| **Scheduling** | Pure-Dart deterministic constraint solver & DAG packer (`SchedulerService` with `clock`) |
| **Calendar Sync** | Google Calendar REST API v3 (`syncToken` incremental sync + OAuth) |
| **Background** | `workmanager` periodic tasks (Android/iOS) |
| **Notifications** | `flutter_local_notifications` + `timezone` |
| **Charts** | `fl_chart` (analytics trends, tag distributions) |
| **Voice Input** | `speech_to_text` (Brain Dump dictation) |
| **Diagnostics** | `sentry_flutter` |
| **Security** | `flutter_secure_storage` + `local_auth` (biometrics) |

---

## 🔐 Security & Privacy

- **Hive encrypted at rest**: A 32-byte AES key is generated on first install and stored in the Android Keystore / iOS Secure Enclave via `flutter_secure_storage`. All boxes use `HiveAesCipher`.
- **Corrupted box recovery**: If a box fails decryption or encounters file corruption, a timestamped `.corrupt.<timestamp>.bak` file is created before the box is cleanly re-opened, preventing unrecoverable data destruction.
- **API key in OS keychain**: The user's Gemini API key is stored via `flutter_secure_storage`, never written to Hive or bundled assets. Google OAuth tokens are also persisted in the secure keychain.
- **Biometric lock**: Optional fingerprint / Face ID gate on cold launch and every time the app resumes from background.
- **Prompt injection mitigation**: All user-supplied strings are sanitised (triple-quote sequences neutralised, null bytes stripped) before being interpolated into AI prompts.

---

## 🚀 Getting Started

### Prerequisites

- Flutter `>=3.8.1`
- Dart `>=3.8.1`
- Java 17 (for Android build tools)
- A [Google AI Studio](https://aistudio.google.com) API key (free tier works) or run in Mock AI mode

### Setup & Run

```bash
# 1. Clone repository
git clone https://github.com/kevinkutoane/autoplanner_ai.git
cd autoplanner_ai

# 2. Copy environment template
cp .env.example .env          # add your GEMINI_API_KEY if available

# 3. Install packages
flutter pub get

# 4. Launch app
flutter run
```

On first launch the onboarding walkthrough introduces the app. You can update your Gemini API key anytime via **Settings → AI Settings → Gemini API key** or enable **Mock AI** to develop offline.

### Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `GEMINI_API_KEY` | (optional) | Google AI Studio API key — enter in `.env` or in **Settings → AI Settings** |
| `ENV` | `prod` | Environment: `dev` / `staging` / `prod` |
| `USE_MOCK_AI` | `false` | Use canned deterministic AI responses (no network token usage) |
| `SENTRY_DSN` | (optional) | Sentry DSN for crash reporting |

---

## 🧪 Testing & Quality Assurance

Quality checks run automatically via GitHub Actions CI on every pull request:

```bash
# Static analysis (enforces zero issues)
flutter analyze --fatal-infos

# Run full test suite (449 passing tests across 24 test suites)
flutter test

# Run scheduler behavioral and constraint tests with clock abstraction
flutter test test/scheduler_service_test.dart test/dependency_graph_service_test.dart

# Build verification
flutter build apk --debug
```

---

## 📦 Project Structure

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
│   ├── planner/                       # Constraint scheduler, task reordering, explainability UI
│   ├── projects/                      # Project management views
│   ├── search/                        # Unified global search interface
│   └── settings/                      # Preferences, theme, connections
│
└── services/
    ├── ai_service.dart                # Sanitized AI calling with exponential back-off
    ├── app_monitor_service.dart       # Event & error monitoring
    ├── calendar_sync_service.dart     # Bidirectional Google sync engine with syncTokens
    ├── dependency_graph_service.dart  # DAG resolution, cycle breaking, and topological sort
    ├── memory_service.dart            # Encrypted persistent memory layer
    ├── offline_ai_queue.dart          # Persistent offline request queue & dispatcher
    ├── scheduler_service.dart         # Pure-Dart deterministic constraint & scoring engine
    └── ...                            # (Auth, Notification, Backup, Key Management, etc.)
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
