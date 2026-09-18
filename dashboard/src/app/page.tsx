import Link from "next/link";
import { redirect } from "next/navigation";

import { dashboardPathForRole, getViewer } from "@/lib/auth";

export default async function HomePage() {
  const viewer = await getViewer();
  if (viewer) redirect(dashboardPathForRole(viewer.role));

  return (
    <main className="auth-wrap">
      <section className="auth-card card">
        <div className="auth-brand"><span className="brand-mark">E</span><strong>EarlyEcho Care Portal</strong></div>
        <p className="eyebrow">Connected care</p>
        <h1 className="auth-title">A clearer next step after screening.</h1>
        <p className="lede">Parents can follow their child&apos;s screening summaries and care plan. Clinicians can coordinate appointments and follow up with families securely.</p>
        <div className="stack" style={{ marginTop: 24 }}>
          <Link className="button" href="/login">Sign in</Link>
          <Link className="button secondary" href="/signup">Create a parent account</Link>
        </div>
        <p className="auth-note">EarlyEcho screens for possible developmental concerns. It does not provide a diagnosis.</p>
      </section>
    </main>
  );
}
