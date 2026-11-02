# AutoPlanner AI — Google Play Store Release Guide

This guide provides a comprehensive, step-by-step walkthrough to sign, package, test, and release **AutoPlanner AI (v3.0.0+1)** to the **Google Play Store**.

---

## 📋 Table of Contents
1. [Prerequisites](#1-prerequisites)
2. [Step 1: Generate Release Keystore](#2-step-1-generate-release-keystore)
3. [Step 2: Configure `key.properties`](#3-step-2-configure-keyproperties)
4. [Step 3: Verify Build & ProGuard Rules](#4-step-3-verify-build--proguard-rules)
5. [Step 4: Build the Release Android App Bundle (AAB)](#5-step-4-build-the-release-android-app-bundle-aab)
6. [Step 5: Google Play Console Setup](#6-step-5-google-play-console-setup)
7. [Step 6: Data Safety & Store Declarations](#7-step-6-data-safety--store-declarations)
8. [Step 7: Testing Tracks & Production Rollout](#8-step-7-testing-tracks--production-rollout)
9. [Pre-Launch Checklist & Pitfall Avoidance](#9-pre-launch-checklist--pitfall-avoidance)

---

## 1. Prerequisites
- **Flutter SDK**: 3.x+ (`flutter doctor` all green)
- **JDK**: Java 17+ with `keytool` installed and available in PATH
- **Google Play Developer Account**: Registered at [play.google.com/console](https://play.google.com/console) ($25 one-time registration fee)
- **App Version**: `3.0.0+1` (already set in `pubspec.yaml`)

---

## 2. Step 1: Generate Release Keystore

The keystore is a cryptographically signed file used by Google Play to verify that updates come from you.

Open PowerShell in the project root directory and run:

```powershell
keytool -genkey -v -keystore android/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

You will be prompted for:
1. **Keystore password**: Choose a strong password and save it in a password manager.
2. **First and last name**: Your name or organization name (e.g. `AutoPlanner Team`).
3. **Organizational unit & Organization**: e.g. `Productivity`.
4. **City, State, Country code**: e.g. `US`, `ZA`, `GB`, etc.
5. **Key password**: Press Enter to use the same password as the keystore.

> ⚠️ **CRITICAL SECURITY NOTE**: Never commit `upload-keystore.jks` or `key.properties` to Git. Keep an encrypted backup of `upload-keystore.jks` in a secure location (e.g., 1Password, Google Drive, or Bitwarden). If you lose this key, you cannot update your app on the Play Store!

---

## 3. Step 2: Configure `key.properties`

1. Duplicate `android/key.properties.example` and name the new file `android/key.properties`:

```powershell
Copy-Item android/key.properties.example android/key.properties
```

2. Open `android/key.properties` and replace the placeholders with your actual passwords:

```ini
storePassword=YOUR_SECURE_KEYSTORE_PASSWORD
keyPassword=YOUR_SECURE_KEYSTORE_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

*Note: `storeFile=../upload-keystore.jks` is relative to the `android/app/` directory where Gradle executes.*

---

## 4. Step 3: Verify Build & ProGuard Rules

AutoPlanner is already configured for production release:
- **`android/app/proguard-rules.pro`**: Configured to preserve Hive type adapters, Flutter plugins, and Riverpod state controllers while obfuscating release code.
- **`android/app/build.gradle.kts`**:
  - `minSdk` / `targetSdk`: managed by the Flutter SDK (Flutter 3.47.2), which keeps `targetSdk` at the level Google Play currently requires
  - `compileSdk`: 37
  - R8 shrinkResources and minifyEnabled enabled for minimal app download size.
  - Building a release app bundle **fails** if `android/key.properties` is missing, so a debug-signed bundle can never be produced by accident.

---

## 5. Step 4: Build the Release Android App Bundle (AAB)

### Recommended: release from CI

Pushing a version tag runs `.github/workflows/release.yml`, which analyzes, tests, signs and builds the AAB and APK with production configuration. Configure these once under **GitHub → Settings → Secrets and variables → Actions**:

| Name | Kind | Required | Value |
|---|---|---|---|
| `KEYSTORE_BASE64` | Secret | Yes | `base64 -w0 android/upload-keystore.jks` (PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\upload-keystore.jks"))`) |
| `KEY_STORE_PASSWORD` | Secret | Yes | Keystore password |
| `KEY_ALIAS` | Secret | Yes | e.g. `upload` |
| `KEY_PASSWORD` | Secret | Yes | Key password |
| `SENTRY_DSN` | Secret | No | Enables crash reporting |
| `GOOGLE_SERVER_CLIENT_ID` | Variable | For Calendar sync | Web OAuth client ID |
| `GEMINI_MODEL` | Variable | No | Overrides the default Gemini model if Google retires it |
| `ENABLE_IOS_RELEASE` | Variable | No | Set to `true` once iOS signing is configured |

Then bump `version:` in `pubspec.yaml` (the build number after `+` must increase for every Play upload), commit, and tag:

```powershell
git tag v3.0.0
git push origin v3.0.0
```

Download `android-release-aab` from the workflow run's artifacts. Keep `android-debug-symbols` too — you need it to read obfuscated stack traces.

> Never pass `GEMINI_API_KEY` to a release build: compiled-in keys can be extracted from the app. Users enter their own key in Settings.

### Local build

```powershell
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=ENV=prod `
  --obfuscate --split-debug-info=build/debug-info-android
```

Release builds do not bundle a `.env` file. Configuration comes from `--dart-define` (or `--dart-define-from-file`); without `ENV=prod` the app runs as a `[DEV]` build.

When completed, your release bundle will be located at:
```
build/app/outputs/bundle/release/app-release.aab
```

Verify that the file size is optimized (typically ~25–35 MB before Google Play Dynamic Delivery splits it into ~12–18 MB download packages per device).

---

## 6. Step 5: Google Play Console Setup

1. Go to [Google Play Console](https://play.google.com/console).
2. Click **Create app**:
   - **App name**: `AutoPlanner AI: Smart Day Planner`
   - **Default language**: English (United States) — `en-US`
   - **App or game**: App
   - **Free or paid**: Free
   - Accept the Developer Program Policies and US Export Laws.
3. Click **Create app**.

### Store Listing Assets Needed:
- **Short description** (max 80 chars):
  `Smart day planner & focus assistant that automatically organizes your schedule.`
- **Full description** (max 4000 chars):
  See [Store Description Template](#store-description-template) below.
- **App icon**: 512 × 512 px, 32-bit PNG with alpha.
- **Feature graphic**: 1024 × 500 px, JPG or 24-bit PNG (no alpha).
- **Phone screenshots**: At least 4 screenshots (aspect ratio 16:9 or 9:16, e.g. 1080 × 2400 px) showing:
  1. *Brain Dump Studio* (Voice recording & automatic sorting)
  2. *Planner Timeline* (Conflict-free daily schedule & capacity indicator)
  3. *Focus Hub* (Radial timer & ambient soundscapes)
  4. *AI Coach* (Conversational planning mentor)

---

## 7. Step 6: Data Safety & Store Declarations

Google Play requires accurate Data Safety disclosures:

Play's definitions: data is **collected** when it is transmitted off the device, and **shared** when it goes to a third party. Data that only ever stays on the device does not need to be declared. Data sent to a service provider that processes it on your behalf counts as collected, not shared. AI requests go **directly from the device to Google** with the user's own API key, so declare them as collected. Do **not** mark them "processed ephemerally": Google may retain free-tier Gemini API content. Answers to give:

| Data type (Play category) | Collected | Shared | Optional | Purpose | Why |
|---|---|---|---|---|---|
| **App activity → Other user-generated content** (tasks, notes, goals, coach chat, dictated text) | Yes | No | Yes | App functionality | Sent to Google Gemini when the user runs an AI feature |
| **Calendar → Calendar events** | Yes | No | Yes | App functionality | Read/written via the Google Calendar API when sync is connected; stored only on device |
| **Personal info → Email address** | Yes | No | Yes | App functionality | Google Sign-In for Calendar sync |
| **App info and performance → Crash logs, Diagnostics** | Yes, if `SENTRY_DSN` is set | No | No | Analytics (crash reporting) | Sentry crash reports |
| **Audio** | No | — | — | — | Speech is converted to text by the OS recognizer; the app never receives or uploads audio |

Also answer:
- **Is data encrypted in transit?** Yes (HTTPS only; cleartext traffic is disabled).
- **Can users request deletion?** Yes — all data is on-device (uninstall / clear storage); calendar access is revocable in Settings and the Google account.
- **Account creation**: the app has no accounts, so the account-deletion URL requirement does not apply.

- **Privacy Policy**: `docs/PRIVACY_POLICY.md`. Fill in the `[CONTACT EMAIL]` and `[EFFECTIVE DATE]` placeholders, then publish it at a public URL. The simplest option is GitHub Pages: **Settings → Pages → Deploy from branch → `main` / `/docs`**, which serves it at `https://kevinkutoane.github.io/autoplanner_ai/PRIVACY_POLICY`. Put the same URL in the Play listing and in the Google Cloud OAuth consent screen.
- **Google Calendar OAuth verification**: the app requests the `https://www.googleapis.com/auth/calendar` scope, which Google classifies as **sensitive**. Until the OAuth consent screen is verified by Google, Calendar sign-in shows an "unverified app" warning and is capped at 100 users. Submit for verification (privacy policy URL, app home page, scope justification and a demo video) well before production rollout.
- **Target Audience**: 18+ (Productivity / Business).
- **Ads**: Declare **No, my app does not contain ads**.

---

## 8. Step 7: Testing Tracks & Production Rollout

### Track 1: Internal Testing (Immediate)
1. Go to **Testing** → **Internal testing**.
2. Create a new release, upload `build/app/outputs/bundle/release/app-release.aab`.
3. Add your personal Google account to the email list.
4. Open the join link on your Android phone and install the app from Google Play.
5. Verify on-device:
   - Voice Brain Dump records and transcribes.
   - Planner loads sample day or new tasks without crashes.
   - Focus Hub audio soundscapes play cleanly.
   - Offline Mode works with airplane mode turned on.

### Track 2: Closed Testing (Play Store Requirement)
- For personal Google Play accounts created after November 2023, Google requires **20 testers opted in for at least 14 days** before applying for production access.
- Invite 20 friends, beta testers, or colleagues to the closed testing track.

### Track 3: Production Rollout
- Once closed testing criteria are met, click **Promote release** → **Production**.
- Roll out at 100% or staged rollout (e.g., 20% on Day 1, 50% on Day 2, 100% on Day 3).

---

## 9. Pre-Launch Checklist & Pitfall Avoidance

- [x] Version set in `pubspec.yaml`; build number increased for every Play upload.
- [x] All unit and widget tests passing (`flutter test`; 732 as of October 2026).
- [x] Zero analyzer issues (`flutter analyze lib test --fatal-infos`).
- [x] `USE_EXACT_ALARM` removed (Play restricts it to alarm/calendar apps); reminders fall back to inexact alarms when exact alarms are not granted.
- [ ] Privacy policy published and linked in Play Console and the OAuth consent screen.
- [ ] Direct Gemini mode verified on a physical device with a real API key.
- [ ] Data Safety form completed per Step 6.
- [ ] Release secrets configured in GitHub (see Step 4).
- [x] ProGuard keep rules verified in `android/app/proguard-rules.pro`.
- [x] Graceful offline fallback verified in AI Coach (no raw debug error strings).
- [x] Dead buttons eliminated (no developer placeholders or unlinked tiles).
- [x] `android/key.properties` and keystore excluded from Git (`.gitignore`).
- [x] High-resolution screenshots captured.

---

### Store Description Template

```
AutoPlanner AI is your personal smart day planner and focus assistant.

Stop stressing over chaotic to-do lists and overlapping schedules. AutoPlanner takes your random thoughts, voice notes, and commitments and automatically transforms them into an optimized, conflict-free daily schedule.

✨ KEY FEATURES:

🎙️ EFFORTLESS BRAIN DUMP
Speak or type your thoughts freely. AutoPlanner automatically sorts them into actionable tasks, milestones, reference notes, and ideas.

⚡ SMART CONFLICT-FREE SCHEDULING
Intelligent day planning that fits tasks around your calendar meetings, respects your working hours, and adds breathing room so you never feel rushed.

🔄 AUTOMATIC SCHEDULE CATCH-UP
When tasks run long or meetings run over, AutoPlanner automatically recalculates your remaining day and shifts tasks forward.

🎯 DEEP FOCUS HUB & SOUNDSCAPES
Enter flow state with customizable Pomodoro timers, relaxing ambient sounds (Rain, Cafe, White Noise, Binaural Beats), and a scratchpad to offload distractions.

🧠 AI PRODUCTIVITY COACH
Get immediate, encouraging guidance to structure your day, break down ambitious goals, and defeat procrastination.

🛡️ PRIVATE BY DESIGN & OFFLINE READY
Your data is stored encrypted on your device, with no accounts and no ads. AI features use your own Google Gemini key; the built-in offline planner works without one.
```
