import type { ReactNode } from "react";

import { DashboardShell } from "@/components/dashboard-shell";
import { requireRole } from "@/lib/auth";

export default async function ClinicianLayout({ children }: { children: ReactNode }) {
  const viewer = await requireRole("clinician", "admin");
  return <DashboardShell viewer={viewer}>{children}</DashboardShell>;
}
