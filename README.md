# AutoPlanner AI

> **AI-powered daily planner for Android & iOS** — turn a stream-of-consciousness brain dump into a fully scheduled, priority-scored day in seconds.

---

## Features

- **Brain Dump** — paste or speak anything on your mind; AI classifies it into tasks, notes, and long-term memories in real time with streaming output
- **AI Task Parser** — natural language → structured tasks with start time, realistic duration, and priority (Low / Medium / High / Urgent)
- **Plan My Day** — one-tap AI enrichment pass re-scores all pending tasks, estimates durations, then a deterministic scheduling engine packs them into your work window with zero conflicts
- **Day Planner** — drag-reorder, inline complete/delete, and tap-to-edit any task (title, priority, time, duration, note)
- **Notes** — AI-generated summaries and auto-tags; extract action items directly into the planner
- **Memory** — persistent AI memory extracted from your tasks, notes, and brain dumps; automatically fed back as context on future AI calls
- **Calendar** — visual day/week view synced with task changes in real time
- **Dashboard** — daily insight card powered by AI, token usage meter, streak tracker
- **Onboarding** — guided walkthrough on first launch
- **Settings** — theme picker, work schedule, biometric lock, API key management, mock AI toggle

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter 3 + Material 3 |
| State | Riverpod (`StateNotifierProvider`) |
| Persistence | Hive — AES-256 encrypted via OS keychain key |
| AI | Google Gemini (`google_generative_ai`) with streaming support |
| Scheduling | Custom pure-Dart greedy slot-packer (`SchedulerService`) |
| Security | `flutter_secure_storage` (API key + Hive key in OS keychain), `local_auth` (biometrics) |
| Architecture | Feature-first with shared `core/` layer |

---

## Security

- **Hive encrypted at rest** — a 32-byte AES key is generated on first install and stored in the Android Keystore / iOS Secure Enclave via `flutter_secure_storage`. All boxes (tasks, notes, calendar, memory, settings, AI logs) use `HiveAesCipher`.
- **API key in OS keychain** — the user's Gemini API key is stored via `flutter_secure_storage`, never written to Hive or bundled assets.
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

---

## Project Structure

```
lib/
├── main.dart                  # App entry, Hive + cipher init, provider overrides
├── app_shell.dart             # Bottom-nav shell, biometric lock-on-resume (WidgetsBindingObserver)
├── core/
│   ├── ai/                    # AIProvider abstraction, GeminiProvider, MockAIProvider, TokenTracker
│   ├── config/                # EnvConfig (flutter_dotenv fallback key)
│   ├── models/                # TaskItem, NoteItem, MemoryEntry, CalendarEvent (Hive adapters)
│   ├── providers/             # Centralized Riverpod providers (settings, AI, biometrics, scheduler)
│   └── theme/                 # UIKit — GlassCard, GradBtn, GlassField, OrbBackground, colour tokens
├── features/
│   ├── brain_dump/            # BrainDumpSheet with live streaming preview
│   ├── calendar/              # CalendarScreen
│   ├── dashboard/             # DashboardScreen, daily insight
│   ├── memory/                # MemoryScreen, MemoryController
│   ├── notes/                 # NotesScreen, NoteController, AI summarize/tag
│   ├── onboarding/            # Splash + multi-page OnboardingScreen
│   ├── planner/               # PlannerScreen, TaskController, Plan My Day, TaskEditSheet
│   └── settings/              # SettingsScreen, SettingsController, AppSettings model
└── services/
    ├── ai_service.dart        # Unified AI layer (retry, parseTasks, planDay, brainDump, streaming)
    ├── biometric_service.dart # local_auth wrapper (availability check, authenticate, stop)
    ├── memory_service.dart    # Hive-backed memory CRUD
    ├── scheduler_service.dart # Deterministic day-scheduling algorithm
    └── secure_key_service.dart# OS keychain wrapper (Gemini key + Hive encryption key)
```

---

## Architecture Notes

### AI Layer

All AI calls go through `AIService`, which sits on top of an `AIProvider` abstraction. Swapping the underlying model (Gemini → OpenAI → local) requires no changes to feature code.

`AIService` provides:
- `parseTasks` — NL → `List<TaskItem>` with `estimatedMinutes`
- `planDay` — AI enrichment: re-score priority + duration for existing tasks, optionally parse new ones from free text
- `brainDump` — streaming or non-streaming; returns tasks, notes, and memories
- `summarizeNote`, `generateTags`, `extractActionItems`, `generateDailyInsight`, `extractMemoryFromContext`
- All methods sanitise user input and use exponential back-off retry (1 s → 2 s → 4 s)

### Scheduling Algorithm

`SchedulerService.scheduleDay` is AI-free and deterministic:
1. Separate completed tasks (treated as immovable occupied blocks)
2. Sort pending tasks by priority descending
3. Greedy forward scan: find the first free slot ≥ task duration, place it, advance cursor + 10-min buffer
4. If scheduling today and past work-start, the cursor begins at the next rounded quarter-hour to avoid placing tasks in the past

### Data Flow — "Plan My Day"

```
User taps "Plan My Day"
  → AIService.planDay()            # AI scores + estimates durations
  → SchedulerService.scheduleDay() # Deterministic time placement
  → TaskController.updateTask()    # Persisted to Hive (encrypted)
  → Riverpod rebuilds UI
```

---

## License

MIT
