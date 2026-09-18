-- EarlyEcho care portal schema.
-- Raw audio, recordings, and spectrograms are intentionally not represented here.
create extension if not exists pgcrypto;

do $$
begin
  create type public.app_role as enum ('parent', 'clinician', 'admin');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.appointment_status as enum ('requested', 'confirmed', 'declined', 'cancelled', 'completed');
exception
  when duplicate_object then null;
end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null default 'parent',
  display_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.children (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  birth_date date,
  created_at timestamptz not null default now()
);

create table if not exists public.child_guardians (
  child_id uuid not null references public.children(id) on delete cascade,
  parent_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (child_id, parent_id)
);

create table if not exists public.care_team (
  child_id uuid not null references public.children(id) on delete cascade,
  clinician_id uuid not null references public.profiles(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  primary key (child_id, clinician_id)
);

create table if not exists public.screening_sessions (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  created_by uuid default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  analysis_status text not null check (analysis_status in ('COMPLETE', 'INCOMPLETE')),
  risk_level text check (risk_level in ('green', 'yellow', 'red')),
  child_age_months integer check (child_age_months between 12 and 60),
  quality_reasons jsonb not null default '[]'::jsonb,
  vttl_ms double precision,
  cvr_ratio double precision,
  pfv_std double precision,
  audio_source text,
  decision_trace jsonb not null default '{}'::jsonb,
  check (vttl_ms is null or vttl_ms >= 0),
  check (cvr_ratio is null or cvr_ratio between 0 and 1),
  check (pfv_std is null or pfv_std >= 0)
);

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  parent_id uuid not null default auth.uid() references public.profiles(id),
  clinician_id uuid not null references public.profiles(id),
  requested_for timestamptz,
  starts_at timestamptz,
  status public.appointment_status not null default 'requested',
  reason text check (char_length(reason) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  parent_id uuid not null references public.profiles(id) on delete cascade,
  clinician_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (child_id, parent_id, clinician_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null default auth.uid() references public.profiles(id),
  body text not null check (char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create table if not exists public.clinical_notes (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  clinician_id uuid not null default auth.uid() references public.profiles(id),
  body text not null check (char_length(trim(body)) between 1 and 5000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists screening_sessions_child_created_idx on public.screening_sessions(child_id, created_at desc);
create index if not exists appointments_clinician_requested_idx on public.appointments(clinician_id, requested_for);
create index if not exists messages_conversation_created_idx on public.messages(conversation_id, created_at);

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();
drop trigger if exists appointments_updated_at on public.appointments;
create trigger appointments_updated_at before update on public.appointments for each row execute procedure public.set_updated_at();
drop trigger if exists conversations_updated_at on public.conversations;
create trigger conversations_updated_at before update on public.conversations for each row execute procedure public.set_updated_at();
drop trigger if exists clinical_notes_updated_at on public.clinical_notes;
create trigger clinical_notes_updated_at before update on public.clinical_notes for each row execute procedure public.set_updated_at();

-- A public registration can only create a parent account. A trusted administrator
-- or service must provision clinician and administrator roles separately.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, role, display_name)
  values (new.id, 'parent', coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.prevent_client_role_change()
returns trigger language plpgsql set search_path = public as $$
begin
  if auth.uid() is not null and new.role is distinct from old.role then
    raise exception 'Roles can only be changed by a trusted administrator';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_prevent_role_change on public.profiles;
create trigger profiles_prevent_role_change before update on public.profiles
for each row execute procedure public.prevent_client_role_change();

create or replace function public.parent_is_child_guardian(target_child uuid, target_parent uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.child_guardians
    where child_id = target_child and parent_id = target_parent
  );
$$;

create or replace function public.is_child_guardian(target_child uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.parent_is_child_guardian(target_child, auth.uid());
$$;

create or replace function public.clinician_is_assigned(target_child uuid, target_clinician uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.care_team
    where child_id = target_child and clinician_id = target_clinician
  );
$$;

create or replace function public.is_assigned_clinician(target_child uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.clinician_is_assigned(target_child, auth.uid());
$$;

create or replace function public.can_access_conversation(target_conversation uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.conversations
    where id = target_conversation and (parent_id = auth.uid() or clinician_id = auth.uid())
  );
$$;

create or replace function public.shares_care_relationship(target_profile uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.care_team team
    join public.child_guardians guardian on guardian.child_id = team.child_id
    where (team.clinician_id = auth.uid() and guardian.parent_id = target_profile)
       or (guardian.parent_id = auth.uid() and team.clinician_id = target_profile)
  );
$$;

alter table public.profiles enable row level security;
alter table public.children enable row level security;
alter table public.child_guardians enable row level security;
alter table public.care_team enable row level security;
alter table public.screening_sessions enable row level security;
alter table public.appointments enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.clinical_notes enable row level security;

create policy "read own or connected profile" on public.profiles for select to authenticated
using (id = auth.uid() or public.shares_care_relationship(id));
create policy "update own profile" on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

create policy "guardians and clinicians read assigned children" on public.children for select to authenticated
using (public.is_child_guardian(id) or public.is_assigned_clinician(id));
create policy "guardians read their child links" on public.child_guardians for select to authenticated
using (parent_id = auth.uid() or public.is_assigned_clinician(child_id));
create policy "care teams read their assignments" on public.care_team for select to authenticated
using (clinician_id = auth.uid() or public.is_child_guardian(child_id));

create policy "care participants read screenings" on public.screening_sessions for select to authenticated
using (public.is_child_guardian(child_id) or public.is_assigned_clinician(child_id));
create policy "assigned clinicians add screenings" on public.screening_sessions for insert to authenticated
with check (public.is_assigned_clinician(child_id) and created_by = auth.uid());

create policy "appointment participants read appointments" on public.appointments for select to authenticated
using (parent_id = auth.uid() or clinician_id = auth.uid());
create policy "guardians request appointments" on public.appointments for insert to authenticated
with check (
  parent_id = auth.uid()
  and public.parent_is_child_guardian(child_id, parent_id)
  and public.clinician_is_assigned(child_id, clinician_id)
);
create policy "assigned clinicians manage appointments" on public.appointments for update to authenticated
using (clinician_id = auth.uid()) with check (clinician_id = auth.uid());

create policy "conversation participants read conversations" on public.conversations for select to authenticated
using (parent_id = auth.uid() or clinician_id = auth.uid());
create policy "care participants start conversations" on public.conversations for insert to authenticated
with check (
  (parent_id = auth.uid() and public.parent_is_child_guardian(child_id, parent_id) and public.clinician_is_assigned(child_id, clinician_id))
  or (clinician_id = auth.uid() and public.clinician_is_assigned(child_id, clinician_id) and public.parent_is_child_guardian(child_id, parent_id))
);
create policy "conversation participants read messages" on public.messages for select to authenticated
using (public.can_access_conversation(conversation_id));
create policy "conversation participants send messages" on public.messages for insert to authenticated
with check (sender_id = auth.uid() and public.can_access_conversation(conversation_id));

create policy "clinicians read their notes" on public.clinical_notes for select to authenticated
using (clinician_id = auth.uid() and public.is_assigned_clinician(child_id));
create policy "clinicians write their notes" on public.clinical_notes for insert to authenticated
with check (clinician_id = auth.uid() and public.is_assigned_clinician(child_id));
create policy "clinicians update their notes" on public.clinical_notes for update to authenticated
using (clinician_id = auth.uid()) with check (clinician_id = auth.uid());

grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;
grant select on public.children, public.child_guardians, public.care_team to authenticated;
grant select, insert on public.screening_sessions to authenticated;
grant select, insert, update on public.appointments to authenticated;
grant select, insert on public.conversations, public.messages to authenticated;
grant select, insert, update on public.clinical_notes to authenticated;

-- Keep a secure conversation available whenever a clinician is assigned or a
-- guardian is linked. The unique constraint makes both trigger paths safe.
create or replace function public.create_care_conversations()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if TG_TABLE_NAME = 'care_team' then
    insert into public.conversations (child_id, parent_id, clinician_id)
    select new.child_id, guardian.parent_id, new.clinician_id
    from public.child_guardians guardian
    where guardian.child_id = new.child_id
    on conflict (child_id, parent_id, clinician_id) do nothing;
  else
    insert into public.conversations (child_id, parent_id, clinician_id)
    select new.child_id, new.parent_id, team.clinician_id
    from public.care_team team
    where team.child_id = new.child_id
    on conflict (child_id, parent_id, clinician_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists care_team_create_conversations on public.care_team;
create trigger care_team_create_conversations after insert on public.care_team
for each row execute procedure public.create_care_conversations();
drop trigger if exists child_guardian_create_conversations on public.child_guardians;
create trigger child_guardian_create_conversations after insert on public.child_guardians
for each row execute procedure public.create_care_conversations();

-- Enable real-time inserts for the secure chat workspace.
alter table public.messages replica identity full;
do $$
begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then null;
end $$;

-- Mobile screening records retain only numeric acoustic biomarkers; raw audio
-- and child names are never uploaded.
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
  created_at timestamptz default now()
);

alter table public.screenings enable row level security;
create policy workers_insert on public.screenings
  for insert with check (auth.jwt() ->> 'anganwadi_id' = anganwadi_id);

-- Append-only consent audit records created before the screening session exists.
create table if not exists public.consent_logs (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references public.screenings(id),
  anganwadi_id text,
  worker_name text,
  consented_at timestamptz not null,
  created_at timestamptz default now()
);

alter table public.consent_logs enable row level security;
create policy workers_insert_consent on public.consent_logs
  for insert with check (auth.jwt() ->> 'anganwadi_id' = anganwadi_id);
