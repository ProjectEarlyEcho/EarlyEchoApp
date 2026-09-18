# Changelog

This file records notable commit-level changes. Update it before every commit using the entry format below.

## Unreleased

### 2026-09-19 - Mathew Hans
Added `hardware/cardsensor.ino`, an ESP32 Hall-effect card sensor sketch with startup baseline calibration, NORTH/SOUTH classification, a deadzone, and rolling majority filtering.

### 2026-09-19 - Mathew Hans
Added a temporary home-screen Gemini Live control that opens a persistent WebSocket, streams 16 kHz PCM microphone audio, and continuously feeds 24 kHz model PCM output to the phone audio route.
Pairing an ESP32 A2DP sink as a Bluetooth speaker now needs no Flutter Bluetooth transport; microphone uplink is muted while model audio plays to reduce acoustic echo.
Android capture explicitly uses the microphone source without Bluetooth SCO management, and the app now requests network access for the Live API socket.
Static analysis has been run with the updated local Flutter SDK; the existing widget suite currently has localisation expectation failures outside this integration.
Added a home widget assertion so the temporary Gemini Live entry point remains visible.
Added a gitignored local Dart-defines file for supplying the Gemini API key from Android Studio without committing the secret.
Serialized Gemini PCM playback writes after a native Android AudioTrack crash caused by overlapping Flutter Sound feed operations.
Configured Gemini's own automatic activity detection with a 700 ms server-side silence threshold and added live input transcription feedback to diagnose whether the service hears each utterance.

### 2026-09-18 - Mathew Joseph
Aligned the screening flow with MozhiMuthal: added the complete MyChild questionnaire engine and dedicated age-based CDC developmental goals, fixed locale-aware English/Hindi rendering, and passed child age into native audio analysis.
Added per-activity voice skips plus real locale-selected Hindi and English parental-consent audio, each shorter than 15 seconds.

### 2026-09-18 - Mathew Joseph
Localized every user-facing screen string through AppStrings — home, enrollment, questionnaire, consent, elicitation protocols, processing, result, referral, history and settings all render in the chosen language.
A language row in settings re-opens the picker; tests keep passing under the Hindi default.

### 2026-09-18 - Mathew Joseph
Added first-run language selection (English/Hindi): a `/language` picker screen gated by router redirect until the choice is persisted in SharedPreferences, an AppStrings table with `tr`/`trf` lookups covering all UI text, and `flutter_localizations` delegates so Material chrome follows the `hi` locale.
Hindi remains the default; the picker only appears when no choice has been saved.

### 2026-09-18 - Mathew Joseph
Mocked the `com.earlyecho/audio_pipeline` MethodChannel in widget tests via a shared helper with canned COMPLETE/INCOMPLETE payloads, and updated the elicitation, processing, result, and routes tests for the live pipeline flow.
The full screening walkthrough now exercises permission → capture → analysis → scored result → referral end to end off-device.

### 2026-09-18 - Mathew Joseph
Scored the result screen from the pipeline outcome: RED/YELLOW/GREEN banner, Hindi explanation, per-biomarker flag chips, referral CTA on RED only, and a retry path for INCOMPLETE analyses instead of a verdict.
COMPLETE results persist SessionModel to SQLite, link the consent audit row, and refresh the sync queue; persistence failures never blank the result.

### 2026-09-18 - Mathew Joseph
The processing screen now stops capture, invokes `runPipeline`, parses the feature vector via `SessionFeatures.fromChannelMap`, scores it with `ScoringEngine`, and auto-advances to the result.
Channel failures surface a retry affordance instead of a screening outcome.

### 2026-09-18 - Mathew Joseph
Added the Dart-side audio pipeline service (requestPermission/startRecording/stopRecording/runPipeline + waveform EventChannel stream) and extended session state to carry the parsed features, scored result, and raw channel payload.
The elicitation flow now opens mic capture on the first protocol and releases it when the sequence completes, feeding the recorded protocol timings into the pipeline request.

### 2026-09-18 - Mathew Joseph
Wired the audio pipeline method channel in MainActivity: `requestPermission`, `startRecording`, `stopRecording`, and `runPipeline` return the full feature-vector contract (VTTL, PFV semitone SD + z-score, CVR, flags, quality reasons, 256-point waveform, decision trace), with a waveform EventChannel for visual levels.
Recording runs a rolling-window loop on a single-thread executor with generation guards, low-memory window selection, and permission checks; `analysis_status` is COMPLETE only when voiced/child/transition minimums are met.

### 2026-09-18 - Mathew Joseph
Bundled the pinned INT8 segmentation ONNX model under `android/app/src/main/assets/models/` with a SHA256SUMS manifest and a `verifySegmentationModel` Gradle task wired into `preBuild`.
The APK now carries the diarization model and fails the build if the model or its checksum is missing, so releases never ship an unverifiable model artifact.

### 2026-09-18 - Mathew Joseph
Added FeatureExtractor and RollingBufferProcessor: segments are labelled ADULT/CHILD via the F0 heuristic (<200 Hz adult, >250 Hz child, ambiguous band excluded), VTTL uses the median of 500 ms-binned adult→child gaps, CVR is child voiced ms over session ms, and each 10 s window (5 s under low memory) runs VAD → diarization → extraction independently.
Turn math lives in pure-Kotlin companion functions so VTTL/CVR behaviour is JVM-testable without Android classes.

### 2026-09-18 - Mathew Joseph
Added the diarization and pitch-analysis core: PyannoteRunner wraps ONNX Runtime around the bundled INT8 segmentation model and merges per-frame log-probabilities into voiced turns, while PfvAnalyzer implements YIN F0 tracking, contour cleaning, and z-score normalization across the three EarlyEcho age buckets (12–24, 24–36, 36–60 months).
Pins onnxruntime-android 1.18.0 and the WebRTC VAD artifact plus JUnit for the JVM tests; speaker labels and biomarker math build on these next.

### 2026-09-18 - Mathew Joseph
Added the Kotlin capture front-end for the native audio pipeline: UnprocessedAudioRecorder opens 16 kHz mono 16-bit PCM on AudioSource.UNPROCESSED with a VOICE_RECOGNITION fallback that reports which source was used, and WebRTCVadBridge produces the 30 ms binary speech/silence frame mask at aggressiveness level 2.
Declares the RECORD_AUDIO permission; capture degrades to the fallback source instead of failing when the raw source is unavailable.

### 2026-09-18 - Mathew Joseph
Replaced the elicitation placeholder with the guided three-protocol sequence: worker-tapped starts, per-protocol Hindi instruction audio, explicit countdown ring, protocol X/3 plus overall progress, and a decorative waveform; a testable ElicitationController owns sequencing while the widget drives one-second ticks.
Finishing all three protocols records the §5.1 protocol_timings onto the session and routes to /processing; playback failures degrade to the on-screen instruction and never block the flow.

### 2026-09-18 - Mathew Joseph
Added SessionState.protocolTimings plus recordProtocolTimings, carrying per-protocol capture windows in the §5.1 contract shape ([{'protocol': 'rattle', 'start_ms': 0, 'end_ms': 60000}, ...]).
The guided elicitation sequence can now hand the native audio pipeline its timing contract without breaking any existing session state.

### 2026-09-18 - Mathew Joseph
Added an ElicitationAudioPlayer port and provider for per-protocol Hindi instruction clips; the three bundled mp3s (rattle, toy hide, imitate) are 3–4 s silent placeholders standing in for real instruction recordings.
The elicitation step can speak each activity's prompt on-device while widget tests stub the player, matching the consent audio pattern.

### 2026-09-18 - Mathew Joseph
Replaced the consent placeholder with the gated flow: the worker plays the Hindi consent audio, the "माता-पिता ने सहमति दी" button unlocks only after playback, and confirming writes a timestamped consent_logs row (session_id NULL) while recording consentedAt and the log id on the session provider.
The screening can no longer reach the recording step without an auditable consent record; playback or persistence failures surface a Hindi fallback and keep the gate closed.

### 2026-09-18 - Mathew Joseph
Added just_audio plus a ConsentAudioPlayer port and provider for the bundled Hindi consent clip; assets/audio/consent_hi.mp3 is a 4-second silent placeholder standing in for the real AI4Bharat TTS recording.
The consent screen can play the statement on-device while widget tests substitute a fake player, sidestepping platform-channel failures.

### 2026-09-18 - Mathew Joseph
Bumped the local database to version 2 so `consent_logs.session_id` is nullable, migrating existing databases via a table rebuild that preserves audit rows; `ConsentLog` now allows a null session link and the repository can backfill it later.
Consent can be recorded before the session row exists — the link attaches when the screening completes — while the foreign-key cascade still protects rows written against older sessions.

### 2026-09-18 - Mathew Joseph
Replaced the questionnaire placeholder with a CDC milestone list loaded from the bundled Hindi asset, age-filtered per enrolled child, with हाँ/नहीं segments, a skip path, and a finish that stores the context-only summary.
Answers and the milestone summary now flow through the session provider into the consent step without ever blocking navigation.

### 2026-09-18 - Mathew Joseph
Replaced the child-profile placeholder with the real enrollment form: optional name, age in months validated via ChildProfile.isAgeValid, Anganwadi ID, state dropdown, district and worker name.
A valid form writes the profile to the session provider and continues to the questionnaire; the routes walkthrough now fills the form before advancing.

### 2026-09-18 - Mathew Joseph
Added a Riverpod session provider carrying the in-progress enrollment profile and questionnaire answers/summary across screens.
Screens can now write the child profile once and read it downstream; state is in-memory and clears on reset.

### 2026-09-18 - Mathew Joseph
Added a pure-Dart milestone engine (age filtering, yes/no tally, normal/warning status) plus a Hindi CDC-milestone question asset.
The optional questionnaire now has a scoring contract: two or more missed age-applicable milestones flag a warning context that never gates the acoustic result.

### 2026-09-18 - Mathew Joseph
Added unit tests for SessionRepository (in-memory SQLite CRUD round-trips) and SyncRepository (fake upload port covering success, failure, and offline paths).
Locks in the data-layer contract: 12 new tests cover ordering, sync-flag transitions, cascade deletes, consent logs, and queue draining.

### 2026-09-18 - Mathew Joseph
Added Riverpod providers for sync state: repository wiring plus a SyncNotifier exposing pending count, isSyncing, and the last sync result.
The UI can now observe the upload queue and trigger a sync pass when connectivity returns.

### 2026-09-18 - Mathew Joseph
Added the Supabase schema for the screenings table and a matching consent_logs audit table, both with insert-only RLS policies.
Defines the cloud sink for synced biomarker rows and consent confirmations scoped to the worker's Anganwadi JWT claim.

### 2026-09-18 - Mathew Joseph
Added SyncRepository that drains the unsynced queue through an injectable ScreeningUploader port backed by Supabase upserts.
Successful uploads flip the synced flag while failures stay queued for retry; an uninitialized client reports an offline result instead of throwing.

### 2026-09-18 - Mathew Joseph
Added SessionRepository with CRUD over the sessions table plus consent-log writes for the audit trail.
The app can now save screenings, query history newest-first, track the unsynced queue, and record timestamped parental consent.

### 2026-09-18 - Mathew Joseph
Added a SQLite database helper that opens earlyecho.db at version 1 with sessions and consent_logs tables and foreign keys enabled.
Screening sessions now have a durable on-device store whose schema mirrors the cloud columns, plus a consent audit trail.

### 2026-09-18 - Mathew Joseph
Added sqflite_common_ffi as a dev dependency so repositories can be tested against an in-memory SQLite database.
Enables data-layer unit tests to exercise real SQL without a device or emulator.

### 2026-09-18 - Mathew Joseph
Wired the app shell together: a GoRouter with all ten routes, a ProviderScope-wrapped MaterialApp.router entry point, and router widget tests.
The app now boots into the home screen and every placeholder is reachable; a smoke test taps through the full seven-step screening flow.

### 2026-09-18 - Mathew Joseph
Added placeholder screens for home, result history and settings, each with a widget test.
Completes the set of app destinations: the home screen links into the screening flow, past results and settings.

### 2026-09-18 - Mathew Joseph
Added placeholder screens for elicitation, processing, result and referral with widget tests.
Completes the screening flow as navigable placeholders, including the three timed protocol rows and the risk-band legend.

### 2026-09-18 - Mathew Joseph
Added shared UI widgets plus placeholder screens for child profile, questionnaire and consent, each with a widget test.
Builds the first half of the screening flow as navigable Hindi-first placeholders styled with the new theme.

### 2026-09-18 - Mathew Joseph
Added the EarlyEcho app theme and shared app constants (channel name, protocol timings, age bounds, audio format).
Establishes the worker-centric visual foundation: India-inspired saffron/teal Material 3 palette, enlarged text, and 48dp+ tap targets for outdoor use.

### 2026-09-18 - Mathew Joseph
Added a rule to the agent working agreement requiring minimum relevant test coverage per change and non-redundant CI tests.
Keeps future test and workflow additions focused on what each change actually exercises.

### 2026-09-18 - Mathew Joseph
Scaffolded the Flutter app skeleton (models, scoring engine, referral text builder) with unit tests and added a GitHub Actions CI workflow.
Every push and pull request to main now runs format checks, static analysis, and the test suite; main pushes also build a release APK artifact.

## Commit Entry Format

### YYYY-MM-DD - Human Author - short-hash
Describe what changed in one concise sentence.
Describe the user, system, or maintenance impact in a second concise sentence.

## History
