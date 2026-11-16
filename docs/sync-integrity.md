# Mobile sync integrity

## Identity and replay contract

A screening gets a UUID and timestamp once in the capture state, normally from
its persisted consent confirmation. Result-screen re-entry reuses that identity;
it never creates a new record just because a widget mounts. New screenings start
after the capture state is reset. Identity is not inferred from a child's name,
age, centre, or other demographics. In-progress capture is not restored after an
app restart; completed SQLite records retain their identity across restarts.

`SessionRepository.saveSession` writes the completed screening and attaches its
consent in one SQLite transaction. Completed records are immutable. Saving the
same ID and content is a no-op and retains acknowledgement flags and consent.
Different content under that ID raises `SyncConflictException` and leaves the
existing data intact. Consent can acquire its first session link, but cannot be
relinked or silently rewritten. Incomplete analyses are never persisted as
completed screenings.

The production `SupabaseScreeningUploader` calls these SECURITY INVOKER RPCs:

| RPC | JSONB parameter | Success result |
| --- | --- | --- |
| `public.sync_screening` | `p_screening` | `inserted` or `replayed` |
| `public.sync_consent_log` | `p_consent` | `inserted` or `replayed` |

Each RPC inserts under the existing UUID primary key. Concurrent inserts wait
for the winning transaction, then compare the stored and incoming typed records.
Equality ignores only server-generated `created_at`; timestamps compare as
instants and numeric JSON encodings compare after conversion to column types.
An identical replay succeeds without an update. Different content raises
PostgREST `PT409` (HTTP 409); neither version is overwritten. A UUID collision
with an invisible record also cannot overwrite or acknowledge it. The functions
use the normal PostgREST READ COMMITTED transaction isolation; higher-isolation
serialization failures must be retried. Direct client updates/deletes are denied.

SQLite acknowledges the full uploaded snapshot only after a recognized remote
success. A lost response, crash before acknowledgement, or failed local
acknowledgement leaves a retryable row with the same ID. Sync is single-flight
per repository; independent clients remain protected by server uniqueness.
Individual upload attempts have a 30-second response budget; a later remote
commit is handled by replay, without a late local acknowledgement.
Screening failures do not stop unrelated queued records. Consent is attempted
only after its exact local screening is acknowledged. A consent-only failure
remains visible in the pending count, and retry does not re-upload the accepted
screening. `SyncResult` reports screening and consent failures/conflicts and
never reports `allSynced` while a linked consent remains pending. Unlinked
consents are retained locally until a screening is completed.

Conflicts remain queued for explicit reconciliation; there is no automatic
last-writer-wins or conflict-discard operation. Repeated retries cannot resolve a
content conflict. There is currently no conflict-resolution or legacy-ownership
recovery UI. Preserve the local and remote records for an authorized review.

## Ownership and account changes

Each repository is bound to one authenticated owner ID, including all reads,
deletes, queue queries, links, and acknowledgements. Signing out or changing
accounts recreates the capture/repository/sync providers, clears in-memory child
details, and rejects late callbacks from the previous capture. A profile refresh
for the same identity keeps the capture; a failed role fetch clears the role,
not the authenticated identity. Concurrent auth/profile loads share the pending
lookup so role checks cannot race it. Login navigation does not wait for sync.

The uploader checks the live authenticated owner before and after its request;
the queue checks again before acknowledgement and before the next upload. An
in-flight request may already have committed for its original owner. That row
can be replayed when the owner returns. Other accounts cannot drain its queue.
No account transition deletes stored screenings or consent.

Remote `screenings` and `consent_logs` reads are owner-only, including for an
authenticated administrator. Inserts require `created_by = auth.uid()` and a
provisioned `clinician` or `admin` profile. Clinicians must match their provisioned
`anganwadi_id`; administrators may upload their own records for any centre.
Consent must reference an owned screening in the same centre. Client profile
updates cannot change role or centre. Trusted service-role provisioning remains
available. The portal's separate `screening_sessions`, guardian access, and
assigned-clinician policies are not changed by the mobile policies.

These are application-level local partitions, not encryption against somebody
who controls the device filesystem. Raw audio, child names, worker names, and
local decision traces are absent from screening upload payloads. Consent audit
payloads retain the existing worker-name field, consent timestamp, centre, owner,
and screening link.

## Existing data and deployment

1. Apply `supabase/schema.sql` for a new database, then all migrations in filename
   order. On an existing deployment, apply only unapplied migrations, including
   `202611160001_mobile_sync_integrity.sql`, before releasing the client.
2. SQLite upgrades v1/v2 to v3 without deleting data. Since those versions did
   not record the authenticated writer, their rows get the reserved
   `legacy-unassigned` partition. They are retained but are not exposed or
   auto-uploaded to whichever account next signs in.
3. Fresh signed-out/offline-only captures use the null-owner partition. They
   remain usable offline and are never automatically claimed at login.
4. Existing remote consent records remain unowned: a link alone cannot establish
   who collected the consent. Existing remote screening ownership is preserved.
   NOT VALID ownership constraints preserve old unowned/unlinked records while
   enforcing valid ownership on new writes. Legacy recovery requires explicit
   provenance review; no ownership is guessed from the current user.

Older mobile builds using table upserts cannot update these immutable records;
their failed uploads should remain queued. Changing a clinician's provisioned
centre can make old-centre uploads fail authorization; the queue is retained for
explicit reconciliation rather than rewritten or reassigned.

## Validation

Run from the repository root with Flutter and native PostgreSQL client tools on
PATH. The existing Flutter CI job discovers the added SQLite, Supabase HTTP,
account-transition, and result-persistence tests. The `sync-database` CI job uses
the runner's native PostgreSQL installation; no Docker daemon is required.

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 \
  test/database_helper_test.dart test/session_repository_test.dart \
  test/sync_repository_test.dart test/sync_integrity_test.dart \
  test/supabase_sync_transport_test.dart test/account_scope_test.dart \
  test/result_persistence_test.dart test/login_sync_test.dart
```

The SQL runner uses Python's standard library and `psql`. Provide a **disposable
local database** owned by a role able to create fixture roles and schemas. It
recreates the `public` and `auth` schemas; never use a production database URL.
Its fixture provides `auth.users`, `auth.uid()`, and the Supabase API roles.
It loads the base schema and complete migration chain, seeds legacy records
before the integrity migration, and exercises real RLS/constraints, replay,
conflicting/concurrent writers, rollback, and lost-acknowledgement retries.

```sh
createdb earlyecho_sync_test
SYNC_TEST_DATABASE_URL=postgresql://localhost/earlyecho_sync_test \
  python3 supabase/tests/test_sync_integrity.py
```

For a separate native PostgREST acceptance database, the same runner supports
`--setup-only`. It prints fixture owner IDs and RPC names. Use a separate
disposable database from the SQL tests, which reset their own fixture on each
run. The Flutter HTTP fixture tests the actual Supabase client serialization,
authorization header, status decoding, queue acknowledgement, and retry paths;
the PostgreSQL suite independently verifies the production migration semantics.
