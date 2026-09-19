import { createClient } from "@/lib/supabase/server";
import { normaliseRisk, type RiskLevel } from "@/lib/screening";

export type Child = {
  id: string;
  displayName: string;
  birthDate: string | null;
};

export type Screening = {
  id: string;
  childId: string;
  createdAt: string;
  risk: RiskLevel;
  analysisStatus: string;
  childAgeMonths: number | null;
  vttlMs: number | null;
  cvrRatio: number | null;
  pfvStd: number | null;
  qualityReasons: string[];
};

export type Appointment = {
  id: string;
  childId: string;
  startsAt: string | null;
  requestedFor: string | null;
  status: string;
  reason: string | null;
};

type DataResult<T> = { data: T; error: string | null };

function dataResult<T>(data: T, error?: string): DataResult<T> {
  return { data, error: error ?? null };
}

function mapDashboardScreening(screening: Record<string, unknown>): Screening {
  return {
    id: screening.id as string,
    childId: screening.child_id as string,
    createdAt: screening.created_at as string,
    risk: normaliseRisk(screening.risk_level as string | null),
    analysisStatus: screening.analysis_status as string,
    childAgeMonths: screening.child_age_months as number | null,
    vttlMs: screening.vttl_ms as number | null,
    cvrRatio: screening.cvr_ratio as number | null,
    pfvStd: screening.pfv_std as number | null,
    qualityReasons: (screening.quality_reasons as string[] | null) ?? [],
  };
}

function mapMobileScreening(screening: Record<string, unknown>): Screening {
  return {
    id: screening.id as string,
    childId: `mobile-${screening.id as string}`,
    createdAt: screening.session_date as string,
    risk: normaliseRisk(screening.risk_level as string | null),
    analysisStatus: "COMPLETE",
    childAgeMonths: screening.child_age_months as number | null,
    vttlMs: screening.vttl_ms as number | null,
    cvrRatio: screening.cvr_ratio as number | null,
    pfvStd: screening.pfv_std as number | null,
    qualityReasons: [],
  };
}

export async function getParentDashboardData(): Promise<
  DataResult<{ children: Child[]; screenings: Screening[]; appointments: Appointment[] }>
> {
  const supabase = await createClient();
  if (!supabase) {
    return dataResult({ children: [], screenings: [], appointments: [] }, "Add Supabase environment variables to view live information.");
  }

  const [childrenResponse, dashboardScreeningsResponse, mobileScreeningsResponse, appointmentsResponse] = await Promise.all([
    supabase.from("children").select("id, display_name, birth_date").order("display_name"),
    supabase
      .from("screening_sessions")
      .select("id, child_id, created_at, risk_level, analysis_status, child_age_months, vttl_ms, cvr_ratio, pfv_std, quality_reasons")
      .order("created_at", { ascending: false }),
    supabase
      .from("screenings")
      .select("id, session_date, risk_level, child_age_months, vttl_ms, cvr_ratio, pfv_std")
      .order("session_date", { ascending: false }),
    supabase
      .from("appointments")
      .select("id, child_id, starts_at, requested_for, status, reason")
      .order("requested_for", { ascending: true }),
  ]);

  const error = [childrenResponse.error, dashboardScreeningsResponse.error, mobileScreeningsResponse.error, appointmentsResponse.error]
    .find(Boolean)?.message;

  return dataResult(
    {
      children: (childrenResponse.data ?? []).map((child) => ({
        id: child.id as string,
        displayName: child.display_name as string,
        birthDate: child.birth_date as string | null,
      })),
      screenings: [
        ...(dashboardScreeningsResponse.data ?? []).map((screening) => mapDashboardScreening(screening as Record<string, unknown>)),
        ...(mobileScreeningsResponse.data ?? []).map((screening) => mapMobileScreening(screening as Record<string, unknown>)),
      ].sort((a, b) => b.createdAt.localeCompare(a.createdAt)),
      appointments: (appointmentsResponse.data ?? []).map((appointment) => ({
        id: appointment.id as string,
        childId: appointment.child_id as string,
        startsAt: appointment.starts_at as string | null,
        requestedFor: appointment.requested_for as string | null,
        status: appointment.status as string,
        reason: appointment.reason as string | null,
      })),
    },
    error,
  );
}

export async function getClinicianDashboardData(): Promise<
  DataResult<{ children: Child[]; screenings: Screening[]; appointments: Appointment[] }>
> {
  // RLS returns only children assigned to the current clinician.
  return getParentDashboardData();
}

export async function getChildScreeningData(childId: string): Promise<
  DataResult<{ child: Child | null; screenings: Screening[] }>
> {
  const supabase = await createClient();
  if (!supabase) return dataResult({ child: null, screenings: [] }, "Add Supabase environment variables to view live information.");

  const [childResponse, screeningsResponse] = await Promise.all([
    supabase.from("children").select("id, display_name, birth_date").eq("id", childId).maybeSingle(),
    supabase
      .from("screening_sessions")
      .select("id, child_id, created_at, risk_level, analysis_status, child_age_months, vttl_ms, cvr_ratio, pfv_std, quality_reasons")
      .eq("child_id", childId)
      .order("created_at", { ascending: false }),
  ]);

  return dataResult(
    {
      child: childResponse.data
        ? {
            id: childResponse.data.id as string,
            displayName: childResponse.data.display_name as string,
            birthDate: childResponse.data.birth_date as string | null,
          }
        : null,
      screenings: (screeningsResponse.data ?? []).map((screening) => ({
        id: screening.id as string,
        childId: screening.child_id as string,
        createdAt: screening.created_at as string,
        risk: normaliseRisk(screening.risk_level as string | null),
        analysisStatus: screening.analysis_status as string,
        childAgeMonths: screening.child_age_months as number | null,
        vttlMs: screening.vttl_ms as number | null,
        cvrRatio: screening.cvr_ratio as number | null,
        pfvStd: screening.pfv_std as number | null,
        qualityReasons: (screening.quality_reasons as string[] | null) ?? [],
      })),
    },
    childResponse.error?.message ?? screeningsResponse.error?.message,
  );
}
