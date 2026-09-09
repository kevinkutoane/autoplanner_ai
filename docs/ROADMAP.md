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
│ Phase 1.2 — Smart Scheduling Engine [READY FOR EXECUTION]                   │
│ • Constraint-Based Planning (Deadlines, Earliest Start, Latest Finish)      │
│ • Task Dependencies DAG (Topological Sort, Cycle Detection)                 │
│ • Task Splitting (Large focus blocks + break intervals)                     │
│ • Multi-Factor Planning Score Function                                      │
│ • Schedule Explainability ("Why was this task placed here?")                │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Phase 1.3 — Personal Intelligence & Behavioral Learning                     │
│ • Estimated vs. Actual Duration Tracking & Feedback Loop                    │
│ • Productivity Health Metrics (Accuracy, Carry-over, Planning Debt)         │
│ • Personal Productivity Model (Deep work windows, Underestimation offsets)  │
│ • Learned Preferences vs. Episodic Memory Separation                        │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Phase 1.4 — AI Assistant & Autonomous Interaction                           │
│ • Natural-Language AI Command Bar ("Clear afternoon", "What to do next?")   │
│ • "What Should I Do Now?" Smart Action Card                                 │
│ • Intelligent Focus Mode (Timer, Distractions, Completion metrics)          │
│ • AI Inbox & Autonomous Triage                                              │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Phase 1.5 — Weekly Intelligence                                             │
│ • "Plan My Week" Multi-Day Capacity Allocation                              │
│ • "Replan My Week" Mid-Week Recovery & Workload Balancing                   │
│ • Planning Debt Burn-Down & Habit Adherence                                 │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Phase 2.0 — Personal Operating System & AI Gateway                          │
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

### Phase 1.2: Smart Scheduling Engine `[SPECIFIED]`
- **Goal**: Transition from a naive priority-based greedy slot-packer into an intelligent constraint-based planning engine.
- **Key Capabilities**:
  1. **Task Constraints**:
     - Hard constraints: `deadline`, `earliestStart`, `latestFinish`, `isFixed`.
     - Soft constraints: `energyLevel` (low/medium/high), `preferredTimeOfDay` (morning/afternoon/evening).
  2. **Task Dependencies DAG**:
     - Tasks declare `dependsOnTaskIds`.
     - Cycle detection via Kahn's algorithm or DFS.
     - Dependent tasks can only be scheduled after all prerequisites have concluded.
  3. **Task Splitting**:
     - Tasks flagged `splittable: true` with `preferredBlockMinutes` (e.g. 60m).
     - Scheduler breaks long tasks (e.g., 240m) across multiple free slots with restorative break buffers.
  4. **Multi-Factor Planning Score**:
     $$\text{PlanningScore} = W_p \cdot \text{Priority} + W_d \cdot \text{DeadlineUrgency} + W_g \cdot \text{GoalWeight} + W_e \cdot \text{EnergyFit} - \text{ContextSwitchPenalty}$$
  5. **Explainability**:
     - Engine outputs a structured `SchedulePlan` containing placement reasoning per task for transparent UI inspectability ("Why 10:30?").

---

### Phase 1.3: Personal Intelligence & Behavioral Learning `[PLANNED]`
- **Goal**: Move from static user rules to an adaptive personal productivity model.
- **Key Capabilities**:
  1. **Feedback Loops**: Post-task prompt ("Was estimated 60m accurate?").
  2. **Estimation Variance Learning**: Tracks $\Delta(\text{estimated}, \text{actual})$ by task category/tag. Automatically offsets AI duration estimates based on historical personal trends (e.g., +35% for development tasks).
  3. **Personal Productivity Model**: Learned preferences (e.g. "User completes deep work best between 08:00–11:00") stored separately from episodic memory facts.
  4. **Productivity Health & Planning Debt**: Metrics tracking carry-over rates, schedule stability, and recurring overdue tasks with remediation suggestions.

---

### Phase 1.4: AI Assistant & Autonomous Interaction `[PLANNED]`
- **Goal**: Turn the planner into an interactive personal assistant.
- **Key Capabilities**:
  1. **AI Command Bar**: Omnipresent action prompt supporting natural language commands ("Clear my afternoon", "Move non-urgent tasks to tomorrow").
  2. **"What Should I Do Now?"**: Smart context card on the home dashboard surfacing the optimal next task with rationale.
  3. **Focus Mode**: Distraction-free execution timer tracking pauses, interruptions, and actual durations.
  4. **AI Inbox**: Semi-automated triage area for unstructured thoughts, ideas, and tasks.

---

### Phase 1.5: Weekly Intelligence `[PLANNED]`
- **Goal**: Multi-day capacity planning and mid-week recovery.
- **Key Capabilities**:
  1. **"Plan My Week"**: Balances workloads across 5–7 days, protecting goal-aligned deep work blocks against meeting overload.
  2. **"Replan My Week"**: Autonomous Thursday/Friday recovery pass moving low-priority tasks, splitting blockers, and protecting upcoming hard deadlines.

---

### Phase 2.0: Personal Operating System & AI Gateway `[PLANNED]`
- **Goal**: Production-grade multi-platform architecture and commercial backend.
- **Key Capabilities**:
  1. **AI Gateway**: Authenticated cloud proxy for centralized rate limits, cost control, prompt versioning, and seamless provider switching (Gemini, Claude, GPT, local LLMs).
  2. **Relational Repository Abstraction**: Seamless sync layer abstracting Hive or SQLite for cross-device synchronization (Mobile, Tablet, Desktop, Web).
  3. **Personal Knowledge Graph**: Unified query graph connecting Goals → Projects → Tasks → Notes → Memories → Calendar.
