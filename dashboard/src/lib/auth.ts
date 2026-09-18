import { cache } from "react";
import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export type AppRole = "parent" | "clinician" | "admin";

export type Viewer = {
  id: string;
  displayName: string | null;
  role: AppRole;
};

export const dashboardPathForRole = (role: AppRole) =>
  role === "parent" ? "/parent" : "/clinician";

export const getViewer = cache(async (): Promise<Viewer | null> => {
  const supabase = await createClient();
  if (!supabase) return null;

  const { data: authData } = await supabase.auth.getUser();
  const user = authData.user;
  if (!user) return null;

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, display_name, role")
    .eq("id", user.id)
    .maybeSingle();

  if (!profile) return null;

  return {
    id: profile.id as string,
    displayName: profile.display_name as string | null,
    role: profile.role as AppRole,
  };
});

export async function requireRole(...roles: AppRole[]): Promise<Viewer> {
  const viewer = await getViewer();
  if (!viewer) redirect("/login");
  if (!roles.includes(viewer.role)) {
    redirect(dashboardPathForRole(viewer.role));
  }
  return viewer;
}
