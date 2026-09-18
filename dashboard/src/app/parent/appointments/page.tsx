import { AppointmentRequestForm } from "@/components/appointment-request-form";
import { EmptyState } from "@/components/empty-state";
import { getParentDashboardData } from "@/lib/dashboard-data";

export default async function ParentAppointmentsPage() {
  const { data, error } = await getParentDashboardData();
  const names = new Map(data.children.map((child) => [child.id, child.displayName]));
  return <div className="stack"><section><p className="eyebrow">Care visits</p><h1>Appointments</h1><p className="lede">Request a time that works for your family. A clinician confirms the appointment before it is final.</p></section>{error ? <p className="alert">{error}</p> : null}<section className="grid grid-2"><AppointmentRequestForm childRecords={data.children} /><div className="card card-pad"><p className="eyebrow">Appointment status</p><h2>Your requests</h2>{data.appointments.length ? <div className="list">{data.appointments.map((appointment) => <div className="list-row" key={appointment.id}><span><span className="row-title">{names.get(appointment.childId) ?? "Child"}</span><span className="row-subtitle">{appointment.startsAt || appointment.requestedFor ? new Intl.DateTimeFormat("en-IN", { dateStyle: "medium", timeStyle: "short" }).format(new Date(appointment.startsAt ?? appointment.requestedFor ?? "")) : "Time to be confirmed"}{appointment.reason ? ` · ${appointment.reason}` : ""}</span></span><span className="badge incomplete">{appointment.status}</span></div>)}</div> : <EmptyState detail="Appointment requests and confirmed visits will show here." title="No appointments" />}</div></section></div>;
}
