-- Keep private mobile audit records separate from shared care-team projections.
-- Parents can sync their own unlinked captures; assigned clinicians can publish
-- an atomic, immutable projection under the same screening UUID.
begin;

-- Permissive policies combine with OR, so remove both historical role-specific
-- policy sets before installing the canonical owner and consent-link predicates.
drop policy if exists workers_insert on public.screenings;
drop policy if exists care_workers_insert_screenings on public.screenings;
drop policy if exists care_workers_read_screenings on public.screenings;
drop policy if exists care_workers_update_screenings on public.screenings;
drop policy if exists parents_insert_screenings on public.screenings;
drop policy if exists parents_update_screenings on public.screenings;
drop policy if exists mobile_owners_read_screenings on public.screenings;
drop policy if exists mobile_owners_insert_screenings on public.screenings;
create policy mobile_owners_read_screenings on public.screenings
  for select to authenticated using (created_by = auth.uid());
create policy mobile_owners_insert_screenings on public.screenings
  for insert to authenticated with check (
    created_by = auth.uid() and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and (
        p.role in ('parent', 'admin') or
        (p.role = 'clinician' and p.anganwadi_id = screenings.anganwadi_id)
      )
    )
  );

drop policy if exists workers_insert_consent on public.consent_logs;
drop policy if exists care_workers_insert_consent on public.consent_logs;
drop policy if exists care_workers_read_consent on public.consent_logs;
drop policy if exists parents_insert_consent on public.consent_logs;
drop policy if exists parents_update_consent on public.consent_logs;
drop policy if exists mobile_owners_read_consent on public.consent_logs;
drop policy if exists mobile_owners_insert_consent on public.consent_logs;
create policy mobile_owners_read_consent on public.consent_logs
  for select to authenticated using (created_by = auth.uid());
create policy mobile_owners_insert_consent on public.consent_logs
  for insert to authenticated with check (
    created_by = auth.uid() and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and (
        p.role in ('parent', 'admin') or
        (p.role = 'clinician' and p.anganwadi_id = consent_logs.anganwadi_id)
      )
    ) and exists (
      select 1 from public.screenings s
      where s.id = consent_logs.session_id and s.created_by = auth.uid()
        and s.anganwadi_id = consent_logs.anganwadi_id
    )
  );

revoke all on public.screenings, public.consent_logs from public, anon, authenticated;
grant select, insert on public.screenings, public.consent_logs to authenticated;
-- Preserve the portal's guardian/assigned-clinician SELECT and INSERT policies.
-- Neither the mobile owner nor another care participant may edit a projection.
revoke update, delete, truncate on public.screening_sessions from public, anon, authenticated;

create or replace function public.sync_child_screening(p_screening jsonb, p_dashboard jsonb)
returns text language plpgsql security invoker set search_path = '' as $$
declare
  mobile public.screenings;
  incoming public.screening_sessions;
  existing public.screening_sessions;
  mobile_result text;
begin
  if jsonb_typeof(p_screening) is distinct from 'object' or
     jsonb_typeof(p_dashboard) is distinct from 'object' then
    raise exception 'Screening and care projection must be JSON objects'
      using errcode = '22023';
  end if;
  mobile := jsonb_populate_record(null::public.screenings, p_screening);
  incoming := jsonb_populate_record(null::public.screening_sessions, p_dashboard);

  if auth.uid() is null or mobile.created_by is distinct from auth.uid() or
     incoming.created_by is distinct from auth.uid() then
    raise exception 'Screening and care projection require the authenticated owner'
      using errcode = '42501';
  end if;
  -- Compare typed values: equivalent numeric encodings and timestamp offsets
  -- replay safely. The dashboard timestamp is capture time, not server time.
  if mobile.id is null or incoming.id is distinct from mobile.id or
     incoming.created_at is distinct from mobile.session_date or
     incoming.child_age_months is distinct from mobile.child_age_months or
     incoming.risk_level is distinct from mobile.risk_level or
     incoming.vttl_ms is distinct from mobile.vttl_ms or
     incoming.pfv_std is distinct from mobile.pfv_std or
     incoming.cvr_ratio is distinct from mobile.cvr_ratio or
     incoming.audio_source is distinct from mobile.audio_source or
     incoming.analysis_status is distinct from 'COMPLETE' or
     incoming.quality_reasons is distinct from '[]'::jsonb then
    raise exception 'Care projection conflicts with the mobile screening'
      using errcode = 'PT409';
  end if;

  mobile_result := public.sync_screening(p_screening);
  -- INSERT checks the existing assigned-child RLS even for a replay. If this
  -- projection is denied or conflicts, the mobile insert above rolls back too.
  insert into public.screening_sessions (
    id, child_id, created_by, created_at, analysis_status, risk_level,
    child_age_months, vttl_ms, pfv_std, cvr_ratio, audio_source,
    decision_trace, quality_reasons
  ) values (
    incoming.id, incoming.child_id, incoming.created_by, incoming.created_at,
    incoming.analysis_status, incoming.risk_level, incoming.child_age_months,
    incoming.vttl_ms, incoming.pfv_std, incoming.cvr_ratio, incoming.audio_source,
    incoming.decision_trace, incoming.quality_reasons
  ) on conflict (id) do nothing;
  if found then return 'inserted'; end if;

  select * into existing from public.screening_sessions where id = incoming.id;
  -- Care-team SELECT visibility does not confer replay ownership. Include every
  -- dashboard field (including child, owner, trace and capture time) in equality.
  if found and existing.created_by = auth.uid() and
     to_jsonb(existing) = to_jsonb(incoming) then
    return mobile_result;
  end if;
  raise exception 'Care projection identity conflicts with an existing record'
    using errcode = 'PT409';
end;
$$;

revoke all on function public.sync_child_screening(jsonb, jsonb) from public, anon;
grant execute on function public.sync_child_screening(jsonb, jsonb) to authenticated;

commit;
