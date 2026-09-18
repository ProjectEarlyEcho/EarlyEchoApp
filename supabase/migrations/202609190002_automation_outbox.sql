-- Outbox used only by the n8n automation service.  Parent email addresses are
-- resolved from auth.users only while a service-role job is being claimed.
create table if not exists public.automation_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in (
    'DEIC_REFERRAL',
    'FOLLOW_UP',
    'APPOINTMENT_24H',
    'CLINICIAN_PRIORITY_DIGEST'
  )),
  recipient_profile_id uuid not null references public.profiles(id) on delete cascade,
  child_id uuid references public.children(id) on delete cascade,
  appointment_id uuid references public.appointments(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  dedupe_key text not null unique,
  scheduled_for timestamptz not null,
  status text not null default 'pending' check (status in ('pending', 'processing', 'sent', 'failed')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  locked_at timestamptz,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);

create index if not exists automation_notification_outbox_due_idx
  on public.automation_notification_outbox (scheduled_for, id)
  where status = 'pending';
create index if not exists automation_notification_outbox_recipient_idx
  on public.automation_notification_outbox (recipient_profile_id, created_at desc);

alter table public.automation_notification_outbox enable row level security;
revoke all on public.automation_notification_outbox from public, anon, authenticated;
grant select, insert, update, delete on public.automation_notification_outbox to service_role;

-- Queue every notification deterministically. Re-running this function is safe:
-- the unique dedupe key prevents duplicate emails for the same care event.
create or replace function public.queue_automation_notifications(
  p_kinds text[] default null,
  p_as_of timestamptz default now()
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  queued_count integer := 0;
begin
  -- A stopped workflow may leave a job claimed. Make it retryable on the next
  -- schedule run rather than silently dropping a family reminder.
  update public.automation_notification_outbox
  set status = 'pending', locked_at = null
  where status = 'processing'
    and locked_at < p_as_of - interval '30 minutes';

  with latest_screenings as (
    select distinct on (session.child_id)
      session.id,
      session.child_id,
      session.created_at,
      session.risk_level
    from public.screening_sessions session
    where session.analysis_status = 'COMPLETE'
      and session.risk_level in ('yellow', 'red')
    order by session.child_id, session.created_at desc
  ), candidates as (
    -- Weekly DEIC referral reminders for an unresolved red result.
    select
      'DEIC_REFERRAL'::text as kind,
      guardian.parent_id as recipient_profile_id,
      screening.child_id,
      null::uuid as appointment_id,
      jsonb_build_object(
        'recipient_name', parent.display_name,
        'child_name', child.display_name
      ) as payload,
      format(
        'deic:%s:%s:%s',
        screening.id,
        guardian.parent_id,
        to_char(p_as_of at time zone 'Asia/Kolkata', 'IYYY-IW')
      ) as dedupe_key,
      p_as_of as scheduled_for
    from latest_screenings screening
    join public.children child on child.id = screening.child_id
    join public.child_guardians guardian on guardian.child_id = screening.child_id
    join public.profiles parent on parent.id = guardian.parent_id
    where screening.risk_level = 'red'
      and screening.created_at <= p_as_of - interval '1 day'
      and not exists (
        select 1
        from public.appointments appointment
        where appointment.child_id = screening.child_id
          and appointment.parent_id = guardian.parent_id
          and appointment.status in ('confirmed', 'completed')
          and coalesce(appointment.starts_at, appointment.requested_for, appointment.created_at) >= screening.created_at
      )

    union all

    -- A yellow result is revisited after twelve weeks, then no more than once
    -- per calendar month while the result remains the latest screening.
    select
      'FOLLOW_UP'::text as kind,
      guardian.parent_id as recipient_profile_id,
      screening.child_id,
      null::uuid as appointment_id,
      jsonb_build_object(
        'recipient_name', parent.display_name,
        'child_name', child.display_name
      ) as payload,
      format(
        'follow-up:%s:%s:%s',
        screening.id,
        guardian.parent_id,
        to_char(p_as_of at time zone 'Asia/Kolkata', 'YYYY-MM')
      ) as dedupe_key,
      p_as_of as scheduled_for
    from latest_screenings screening
    join public.children child on child.id = screening.child_id
    join public.child_guardians guardian on guardian.child_id = screening.child_id
    join public.profiles parent on parent.id = guardian.parent_id
    where screening.risk_level = 'yellow'
      and screening.created_at <= p_as_of - interval '84 days'
      and not exists (
        select 1
        from public.appointments appointment
        where appointment.child_id = screening.child_id
          and appointment.parent_id = guardian.parent_id
          and appointment.status in ('confirmed', 'completed')
          and coalesce(appointment.starts_at, appointment.requested_for, appointment.created_at) >= screening.created_at
      )

    union all

    -- This workflow runs every fifteen minutes. The one-hour window makes a
    -- missed scheduler tick harmless, while the unique key keeps it single-send.
    select
      'APPOINTMENT_24H'::text as kind,
      appointment.parent_id as recipient_profile_id,
      appointment.child_id,
      appointment.id as appointment_id,
      jsonb_build_object(
        'recipient_name', parent.display_name,
        'child_name', child.display_name,
        'starts_at', to_char(appointment.starts_at at time zone 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM')
      ) as payload,
      format(
        'appointment:%s:%s',
        appointment.id,
        to_char(appointment.starts_at at time zone 'Asia/Kolkata', 'YYYYMMDDHH24MI')
      ) as dedupe_key,
      p_as_of as scheduled_for
    from public.appointments appointment
    join public.children child on child.id = appointment.child_id
    join public.profiles parent on parent.id = appointment.parent_id
    where appointment.status = 'confirmed'
      and appointment.starts_at >= p_as_of + interval '23 hours 30 minutes'
      and appointment.starts_at < p_as_of + interval '24 hours 30 minutes'

    union all

    -- A clinician receives a count-only end-of-day digest for appointment
    -- requests that have not been answered in 24 hours.
    select
      'CLINICIAN_PRIORITY_DIGEST'::text as kind,
      appointment.clinician_id as recipient_profile_id,
      null::uuid as child_id,
      null::uuid as appointment_id,
      jsonb_build_object(
        'recipient_name', clinician.display_name,
        'pending_request_count', count(*)
      ) as payload,
      format(
        'clinician-digest:%s:%s',
        appointment.clinician_id,
        to_char(p_as_of at time zone 'Asia/Kolkata', 'YYYY-MM-DD')
      ) as dedupe_key,
      p_as_of as scheduled_for
    from public.appointments appointment
    join public.profiles clinician on clinician.id = appointment.clinician_id
    where appointment.status = 'requested'
      and appointment.created_at <= p_as_of - interval '24 hours'
    group by appointment.clinician_id, clinician.display_name
  )
  insert into public.automation_notification_outbox (
    kind,
    recipient_profile_id,
    child_id,
    appointment_id,
    payload,
    dedupe_key,
    scheduled_for
  )
  select
    candidate.kind,
    candidate.recipient_profile_id,
    candidate.child_id,
    candidate.appointment_id,
    candidate.payload,
    candidate.dedupe_key,
    candidate.scheduled_for
  from candidates candidate
  where p_kinds is null or candidate.kind = any(p_kinds)
  on conflict (dedupe_key) do nothing;

  get diagnostics queued_count = row_count;
  return queued_count;
end;
$$;

-- Atomically reserve due emails and expose only the delivery data needed by
-- n8n. FOR UPDATE SKIP LOCKED keeps concurrent workflow executions safe.
create or replace function public.claim_automation_notifications(
  p_kinds text[] default null,
  p_limit integer default 50
)
returns table (
  notification_id uuid,
  recipient_email text,
  subject text,
  body text
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  return query
  with due as (
    select outbox.id
    from public.automation_notification_outbox outbox
    join auth.users recipient on recipient.id = outbox.recipient_profile_id
    where outbox.status = 'pending'
      and outbox.scheduled_for <= now()
      and (p_kinds is null or outbox.kind = any(p_kinds))
      and recipient.email is not null
      and coalesce(recipient.email_confirmed_at, recipient.confirmed_at) is not null
    order by outbox.scheduled_for, outbox.id
    for update of outbox skip locked
    limit least(greatest(coalesce(p_limit, 50), 1), 100)
  ), claimed as (
    update public.automation_notification_outbox outbox
    set
      status = 'processing',
      locked_at = now(),
      attempt_count = outbox.attempt_count + 1,
      last_error = null
    from due
    where outbox.id = due.id
    returning outbox.*
  )
  select
    claimed.id,
    recipient.email,
    case claimed.kind
      when 'DEIC_REFERRAL' then 'EarlyEcho: follow-up support is available'
      when 'FOLLOW_UP' then 'EarlyEcho: it is time to plan a follow-up screening'
      when 'APPOINTMENT_24H' then 'EarlyEcho: appointment reminder for tomorrow'
      when 'CLINICIAN_PRIORITY_DIGEST' then 'EarlyEcho: appointment requests need review'
    end,
    case claimed.kind
      when 'DEIC_REFERRAL' then format(
        'Hello %s,\n\nA follow-up care referral for %s is still open. Please sign in to EarlyEcho or contact your care centre to plan the next step. This reminder does not provide a diagnosis.',
        coalesce(nullif(claimed.payload ->> 'recipient_name', ''), 'there'),
        coalesce(nullif(claimed.payload ->> 'child_name', ''), 'your child')
      )
      when 'FOLLOW_UP' then format(
        'Hello %s,\n\nIt is time to plan a follow-up screening for %s. Please sign in to EarlyEcho or contact your care centre to choose the next step.',
        coalesce(nullif(claimed.payload ->> 'recipient_name', ''), 'there'),
        coalesce(nullif(claimed.payload ->> 'child_name', ''), 'your child')
      )
      when 'APPOINTMENT_24H' then format(
        'Hello %s,\n\nThis is a reminder that %s has an EarlyEcho appointment on %s. Please contact your care team if you need help attending.',
        coalesce(nullif(claimed.payload ->> 'recipient_name', ''), 'there'),
        coalesce(nullif(claimed.payload ->> 'child_name', ''), 'your child'),
        coalesce(nullif(claimed.payload ->> 'starts_at', ''), 'the scheduled time')
      )
      when 'CLINICIAN_PRIORITY_DIGEST' then format(
        'Hello %s,\n\nYou have %s appointment request(s) awaiting a response for more than 24 hours. Please open the EarlyEcho clinical workspace to review them.',
        coalesce(nullif(claimed.payload ->> 'recipient_name', ''), 'there'),
        coalesce(nullif(claimed.payload ->> 'pending_request_count', ''), '0')
      )
    end
  from claimed
  join auth.users recipient on recipient.id = claimed.recipient_profile_id;
end;
$$;

create or replace function public.mark_automation_notification_sent(
  p_notification_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.automation_notification_outbox
  set status = 'sent', sent_at = now(), locked_at = null
  where id = p_notification_id
    and status = 'processing';

  return found;
end;
$$;

revoke all on function public.queue_automation_notifications(text[], timestamptz) from public, anon, authenticated;
revoke all on function public.claim_automation_notifications(text[], integer) from public, anon, authenticated;
revoke all on function public.mark_automation_notification_sent(uuid) from public, anon, authenticated;
grant execute on function public.queue_automation_notifications(text[], timestamptz) to service_role;
grant execute on function public.claim_automation_notifications(text[], integer) to service_role;
grant execute on function public.mark_automation_notification_sent(uuid) to service_role;
