"use client";

import { FormEvent, useEffect, useState } from "react";
import { sendPasswordResetEmail, signInWithEmailAndPassword, signOut } from "firebase/auth";
import { ArrowRight, LogOut } from "lucide-react";
import { auth, ensureAuthPersistence, requireAuth } from "@/lib/firebase";

export function LoginForm() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [signedInEmail, setSignedInEmail] = useState<string | null>(null);

  useEffect(() => {
    if (!auth) {
      setMessage("Firebase configuration is missing for this build.");
      return undefined;
    }
    return auth.onAuthStateChanged((user) => {
      setSignedInEmail(user?.email ?? null);
    });
  }, []);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      await ensureAuthPersistence();
      await signInWithEmailAndPassword(requireAuth(), email.trim(), password);
      window.location.href = "/app/";
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Login failed.");
    } finally {
      setBusy(false);
    }
  }

  async function resetPassword() {
    if (!email.trim()) {
      setMessage("Enter your email address first.");
      return;
    }
    setBusy(true);
    setMessage("");
    try {
      await sendPasswordResetEmail(requireAuth(), email.trim());
      setMessage("Password reset email sent.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Password reset failed.");
    } finally {
      setBusy(false);
    }
  }

  async function logout() {
    await signOut(requireAuth());
  }

  return (
    <div className="mx-auto max-w-md rounded-lg border border-slate-200 bg-white p-6 shadow-sm">
      {signedInEmail ? (
        <div className="grid gap-4">
          <p className="text-sm font-bold text-slate-700">Signed in as {signedInEmail}.</p>
          <a href="/app/" className="alluwal-button alluwal-button-primary">
            Open dashboard
            <ArrowRight size={18} />
          </a>
          <button type="button" className="alluwal-button alluwal-button-light" onClick={logout}>
            <LogOut size={18} />
            Sign out
          </button>
        </div>
      ) : (
        <form onSubmit={onSubmit} className="grid gap-4">
          <label className="field-label">
            Email
            <input
              className="field-input"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              type="email"
              required
              autoComplete="email"
            />
          </label>
          <label className="field-label">
            Password
            <input
              className="field-input"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              type="password"
              required
              autoComplete="current-password"
            />
          </label>
          <button type="submit" className="alluwal-button alluwal-button-primary" disabled={busy}>
            {busy ? "Signing in..." : "Login"}
          </button>
          <button type="button" className="text-sm font-black text-[#0386FF]" disabled={busy} onClick={resetPassword}>
            Send password reset email
          </button>
        </form>
      )}
      {message ? <p className="mt-4 text-sm font-bold text-slate-700">{message}</p> : null}
    </div>
  );
}
