"use client";

import {
  EmailAuthProvider,
  onAuthStateChanged,
  reauthenticateWithCredential,
  signOut,
  updatePassword,
  type User,
} from "firebase/auth";
import { doc, serverTimestamp, setDoc, updateDoc } from "firebase/firestore";
import {
  Bell,
  Check,
  CircleUserRound,
  Clock3,
  Globe2,
  Info,
  KeyRound,
  ListChecks,
  LogOut,
  Mail,
  Menu,
  MessageSquare,
  Moon,
  Save,
  Shield,
  Sun,
  X,
} from "lucide-react";
import Link from "next/link";
import { useEffect, useState, type ReactNode } from "react";
import { TeacherAccessPrompt, TeacherShell, openTeacherMobileMenu } from "@/components/TeacherDashboardHome";
import { auth, db } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type NotificationPrefs = {
  shiftEnabled: boolean;
  shiftMinutes: number;
  taskEnabled: boolean;
  taskDays: number;
  chatEnabled: boolean;
  prayerEnabled: boolean;
};

const defaultPrefs: NotificationPrefs = {
  shiftEnabled: true,
  shiftMinutes: 15,
  taskEnabled: true,
  taskDays: 1,
  chatEnabled: true,
  prayerEnabled: true,
};

export function TeacherSettingsPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [summary, setSummary] = useState({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [language, setLanguage] = useState("en");
  const [dark, setDark] = useState(false);
  const [passwordOpen, setPasswordOpen] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [preferences, setPreferences] = useState(defaultPrefs);

  useEffect(() => {
    const savedLanguage = window.localStorage.getItem("alluwal-language") || "en";
    const savedTheme = window.localStorage.getItem("alluwal-theme") === "dark";
    setLanguage(savedLanguage);
    setDark(savedTheme);
    document.documentElement.classList.toggle("dark", savedTheme);
    return onAuthStateChanged(auth, async (nextUser) => {
      setUser(nextUser);
      if (!nextUser) { setAccess("signedOut"); return; }
      if (!await isCurrentUserTeacher(nextUser)) { setAccess("denied"); return; }
      const record = await getCurrentUserRecord(nextUser);
      const displayName = text(record?.fullName) || text(record?.displayName) || `${text(record?.first_name)} ${text(record?.last_name)}`.trim() || nextUser.displayName || nextUser.email || "Teacher";
      const stored = objectValue(record?.notificationPreferences);
      setPreferences({
        shiftEnabled: boolValue(stored.shiftEnabled, true),
        shiftMinutes: optionValue(stored.shiftMinutes, [10, 15, 20, 30], 15),
        taskEnabled: boolValue(stored.taskEnabled, true),
        taskDays: optionValue(stored.taskDays, [1, 2, 3, 5, 7], 1),
        chatEnabled: boolValue(stored.chatEnabled, true),
        prayerEnabled: localBool("prayer_notification_enabled", true),
      });
      setSummary({
        displayName,
        firstName: displayName.split(/\s+/)[0] || "Teacher",
        initials: displayName.split(/\s+/).slice(0, 2).map((part) => part[0]).join("").toUpperCase() || "TE",
      });
      setAccess("allowed");
    });
  }, []);

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  function setTheme(next: boolean) {
    setDark(next);
    window.localStorage.setItem("alluwal-theme", next ? "dark" : "light");
    document.documentElement.classList.toggle("dark", next);
  }

  return (
    <TeacherShell activeLabel="Settings" breadcrumb="Account / Settings" summary={summary}>
      <div className="min-h-full bg-[#F8FAFC]">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] bg-white px-4 py-3 lg:hidden">
          <button type="button" aria-label="Open teacher menu" onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl"><Menu size={22} /></button>
          <p className="font-extrabold">Settings</p>
        </header>
        <div className="mx-auto max-w-3xl space-y-5 p-4 sm:p-6 lg:p-8">
          <div><h1 className="text-2xl font-extrabold text-[#111827]">Settings</h1><p className="mt-1 text-sm text-[#64748B]">Manage your account and app preferences.</p></div>
          <SettingsCard title="PROFILE"><SettingsLink href="/teacher/profile/" icon={CircleUserRound} title="View Profile" subtitle="Profile photo and teaching information" /></SettingsCard>
          <SettingsCard title="ACCOUNT SECURITY"><SettingsButton icon={KeyRound} title="Change Password" subtitle="Update your account password" onClick={() => setPasswordOpen(true)} /></SettingsCard>
          <SettingsCard title="APP SETTINGS">
            <SettingsButton icon={Bell} title="Notifications" subtitle="Shift, task, chat, and prayer reminders" onClick={() => setNotificationsOpen(true)} />
            <label className="flex min-h-16 items-center gap-3 border-t border-[#E2E8F0] px-4"><IconBox icon={Globe2} /><span className="min-w-0 flex-1"><strong className="block text-sm text-[#334155]">Language</strong><span className="text-xs text-[#64748B]">Choose the display language</span></span><select aria-label="Language" value={language} onChange={(event) => { setLanguage(event.target.value); window.localStorage.setItem("alluwal-language", event.target.value); }} className="h-10 rounded-xl border border-[#CBD5E1] bg-white px-3 text-sm font-bold"><option value="en">English</option><option value="fr">Français</option></select></label>
            <div className="border-t border-[#E2E8F0]"><SettingsButton icon={dark ? Moon : Sun} title="Dark Mode" subtitle={dark ? "Enabled" : "Disabled"} onClick={() => setTheme(!dark)} trailing={<Switch checked={dark} />} /></div>
          </SettingsCard>
          <SettingsCard title="SUPPORT">
            <a href="mailto:support@alluwaleducationhub.org" className="block"><SettingsRow icon={Mail} title="Help & Support" subtitle="support@alluwaleducationhub.org" /></a>
            <div className="border-t border-[#E2E8F0]"><SettingsLink href="/privacy-policy/" icon={Shield} title="Privacy Policy" subtitle="Read our privacy policy" /></div>
            <div className="border-t border-[#E2E8F0]"><SettingsRow icon={Info} title="About" subtitle="Alluwal Education Hub" /></div>
          </SettingsCard>
          <button type="button" onClick={async () => { await signOut(auth); window.location.assign("/login/"); }} className="flex min-h-12 w-full items-center justify-center gap-2 rounded-xl bg-red-500 px-4 font-bold text-white"><LogOut size={19} />Sign Out</button>
        </div>
        {passwordOpen && user ? <PasswordDialog user={user} onClose={() => setPasswordOpen(false)} /> : null}
        {notificationsOpen ? <NotificationDialog preferences={preferences} onSaved={setPreferences} onClose={() => setNotificationsOpen(false)} /> : null}
      </div>
    </TeacherShell>
  );
}

function NotificationDialog({ preferences, onSaved, onClose }: { preferences: NotificationPrefs; onSaved: (value: NotificationPrefs) => void; onClose: () => void }) {
  const [draft, setDraft] = useState(preferences);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const set = <K extends keyof NotificationPrefs>(key: K, value: NotificationPrefs[K]) => setDraft((current) => ({ ...current, [key]: value }));
  async function save() {
    setBusy(true); setMessage("");
    try {
      const user = auth.currentUser;
      if (!user) throw new Error("unauthenticated");
      await updateDoc(doc(db, "users", user.uid), {
        "notificationPreferences.shiftEnabled": draft.shiftEnabled,
        "notificationPreferences.shiftMinutes": draft.shiftMinutes,
        "notificationPreferences.taskEnabled": draft.taskEnabled,
        "notificationPreferences.taskDays": draft.taskDays,
        "notificationPreferences.chatEnabled": draft.chatEnabled,
        "notificationPreferences.updatedAt": serverTimestamp(),
      });
      window.localStorage.setItem("prayer_notification_enabled", String(draft.prayerEnabled));
      onSaved(draft);
      setMessage("Notification preferences saved.");
    } catch (cause) { setMessage(actionError(cause, "Could not save notification preferences.")); }
    finally { setBusy(false); }
  }
  return <section className="fixed inset-0 z-[90] grid items-end bg-black/45 sm:place-items-center" role="dialog" aria-modal="true" aria-label="Notification preferences"><div className="max-h-[92vh] w-full overflow-y-auto rounded-t-3xl bg-[#F8FAFC] p-5 shadow-2xl sm:max-w-2xl sm:rounded-3xl sm:p-6"><header className="flex items-start gap-3"><span className="grid h-11 w-11 place-items-center rounded-xl bg-blue-100 text-[#0386FF]"><Bell size={21} /></span><div className="min-w-0 flex-1"><h2 className="text-xl font-extrabold text-[#111827]">Notification Preferences</h2><p className="text-sm text-[#64748B]">Choose which reminders you receive.</p></div><button type="button" onClick={onClose} aria-label="Close notification preferences" className="grid h-10 w-10 place-items-center rounded-xl"><X size={20} /></button></header><div className="mt-5 space-y-4"><PreferenceCard icon={Clock3} title="SHIFT REMINDERS" description="Get notified before your shift starts" checked={draft.shiftEnabled} onToggle={(value) => set("shiftEnabled", value)}>{draft.shiftEnabled ? <OptionChips label="Notify me before shift" options={[10, 15, 20, 30]} value={draft.shiftMinutes} suffix="min" onChange={(value) => set("shiftMinutes", value)} /> : null}</PreferenceCard><PreferenceCard icon={ListChecks} title="TASK REMINDERS" description="Get notified before a task due date" checked={draft.taskEnabled} onToggle={(value) => set("taskEnabled", value)}>{draft.taskEnabled ? <OptionChips label="Notify me before due date" options={[1, 2, 3, 5, 7]} value={draft.taskDays} suffix="day" onChange={(value) => set("taskDays", value)} /> : null}</PreferenceCard><PreferenceCard icon={MessageSquare} title="CHAT MESSAGES" description="Get notified when you receive messages" checked={draft.chatEnabled} onToggle={(value) => set("chatEnabled", value)} /><PreferenceCard icon={Bell} title="PRAYER TIMES (ADHAN)" description="Adhan reminders at all five daily prayer times" checked={draft.prayerEnabled} onToggle={(value) => set("prayerEnabled", value)}>{draft.prayerEnabled ? <p className="mt-3 border-t border-[#E2E8F0] pt-3 text-xs leading-5 text-[#64748B]">Prayer reminders use your device and browser location settings.</p> : null}</PreferenceCard></div>{message ? <p role="status" className={`mt-4 rounded-xl p-3 text-sm font-semibold ${message.includes("saved") ? "bg-emerald-50 text-emerald-800" : "bg-red-50 text-red-800"}`}>{message}</p> : null}<div className="mt-5 flex justify-end gap-3"><button type="button" disabled={busy} onClick={onClose} className="min-h-11 px-4 font-bold text-[#64748B]">Close</button><button type="button" disabled={busy} onClick={() => void save()} className="inline-flex min-h-11 items-center gap-2 rounded-xl bg-[#0386FF] px-5 font-bold text-white disabled:opacity-60"><Save size={18} />{busy ? "Saving…" : "Save Preferences"}</button></div></div></section>;
}

function PreferenceCard({ icon, title, description, checked, onToggle, children }: { icon: typeof Bell; title: string; description: string; checked: boolean; onToggle: (value: boolean) => void; children?: ReactNode }) { return <section className="rounded-2xl border border-[#E2E8F0] bg-white p-4"><div className="flex items-center gap-3"><IconBox icon={icon} /><div className="min-w-0 flex-1"><h3 className="text-xs font-black tracking-wide text-[#334155]">{title}</h3><p className="text-sm text-[#64748B]">{description}</p></div><button type="button" role="switch" aria-label={title} aria-checked={checked} onClick={() => onToggle(!checked)}><Switch checked={checked} /></button></div>{children}</section>; }
function OptionChips({ label, options, value, suffix, onChange }: { label: string; options: number[]; value: number; suffix: string; onChange: (value: number) => void }) { return <div className="mt-3 border-t border-[#E2E8F0] pt-3"><p className="mb-2 text-sm font-semibold text-[#334155]">{label}</p><div className="flex flex-wrap gap-2">{options.map((option) => <button key={option} type="button" aria-pressed={value === option} onClick={() => onChange(option)} className={`inline-flex min-h-9 items-center gap-1 rounded-full border px-3 text-sm font-bold ${value === option ? "border-[#0386FF] bg-[#EAF4FF] text-[#0386FF]" : "border-[#CBD5E1] bg-white text-[#64748B]"}`}>{value === option ? <Check size={14} /> : null}{option} {suffix}{suffix === "day" && option !== 1 ? "s" : ""}</button>)}</div></div>; }
function Switch({ checked }: { checked: boolean }) { return <span className={`relative block h-7 w-12 rounded-full ${checked ? "bg-[#0386FF]" : "bg-[#CBD5E1]"}`}><span className={`absolute top-1 h-5 w-5 rounded-full bg-white transition ${checked ? "left-6" : "left-1"}`} /></span>; }
function SettingsCard({ title, children }: { title: string; children: ReactNode }) { return <section className="overflow-hidden rounded-2xl border border-[#E2E8F0] bg-white shadow-sm"><h2 className="px-4 pb-2 pt-4 text-xs font-black tracking-wider text-[#64748B]">{title}</h2>{children}</section>; }
function IconBox({ icon: Icon }: { icon: typeof Bell }) { return <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-[#EAF4FF] text-[#0386FF]"><Icon size={19} /></span>; }
function SettingsRow({ icon, title, subtitle }: { icon: typeof Bell; title: string; subtitle: string }) { return <div className="flex min-h-16 items-center gap-3 px-4"><IconBox icon={icon} /><span className="min-w-0 flex-1"><strong className="block text-sm text-[#334155]">{title}</strong><span className="text-xs text-[#64748B]">{subtitle}</span></span></div>; }
function SettingsButton({ icon, title, subtitle, onClick, trailing }: { icon: typeof Bell; title: string; subtitle: string; onClick: () => void; trailing?: ReactNode }) { return <button type="button" onClick={onClick} className="flex min-h-16 w-full items-center gap-3 px-4 text-left hover:bg-[#F8FAFC]"><IconBox icon={icon} /><span className="min-w-0 flex-1"><strong className="block text-sm text-[#334155]">{title}</strong><span className="text-xs text-[#64748B]">{subtitle}</span></span>{trailing}</button>; }
function SettingsLink({ href, icon, title, subtitle }: { href: string; icon: typeof Bell; title: string; subtitle: string }) { return <Link href={href} className="block hover:bg-[#F8FAFC]"><SettingsRow icon={icon} title={title} subtitle={subtitle} /></Link>; }

function PasswordDialog({ user, onClose }: { user: User; onClose: () => void }) {
  const [current, setCurrent] = useState(""); const [next, setNext] = useState(""); const [confirm, setConfirm] = useState(""); const [busy, setBusy] = useState(false); const [message, setMessage] = useState("");
  async function save() { if (!user.email) { setMessage("Your account does not have an email address."); return; } if (next.length < 6) { setMessage("The new password must be at least 6 characters."); return; } if (next !== confirm) { setMessage("The new passwords do not match."); return; } setBusy(true); setMessage(""); try { await reauthenticateWithCredential(user, EmailAuthProvider.credential(user.email, current)); await updatePassword(user, next); await setDoc(doc(db, "users", user.uid), { temp_password: next, password_updated_at: serverTimestamp() }, { merge: true }); setMessage("Password changed successfully."); setCurrent(""); setNext(""); setConfirm(""); } catch (cause) { const code = errorCode(cause); setMessage(code.includes("invalid-credential") || code.includes("wrong-password") ? "The current password is incorrect." : code.includes("network") ? "You appear to be offline. Try again when connected." : "Could not change your password."); } finally { setBusy(false); } }
  return <section className="fixed inset-0 z-[90] grid items-end bg-black/45 sm:place-items-center" role="dialog" aria-modal="true" aria-label="Change password"><form onSubmit={(event) => { event.preventDefault(); void save(); }} className="w-full rounded-t-3xl bg-white p-6 shadow-2xl sm:max-w-md sm:rounded-3xl"><h2 className="text-xl font-extrabold">Change Password</h2><div className="mt-5 space-y-4">{[["Current password", current, setCurrent], ["New password", next, setNext], ["Confirm new password", confirm, setConfirm]].map(([label, value, setter]) => <label key={label as string} className="block text-sm font-bold text-[#374151]">{label as string}<input type="password" required value={value as string} onChange={(event) => (setter as (value: string) => void)(event.target.value)} className="mt-2 h-11 w-full rounded-xl border border-[#CBD5E1] px-3 font-normal" /></label>)}</div>{message ? <p role="status" className={`mt-4 text-sm font-semibold ${message.includes("successfully") ? "text-emerald-700" : "text-red-700"}`}>{message}</p> : null}<div className="mt-6 flex justify-end gap-3"><button type="button" disabled={busy} onClick={onClose} className="min-h-11 px-4 font-bold text-[#64748B]">Cancel</button><button type="submit" disabled={busy} className="min-h-11 rounded-xl bg-[#0386FF] px-5 font-bold text-white disabled:opacity-60">{busy ? "Saving…" : "Change Password"}</button></div></form></section>;
}

function text(value: unknown) { return typeof value === "string" ? value.trim() : ""; }
function objectValue(value: unknown): Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : {}; }
function boolValue(value: unknown, fallback: boolean) { return typeof value === "boolean" ? value : fallback; }
function optionValue(value: unknown, options: number[], fallback: number) { return typeof value === "number" && options.includes(value) ? value : fallback; }
function localBool(key: string, fallback: boolean) { const value = window.localStorage.getItem(key); return value === null ? fallback : value === "true"; }
function errorCode(cause: unknown) { return typeof cause === "object" && cause && "code" in cause ? String((cause as { code: unknown }).code) : ""; }
function actionError(cause: unknown, fallback: string) { const code = errorCode(cause); if (code.includes("permission") || code.includes("unauthenticated")) return "You do not have permission to update these preferences."; if (code.includes("network") || code.includes("unavailable") || code.includes("internal")) return "The notification service is unavailable. Check your connection and try again."; return fallback; }
