# AutoPlanner AI

> **AI-powered daily planner for Android & iOS** — turn a stream-of-consciousness brain dump into a fully scheduled, priority-scored day in seconds.

[![Flutter](https://img.shields.io/badge/Flutter-%5E3.8.1-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%5E3.8.1-0175C2?logo=dart)](https://dart.dev)
[![AI Engine](https://img.shields.io/badge/AI-Gemini%202.5%20Flash-4285F4?logo=google)](https://aistudio.google.com)
[![Tests](https://img.shields.io/badge/Tests-528%20Passing-brightgreen)](test/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Version:** 2.3.1 · **Target Platforms:** Android & iOS · **State:** Riverpod · **Persistence:** Encrypted Hive (AES-256)

---

## 📚 Documentation Directory

Explore the technical and architectural documentation:

| Document | Purpose |
| --- | --- |
| 🛡️ [PRODUCTION_READINESS.md](docs/PRODUCTION_READINESS.md) | Release Candidate verification matrix, empirical certification evidence, and quality checklist |
| 🧱 [ARCHITECTURE_DEBT.md](docs/ARCHITECTURE_DEBT.md) | Formally tracked non-blocking architectural debt, impact, risks, and deferral rationale |
| 🏗️ [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Complete system architecture map, runtime data flows, AI safety boundary, and Hive schema |
| 📋 [PHASE_1_2_SPEC.md](docs/PHASE_1_2_SPEC.md) | Technical specification and verification details for the Smart Scheduling Engine |
| 🗺️ [ROADMAP.md](docs/ROADMAP.md) | Strategic product & engineering roadmap from Phase 1.1 to 2.3.1 Release Candidate |
| 📜 [CHANGELOG.md](docs/CHANGELOG.md) | Full release notes and historical change record |
| 🤝 [CONTRIBUTING.md](docs/CONTRIBUTING.md) | Developer guidelines, coding standards, test instructions, and PR checklist |

---

## ✨ Features

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

### 👑 Flagship Brain Dump 2.0 & Voice Studio
- **🎙️ Fluid Sensory Voice Studio**: Dynamic 32-bar reactive frequency equalizer (`AudioWaveformVisualizer`) that animates in real-time to microphone sound levels with harmonic sine wave rendering.
- **🔐 Microphone Permissions & Recovery**: Explicit Android runtime permissions (`RECORD_AUDIO`, `BLUETOOTH`, `RecognitionService` queries) and friendly recovery modal if permissions were denied.
- **🧪 Emulator Voice Dictation Simulator**: In environments without speech recognition hardware (e.g. Android Emulators, headless/desktop testing), streams simulated voice input (`_simulateVoiceDictation`) that directly powers the 32-bar reactive equalizer and 4-pillar cognitive parser.
- **🧠 4-Pillar Cognitive Extraction**: Parses stream-of-consciousness thoughts into **Tasks**, **Notes** (saved directly to `notesBox` with `#braindump`), **Goals** (auto-linked to tasks), and **Memories**.
- **📅 Smart Gap-Aware Auto-Scheduling**: Automatically packs newly extracted tasks into upcoming open calendar windows without collisions or past-time placement.
- **🎨 Interactive Live Triage Canvas**: Inline duration selector chips (`15m`, `30m`, `45m`, `60m`), priority cycling, schedule fit status badges, and one-tap conversion between Tasks and Notes.
- **⚡ Cognitive Clarity Rewards**: Mental declutter score banner with atomic multi-box persistence and instant **+50 XP** bonus.

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

### 📖 Flagship Onboarding & In-App Help Guide
- **6-Slide Onboarding Walkthrough**: Rich, vibrantly stylized capability pages showcasing Brain Dump 2.0 Studio, DAG scheduling, Daily Rituals, Circadian Focus, Mastery Ranks, and Living Memory.
- **Comprehensive In-App Help (`HelpScreen`)**: 5-stage daily productivity lifecycle diagram, 11 expandable capability deep dives, and interactive FAQs.

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
- **Multi-Factor Planning Score**: Deterministic slot-evaluation factoring priority, deadline urgency (exponential escalation), goal alignment, energy level, preferred time of day, and context switching penalties.
- **Directed Acyclic Graph (DAG) Task Dependencies**: Tasks declare dependencies (`dependsOnTaskIds`); Kahn's algorithm resolves topological order and safely breaks cycles with diagnostics.
- **Task Splitting Engine**: Large focus tasks (`splittable: true`) break down into configurable blocks with restorative buffer breaks.
- **Hard Temporal Constraints**: Full support for deadlines, earliest start times, latest finish times, and fixed time anchors (`isFixed`).
- **Explainable Planning ("Why Here?")**: Interactive inspection sheet displaying planning score progress and transparent factor reasoning for every scheduled item.
- **Proactive Rescheduling**: Detects overdue tasks upon app resume and suggests optimal replacement slots from the remaining work window.

### 🧘 Immersive Focus & AI Command Omnibar
- **⚡ AI Command Omnibar (`Cmd+K` / `Ctrl+K`)**: Spotlight command palette parsing natural language schedule instructions (push afternoon, clear window, quick add, find fitting tasks) with safety preview before execution.
- **🧘 Immersive Focus Mode**: Fullscreen distraction-free timer with radial progress, +5m/+15m flow extensions, distraction logs, actual duration tracking, and 60fps confetti celebration emitter.
- **🎯 "What Should I Do Now?" Hero Card**: Context-aware recommendation engine evaluating schedule windows, priority, and energy level.
- **📈 Duration Variance Learning & Auto-Calibration**: Machine learning from past completion variance ($\text{actual} / \text{estimated}$), injecting dynamic duration multipliers into the daily scheduler.
- **🩺 Productivity Health & Planning Debt**: Live Schedule Accuracy Index (SAI) and accumulated planning debt metrics in Analytics.

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

# Run full test suite (528 passing tests across 34 test files)
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
