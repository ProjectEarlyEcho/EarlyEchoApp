import { AuthForm } from "@/components/auth-form";

export default function SignupPage() {
  return (
    <main className="auth-wrap"><section className="auth-card card">
      <div className="auth-brand"><span className="brand-mark">E</span><strong>EarlyEcho</strong></div>
      <p className="eyebrow">For parents and guardians</p><h1 className="auth-title">Create your account</h1>
      <p className="lede">Connect with your child&apos;s care team and keep screening follow-up in one secure place.</p>
      <div style={{ marginTop: 24 }}><AuthForm mode="signup" /></div>
    </section></main>
  );
}
