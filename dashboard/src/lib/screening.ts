export type RiskLevel = "green" | "yellow" | "red" | "incomplete";

export type ScreeningSnapshot = {
  riskLevel: RiskLevel;
  screenedAt: string;
  childAgeMonths?: number | null;
  vttlMs: number | null;
  cvrRatio: number | null;
  pfvStd: number | null;
  qualityReasons?: string[] | null;
};

export function normaliseRisk(value: string | null | undefined): RiskLevel {
  switch (value?.toLowerCase()) {
    case "red":
      return "red";
    case "yellow":
      return "yellow";
    case "green":
      return "green";
    default:
      return "incomplete";
  }
}

export function riskTitle(risk: RiskLevel): string {
  return {
    green: "No concern identified",
    yellow: "Follow-up recommended",
    red: "Clinical review recommended",
    incomplete: "Screening needs to be repeated",
  }[risk];
}

export function riskAction(risk: RiskLevel): string {
  return {
    green: "Continue routine developmental monitoring.",
    yellow: "Arrange a repeat screening in around three months, or sooner if concerns persist.",
    red: "Arrange a comprehensive developmental evaluation with the care team.",
    incomplete: "The recording quality was not sufficient for a result. Arrange another screening.",
  }[risk];
}

export function flaggedBiomarkers(snapshot: ScreeningSnapshot): string[] {
  const flags: string[] = [];
  if ((snapshot.vttlMs ?? 0) > 1000) flags.push("VTTL");
  const cvrThreshold = snapshot.childAgeMonths === null || snapshot.childAgeMonths === undefined
    ? null
    : snapshot.childAgeMonths < 24 ? 0.08 : snapshot.childAgeMonths < 36 ? 0.12 : 0.15;
  if (cvrThreshold !== null && (snapshot.cvrRatio ?? 1) < cvrThreshold) flags.push("CVR");
  if ((snapshot.childAgeMonths ?? 0) >= 36 && (snapshot.pfvStd ?? 99) < 15) flags.push("PFV");
  return flags;
}

export function formatScreeningDate(value: string): string {
  return new Intl.DateTimeFormat("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(new Date(value));
}
