# Changelog

This file records notable commit-level changes. Update it before every commit using the entry format below.

## Unreleased

### 2026-09-18 - Devadathan M R - pending
Added an idempotent, development-only Supabase demo-data seeder with synthetic parent and clinician accounts.
It creates linked children, screening histories, appointments, messages, and clinician-only notes for dashboard testing.

### 2026-09-18 - Devadathan M R - pending
Added the EarlyEcho Next.js care portal with parent and clinician workspaces for screening summaries, appointments, and secure care-team messaging.
Introduced Supabase role-based access controls and row-level security, plus dashboard checks in continuous integration.

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
