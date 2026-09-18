import Link from "next/link";

import { EmptyState } from "@/components/empty-state";
import { ScreeningSummary } from "@/components/screening-summary";
import { getChildScreeningData } from "@/lib/dashboard-data";
import { flaggedBiomarkers } from "@/lib/screening";

export default async function ClinicianChildPage({ params }: { params: Promise<{ childId: string }> }) {
  const { childId } = await params;
  const { data, error } = await getChildScreeningData(childId);
  if (!data.child) return <EmptyState detail="This child is not assigned to you, or the record is unavailable." title="Child record not found" action={<Link className="button secondary" href="/clinician/families">Back to families</Link>} />;
  return <div className="stack"><section><Link className="link" href="/clinician/families">← Assigned families</Link><p className="eyebrow" style={{ marginTop: 20 }}>Clinical screening record</p><h1>{data.child.displayName}</h1><p className="lede">Use the numeric biomarkers alongside clinical judgement. A screening result is not a diagnosis.</p></section>{error ? <p className="alert">{error}</p> : null}{data.screenings.length ? data.screenings.map((screening) => <section className="grid grid-2" key={screening.id}><ScreeningSummary screening={{ riskLevel: screening.risk, screenedAt: screening.createdAt, childAgeMonths: screening.childAgeMonths, vttlMs: screening.vttlMs, cvrRatio: screening.cvrRatio, pfvStd: screening.pfvStd, qualityReasons: screening.qualityReasons }} /><div className="card card-pad"><p className="eyebrow">Clinical review</p><h2>Signal details</h2><p className="muted">Analysis status: {screening.analysisStatus}</p><p className="muted">Flagged biomarkers: {flaggedBiomarkers({ riskLevel: screening.risk, screenedAt: screening.createdAt, childAgeMonths: screening.childAgeMonths, vttlMs: screening.vttlMs, cvrRatio: screening.cvrRatio, pfvStd: screening.pfvStd }).join(", ") || "None"}</p><p className="action-box">Document a clinical assessment in your approved clinical record system. Keep sensitive notes out of general family chat.</p></div></section>) : <EmptyState detail="There are no screening sessions for this child." title="No screening history" />}</div>;
}
