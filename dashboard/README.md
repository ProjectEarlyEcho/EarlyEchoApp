# EarlyEcho dashboard

The EarlyEcho dashboard gives parents a clear view of their child's screening
summaries, appointments, and clinician messages, while clinicians can review
assigned children, manage appointments, and respond to families.

## Local setup

1. Copy `.env.example` to `.env.local` and add the Supabase project URL and
   publishable key.
2. Apply `../supabase/schema.sql` in the Supabase SQL editor or with the
   Supabase CLI.
3. Install and start the dashboard:

   ```bash
   npm install
   npm run dev
   ```

Only a clinician administrator or trusted backend may grant the `clinician`
role. New self-service registrations become parent accounts.

## Demo data

The demo seed creates synthetic, sign-in-capable accounts and related children,
screenings, appointments, and messages. It is strictly for a local or disposable
development project; it must never be run against a production project.

1. Copy `seed-demo.example.env` to a local, untracked file and set its values
   in your shell as `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
2. Run `npm run seed:demo`.

Every mock account uses the password `EarlyEchoDemo1!`:

| Role | Email |
| --- | --- |
| Parent | `maya.parent@example.test` |
| Parent | `rohan.parent@example.test` |
| Clinician | `anaya.clinician@example.test` |
| Clinician | `vivek.clinician@example.test` |

The seed can be run again safely; it uses stable demo records and updates them
instead of inserting duplicates.

## Checks

```bash
npm run lint
npm test
npm run build
```
