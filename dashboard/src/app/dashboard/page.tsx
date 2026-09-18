import { redirect } from "next/navigation";

import { dashboardPathForRole, requireRole } from "@/lib/auth";

export default async function DashboardRedirect() {
  const viewer = await requireRole("parent", "clinician", "admin");
  redirect(dashboardPathForRole(viewer.role));
}
