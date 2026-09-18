import type { ReactNode } from "react";

import { DashboardShell } from "@/components/dashboard-shell";
import { requireRole } from "@/lib/auth";

export default async function ParentLayout({ children }: { children: ReactNode }) {
  const viewer = await requireRole("parent");
  return <DashboardShell viewer={viewer}>{children}</DashboardShell>;
}
