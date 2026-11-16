# Owner-scoped synchronization: implementation overview

- Author: Mathew Joseph
- Date: 2026-11-16
- Branch: `feat/sync-integrity`
- Implementation revision: `4d218d2`

## Summary

EarlyEcho's completed screenings and consent records now have stable identities,
immutable replay semantics, owner-scoped local and remote access, and recoverable
queue processing. The implementation covers the Flutter capture lifecycle, SQLite
persistence, Supabase transport, PostgreSQL policies/RPCs, and conflict/replay tests.

Verification used synthetic users and screening fixtures in local test databases.
No patient dataset or production Supabase instance was used.

## End-to-end flow

```text
New enrollment -> fresh capture state
    -> consent saved locally; stable screening UUID and timestamp
    -> completed analysis
    -> SQLite transaction: immutable screening + consent linkage
    -> owner-bound queue drain
    -> sync_screening RPC -> inserted / replayed / conflict
    -> acknowledge the uploaded local snapshot
    -> sync_consent_log RPC -> acknowledge consent separately
```

A repeated result-screen mount reuses the same capture identity. Starting another
screening, including after Android/AppBar Back or direct enrollment, creates a
fresh capture. A storage failure is shown with a safe same-identity retry action;
the result is only described as saved after the SQLite transaction commits.

## Components and data model

| Component | Implementation |
| --- | --- |
| SQLite schema, upgrades, owner queue indexes | `lib/data/local/database_helper.dart` |
| Stable session model and upload payload | `lib/data/models/session_model.dart` |
| Owner-scoped reads/writes, immutable saves, atomic consent links | `lib/data/repositories/session_repository.dart` |
| Queue drain, uploader, replay decoding, snapshot acknowledgements | `lib/data/repositories/sync_repository.dart` |
| Explicit content-conflict representation | `lib/data/repositories/sync_conflict.dart` |
| Account, capture, and queue lifecycle | `lib/presentation/providers/auth_provider.dart`, `lib/presentation/providers/session_provider.dart`, `lib/presentation/providers/sync_provider.dart` |
| New-capture boundaries and save feedback | `lib/presentation/screens/home/home_screen.dart`, `lib/presentation/screens/child_profile/child_profile_screen.dart`, `lib/presentation/screens/result/result_screen.dart` |
| Remote policies and replay RPCs | `supabase/migrations/202611160001_mobile_sync_integrity.sql` |

SQLite schema version 3 adds owner partitions to `sessions` and `consent_logs`.
Queue indexes cover `(owner_id, synced, session_date)` and
`(owner_id, synced, session_id)`. Foreign keys enforce consent/session linkage.
Consent can be collected before the completed screening exists and linked in the
same transaction that saves that screening.

Completed screenings are immutable. An identical local save preserves the stored
record and acknowledgement state; different content with the same ID raises
`SyncConflictException`. Consent can acquire its initial screening link but cannot
be silently rewritten or relinked. Incomplete analyses are not saved as completed
screenings.

## Remote replay and conflict contract

| RPC | Argument | Successful response |
| --- | --- | --- |
| `public.sync_screening` | `p_screening` JSONB | `inserted` or `replayed` |
| `public.sync_consent_log` | `p_consent` JSONB | `inserted` or `replayed` |

Both RPCs run as `SECURITY INVOKER`, so row-level security applies to the caller.
The UUID primary key arbitrates concurrent inserts. After an ID collision, the
stored and incoming typed records are compared, excluding server-generated
`created_at`. Equivalent numeric JSON representations and timestamp instants
therefore replay successfully.

| Situation | Behavior |
| --- | --- |
| New ID and authorized payload | Insert once and return `inserted` |
| Same ID and identical content | Return `replayed` without an update |
| Same ID and changed content | HTTP 409 / `PT409`; preserve the existing row |
| Remote commit succeeds but response is lost | Keep local row queued; retry the same ID safely |
| Local acknowledgement fails | Keep the uploaded snapshot retryable |
| Screening succeeds, consent fails | Retry consent independently; retain its pending count |
| Consent refers to another owner's screening | Deny the operation |
| Direct client update/delete | Deny the mutation |

Conflicts remain queued for explicit reconciliation. There is no automatic
last-writer-wins merge or conflict-discard behavior.

## Owner-scoped access

Every local repository is bound to one owner, including reads, deletes, queue
queries, consent linkage, and acknowledgements. The authenticated Supabase identity
is checked before and after uploads, and the queue checks again before local
acknowledgement.

Remote `screenings` and `consent_logs` reads are owner-only, including for an
authenticated administrator. Inserts require `created_by = auth.uid()` and a
provisioned `clinician` or `admin` role. Clinicians must match their provisioned
centre; administrators can upload their own records for any centre. Consent must
reference an owned screening in the same centre. Client profile updates cannot
change role or centre.

Account changes replace account-bound providers and clear in-memory capture data.
Disposed repositories cannot acknowledge late responses, even if the same account
signs in again. The next account epoch uses a new queue repository. The portal's
separate `screening_sessions` and guardian/assigned-clinician access remain governed
by their own policies.

## Queue concurrency and recovery

Concurrent sync requests share one drain. A request made while an upload is active
schedules a coalesced rescan, so newly saved screenings are included in that drain.
Each row is attempted at most once per flight; failed/conflicting rows wait for a
later explicit flight instead of entering a retry loop. Upload attempts have a
30-second response budget.

A failed screening does not prevent unrelated rows from syncing. Its consent is
only eligible after that exact screening is acknowledged. Counts include linked
consent failures, so a queue with pending consent is not reported as fully synced.
Unlinked consent stays local until a screening is completed.

SQLite v1/v2 upgrades retain existing rows in `legacy-unassigned`, because older
rows did not record an authenticated owner. Fresh signed-out captures use a
separate null-owner partition. Neither category is automatically assigned to the
next user who logs in. Remote legacy consent remains unowned; additive constraints
preserve old rows while enforcing ownership for new writes.

## Verification

Recorded local validation on 2026-11-16:

| Layer | Result | What it verifies |
| --- | --- | --- |
| Focused Flutter suite | 99 tests across 19 files passed | SQLite upgrades, immutable saves, transport decoding, capture identity, owner/account transitions, consent linkage, late acknowledgements, coalesced rescans, save failures and retry |
| Native PostgreSQL suite | 10 tests passed | Complete migration chain, legacy preservation, RLS, concurrent replay/conflicts, rollback, lost acknowledgement |
| Native PostgREST HTTP suite | 7 tests passed | Signed-JWT access, HTTP 409 mapping, simultaneous writers, replay, consent authorization, anonymous denial, mutation/profile-escalation denial |
| Static checks | Analyzer clean; 78 Dart files required no formatting changes | Dart analysis, formatting, staged whitespace |

The database and HTTP tests ran on PostgreSQL 18.7 and PostgREST 16.5. The subsequent
Dart-only lifecycle fixes passed the expanded Flutter suite; the unchanged SQL/HTTP
suites were not rerun for those fixes. Lifecycle tests use actual routes and SQLite
with native audio/analysis mocked. Full application builds were not run.

The existing Flutter GitHub Actions job discovers the added Dart tests. A new
`sync-database` job runs the native PostgreSQL suite. The real-PostgREST acceptance
suite has a separate local command; it is not an automatic CI job.

## Deployment and operational boundaries

1. On a new Supabase database, apply `supabase/schema.sql` and the migrations in
   filename order. On an existing deployment, apply only unapplied migrations,
   including `202611160001_mobile_sync_integrity.sql`, before releasing the client.
2. Provision clinician roles and centre assignments through a trusted administrative
   path. Configure the Flutter app with `SUPABASE_URL` and
   `SUPABASE_PUBLISHABLE_KEY` for authenticated synchronization.
3. SQLite upgrades automatically to version 3. Retain legacy records for explicit
   ownership review; logging in does not claim them.
4. Use disposable databases for SQL/HTTP test fixtures. The SQL setup recreates
   the `public` and `auth` schemas.

In-progress captures are not restored after process restart; completed SQLite
records are durable. Local owner partitions provide application isolation, not
filesystem encryption. Screening uploads omit raw audio, child names, worker names,
and local decision traces; consent audit payloads retain the existing worker-name
field. Conflict-resolution and legacy-ownership recovery screens are not included.

Detailed semantics, migration order, Flutter commands, and native PostgreSQL/
PostgREST reproduction instructions: `docs/sync-integrity.md`.
