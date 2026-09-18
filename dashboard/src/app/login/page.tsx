import { AuthForm } from "@/components/auth-form";

export default function LoginPage() {
  return (
    <main className="auth-wrap"><section className="auth-card card">
      <div className="auth-brand"><span className="brand-mark">E</span><strong>EarlyEcho</strong></div>
      <p className="eyebrow">Welcome back</p><h1 className="auth-title">Sign in to your care portal</h1>
      <p className="lede">Use the email address associated with your EarlyEcho account.</p>
      <div style={{ marginTop: 24 }}><AuthForm mode="login" /></div>
      <p className="auth-note">Clinician accounts are created by the care organisation.</p>
    </section></main>
  );
}
