import Link from "next/link";

import { EmptyState } from "@/components/empty-state";
import { RiskBadge } from "@/components/risk-badge";
import { getClinicianDashboardData } from "@/lib/dashboard-data";

export default async function ClinicianFamiliesPage() {
  const { data, error } = await getClinicianDashboardData();
  const latestByChild = new Map<string, (typeof data.screenings)[number]>();
  for (const screening of data.screenings) if (!latestByChild.has(screening.childId)) latestByChild.set(screening.childId, screening);
  return <div className="stack"><section><p className="eyebrow">Assigned care</p><h1>Families and children</h1><p className="lede">Only children formally assigned to you are listed here. Open a record to review the screening history.</p></section>{error ? <p className="alert">{error}</p> : null}<section className="card card-pad">{data.children.length ? <div className="list">{data.children.map((child) => { const screening = latestByChild.get(child.id); return <Link className="list-row" href={`/clinician/children/${child.id}`} key={child.id}><span><span className="row-title">{child.displayName}</span><span className="row-subtitle">{screening ? `Latest screen: ${new Intl.DateTimeFormat("en-IN", { dateStyle: "medium" }).format(new Date(screening.createdAt))}` : "No screening sessions"}</span></span>{screening ? <RiskBadge risk={screening.risk} /> : <span className="badge incomplete">No result</span>}</Link>; })}</div> : <EmptyState detail="When an administrator assigns a child to you, they will appear here." title="No families assigned" />}</section></div>;
}
