-- Completed mobile screenings and consent are immutable, owner-scoped records.
-- Keep legacy consent records unowned: the previous schema did not record the
-- writer and a screening link alone cannot prove who collected the consent.
begin;

alter table public.consent_logs
  add column created_by uuid references public.profiles(id);
alter table public.consent_logs alter column created_by set default auth.uid();

-- NOT VALID retains pre-existing unowned/unlinked records without making them
-- accessible to clients. All new writes must establish owner and linkage.
alter table public.screenings add constraint screenings_owner_required
  check (created_by is not null) not valid;
alter table public.consent_logs add constraint consent_logs_owner_required
  check (created_by is not null and session_id is not null) not valid;
create index consent_logs_created_by_idx on public.consent_logs(created_by);

-- Provisioned role and centre may only be changed by the trusted service role.
create or replace function public.prevent_client_role_change()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is not null and (
    new.role is distinct from old.role or
    new.anganwadi_id is distinct from old.anganwadi_id
  ) then
    raise exception 'Role and centre changes require administrative provisioning'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop policy if exists workers_insert on public.screenings;
drop policy if exists care_workers_insert_screenings on public.screenings;
drop policy if exists care_workers_read_screenings on public.screenings;
drop policy if exists care_workers_update_screenings on public.screenings;
create policy care_workers_read_screenings on public.screenings
  for select to authenticated using (created_by = auth.uid());
create policy care_workers_insert_screenings on public.screenings
  for insert to authenticated with check (
    created_by = auth.uid() and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('clinician', 'admin')
        and (p.role = 'admin' or p.anganwadi_id = screenings.anganwadi_id)
    )
  );

drop policy if exists workers_insert_consent on public.consent_logs;
drop policy if exists care_workers_insert_consent on public.consent_logs;
create policy care_workers_read_consent on public.consent_logs
  for select to authenticated using (created_by = auth.uid());
create policy care_workers_insert_consent on public.consent_logs
  for insert to authenticated with check (
    created_by = auth.uid() and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('clinician', 'admin')
        and (p.role = 'admin' or p.anganwadi_id = consent_logs.anganwadi_id)
    ) and exists (
      select 1 from public.screenings s
      where s.id = consent_logs.session_id and s.created_by = auth.uid()
        and s.anganwadi_id = consent_logs.anganwadi_id
    )
  );

revoke all on public.screenings, public.consent_logs from public, anon, authenticated;
grant select, insert on public.screenings, public.consent_logs to authenticated;

-- SECURITY INVOKER deliberately preserves RLS for both inserts and replays.
-- The primary key serializes concurrent attempts. A second statement reads the
-- winning committed row under READ COMMITTED; no conflict overwrites occur.
create function public.sync_screening(p_screening jsonb)
returns text language plpgsql security invoker set search_path = '' as $$
declare
  incoming public.screenings;
  existing public.screenings;
begin
  incoming := jsonb_populate_record(null::public.screenings, p_screening);
  insert into public.screenings (
    id, anganwadi_id, state_code, district_code, child_age_months, risk_level,
    vttl_ms, pfv_std, cvr_ratio, vttl_flagged, pfv_flagged, cvr_flagged,
    audio_source, session_date, created_by
  ) values (
    incoming.id, incoming.anganwadi_id, incoming.state_code, incoming.district_code,
    incoming.child_age_months, incoming.risk_level, incoming.vttl_ms,
    incoming.pfv_std, incoming.cvr_ratio, incoming.vttl_flagged,
    incoming.pfv_flagged, incoming.cvr_flagged, incoming.audio_source,
    incoming.session_date, incoming.created_by
  ) on conflict (id) do nothing;
  if found then return 'inserted'; end if;

  select * into existing from public.screenings where id = incoming.id;
  if found and (to_jsonb(existing) - 'created_at') = (to_jsonb(incoming) - 'created_at') then
    return 'replayed';
  end if;
  raise exception 'Screening identity conflicts with an existing record'
    using errcode = 'PT409';
end;
$$;

create function public.sync_consent_log(p_consent jsonb)
returns text language plpgsql security invoker set search_path = '' as $$
declare
  incoming public.consent_logs;
  existing public.consent_logs;
begin
  incoming := jsonb_populate_record(null::public.consent_logs, p_consent);
  insert into public.consent_logs (
    id, session_id, anganwadi_id, worker_name, consented_at, created_by
  ) values (
    incoming.id, incoming.session_id, incoming.anganwadi_id,
    incoming.worker_name, incoming.consented_at, incoming.created_by
  ) on conflict (id) do nothing;
  if found then return 'inserted'; end if;

  select * into existing from public.consent_logs where id = incoming.id;
  if found and (to_jsonb(existing) - 'created_at') = (to_jsonb(incoming) - 'created_at') then
    return 'replayed';
  end if;
  raise exception 'Consent identity conflicts with an existing record'
    using errcode = 'PT409';
end;
$$;

revoke all on function public.sync_screening(jsonb), public.sync_consent_log(jsonb)
  from public, anon;
grant execute on function public.sync_screening(jsonb), public.sync_consent_log(jsonb)
  to authenticated;

commit;
