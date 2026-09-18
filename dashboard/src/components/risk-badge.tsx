import type { RiskLevel } from "@/lib/screening";

export function RiskBadge({ risk }: { risk: RiskLevel }) {
  const label = risk === "incomplete" ? "Repeat needed" : risk;
  return <span className={`badge ${risk}`}>{label}</span>;
}
