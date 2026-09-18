import { describe, expect, it } from "vitest";

import { flaggedBiomarkers, normaliseRisk, riskAction } from "../src/lib/screening";

describe("screening presentation rules", () => {
  it("normalises stored risk values and treats unknown states as incomplete", () => {
    expect(normaliseRisk("RED")).toBe("red");
    expect(normaliseRisk("yellow")).toBe("yellow");
    expect(normaliseRisk(null)).toBe("incomplete");
  });

  it("identifies biomarker values that need clinical attention", () => {
    expect(
      flaggedBiomarkers({
        riskLevel: "red",
        screenedAt: "2026-09-18T00:00:00Z",
        childAgeMonths: 28,
        vttlMs: 1300,
        cvrRatio: 0.06,
        pfvStd: 20,
      }),
    ).toEqual(["VTTL", "CVR"]);
  });

  it("does not present a screening result as a diagnosis", () => {
    expect(riskAction("red")).toContain("evaluation");
    expect(riskAction("red")).not.toContain("diagnosis");
  });
});
