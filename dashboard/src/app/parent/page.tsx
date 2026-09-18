import Link from "next/link";

import { EmptyState } from "@/components/empty-state";
import { RiskBadge } from "@/components/risk-badge";
import { ScreeningSummary } from "@/components/screening-summary";
import { getParentDashboardData } from "@/lib/dashboard-data";

export default async function ParentDashboardPage() {
  const { data, error } = await getParentDashboardData();
  const latestByChild = new Map<string, (typeof data.screenings)[number]>();
  for (const screening of data.screenings) {
    if (!latestByChild.has(screening.childId)) latestByChild.set(screening.childId, screening);
  }
  const followUps = [...latestByChild.values()].filter((screening) => screening.risk === "red" || screening.risk === "yellow").length;
  const nextAppointment = data.appointments.find((appointment) => appointment.status !== "cancelled" && appointment.status !== "declined");

  return <div className="stack">
    <section>
      <p className="eyebrow">My family</p><h1>Care that stays connected.</h1>
      <p className="lede">Review screening summaries, see the next care step, and stay in touch with your child&apos;s clinician.</p>
    </section>
    {error ? <p className="alert">{error}</p> : null}
    <section className="grid grid-3">
      <div className="card card-pad"><p className="metric-label">Children linked</p><p className="metric-value">{data.children.length}</p><p className="metric-note">Visible only to your family</p></div>
      <div className="card card-pad"><p className="metric-label">Follow-up to plan</p><p className="metric-value">{followUps}</p><p className="metric-note">Screening guidance is not a diagnosis</p></div>
      <div className="card card-pad"><p className="metric-label">Next appointment</p><p className="metric-value">{nextAppointment ? "Planned" : "None"}</p><p className="metric-note">{nextAppointment?.startsAt || nextAppointment?.requestedFor ? new Intl.DateTimeFormat("en-IN", { day: "numeric", month: "short" }).format(new Date(nextAppointment.startsAt ?? nextAppointment.requestedFor ?? "")) : "Request a visit when needed"}</p></div>
    </section>
    <section className="grid grid-2">
      <div className="card card-pad">
        <div className="section-head"><div><p className="eyebrow">Children</p><h2>Your family</h2></div><Link className="link" href="/parent/appointments">Request a visit</Link></div>
        {data.children.length ? <div className="list">{data.children.map((child) => {
          const screening = latestByChild.get(child.id);
          return <Link className="child-card" href={`/parent/children/${child.id}`} key={child.id}><span><span className="child-name">{child.displayName}</span><span className="child-meta">{screening ? "Latest screening available" : "No shared screening yet"}</span></span>{screening ? <RiskBadge risk={screening.risk} /> : <span className="badge incomplete">No result</span>}</Link>;
        })}</div> : <EmptyState detail="A child will appear here when your care team connects their record to your account." title="No children linked yet" />}
      </div>
      <div className="stack">
        {data.screenings[0] ? <ScreeningSummary screening={{ riskLevel: data.screenings[0].risk, screenedAt: data.screenings[0].createdAt, childAgeMonths: data.screenings[0].childAgeMonths, vttlMs: data.screenings[0].vttlMs, cvrRatio: data.screenings[0].cvrRatio, pfvStd: data.screenings[0].pfvStd, qualityReasons: data.screenings[0].qualityReasons }} /> : <EmptyState detail="After an eligible screening is synced, its parent-friendly summary will appear here." title="No screening summary yet" />}
        <div className="card card-pad"><p className="eyebrow">Need help?</p><h2>Message the care team</h2><p className="muted">Ask a non-urgent question, clarify a care step, or request a visit. For urgent health concerns, use local emergency services.</p><Link className="button secondary" href="/parent/messages">Open messages</Link></div>
      </div>
    </section>
  </div>;
}
