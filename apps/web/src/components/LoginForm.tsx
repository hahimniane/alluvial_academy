"use client";

import { FormEvent, useEffect, useState } from "react";
import {
  GoogleAuthProvider,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut,
} from "firebase/auth";
import { ArrowRight, Eye, EyeOff, LogOut, Mail, Phone, LockKeyhole, Badge } from "lucide-react";
import { auth, ensureAuthPersistence, requireAuth } from "@/lib/firebase";
import { dashboardPathForUser } from "@/lib/userRoles";

const flutterDashboardLoginPath = "/app/#/login";

export function LoginForm() {
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [useStudentId, setUseStudentId] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [signedInEmail, setSignedInEmail] = useState<string | null>(null);
  const [dashboardPath, setDashboardPath] = useState(flutterDashboardLoginPath);

  useEffect(() => {
    if (!auth) {
      setMessage("Firebase configuration is missing for this build.");
      return undefined;
    }
    return auth.onAuthStateChanged((user) => {
      setSignedInEmail(user?.email ?? null);
      if (!user) {
        setDashboardPath(flutterDashboardLoginPath);
        return;
      }
      dashboardPathForUser(user).then(setDashboardPath).catch(() => setDashboardPath(flutterDashboardLoginPath));
    });
  }, []);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      await ensureAuthPersistence();
      const credential = await signInWithEmailAndPassword(requireAuth(), loginEmail(), password);
      window.location.href = await dashboardPathForUser(credential.user);
    } catch (error) {
      setMessage(friendlyAuthError(error));
    } finally {
      setBusy(false);
    }
  }

  async function resetPassword() {
    if (useStudentId) {
      setMessage("Switch to Email and enter your email address first.");
      return;
    }
    if (!identifier.trim()) {
      setMessage("Please enter your email address first.");
      return;
    }
    setBusy(true);
    setMessage("");
    try {
      await sendPasswordResetEmail(requireAuth(), identifier.trim());
      setMessage("Password Reset Email Sent. Please check your inbox.");
    } catch (error) {
      setMessage(friendlyAuthError(error));
    } finally {
      setBusy(false);
    }
  }

  async function googleSignIn() {
    setBusy(true);
    setMessage("");
    try {
      await ensureAuthPersistence();
      const credential = await signInWithPopup(requireAuth(), new GoogleAuthProvider());
      window.location.href = await dashboardPathForUser(credential.user);
    } catch (error) {
      setMessage(friendlyAuthError(error));
    } finally {
      setBusy(false);
    }
  }

  async function logout() {
    await signOut(requireAuth());
  }

  function loginEmail() {
    const value = identifier.trim();
    return useStudentId ? `${value.toLowerCase()}@alluwaleducationhub.org` : value;
  }

  return (
    <div className="mx-auto w-full max-w-[450px] md:rounded-2xl md:bg-white md:p-5 md:shadow-[0_8px_24px_rgba(15,23,42,0.08)]">
      {signedInEmail ? (
        <div className="grid gap-4 rounded-2xl bg-white p-5 shadow-[0_8px_24px_rgba(15,23,42,0.08)] md:p-0 md:shadow-none">
          <p className="text-sm font-bold text-slate-700">Signed in as {signedInEmail}.</p>
          <a href={dashboardPath} className="alluwal-button alluwal-button-primary">
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
          <LogoHeader />

          <div className="grid gap-4 rounded-[24px] bg-white p-4 shadow-[0_8px_24px_rgba(15,23,42,0.05)] md:contents md:p-0 md:shadow-none">
          <label className="hidden items-center gap-3 text-sm font-medium text-[#374151] md:flex">
            <button
              type="button"
              aria-pressed={useStudentId}
              onClick={() => {
                setUseStudentId(!useStudentId);
                setIdentifier("");
              }}
              className={`flex h-8 w-[54px] items-center rounded-full border px-1 transition ${
                useStudentId ? "border-[#0386FF] bg-[#0386FF]/15" : "border-[#9CA3AF] bg-[#E5E7EB]"
              }`}
            >
              <span
                className={`h-6 w-6 rounded-full shadow-sm transition ${
                  useStudentId ? "translate-x-5 bg-[#0386FF]" : "translate-x-0 bg-[#6B7280]"
                }`}
              />
            </button>
            Use Student Id
          </label>

          <div className="flex items-center gap-3 md:hidden">
            <ModeTabs
              useStudentId={useStudentId}
              setUseStudentId={(next) => {
                setUseStudentId(next);
                setIdentifier("");
              }}
            />
          </div>

          <label className="grid gap-1.5 text-sm font-medium text-[#374151]">
            <span>{useStudentId ? "Student ID" : "Email"}</span>
            <span className="flex min-h-12 items-center gap-3 rounded-xl border border-[#D1D5DB] bg-[#F9FAFB] px-3 focus-within:border-[#0386FF] focus-within:ring-2 focus-within:ring-[#0386FF]/15 md:min-h-[50px]">
              {useStudentId ? <Badge size={20} className="text-[#6B7280]" /> : <Mail size={20} className="text-[#6B7280]" />}
              <input
                className="min-w-0 flex-1 bg-transparent text-base text-[#111827] outline-none placeholder:text-[#9CA3AF]"
                value={identifier}
                onChange={(event) => setIdentifier(event.target.value)}
                type={useStudentId ? "text" : "email"}
                required
                placeholder={useStudentId ? "Enter your Student ID (e.g., A7Q4-MZ2N)" : "Enter your email address"}
                autoComplete={useStudentId ? "username" : "email"}
              />
            </span>
          </label>

          <label className="grid gap-1.5 text-sm font-medium text-[#374151]">
            <span>Password</span>
            <span className="flex min-h-12 items-center gap-3 rounded-xl border border-[#D1D5DB] bg-[#F9FAFB] px-3 focus-within:border-[#0386FF] focus-within:ring-2 focus-within:ring-[#0386FF]/15 md:min-h-[50px]">
              <LockKeyhole size={20} className="text-[#6B7280]" />
              <input
                className="min-w-0 flex-1 bg-transparent text-base text-[#111827] outline-none placeholder:text-[#9CA3AF]"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                type={showPassword ? "text" : "password"}
                required
                placeholder="Enter your password"
                autoComplete="current-password"
              />
              <button
                type="button"
                className="text-[#6B7280]"
                onClick={() => setShowPassword((current) => !current)}
                aria-label={showPassword ? "Hide password" : "Show password"}
              >
                {showPassword ? <Eye size={21} /> : <EyeOff size={21} />}
              </button>
            </span>
          </label>

          <button type="button" className="justify-self-end text-sm font-medium text-[#0386FF]" disabled={busy} onClick={resetPassword}>
            Forgot Password
          </button>

          <button
            type="submit"
            className="min-h-11 rounded-xl bg-[#0386FF] px-5 text-base font-semibold text-white transition hover:bg-[#0276DF] disabled:cursor-wait disabled:opacity-70"
            disabled={busy}
          >
            {busy ? "Signing in..." : "Sign In"}
          </button>

          <div className="hidden items-center gap-4 md:flex">
            <span className="h-px flex-1 bg-[#E5E7EB]" />
            <span className="text-sm text-[#6B7280]">Or</span>
            <span className="h-px flex-1 bg-[#E5E7EB]" />
          </div>

          <button
            type="button"
            className="hidden min-h-11 items-center justify-center gap-3 rounded-xl border border-[#D1D5DB] bg-white px-5 text-base font-medium text-[#374151] transition hover:bg-[#F9FAFB] disabled:cursor-wait disabled:opacity-70 md:flex"
            disabled={busy}
            onClick={googleSignIn}
          >
            <GoogleMark />
            Continue With Google
          </button>

          <a
            href={flutterDashboardLoginPath}
            className="inline-flex min-h-11 items-center justify-center gap-3 rounded-xl border border-[#E5E7EB] bg-white px-5 text-[15px] font-semibold text-[#111827] transition hover:bg-[#F9FAFB] md:hidden"
          >
            <Phone size={20} />
            Sign in with Phone
          </a>
          </div>
        </form>
      )}
      {message ? <p className="mt-4 text-sm font-bold text-slate-700">{message}</p> : null}
    </div>
  );
}

function LogoHeader() {
  return (
    <div className="text-center">
      <div className="mx-auto flex h-[170px] w-[170px] items-center justify-center rounded-[20px] bg-[#F8FAFC] p-5 shadow-[0_6px_20px_rgba(15,23,42,0.08)] max-md:h-[58px] max-md:w-[58px] max-md:rounded-xl max-md:p-2 max-md:shadow-[0_1px_8px_rgba(3,134,255,0.10)]">
        <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="Alluwal Education Hub" className="h-full w-full object-contain" />
      </div>
      <h1 className="mt-3 text-xl font-bold tracking-[-0.02em] text-[#111827] max-md:mt-2 max-md:text-lg">Welcome Back</h1>
      <p className="mt-1 text-[15px] text-[#6B7280] max-md:text-xs">Sign in to continue</p>
    </div>
  );
}

function ModeTabs({
  useStudentId,
  setUseStudentId,
}: {
  useStudentId: boolean;
  setUseStudentId: (value: boolean) => void;
}) {
  return (
    <div className="grid w-full grid-cols-2 rounded-xl bg-[#F3F4F6] p-[3px]">
      <button
        type="button"
        onClick={() => setUseStudentId(false)}
        className={`rounded-lg py-2 text-xs font-semibold transition ${!useStudentId ? "bg-white text-[#111827] shadow-sm" : "text-[#6B7280]"}`}
      >
        Email
      </button>
      <button
        type="button"
        onClick={() => setUseStudentId(true)}
        className={`rounded-lg py-2 text-xs font-semibold transition ${useStudentId ? "bg-white text-[#111827] shadow-sm" : "text-[#6B7280]"}`}
      >
        Student ID
      </button>
    </div>
  );
}

function GoogleMark() {
  return (
    <span className="relative inline-flex h-5 w-5 items-center justify-center text-base font-bold">
      <span className="text-[#4285F4]">G</span>
    </span>
  );
}

function friendlyAuthError(error: unknown) {
  const message = error instanceof Error ? error.message : "";
  if (message.includes("user-not-found")) return "No account found with this email address. Please check your email or contact an administrator.";
  if (message.includes("wrong-password") || message.includes("invalid-credential")) return "Incorrect password. Please try again or use Forgot Password if needed.";
  if (message.includes("invalid-email")) return "Please enter a valid email address.";
  if (message.includes("too-many-requests")) return "Too many failed attempts. Please wait a few minutes before trying again.";
  if (message.includes("network-request-failed")) return "Network connection failed. Please check your internet connection and try again.";
  return message || "Login failed. Please check your credentials and try again.";
}
