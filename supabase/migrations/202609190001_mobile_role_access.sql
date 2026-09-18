-- Mobile role access uses the same profiles.role values as the dashboard:
-- parent, clinician (care worker), and admin.
create table if not exists public.screenings (
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
  created_by uuid references public.profiles(id) default auth.uid(),
  created_at timestamptz default now()
);

create table if not exists public.consent_logs (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references public.screenings(id),
  anganwadi_id text,
  worker_name text,
  consented_at timestamptz not null,
  created_at timestamptz default now()
);

alter table public.profiles
  add column if not exists anganwadi_id text;

alter table public.screenings
  add column if not exists created_by uuid references public.profiles(id)
  default auth.uid();

create index if not exists screenings_created_by_idx
  on public.screenings(created_by);

alter table public.screenings enable row level security;
alter table public.consent_logs enable row level security;

drop policy if exists workers_insert on public.screenings;
drop policy if exists care_workers_insert_screenings on public.screenings;
create policy care_workers_insert_screenings on public.screenings
  for insert to authenticated
  with check (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and role in ('clinician', 'admin')
        and (role = 'admin' or anganwadi_id = screenings.anganwadi_id)
    )
  );

drop policy if exists care_workers_read_screenings on public.screenings;
create policy care_workers_read_screenings on public.screenings
  for select to authenticated
  using (created_by = auth.uid() or exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  ));

drop policy if exists care_workers_update_screenings on public.screenings;
create policy care_workers_update_screenings on public.screenings
  for update to authenticated
  using (created_by = auth.uid())
  with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.profiles
      where id = auth.uid()
        and role in ('clinician', 'admin')
        and (role = 'admin' or anganwadi_id = screenings.anganwadi_id)
    )
  );

drop policy if exists workers_insert_consent on public.consent_logs;
drop policy if exists care_workers_insert_consent on public.consent_logs;
create policy care_workers_insert_consent on public.consent_logs
  for insert to authenticated
  with check (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and role in ('clinician', 'admin')
        and (role = 'admin' or anganwadi_id = consent_logs.anganwadi_id)
    )
  );

grant insert, select, update on public.screenings to authenticated;
grant insert on public.consent_logs to authenticated;