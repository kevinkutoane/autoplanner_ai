# AutoPlanner AI Architecture & Cloud Boundary Specification

## 1. Core Architectural Principle

> **"AI decides what something means. Deterministic application logic decides what is valid and executable."**

AutoPlanner strictly separates non-deterministic language understanding from deterministic scheduling and state persistence:
- **AI Service Layer (`AIService`, Gateway)**: Interprets unstructured user inputs, extracts intent, classifies entities, enriches task duration/priority suggestions, and generates natural language coaching.
- **Deterministic Domain Engine (`SchedulerService`, `ConflictDetector`, `AIGuard`, `Hive`)**: Validates time bounds, enforces calendar constraints, prevents double-booking, sanitizes inputs, clamps values, and manages local persistence.

The AI boundary never directly writes to the database or mutates schedule state without passing through deterministic business logic and user confirmation.

---

## 2. System Architecture: Current vs. Target

### Current Architecture (Phase 1 Implemented)

```text
┌────────────────────────────────────────────────────────┐
│                   Flutter Application                  │
│                                                        │
│  [UI Screens & Features]                               │
│       │                                                │
│       ▼                                                │
│  [AIService]                                           │
│       │                                                │
│       ├─► Validates & sanitizes input (AIGuard)        │
│       ├─► Builds typed semantic AIInvocation           │
│       │                                                │
│       ▼                                                │
│  [AIProvider Abstraction]                              │
│       │                                                │
│       ├──► MockAIProvider (Tests & Offline/Mock Mode)  │
│       ├──► GeminiProvider (Direct BYOK Google AI SDK)  │
│       └──► CloudAIProvider (Cloud Gateway HTTP Client) │
└────────────────────────────────────────────────────────┘
```

### Target Architecture (Phase 2+ Cloud AI Gateway)

```text
┌────────────────────────────────────────────────────────┐
│                   Flutter Application                  │
│  [AIService]                                           │
│       │ creates AIInvocation                           │
│       ▼                                                │
│  [CloudAIProvider]                                     │
└───────────────────────┬────────────────────────────────┘
                        │ HTTPS (X-Request-ID, Bearer Token)
                        ▼
┌────────────────────────────────────────────────────────┐
│        AutoPlanner AI Gateway (Cloud Run / FastAPI)    │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Semantic Operation Router (/v1/ai/complete)      │  │
│  │ - Auth verification & Rate limiting (Redis/Tier) │  │
│  │ - Request deduplication & Telemetry logging      │  │
│  └────────────────────────┬─────────────────────────┘  │
│                           │                            │
│  ┌────────────────────────▼─────────────────────────┐  │
│  │ Prompt Engineering & Model Orchestration Layer   │  │
│  │ - Server-owned prompt templates & schemas        │  │
│  │ - Model routing (Gemini 1.5 Flash vs. Pro)       │  │
│  │ - Safety filters & Content guardrails            │  │
│  │ - Fallback provider failover (Claude, OpenAI)    │  │
│  └────────────────────────┬─────────────────────────┘  │
└───────────────────────────┼────────────────────────────┘
                            │
                            ▼
               [Google Vertex AI / Gemini API]
```

---

## 3. Semantic AI Operations Inventory

All AI interactions flow through strongly-typed operations identified by `AIOperation` (defined in `lib/core/ai/ai_invocation.dart`):

| Operation Enum | Wire Name | Purpose | Key Inputs | Key Context |
| :--- | :--- | :--- | :--- | :--- |
| `brainDump` | `brain_dump` | Parse unstructured stream-of-consciousness text into tasks, notes, goals, and memories. | `rawInput` | `suggestedStartTime` |
| `parseTasks` | `parse_tasks` | Extract structured actionable tasks from natural language. | `text` | `memories` |
| `planDay` | `plan_day` | Re-score priority and calibrate duration estimates for pending tasks. | `additionalInput` | `existingTasks`, `workStartHour`, `workHoursPerDay`, `memories` |
| `chatCoach` | `chat_coach` | Interactive productivity mentoring and personal coaching. | `message`, `history` | User preferences |
| `dailyInsight` | `daily_insight` | Generate motivational daily morning briefing and tip. | _(empty)_ | `tasks`, `goals`, `memories` |
| `suggestReschedule` | `suggest_reschedule` | Select the optimal candidate slot for missed or overdue tasks. | `taskTitle`, `durationMinutes` | `candidateSlots`, `linkedGoal`, `memories` |
| `summarizeNote` | `summarize_note` | Generate a 1–3 sentence concise note summary for quick reference. | `content` | _(empty)_ |
| `generateTags` | `generate_tags` | Infer 2–5 lowercase topical categorization tags. | `content` | _(empty)_ |
| `extractMemory` | `extract_memory` | Extract reusable long-term preference or insight for Hive memory storage. | `context`, `sourceType` | _(empty)_ |
| `extractPatterns` | `extract_patterns` | Analyze completed task history to discover productivity habits and rhythms. | _(empty)_ | `completedHistory`, `memories` |
| `suggestTasks` | `suggest_tasks` | Contextual task suggestions for a given calendar day. | `dayName`, `date` | `memories`, `recentHistory` |
| `weeklyReview` | `weekly_review` | Synthesize weekly accomplishment review across tasks and active goals. | `tasksCount`, `completedCount`, `completionRate` | `goals`, `memories` |
| `parseScheduleCommand` | `parse_schedule_command` | Parse natural language schedule manipulation commands (shift, fit, focus). | `query`, `referenceTime` | _(empty)_ |

---

## 4. Invocation Wire Contract (`AIInvocation`)

The invocation contract cleanly decouples client intent from the underlying language model and prompt text:

```json
{
  "id": "c62b9a7b-3ef1-4b77-a5dc-72e7d7a12b01",
  "operation": "plan_day",
  "input": {
    "additionalInput": "Finish tax filing before 2pm"
  },
  "context": {
    "workStartHour": 9,
    "workHoursPerDay": 8,
    "existingTasks": [
      { "id": "task-1", "title": "Design review", "priority": 2 }
    ],
    "memories": [
      "User focuses best on deep work in the morning"
    ]
  },
  "client": {
    "appVersion": "2.3.1+1",
    "platform": "android"
  },
  "timestamp": "2026-09-19T19:25:00.000Z"
}
```

### Response Schema (`/v1/ai/complete`)

```json
{
  "text": "[{\"id\":\"task-1\",\"title\":\"Design review\",\"estimatedMinutes\":60,\"priority\":2,\"tags\":[\"work\"]}]",
  "promptTokens": 412,
  "completionTokens": 84,
  "model": "gemini-1.5-pro",
  "requestId": "c62b9a7b-3ef1-4b77-a5dc-72e7d7a12b01"
}
```

---

## 5. Security & Governance

1. **Safety Screening (`AIGuard`)**: All user inputs continue to be pre-screened on the client for prompt-injection attacks, context flooding (>8000 chars), and delimiter escapes before network transmission.
2. **Server-Side Ownership**: In Phase 2, prompt templates and safety policies will reside on the AI Gateway, shielding proprietary prompts and preventing client prompt manipulation.
3. **Bring Your Own Key (BYOK) Compatibility**: Users who prefer direct communication with Gemini can enter their API key in Settings; AutoPlanner switches seamlessly to `GeminiProvider` without sending data to third-party gateways.
