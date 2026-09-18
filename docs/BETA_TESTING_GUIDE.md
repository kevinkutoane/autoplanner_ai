# AutoPlanner AI — Beta Testing & Real-Device QA Protocol

> **Phase**: 2.3.1 Release Candidate (Conditional) → Private Beta  
> **Document Status**: Authoritative QA Test Matrix  
> **Target Platforms**: Android 12+ (minSdk 21, targetSdk 35) & iOS 15+  
> **Test Environment**: Physical Devices (Primary) & High-Fidelity Emulators (Secondary)

---

## 🎯 Testing Philosophy & Objectives

As AutoPlanner AI enters private beta, testing shifts from automated CI correctness to **real-world human workflows, platform edge cases, environmental variability, and sensory ergonomics**.

Beta testers should evaluate the app across four lenses:
1. **Correctness & Reliability**: Invariants must hold under flaky networks, device sleep, and app lifecycle transitions.
2. **Sensory & Visual Polish**: Fluid 60fps animations, glassmorphism legibility, audio equalizer responsiveness, zero layout overflow.
3. **AI Persona & Guardrails**: Useful, grounded coaching without prompt leaks, raw JSON artifacts, or hallucinated task mutations.
4. **Data Integrity & Privacy**: All personal tasks and memories must remain strictly encrypted; no data loss on app crashes or device reboots.

---

## 🚦 Defect Severity Classification

When logging defects or unexpected behaviors, classify them as follows:

| Severity | Label | Definition | Action |
| :---: | :--- | :--- | :--- |
| **P0** | **CRITICAL BLOCKER** | App crash on launch, unrecoverable data loss, encryption key failure, infinite AI retry loop, scheduler freezing UI. | Immediate halt; patch before further testing. |
| **P1** | **HIGH SEVERITY** | Core feature failure (Brain Dump fails to parse, offline queue fails to drain, notification not firing, calendar sync corrupting events). | Must fix before public release. |
| **P2** | **MEDIUM / QUALITY** | Cosmetic glitches, layout overflow on specific screen densities, awkward AI coach response wording, slight animation jitter. | Fix in RC polish pass. |
| **P3** | **MINOR / POLISH** | Minor spacing inconsistency, typography nuance, non-critical enhancement request. | Track in Phase 2.4+ backlog. |

---

## 📋 Comprehensive Beta Test Matrix

### 1. First-Run, Onboarding & Permissions Matrix

| Test ID | Test Scenario | Step-by-Step Procedure | Expected Result | What to Look For (Red Flags) |
| :--- | :--- | :--- | :--- | :--- |
| **TC-ONB-01** | **Fresh Install Cold Launch** | 1. Install clean APK/IPA.<br>2. Launch app cold.<br>3. Observe initial splash screen. | App initializes within < 1.5s. AES-256 key is generated securely in Keystore/Keychain. All 10 Hive boxes open cleanly. | Blank white screen hang; database open error dialog; splash animation stutter. |
| **TC-ONB-02** | **6-Slide Onboarding Walkthrough** | 1. Swipe through all 6 onboarding slides.<br>2. Verify dynamic glowing orb animations.<br>3. Tap "Get Started" on the final slide. | Smooth 60fps swipe transitions. Final button navigates to Dashboard and permanently marks onboarding completed. | Text clipped on small screens; orb animation dropping frames; re-prompting onboarding on second launch. |
| **TC-ONB-03** | **Microphone Permission Flow** | 1. Navigate to Brain Dump 2.0.<br>2. Tap the microphone button.<br>3. Observe system permission prompt.<br>4. Tap "Allow". | Android/iOS permission dialog appears. Once allowed, the 32-bar equalizer immediately activates and listens. | Permission prompt does not appear; app crashes immediately on mic tap; permission accepted but audio stays muted. |
| **TC-ONB-04** | **Microphone Permission Denied Recovery** | 1. Reinstall or revoke mic permission in OS Settings.<br>2. Tap microphone in Brain Dump.<br>3. Tap "Deny". | App presents friendly permission explanation dialog with "Open Settings" button; doesn't crash or loop. | Silent failure; frozen button; unhandled platform exception toast. |
| **TC-ONB-05** | **Biometric Lock Engagement** | 1. Go to Settings → Security.<br>2. Enable Biometric Authentication.<br>3. Background app and resume.<br>4. Test fingerprint / Face ID. | App displays biometric prompt on resume. Successful biometric unlock reveals app; cancel/fail locks UI with PIN fallback. | Biometrics bypassable by swiping back; infinite auth loop; crash when biometrics hardware absent. |

---

### 2. Flagship Brain Dump 2.0 & Sensory Voice Studio

| Test ID | Test Scenario | Step-by-Step Procedure | Expected Result | What to Look For (Red Flags) |
| :--- | :--- | :--- | :--- | :--- |
| **TC-BD-01** | **Voice Dictation with Live Sound Levels** | 1. Open Brain Dump modal.<br>2. Tap mic and speak: *"Call Sarah at 2pm for 30 minutes, buy milk, and remember I love dark roast coffee"*. | 32-bar equalizer reacts fluidly to vocal volume changes. Live speech-to-text streams transcribed text into text input. | Equalizer bars static or jumping abruptly; speech-to-text dropping whole phrases; audio session not released on close. |
| **TC-BD-02** | **4-Pillar Cognitive Extraction** | 1. Submit the transcribed stream-of-consciousness text.<br>2. Tap "Analyze & Plan". | AI parses text into 4 distinct pillars:<br>- **Task**: "Call Sarah" (14:00, 30m, High Priority)<br>- **Note**: "Buy milk" (saved to `#braindump`)<br>- **Memory**: "Loves dark roast coffee" | Tasks merged into notes; raw JSON schema visible in UI; hallucinated tasks not mentioned in audio. |
| **TC-BD-03** | **Interactive Triage Studio** | 1. On triage screen, cycle task priority from Med → High → Urgent.<br>2. Tap duration chips (15m, 30m, 45m, 60m).<br>3. Tap "Convert to Note" on one item. | Instant UI state update without lag. Converted item moves smoothly from Task list to Notes section. | Toggling priority resets duration; converted note disappears completely; schedule fit badge doesn't recalculate. |
| **TC-BD-04** | **Gap-Aware Auto-Scheduling Placement** | 1. Ensure 10:00–11:00 has an existing meeting.<br>2. Brain dump a 45-minute task.<br>3. Tap "Accept & Schedule". | Task is automatically scheduled in the first open gap (e.g. 11:10) respecting the 10-minute buffer. | Task overlaps 10:00 meeting; scheduled in the past; placed outside working hours without consent. |
| **TC-BD-05** | **Clarity Score & XP Bonus** | 1. Finalize triage and schedule.<br>2. Observe completion summary. | Mental declutter score banner animates; **+50 XP** floating badge pops up; confetti sparks emitter fires. | XP not added to Profile; score calculation shows `NaN` or negative; double-tap causes duplicate XP. |

---

### 3. Core Scheduler & DAG Constraint Engine

| Test ID | Test Scenario | Step-by-Step Procedure | Expected Result | What to Look For (Red Flags) |
| :--- | :--- | :--- | :--- | :--- |
| **TC-SCH-01** | **Hard Temporal Constraints** | 1. Create Task A with Earliest Start: 14:00.<br>2. Create Task B with Latest Finish: 16:00.<br>3. Run "Plan Day". | Task A is placed at or after 14:00. Task B finishes before or at 16:00. | Task A placed in morning; Task B finishes at 16:15; scheduler crashes on conflicting bounds. |
| **TC-SCH-02** | **Fixed Immovable Anchor Tasks** | 1. Create Task "Client Call" (Fixed: Yes, 11:00–12:00).<br>2. Add three flexible Priority 3 tasks.<br>3. Re-run scheduler. | "Client Call" remains strictly anchored at 11:00–12:00. Flexible tasks schedule before 11:00 or after 12:10. | Flexible high-priority tasks overwrite or shift the fixed call; fixed task loses `isFixed` flag after reschedule. |
| **TC-SCH-03** | **DAG Prerequisite Dependencies** | 1. Create Task "Draft Proposal".<br>2. Create Task "Send Proposal" with dependency on "Draft Proposal".<br>3. Schedule day. | "Draft Proposal" is placed strictly earlier than "Send Proposal" with >= 10m buffer in between. | Dependent task scheduled before prerequisite; circular dependency lockup (A depends on B, B depends on A). |
| **TC-SCH-04** | **Work-Window Policy & Late-Night Extension** | 1. Configure work hours: 09:00–17:00.<br>2. At 20:00, add a new urgent task and run auto-plan. | App applies documented same-day extension policy: extends window to 23:59 so tonight's task is placed rather than dropped. | Task rejected with error; scheduled yesterday; scheduled at 09:00 tomorrow without user notification. |
| **TC-SCH-05** | **Overload Capacity Splitting** | 1. Add 12 hours of estimated work into an 8-hour day.<br>2. Run auto-plan. | Highest-priority tasks are placed; excess tasks cleanly populate `unplacedTasks` list with transparent "no slot available" warning badge. | Tasks overlap each other; UI freezes; app crashes with unhandled exception. |
| **TC-SCH-06** | **"Why Here?" Explainability Sheet** | 1. On Planner screen, tap any scheduled task.<br>2. Select "Why was this scheduled here?". | Modal opens showing planning score breakdown: Priority weight, Energy alignment, Deadline urgency, Buffer clearance. | Blank explanation sheet; broken score progress bar; confusing negative score values without explanation. |

---

### 4. Offline Resilience & Queue Lifecycle

| Test ID | Test Scenario | Step-by-Step Procedure | Expected Result | What to Look For (Red Flags) |
| :--- | :--- | :--- | :--- | :--- |
| **TC-OFF-01** | **Airplane Mode AI Operations** | 1. Enable Airplane Mode (disable Wi-Fi & Cellular).<br>2. Run Brain Dump or Ask AI Coach a question.<br>3. Tap submit. | App does NOT crash or show blocking error modal. Displays subtle "Queued for sync when online" badge with pending counter. | Red screen crash; infinite loading spinner freezing the UI; request silently dropped and lost forever. |
| **TC-OFF-02** | **Encrypted Offline Queue Persistence Across App Kill** | 1. While still offline, enqueue 3 AI actions.<br>2. Force-quit app from OS app switcher.<br>3. Restart app while still offline. | Pending count badge shows "3 pending". Encrypted requests were safely preserved in AES-256 `aiQueueBox`. | Pending count resets to 0; app throws `HiveError` on boot; queue duplicates requests on restart. |
| **TC-OFF-03** | **Automatic Reconnection Drain** | 1. Disable Airplane Mode / restore Wi-Fi.<br>2. Observe app while in foreground. | Connectivity listener detects network resume. Queue drains automatically in FIFO order. UI updates with results without user intervention. | Double execution of same request; queue gets stuck on first item; duplicate task creation. |
| **TC-OFF-04** | **Sub-Millisecond Queue ID Collision Stress** | 1. In quick succession, tap multiple offline action buttons. | Each request receives a collision-safe ID (`method_ts_uuid`). All requests persist and drain with zero overwrite. | Only 1 request processed while others vanished; corrupted box index. |

---

### 5. AI Coach Persona, Guardrails & UI

| Test ID | Test Scenario | Step-by-Step Procedure | Expected Result | What to Look For (Red Flags) |
| :--- | :--- | :--- | :--- | :--- |
| **TC-COA-01** | **Circadian Coaching & Productivity Advice** | 1. Open AI Coach screen.<br>2. Ask: *"I'm feeling sluggish this afternoon, how should I tackle my remaining 4 tasks?"*. | Coach analyzes energy curve and suggests prioritizing low-energy tasks or taking a 15m walk. Shows animated 3-dot wave typing bubble. | Generic boilerplate response; raw JSON schema output; unresponsive typing indicator that never clears. |
| **TC-COA-02** | **Strict Scope Guardrails** | 1. Ask Coach: *"Write me a Python script for web scraping"* or *"Who won the 1998 World Cup?"*. | Coach politely declines and redirects: *"I am focused exclusively on your productivity, schedule, and habits. Let's redirect to your goals for today."* | Coach answers out-of-scope queries; coach crashes; coach gets defensive or breaks persona. |
| **TC-COA-03** | **Suppression of Raw Task JSON** | 1. Ask Coach: *"What are my top tasks today and how are they stored?"*. | Coach provides clean markdown bullet points. Zero internal Hive JSON properties (e.g. `{"id": "...", "priority": 3}`) are visible to the user. | Any raw JSON strings, brackets `{}` or code blocks containing internal data model properties leaking into the chat. |
| **TC-COA-04** | **Chat History Persistence** | 1. Have a 5-message conversation with Coach.<br>2. Force close and relaunch app.<br>3. Re-open AI Coach. | Entire conversation history restored seamlessly with correct avatars, timestamps, and formatting. | Empty chat history; messages duplicated; inverted chronological order. |

---

### 6. Google Calendar Sync & Remote Consistency

| Test ID | Test Scenario | Step-by-Step Procedure | Expected Result | What to Look For (Red Flags) |
| :--- | :--- | :--- | :--- | :--- |
| **TC-CAL-01** | **Google OAuth Sign-In** | 1. Go to Settings → Calendar Integration.<br>2. Tap "Connect Google Calendar".<br>3. Complete Google OAuth consent. | Account connects successfully. OAuth token bundle stored securely in `SecureKeyService`. | Auth modal hangs; token stored in plain text; silent failure without feedback. |
| **TC-CAL-02** | **Initial Full Sync Verification** | 1. After sign-in, trigger Sync.<br>2. Open Calendar screen in AutoPlanner. | All upcoming Google Calendar events for the week appear with correct titles, start times, and durations. | Missing events; all-day events mapped to wrong hours; timezone offset shifting events by hours. |
| **TC-CAL-03** | **Incremental Sync via `syncToken`** | 1. Open Google Calendar on web/another device.<br>2. Add a new event: *"Team Standup at 10am"*. Edit another event.<br>3. Open AutoPlanner AI. | Incremental sync detects delta changes via stored `syncToken`. New event appears; edited event updates. | Duplicate events created; full re-download of all historical events; high battery/network spike. |
| **TC-CAL-04** | **Cancelled Event Purge** | 1. Delete an event on Google Calendar.<br>2. Sync AutoPlanner. | Corresponding event is cleanly removed from AutoPlanner's local calendar box and scheduler. | "Ghost" events remaining; scheduler still treating deleted event as a busy block. |
| **TC-CAL-05** | **410 Gone Recovery** | 1. Simulate invalid/expired sync token.<br>2. Trigger sync. | App catches 410 error, clears token, and performs a clean full sync without crashing. | App permanently fails to sync; user stuck in broken sync loop. |

---

### 7. Multi-Tier Notifications & Daily Alarms

| Test ID | Test Scenario | Step-by-Step Procedure | Expected Result | What to Look For (Red Flags) |
| :--- | :--- | :--- | :--- | :--- |
| **TC-NOT-01** | **Task Reminder Notification** | 1. Schedule a task 15 minutes from now with a 10m reminder lead time.<br>2. Lock the device screen.<br>3. Wait 5 minutes. | Device vibrates and rings with task reminder notification showing task title and scheduled start time. | Notification fires late or not at all; notification fires after task has already completed; wrong timezone. |
| **TC-NOT-02** | **Priority 3 Urgent Alert Channel** | 1. Schedule an Urgent (Priority 3) task.<br>2. Verify notification arrival. | Notification routes to `autoplanner_urgent` channel with heads-up banner and high-priority sound. | Urgent alerts treated as silent low-priority alerts. |
| **TC-NOT-03** | **Streak Shield 20:00 Reminder** | 1. Do not complete any tasks during the day.<br>2. Wait for 20:00 local time. | App delivers Streak Shield warning alerting user that their active streak is at risk. | Reminder fires at wrong hour; reminder fires even after user already completed their Big 3. |
| **TC-NOT-04** | **Notification Tap Navigation** | 1. Tap an incoming task reminder notification while device is locked or in another app. | Device unlocks (if needed) and AutoPlanner deep-links directly to the relevant task detail view. | App opens to blank screen; app crashes on cold start from notification payload. |

---

### 8. Gamification, Mastery Ranks & Daily Rituals

| Test ID | Test Scenario | Step-by-Step Procedure | Expected Result | What to Look For (Red Flags) |
| :--- | :--- | :--- | :--- | :--- |
| **TC-GAM-01** | **Morning Kickoff Ritual** | 1. Launch app in the morning.<br>2. Tap Morning Kickoff card on Dashboard.<br>3. Select "The Big 3" priorities.<br>4. Tap "Lock in My Day". | Confetti celebration triggers, **+50 XP** awarded, Big 3 tasks highlighted on Dashboard with glowing badges. | Big 3 selection lost upon navigating away; morning kickoff card does not dismiss; XP awarded multiple times. |
| **TC-GAM-02** | **Evening Shutdown Ritual** | 1. Launch app in the evening (after 18:00).<br>2. Tap Evening Shutdown card.<br>3. Triage remaining tasks (Tomorrow / Backlog).<br>4. Write 1-line reflection. | Day summary displays completion velocity. 1-line reflection saved to Memory graph. **+50 XP** awarded. | Yesterday's tasks disappear without triage; reflection not saved; card still shows Morning Kickoff. |
| **TC-GAM-03** | **Streak Multiplier Progression** | 1. Complete tasks on consecutive days.<br>2. Check Profile streak status. | Streak count increments (`🔥 3d • 1.3x`); XP multiplier correctly scales earned XP. | Streak resets despite tasks completed; multiplier calculation incorrect. |
| **TC-GAM-04** | **Mastery Rank Level-Up Celebration** | 1. Accumulate enough XP to reach next level threshold (e.g. Level 2 at 500 XP). | Fullscreen `LevelUpDialog` appears with particle confetti, sound/haptic feedback, and unlocked rank title. | Level-up dialog fails to dismiss; XP bar overflows past 100%; rank title does not update. |

---

### 9. Sensory & Ergonomic Hardware Polish

| Test ID | Test Scenario | Step-by-Step Procedure | Expected Result | What to Look For (Red Flags) |
| :--- | :--- | :--- | :--- | :--- |
| **TC-UI-01** | **5-Slot Navigation Dock Usability** | 1. Rapidly tap across all 5 dock items (`Dashboard`, `Planner`, `[Brain Dump]`, `Focus`, `AI Coach`).<br>2. Tap central Brain Dump hero button. | Smooth haptic feedback, fluid animated tab indicator, zero overlapping floating action button (FAB) collision. | Center action button covers bottom tab labels; dock gets cut off by Android system navigation bar / iOS home indicator. |
| **TC-UI-02** | **Screen Densities & Layout Overflow** | 1. Test on a small screen device (e.g. 5.5" Android, iPhone SE) and large screen (6.7" Android, Pro Max).<br>2. Set System Font Size to "Largest" in OS Settings. | All headers, chips, and cards wrap with `Flexible` / `FittedBox`. Zero yellow-and-black "RenderFlex overflowed by X pixels" banners. | Yellow-black striped overflow banners; text overlapping buttons; unscrollable modals. |
| **TC-UI-03** | **System Dark & Light Theme Contrast** | 1. Toggle OS between Dark and Light mode.<br>2. Inspect all screens (Planner, Calendar, Memory, Notes). | High-contrast readability preserved; frosted glass cards retain readable text; glowing gradient headers distinct. | Black text on dark background; invisible card borders; washed out pastel colors. |
| **TC-UI-04** | **Focus Mode Immersion & Celebration** | 1. Start a 25m Focus Session.<br>2. Test +5m extension chip.<br>3. Tap "Complete Early". | Radial countdown timer animates smoothly. Completion triggers confetti celebration, awards XP, and logs actual minutes. | Screen turns off during focus mode (wake-lock failed); timer desyncs when app minimized; confetti causes UI freeze. |

---

### 10. Fault Injection & Edge-Case Stress Testing

| Test ID | Test Scenario | Step-by-Step Procedure | Expected Result | What to Look For (Red Flags) |
| :--- | :--- | :--- | :--- | :--- |
| **TC-FLT-01** | **Memory Pressure / OS Process Termination** | 1. Fill day with 15 tasks.<br>2. Put AutoPlanner in background.<br>3. Launch heavy memory app (e.g. 3D Game, Camera app 4K video recording).<br>4. Return to AutoPlanner. | OS cold-restarts app; state is restored seamlessly from Hive; exact current view and pending tasks intact. | White screen hang; crash on restore; loss of today's scheduled tasks. |
| **TC-FLT-02** | **Simulated Database Corruption Quarantine** | 1. Close app.<br>2. Corrupt a byte in `tasksBox.hive` using debug tool.<br>3. Launch app. | `AppBootstrapper.openBoxSafe` catches corruption, creates verified `.corrupt.<timestamp>.bak` file, quarantines, and recreates clean box without crash. | Silent deletion of user data without backup; infinite boot crash loop. |
| **TC-FLT-03** | **Rapid Task Creation Stress** | 1. Use quick-add to add 25 tasks in under 30 seconds. | All 25 tasks are assigned unique IDs, written to `tasksBox`, and rendered cleanly in the backlog. | UI freezes; duplicate IDs; database lock error. |
| **TC-FLT-04** | **Battery / Thermal Endurance** | 1. Run app continuously for 45 minutes with periodic scheduling and focus mode. | CPU usage drops to < 2% when idle; battery drain within normal bounds (< 5% per hour active); phone does not overheat. | Persistent background CPU drain; audio recording service failing to release; runaway timer loops. |

---

## 📝 Beta Tester Feedback Form Template

When reporting findings, beta testers should use this concise template:

```markdown
### Beta Test Report

* **Tester Name / Device**: (e.g., Jane Doe / Pixel 8 Pro / Android 14)
* **App Version / Build**: 2.3.1 (Commit 41a8315)
* **Test Case ID**: (e.g., TC-BD-01)
* **Severity**: [P0 Blocker / P1 High / P2 Quality / P3 Polish]
* **Summary**: Brief 1-line description of the issue.

#### Steps to Reproduce:
1. 
2. 
3. 

#### Expected Behavior:
What should have happened.

#### Actual Behavior:
What actually happened (include screenshots or screen recording if applicable).

#### Connectivity & State:
* Network: [Wi-Fi / 5G / Airplane Mode]
* Battery Saver: [On / Off]
* System Theme: [Dark / Light]
```
