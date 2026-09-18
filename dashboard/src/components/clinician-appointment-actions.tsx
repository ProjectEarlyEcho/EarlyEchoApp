"use client";

import { useState } from "react";

import { createClient } from "@/lib/supabase/client";

export function ClinicianAppointmentActions({ appointmentId, status }: { appointmentId: string; status: string }) {
  const [currentStatus, setCurrentStatus] = useState(status);
  const [busy, setBusy] = useState(false);

  async function update(nextStatus: "confirmed" | "declined") {
    setBusy(true);
    const { error } = await createClient().from("appointments").update({ status: nextStatus }).eq("id", appointmentId);
    if (!error) setCurrentStatus(nextStatus);
    setBusy(false);
  }

  if (currentStatus !== "requested") return <span className="badge green">{currentStatus}</span>;
  return <span style={{ display: "flex", gap: 8 }}><button className="button" disabled={busy} onClick={() => update("confirmed")} type="button">Confirm</button><button className="button secondary" disabled={busy} onClick={() => update("declined")} type="button">Decline</button></span>;
}
