import { ClinicianAppointmentActions } from "@/components/clinician-appointment-actions";
import { EmptyState } from "@/components/empty-state";
import { getClinicianDashboardData } from "@/lib/dashboard-data";

export default async function ClinicianAppointmentsPage() {
  const { data, error } = await getClinicianDashboardData();
  const names = new Map(data.children.map((child) => [child.id, child.displayName]));
  return <div className="stack"><section><p className="eyebrow">Care visits</p><h1>Appointment requests</h1><p className="lede">Confirm only a time you can honour. Families see the confirmed status in their care portal.</p></section>{error ? <p className="alert">{error}</p> : null}<section className="card card-pad">{data.appointments.length ? <div className="list">{data.appointments.map((appointment) => <div className="list-row" key={appointment.id}><span><span className="row-title">{names.get(appointment.childId) ?? "Child"}</span><span className="row-subtitle">{appointment.requestedFor ? new Intl.DateTimeFormat("en-IN", { dateStyle: "medium", timeStyle: "short" }).format(new Date(appointment.requestedFor)) : "No preferred time"}{appointment.reason ? ` · ${appointment.reason}` : ""}</span></span><ClinicianAppointmentActions appointmentId={appointment.id} status={appointment.status} /></div>)}</div> : <EmptyState detail="Family appointment requests will appear here." title="No appointment requests" />}</section></div>;
}
