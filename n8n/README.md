# Local n8n care automations

This folder contains three inactive, importable n8n workflows. They use the
service-only Supabase outbox introduced by
`supabase/migrations/202609190002_automation_outbox.sql`; no email address is
stored in the public outbox table and every delivery has a unique key.

| Workflow | Cadence | Outcome |
| --- | --- | --- |
| Parent follow-up and referral reminders | Monday, 9:00 AM IST | Reminds a parent about an unresolved red-result referral weekly, and a yellow-result follow-up after twelve weeks, at most monthly. |
| Appointment reminders | Every 15 minutes | Sends one reminder roughly 24 hours before a confirmed appointment. |
| Clinician priority digest | Weekdays, 5:30 PM IST | Sends each clinician a count-only digest of appointment requests open longer than 24 hours. |

All workflows are imported **inactive**. A manual trigger is included in each
workflow so it can be checked before it is published.

## Local setup

1. Apply `supabase/schema.sql`, then apply the files in `supabase/migrations/`
   in order to the intended Supabase project. The automation migration must be
   applied before importing a workflow.
2. Copy `.env.example` to `.env`, set the project URL, service-role key, sender
   address, and a long unique n8n encryption key. Keep `.env` local.
3. Start the local stack:

   ```powershell
   docker compose --env-file .env up -d
   ```

4. Open `http://localhost:5678`, create an SMTP credential, and import each
   JSON file from the mounted `/files/workflows` directory. For a safe local
   delivery check, use SMTP host `mailpit`, port `1025`, and no authentication;
   inspect messages at `http://localhost:8025`.
5. Attach the SMTP credential to each `Send ...` node, run its `Manual test`
   trigger, confirm the message in Mailpit, then publish the workflow when it
   is ready to deliver real reminders.

For production, use a real authenticated SMTP provider, a verified sender, and
an HTTPS reverse proxy. `N8N_SECURE_COOKIE=false` exists only so the local
`http://localhost` setup can be used.

## Validation

Run the focused checks from this directory:

```powershell
npm run test:all
```

They validate the workflow graph, test the actual Supabase migration against a
disposable local PostgreSQL container, and import every workflow using the
pinned n8n image. Docker must be running; the test removes its temporary
database container automatically.
