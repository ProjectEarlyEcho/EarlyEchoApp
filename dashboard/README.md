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

## Checks

```bash
npm run lint
npm test
npm run build
```
