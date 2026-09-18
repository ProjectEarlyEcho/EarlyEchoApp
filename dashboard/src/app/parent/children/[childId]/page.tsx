import Link from "next/link";

import { EmptyState } from "@/components/empty-state";
import { ScreeningSummary } from "@/components/screening-summary";
import { getChildScreeningData } from "@/lib/dashboard-data";

export default async function ParentChildPage({ params }: { params: Promise<{ childId: string }> }) {
  const { childId } = await params;
  const { data, error } = await getChildScreeningData(childId);
  if (!data.child) return <EmptyState detail="This child is not linked to your account, or the record is unavailable." title="Child record not found" action={<Link className="button secondary" href="/parent">Back to my family</Link>} />;
  return <div className="stack"><section><Link className="link" href="/parent">← My family</Link><p className="eyebrow" style={{ marginTop: 20 }}>Child record</p><h1>{data.child.displayName}</h1><p className="lede">A chronological screening summary for your family. These results help guide follow-up; they do not diagnose a condition.</p></section>{error ? <p className="alert">{error}</p> : null}{data.screenings.length ? <section className="stack">{data.screenings.map((screening) => <ScreeningSummary key={screening.id} screening={{ riskLevel: screening.risk, screenedAt: screening.createdAt, childAgeMonths: screening.childAgeMonths, vttlMs: screening.vttlMs, cvrRatio: screening.cvrRatio, pfvStd: screening.pfvStd, qualityReasons: screening.qualityReasons }} />)}</section> : <EmptyState detail="There are no screening sessions shared with your account yet." title="No screening history" />}</div>;
}
