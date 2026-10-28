# AutoPlanner AI — Privacy Policy

**Effective date:** [EFFECTIVE DATE]
**Contact:** [CONTACT EMAIL]

AutoPlanner AI ("the app") is a local-first planner. It has no user accounts and
no AutoPlanner server that stores your data. This policy explains what the app
stores, what leaves your device, and why.

## Data stored on your device

Your tasks, notes, goals, projects, memories, focus history, settings and
imported calendar events are stored only on your device, in a database
encrypted with AES-256. The encryption key is kept in the Android Keystore or
iOS Keychain.

Your Google Gemini API key, if you add one, is stored in the Android Keystore
or iOS Keychain.

Biometric unlock (fingerprint or face) is handled entirely by your device's
operating system. The app never receives or stores biometric data.

## Data that leaves your device

The app sends data off your device only in the cases below.

### AI features (Google Gemini)

When you use an AI feature (Brain Dump, AI Coach, day or week planning,
note summaries, tag suggestions, insights, reviews or schedule commands), the
app sends the relevant text directly to Google's Gemini API, using the API key
you provided. Depending on the feature, this can include:

- what you typed or dictated
- titles, times and details of your tasks
- note content
- your goals
- short memories the app has saved to personalise suggestions

This data is processed by Google under the
[Gemini API Additional Terms of Service](https://ai.google.dev/gemini-api/terms)
and the [Google Privacy Policy](https://policies.google.com/privacy).
**If your API key is on Google's free tier, Google may use the content you
submit to improve its products, and it may be read by human reviewers.** Do
not submit sensitive personal information through AI features if this
concerns you, or use a paid-tier key.

AI features are optional. The app works without an API key using its built-in
offline planner.

### Voice input

Brain Dump voice input uses your device's built-in speech recognition service.
On many Android devices this is provided by Google and may process audio on
Google's servers. The app receives only the resulting text and does not record
or store audio.

### Google Calendar (optional)

If you connect Google Calendar, the app uses Google Sign-In to request
permission to view and edit your calendars. It downloads your events to show
them next to your tasks and to avoid scheduling conflicts. It writes changes
back to your calendar only when you schedule or move items yourself. Calendar
data is stored only on your device and is not sent anywhere else.

You can disconnect Google Calendar at any time in Settings, and revoke access
at [myaccount.google.com/permissions](https://myaccount.google.com/permissions).

AutoPlanner AI's use and transfer of information received from Google APIs
adheres to the
[Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy),
including the Limited Use requirements.

### Crash reports

Release builds may send crash reports to Sentry, a crash monitoring service,
so that bugs can be fixed. A crash report contains technical information:
the error and stack trace, app version, device model and operating system
version. Error messages could occasionally include fragments of app data.
Crash reports are not used for advertising or profiling.

### Backups you export

When you export a backup, the app creates a JSON file containing your data and
opens your device's share sheet. **The backup file is not encrypted.** Where
it goes is up to you; store it somewhere you trust.

## What the app does not do

- No advertising and no advertising identifiers
- No analytics or usage tracking
- No selling or sharing of your data with data brokers or advertisers
- No account creation and no AutoPlanner-operated data storage

## Notifications and permissions

The app asks for notification, exact alarm, microphone, speech recognition and
biometric permissions only to provide reminders, voice input and app lock.
All are optional and can be changed in your device settings.

## Deleting your data

All app data lives on your device. To delete it, uninstall the app or clear
its storage in your device settings. To delete data sent to Google through AI
features, see your Google account's data controls. To remove calendar access,
disconnect in Settings or revoke access in your Google account.

## Children

The app is not directed at children under 13 and does not knowingly collect
data from them.

## Changes to this policy

If this policy changes, the updated version will be posted at this address with
a new effective date.

## Contact

Questions about this policy: [CONTACT EMAIL]
