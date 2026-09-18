"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";

import { createClient } from "@/lib/supabase/client";

type Props = { mode: "login" | "signup" };

export function AuthForm({ mode }: Props) {
  const router = useRouter();
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const isSignup = mode === "signup";

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage(null);
    const values = new FormData(event.currentTarget);
    const email = String(values.get("email") ?? "");
    const password = String(values.get("password") ?? "");
    const supabase = createClient();
    const response = isSignup
      ? await supabase.auth.signUp({
          email,
          password,
          options: { data: { display_name: String(values.get("displayName") ?? "") } },
        })
      : await supabase.auth.signInWithPassword({ email, password });

    if (response.error) {
      setMessage(response.error.message);
      setBusy(false);
      return;
    }
    if (isSignup && !response.data.session) {
      setMessage("Check your email to confirm your account, then sign in.");
      setBusy(false);
      return;
    }
    router.replace("/dashboard");
    router.refresh();
  }

  return (
    <form className="form" onSubmit={onSubmit}>
      {isSignup ? (
        <div className="field">
          <label htmlFor="displayName">Your name</label>
          <input autoComplete="name" id="displayName" name="displayName" required />
        </div>
      ) : null}
      <div className="field">
        <label htmlFor="email">Email address</label>
        <input autoComplete="email" id="email" name="email" required type="email" />
      </div>
      <div className="field">
        <label htmlFor="password">Password</label>
        <input autoComplete={isSignup ? "new-password" : "current-password"} id="password" minLength={8} name="password" required type="password" />
      </div>
      {message ? <p className={`form-message${message.includes("Check your email") ? " success" : " error"}`}>{message}</p> : null}
      <button className="button" disabled={busy} type="submit">{busy ? "Please wait…" : isSignup ? "Create parent account" : "Sign in"}</button>
      <p className="auth-note">
        {isSignup ? "Already have an account? " : "New to EarlyEcho? "}
        <Link className="link" href={isSignup ? "/login" : "/signup"}>{isSignup ? "Sign in" : "Create a parent account"}</Link>
      </p>
    </form>
  );
}
