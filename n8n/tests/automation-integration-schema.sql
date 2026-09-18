create extension if not exists pgcrypto;
create schema if not exists auth;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role; end if;
end;
$$;

create table auth.users (
  id uuid primary key,
  email text,
  email_confirmed_at timestamptz,
  confirmed_at timestamptz
);

create type public.app_role as enum ('parent', 'clinician', 'admin');
create type public.appointment_status as enum ('requested', 'confirmed', 'declined', 'cancelled', 'completed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null,
  display_name text not null default ''
);

create table public.children (
  id uuid primary key default gen_random_uuid(),
  display_name text not null
);

create table public.child_guardians (
  child_id uuid not null references public.children(id) on delete cascade,
  parent_id uuid not null references public.profiles(id) on delete cascade,
  primary key (child_id, parent_id)
);

create table public.screening_sessions (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  created_at timestamptz not null default now(),
  analysis_status text not null,
  risk_level text
);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  parent_id uuid not null references public.profiles(id) on delete cascade,
  clinician_id uuid not null references public.profiles(id) on delete cascade,
  requested_for timestamptz,
  starts_at timestamptz,
  status public.appointment_status not null default 'requested',
  created_at timestamptz not null default now()
);
