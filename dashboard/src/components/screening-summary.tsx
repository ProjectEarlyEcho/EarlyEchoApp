import { RiskBadge } from "@/components/risk-badge";
import { formatScreeningDate, riskAction, riskTitle, type ScreeningSnapshot } from "@/lib/screening";

type Props = { screening: ScreeningSnapshot; compact?: boolean };

export function ScreeningSummary({ screening, compact = false }: Props) {
  const tone = screening.riskLevel === "green" || screening.riskLevel === "incomplete" ? "" : screening.riskLevel;
  return (
    <article className="card screening-card">
      <div className="screening-top">
        <div>
          <p className="eyebrow">Screening summary</p>
          <h3>{riskTitle(screening.riskLevel)}</h3>
          <p className="muted" style={{ marginBottom: 0 }}>Completed {formatScreeningDate(screening.screenedAt)}</p>
        </div>
        <RiskBadge risk={screening.riskLevel} />
      </div>
      {!compact ? (
        <div className="metric-table" aria-label="Acoustic biomarkers">
          <div><span>VTTL</span><strong>{screening.vttlMs === null ? "—" : `${Math.round(screening.vttlMs)} ms`}</strong></div>
          <div><span>CVR</span><strong>{screening.cvrRatio === null ? "—" : screening.cvrRatio.toFixed(3)}</strong></div>
          <div><span>PFV</span><strong>{screening.pfvStd === null ? "—" : `${screening.pfvStd.toFixed(1)} ST`}</strong></div>
        </div>
      ) : null}
      <div className={`action-box ${tone}`}>{riskAction(screening.riskLevel)}</div>
      {screening.qualityReasons?.length ? <p className="muted" style={{ margin: "12px 0 0", fontSize: 12 }}>Quality note: {screening.qualityReasons.join(", ")}</p> : null}
    </article>
  );
}
