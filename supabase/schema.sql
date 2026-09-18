-- EarlyEcho cloud schema.
-- Stores only numeric acoustic biomarkers per screening; audio is never
-- uploaded and child names are never transmitted (DPDP Act 2023).

-- Screening results uploaded from EarlyEcho devices.
create table public.screenings (
  id uuid primary key default gen_random_uuid(),
  anganwadi_id text not null,
  state_code text,
  district_code text,
  child_age_months integer,
  risk_level text,
  vttl_ms float,
  pfv_std float,
  cvr_ratio float,
  vttl_flagged boolean,
  pfv_flagged boolean,
  cvr_flagged boolean,
  audio_source text,
  session_date timestamptz,
  created_at timestamptz default now()
);

-- Workers may only insert rows for their own Anganwadi; the DEIC dashboard
-- reads via the service_role key, which bypasses RLS.
alter table public.screenings enable row level security;
create policy workers_insert on public.screenings
  for insert using (auth.jwt() ->> 'anganwadi_id' = anganwadi_id);

-- Append-only audit trail for parental-consent confirmations recorded on
-- the device consent screen.
create table public.consent_logs (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references public.screenings(id),
  anganwadi_id text,
  worker_name text,
  consented_at timestamptz not null,
  created_at timestamptz default now()
);

-- Insert-only: workers can write audit entries but cannot read, update, or
-- delete them; dashboard access uses the service_role key.
alter table public.consent_logs enable row level security;
create policy workers_insert_consent on public.consent_logs
  for insert with check (auth.jwt() ->> 'anganwadi_id' = anganwadi_id);
