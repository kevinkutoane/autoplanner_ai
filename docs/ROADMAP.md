# AutoPlanner AI — Strategic Product & Architectural Roadmap

> **Core Philosophy**: *"AI decides what something means. Deterministic code decides whether it can actually fit."*  
> AutoPlanner AI is evolving from a daily task assistant into a local-first, autonomous AI Personal Planning Operating System.

---

## Evolution Stages

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Phase 1.1 — Reliability & Hardening [COMPLETED]                             │
│ • Offline AI Queue Dispatcher & Persistence                                 │
│ • Google Calendar Incremental Sync via syncTokens                           │
│ • Safe Corrupted Hive Recovery with Timestamped Backups                     │
│ • AI Structured-Output Validation Boundary (AIValidator)                    │
│ • Clock Abstraction & Deterministic Scheduler Behavioral Tests              │
│ • AppBootstrapper Unified Startup Lifecycle                                 │
│ • CI Quality Gate (Java 17, analyze --fatal-infos, build verification)      │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Phase 1.2 — Smart Scheduling Engine [COMPLETED]                             │
│ • Constraint-Based Planning (Deadlines, Earliest Start, Latest Finish)      │
│ • Task Dependencies DAG (Topological Sort, Cycle Detection)                 │
│ • Task Splitting (Large focus blocks + break intervals)                     │
│ • Multi-Factor Planning Score Function                                      │
│ • Schedule Explainability ("Why Here?" rationale & warning diagnostics)     │
│ • UI Integration (Advanced Scheduling Panel, Warnings Banner, Sheets)       │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Phase 1.3 — Personal Intelligence & Duration Learning [COMPLETED]           │
│ • Estimated vs. Actual Duration Tracking & Feedback Loop                    │
│ • Productivity Health Metrics (Schedule Accuracy Index, Planning Debt)      │
│ • Category Estimation Variance Multipliers injected into Scheduler          │
│ • ProductivityHealthCard on Dashboard and Analytics                         │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Phase 1.4 — AI Assistant & Autonomous Interaction [COMPLETED]               │
│ • AI Command Omnibar with Global Shortcuts (Cmd+K / Ctrl+K)                 │
│ • Natural Language Scheduling Actions (shift, clear window, quick add, fit) │
│ • "What Should I Do Now?" Context-Aware Smart Action Hero Card              │
│ • Fullscreen Immersive Focus Mode (Radial timer, Flow extenders, Confetti)   │
│ • Tactile Sensory Haptic Feedback System                                    │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Phase 2.0–2.3 — Flagship OS, Dock & Sensory Themes [COMPLETED]              │
│ • Brain Dump 2.0 Studio (32-bar visualizer, 4 pillars, gap packing)         │
│ • Voice Dictation Permissions & Emulator Dictation Simulator                │
│ • Multi-Tier Notifications, Crucial Task Filter & Streak Shield             │
│ • Gamification Engine (10 ranks, streak multipliers, badge showcase)        │
│ • 5-Slot Balanced Navigation Dock & Responsive 4x2 Feature Sheet            │
│ • Signature Screen Gradient Palettes & Glowing Headers                      │
│ • AI Coach Persona Guardrails, Avatars & Animated Typing Wave               │
│ • 6-Slide Capability Onboarding & Comprehensive Help Guide                  │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Phase 2.4 — Weekly Intelligence & Capacity Planning [NEXT UP]               │
│ • "Plan My Week" Multi-Day Capacity Allocation                              │
│ • "Replan My Week" Mid-Week Recovery & Workload Balancing                   │
│ • Planning Debt Burn-Down & Habit Adherence                                 │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Phase 3.0 — Cloud AI Gateway & Cross-Device Sync [PLANNED]                  │
│ • Authenticated Cloud AI Gateway (Model Agnostic: Gemini, Claude, Local)    │
│ • Multi-Device Sync Engine (Relational Repository Abstraction)              │
│ • Knowledge Graph Queries across Goals, Projects, Tasks, and Memories       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Phase Breakdown

### Phase 1.1: Reliability & Hardening `[COMPLETED]`
- **Goal**: Make existing architecture reliable and deterministic so higher-order intelligence can be safely built on top.
- **Delivered**:
  1. Real `OfflineAIQueue` routing to `AIService` with exponential retry bounds and permanent failure tracking.
  2. Full Google Calendar API v3 `syncToken` incremental sync with pagination safety and 410 Gone recovery.
  3. Safe Hive corruption recovery creating `.corrupt.<timestamp>.bak` copies before resetting data.
  4. `AIValidator` domain and schema boundary enforcing priority, duration, time format, and title bounds.
  5. `package:clock` abstraction enabling 16 deterministic behavioral tests across edge cases (morning starts, mid-day future placements, end-of-day overflows, post-work extensions).
  6. `AppBootstrapper` consolidating 200+ lines of raw startup initialization into a single unified entry point.
  7. CI quality gate enforcing formatting, zero static analysis issues with `--fatal-infos`, full 402-test pass rate, and debug APK build verification.

---

### Phase 1.2: Smart Scheduling Engine `[COMPLETED]`
- **Goal**: Transition from a naive priority-based greedy slot-packer into an intelligent constraint-based planning engine.
- **Delivered**:
  1. **Domain Evolution (`TaskItem`)**: Added backward-compatible fields 12–22 (`deadline`, `earliestStart`, `latestFinish`, `isFixed`, `energyLevel`, `preferredTimeOfDay`, `splittable`, `preferredBlockMinutes`, `dependsOnTaskIds`, `linkedProjectId`, `parentTaskId`).
  2. **Task Dependencies DAG (`DependencyGraphService`)**: Built dependency graph resolution with Kahn's algorithm cycle detection and topological sorting, guaranteeing dependent tasks start strictly after prerequisite tasks finish.
  3. **Task Splitting Engine**: Decomposes large tasks (`splittable == true`) into discrete focus blocks with restorative transition breaks.
  4. **Multi-Factor Planning Score**:
     $$\text{PlanningScore} = W_p \cdot \text{Priority} + W_d \cdot \text{DeadlineUrgency} + W_g \cdot \text{GoalWeight} + W_e \cdot \text{EnergyFit} + W_t \cdot \text{TimeOfDayFit} - \text{ContextSwitchPenalty}$$
  5. **Explainability & Diagnostics**: Engine generates `ScheduleResult` with transparent factor breakdowns (`TaskPlacementRationale`) and warnings (`ScheduleWarning`).
  6. **UI Integration**:
     - Advanced Scheduling Panel in Task Edit sheet with date-time pickers, fixed toggle, energy chips, time-of-day chips, and split controls.
     - "Plan My Day" executes `scheduleDayWithDetails`, stores explanations in Riverpod `scheduleRationaleProvider`, and presents `_ScheduleWarningsBanner`.
     - Interactive "Why Here?" bottom sheet (`_ScheduleRationaleSheet`) displaying score breakdown and decision factors per task.
  7. **Verification**: 449 unit and integration tests passing, 0 analyzer issues.

---

### Phase 1.3: Personal Intelligence & Duration Learning `[COMPLETED]`
- **Goal**: Move from static user rules to an adaptive personal productivity model.
- **Delivered**:
  1. **Feedback Loops**: Actual duration logging in `TaskItem.actualDurationMinutes` linked to Focus Mode.
  2. **Estimation Variance Learning (`DurationLearningService`)**: Tracks personal ratio $\text{actual} / \text{estimated}$ across categories and injects rolling multipliers into `SchedulerService`.
  3. **Productivity Health Metrics**: Real-time Schedule Accuracy Index (SAI) and accumulated planning debt indicators displayed in Analytics and Dashboard.
  4. **Dynamic Health Visualization**: `ProductivityHealthCard` summarizing estimation reliability.

---

### Phase 1.4: AI Assistant & Autonomous Interaction `[COMPLETED]`
- **Goal**: Turn the planner into an interactive, natural-language personal assistant.
- **Delivered**:
  1. **AI Command Omnibar (`Cmd+K` / `Ctrl+K`)**: Global spotlight palette supporting natural language actions (`shift`, `clearWindow`, `quickAdd`, `findFit`, `startFocus`).
  2. **Safety Boundaries (`CommandPreview`)**: Action preview modal displaying before/after timestamps with mandatory user confirmation before schedule mutation.
  3. **"What Should I Do Now?" Hero Card**: Context-aware recommendation card evaluating active sessions, user energy, open gaps, and task priorities.
  4. **Fullscreen Focus Mode (`FocusModeScreen`)**: Distraction-free radial timer, flow extenders (+5m, +15m), pause tracking, distraction scratchpad, and 60fps confetti emitter.
  5. **Tactile Haptics**: Micro-vibrations on interactive triggers and completion milestones.

---

### Phase 2.0–2.3: Flagship OS, Dock & Sensory Themes `[COMPLETED]`
- **Goal**: Deliver a flagship, sensory personal planning operating system with rich gamification, automated daily rituals, balanced navigation, and distinct screen aesthetics.
- **Delivered**:
  1. **Brain Dump 2.0 Studio**: 32-bar reactive frequency equalizer (`AudioWaveformVisualizer`), 4-pillar extraction (Tasks, Notes, Goals, Memories), gap-packing calendar placement, and interactive triage studio.
  2. **Voice Dictation & Emulator Simulator**: Android `RECORD_AUDIO` and Bluetooth runtime permissions, permission recovery dialogs, and an offline voice streaming simulator (`_simulateVoiceDictation`) for emulator/desktop environments.
  3. **Multi-Tier Notification Center (`NotificationService`)**: Differentiated channels (`autoplanner_urgent`, `autoplanner_tasks`, `autoplanner_rituals`), configurable lead times (5m, 10m, 15m, 30m), crucial tasks filter, and 20:00 Streak Shield alerts.
  4. **Multi-Agent Routines & Automated Rituals (`RoutineService`)**: Morning Kickoff sheet with "The Big 3" priority commitments (+50 XP) and Evening Shutdown sheet with task triaging and 1-line memory reflection (+50 XP).
  5. **Gamification & Mastery Ranks (`GamificationService`)**: 10 progression tiers (Novice to Grandmaster), scaling streak multipliers (1.0x to 2.0x), milestone badge catalog, and `LevelUpDialog` celebration.
  6. **Ergonomic 5-Slot Navigation Dock (`_GlassNavBar`)**: Floating frosted glass dock, elevated center Brain Dump hero button (`_DockedBrainDumpButton`) with neon glow, removal of overlapping FAB, and responsive 4x2 More Features grid (`_GlassMoreSheet`).
  7. **Signature Screen Themes & Glowing Headers (`ui_kit.dart`)**: Curated gradient header tokens across all screens (`kGradientPlanner`, `kGradientCalendar`, `kGradientMemory`, `kGradientNotes`, `kGradientProjects`, `kGradientAnalytics`, `kGradientSettings`, `kGradientNeonSunset`).
  8. **AI Coach Guardrails & Conversational UI (`AiCoachScreen`)**: Strict productivity scope enforcement, suppression of raw task JSON, glowing bot avatar, user badge, and inline animated 3-dot wave typing indicator (`_TypingBubble`).
  9. **Onboarding Walkthrough & Comprehensive Help Guide**: 6-slide capability onboarding with dynamic glowing orbs, and 5-stage daily lifecycle Help guide with 11 expandable capability deep dives.
  10. **Verification**: 503 passing unit, widget, and integration tests with zero analyzer errors.

---

### Phase 2.4: Weekly Intelligence & Capacity Planning `[NEXT UP]`
- **Goal**: Multi-day capacity planning, mid-week recovery, and workload balancing.
- **Key Capabilities**:
  1. **"Plan My Week"**: Balances workloads across 5–7 days, protecting goal-aligned deep work blocks against meeting overload.
  2. **"Replan My Week"**: Autonomous Thursday/Friday recovery pass moving low-priority tasks, splitting blockers, and protecting upcoming hard deadlines.
  3. **Planning Debt Burn-Down**: Actionable recommendations to clear accumulated scheduling debt without burning out.

---

### Phase 3.0: Cloud AI Gateway & Cross-Device Sync `[PLANNED]`
- **Goal**: Production-grade multi-platform architecture and commercial backend.
- **Key Capabilities**:
  1. **AI Gateway**: Authenticated cloud proxy for centralized rate limits, cost control, prompt versioning, and seamless provider switching (Gemini, Claude, GPT, local LLMs).
  2. **Relational Repository Abstraction**: Seamless sync layer abstracting Hive or SQLite for cross-device synchronization (Mobile, Tablet, Desktop, Web).
  3. **Personal Knowledge Graph**: Unified query graph connecting Goals → Projects → Tasks → Notes → Memories → Calendar.
