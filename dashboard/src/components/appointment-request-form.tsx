"use client";

import { FormEvent, useState } from "react";

import type { Child } from "@/lib/dashboard-data";
import { createClient } from "@/lib/supabase/client";

export function AppointmentRequestForm({ childRecords }: { childRecords: Child[] }) {
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function requestAppointment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage(null);
    const form = new FormData(event.currentTarget);
    const childId = String(form.get("childId"));
    const preferredTime = String(form.get("preferredTime"));
    const reason = String(form.get("reason"));
    const supabase = createClient();
    const { data: team, error: teamError } = await supabase
      .from("care_team")
      .select("clinician_id")
      .eq("child_id", childId)
      .limit(1)
      .maybeSingle();

    if (teamError || !team) {
      setMessage("There is no assigned clinician for this child yet. Please contact your care centre.");
      setBusy(false);
      return;
    }

    const { error } = await supabase.from("appointments").insert({
      child_id: childId,
      clinician_id: team.clinician_id,
      requested_for: new Date(preferredTime).toISOString(),
      reason,
    });
    if (error) {
      setMessage(error.message);
    } else {
      event.currentTarget.reset();
      setMessage("Your appointment request has been sent to the care team.");
    }
    setBusy(false);
  }

  return (
    <form className="card card-pad form" onSubmit={requestAppointment}>
      <div><p className="eyebrow">Request a visit</p><h2>Ask for an appointment</h2><p className="muted">Your clinician will confirm or suggest another time.</p></div>
      <div className="field"><label htmlFor="childId">Child</label><select defaultValue="" id="childId" name="childId" required><option disabled value="">Select a child</option>{childRecords.map((child) => <option key={child.id} value={child.id}>{child.displayName}</option>)}</select></div>
      <div className="field"><label htmlFor="preferredTime">Preferred date and time</label><input id="preferredTime" name="preferredTime" required type="datetime-local" /></div>
      <div className="field"><label htmlFor="reason">What would you like to discuss?</label><textarea id="reason" maxLength={1000} name="reason" placeholder="Optional" /></div>
      {message ? <p className={`form-message${message.includes("sent") ? " success" : " error"}`}>{message}</p> : null}
      <button className="button" disabled={busy || childRecords.length === 0} type="submit">{busy ? "Sending…" : "Send request"}</button>
    </form>
  );
}
