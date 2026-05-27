# Changelog

All notable changes to AutoPlanner AI are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] — 2026-05-27

### Initial Production Release

#### Core Features
- AI-powered task scheduling with Gemini API integration
- Natural-language Brain Dump — capture tasks and let AI organise them
- Daily planner with drag-and-drop rescheduling
- Goal tracking with milestone decomposition
- Notes with AI summarisation
- Projects workspace for multi-task groupings
- Weekly review and analytics dashboard
- Morning briefing — daily AI summary at a configurable time
- Offline AI queue — requests queued when offline and drained on reconnect

#### Platform & Infrastructure
- Hive local persistence (no cloud dependency by default)
- Google Calendar two-way sync
- Google Sign-In OAuth
- Biometric app lock (Face ID / fingerprint)
- Local push notifications with exact-alarm scheduling
- Android home-screen widget (today's task count)
- Encrypted backup / restore (export to file, import from file)
- Token usage tracker with configurable daily cap

#### Quality
- 364 unit tests, 0 analyzer issues
- ProGuard minification + resource shrinking on Android release builds
- Dart obfuscation with split debug symbols on release builds
- ErrorBoundary wired at app root for graceful crash recovery
- Connectivity banner for offline awareness
