# Changelog

This file records notable commit-level changes. Update it before every commit using the entry format below.

## Unreleased

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
