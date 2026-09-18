# Changelog

This file records notable commit-level changes. Update it before every commit using the entry format below.

## Unreleased

### 2026-09-18 - Mathew Joseph - pending
Added a pure-Dart milestone engine (age filtering, yes/no tally, normal/warning status) plus a Hindi CDC-milestone question asset.
The optional questionnaire now has a scoring contract: two or more missed age-applicable milestones flag a warning context that never gates the acoustic result.

### 2026-09-18 - Mathew Joseph - pending
Added unit tests for SessionRepository (in-memory SQLite CRUD round-trips) and SyncRepository (fake upload port covering success, failure, and offline paths).
Locks in the data-layer contract: 12 new tests cover ordering, sync-flag transitions, cascade deletes, consent logs, and queue draining.

### 2026-09-18 - Mathew Joseph - pending
Added Riverpod providers for sync state: repository wiring plus a SyncNotifier exposing pending count, isSyncing, and the last sync result.
The UI can now observe the upload queue and trigger a sync pass when connectivity returns.

### 2026-09-18 - Mathew Joseph - pending
Added the Supabase schema for the screenings table and a matching consent_logs audit table, both with insert-only RLS policies.
Defines the cloud sink for synced biomarker rows and consent confirmations scoped to the worker's Anganwadi JWT claim.

### 2026-09-18 - Mathew Joseph - pending
Added SyncRepository that drains the unsynced queue through an injectable ScreeningUploader port backed by Supabase upserts.
Successful uploads flip the synced flag while failures stay queued for retry; an uninitialized client reports an offline result instead of throwing.

### 2026-09-18 - Mathew Joseph - pending
Added SessionRepository with CRUD over the sessions table plus consent-log writes for the audit trail.
The app can now save screenings, query history newest-first, track the unsynced queue, and record timestamped parental consent.

### 2026-09-18 - Mathew Joseph - pending
Added a SQLite database helper that opens earlyecho.db at version 1 with sessions and consent_logs tables and foreign keys enabled.
Screening sessions now have a durable on-device store whose schema mirrors the cloud columns, plus a consent audit trail.

### 2026-09-18 - Mathew Joseph - pending
Added sqflite_common_ffi as a dev dependency so repositories can be tested against an in-memory SQLite database.
Enables data-layer unit tests to exercise real SQL without a device or emulator.

### 2026-09-18 - Mathew Joseph - pending
Wired the app shell together: a GoRouter with all ten routes, a ProviderScope-wrapped MaterialApp.router entry point, and router widget tests.
The app now boots into the home screen and every placeholder is reachable; a smoke test taps through the full seven-step screening flow.

### 2026-09-18 - Mathew Joseph - pending
Added placeholder screens for home, result history and settings, each with a widget test.
Completes the set of app destinations: the home screen links into the screening flow, past results and settings.

### 2026-09-18 - Mathew Joseph - pending
Added placeholder screens for elicitation, processing, result and referral with widget tests.
Completes the screening flow as navigable placeholders, including the three timed protocol rows and the risk-band legend.

### 2026-09-18 - Mathew Joseph - pending
Added shared UI widgets plus placeholder screens for child profile, questionnaire and consent, each with a widget test.
Builds the first half of the screening flow as navigable Hindi-first placeholders styled with the new theme.

### 2026-09-18 - Mathew Joseph - pending
Added the EarlyEcho app theme and shared app constants (channel name, protocol timings, age bounds, audio format).
Establishes the worker-centric visual foundation: India-inspired saffron/teal Material 3 palette, enlarged text, and 48dp+ tap targets for outdoor use.

### 2026-09-18 - Mathew Joseph - pending
Added a rule to the agent working agreement requiring minimum relevant test coverage per change and non-redundant CI tests.
Keeps future test and workflow additions focused on what each change actually exercises.

### 2026-09-18 - Mathew Joseph - pending
Scaffolded the Flutter app skeleton (models, scoring engine, referral text builder) with unit tests and added a GitHub Actions CI workflow.
Every push and pull request to main now runs format checks, static analysis, and the test suite; main pushes also build a release APK artifact.

## Commit Entry Format

### YYYY-MM-DD - Human Author - short-hash
Describe what changed in one concise sentence.
Describe the user, system, or maintenance impact in a second concise sentence.

## History
