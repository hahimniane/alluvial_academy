"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import { doc, getDoc, serverTimestamp, setDoc } from "firebase/firestore";
import { deleteObject, getDownloadURL, ref, uploadBytes } from "firebase/storage";
import { AlertTriangle, Camera, Clock3, Edit3, Mail, Menu, Phone, Save, UserRound, X } from "lucide-react";
import { useEffect, useState } from "react";
import { TeacherAccessPrompt, TeacherShell, openTeacherMobileMenu } from "@/components/TeacherDashboardHome";
import { auth, db, storage } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type RecordData = Record<string, unknown>;
type ProfileDraft = { full_name: string; professional_title: string; biography: string; years_of_experience: string; specialties: string; education_certifications: string };
const emptyDraft: ProfileDraft = { full_name: "", professional_title: "", biography: "", years_of_experience: "", specialties: "", education_certifications: "" };

export function TeacherProfilePage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [record, setRecord] = useState<RecordData>({});
  const [profile, setProfile] = useState<RecordData>({});
  const [draft, setDraft] = useState<ProfileDraft>(emptyDraft);
  const [editing, setEditing] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  useEffect(() => onAuthStateChanged(auth, async (nextUser) => {
    setUser(nextUser);
    if (!nextUser) { setAccess("signedOut"); return; }
    try {
      if (!await isCurrentUserTeacher(nextUser)) { setAccess("denied"); return; }
      await loadProfile(nextUser, setRecord, setProfile, setDraft);
      setAccess("allowed");
    } catch (cause) { setError(actionError(cause, "Could not load your profile.")); setAccess("allowed"); }
  }), []);

  const displayName = text(profile.full_name) || text(record.fullName) || text(record.displayName) || `${text(record.first_name)} ${text(record.last_name)}`.trim() || user?.displayName || user?.email || "Teacher";
  const summary = { displayName, firstName: displayName.split(/\s+/)[0] || "Teacher", initials: initials(displayName) };
  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  async function saveProfile() {
    if (!user) return;
    if (!draft.full_name.trim()) { setError("Full name is required."); return; }
    setBusy(true); setError(""); setNotice("");
    try {
      const values = Object.fromEntries(Object.entries(draft).map(([key, value]) => [key, value.trim()]));
      await setDoc(doc(db, "teacher_profiles", user.uid), { ...values, user_id: user.uid, email: user.email ?? "", updated_at: serverTimestamp() }, { merge: true });
      setProfile((current) => ({ ...current, ...values })); setEditing(false); setNotice("Profile updated successfully.");
    } catch (cause) { setError(actionError(cause, "Could not save your profile.")); }
    finally { setBusy(false); }
  }

  async function uploadPhoto(file: File) {
    if (!user) return;
    if (!file.type.startsWith("image/")) { setError("Choose an image file."); return; }
    if (file.size > 10 * 1024 * 1024) { setError("Profile images must be smaller than 10 MB."); return; }
    setBusy(true); setError(""); setNotice("");
    const objectRef = ref(storage, `profile_pictures/${user.uid}/${Date.now()}-${safeName(file.name)}`);
    try {
      await uploadBytes(objectRef, file, { contentType: file.type });
      const url = await getDownloadURL(objectRef);
      const previous = text(record.profile_picture_url);
      await setDoc(doc(db, "users", user.uid), { profile_picture_url: url, profile_picture_updated_at: serverTimestamp() }, { merge: true });
      setRecord((current) => ({ ...current, profile_picture_url: url }));
      if (previous) await deleteObject(ref(storage, previous)).catch(() => undefined);
      setNotice("Profile photo updated successfully.");
    } catch (cause) { await deleteObject(objectRef).catch(() => undefined); setError(actionError(cause, "Could not upload your profile photo.")); }
    finally { setBusy(false); }
  }

  return <TeacherShell activeLabel="Profile" breadcrumb="Account / Profile" summary={summary}>
    <div className="min-h-full bg-[#F8FAFC]">
      <MobileHeader title="My Profile" />
      <div className="mx-auto max-w-5xl p-4 sm:p-6 lg:p-8">
        <section className="overflow-hidden rounded-3xl bg-gradient-to-br from-[#0E72ED] to-[#1E3A5F] p-6 text-white shadow-lg sm:p-8">
          <div className="flex flex-col items-center gap-5 sm:flex-row">
            <label className="group relative grid h-28 w-28 shrink-0 cursor-pointer place-items-center overflow-hidden rounded-full border-4 border-white bg-white/15" aria-label="Change profile photo">
              {text(record.profile_picture_url) ? <img src={text(record.profile_picture_url)} alt="Teacher profile" className="h-full w-full object-cover" /> : <span className="text-3xl font-black">{summary.initials}</span>}
              <span className="absolute inset-x-0 bottom-0 grid h-9 place-items-center bg-black/50 opacity-0 transition group-hover:opacity-100"><Camera size={18} /></span>
              <input type="file" accept="image/*" disabled={busy} className="sr-only" onChange={(event) => { const file = event.target.files?.[0]; if (file) void uploadPhoto(file); event.currentTarget.value = ""; }} />
            </label>
            <div className="min-w-0 flex-1 text-center sm:text-left"><h1 className="text-2xl font-black sm:text-3xl">{displayName}</h1><p className="mt-1 text-white/80">{text(profile.professional_title) || "Teacher"}</p><span className="mt-3 inline-flex rounded-full bg-white/20 px-3 py-1 text-xs font-black tracking-wider">TEACHER</span></div>
            <button type="button" onClick={() => { setEditing(true); setError(""); setNotice(""); }} className="inline-flex min-h-11 items-center gap-2 rounded-xl bg-white px-4 font-bold text-[#0E72ED]"><Edit3 size={18} />Edit Profile</button>
          </div>
        </section>
        {error ? <p role="alert" className="mt-5 flex items-start gap-2 rounded-2xl border border-red-200 bg-red-50 p-4 font-semibold text-red-800"><AlertTriangle size={20} />{error}</p> : null}
        {notice ? <p role="status" className="mt-5 rounded-2xl border border-emerald-200 bg-emerald-50 p-4 font-semibold text-emerald-800">{notice}</p> : null}
        <div className="mt-5 grid gap-5 lg:grid-cols-2">
          <Card title="Contact & account"><Info icon={Mail} label="Email" value={text(record["e-mail"]) || text(record.email) || user?.email || "Not set"} /><Info icon={Phone} label="Phone" value={text(record.phone_number) || text(record.phone) || "Not set"} /><Info icon={Clock3} label="Timezone" value={text(record.timezone) || "Not set"} /></Card>
          <Card title="About"><About label="Title" value={text(profile.professional_title)} /><About label="Bio" value={text(profile.biography)} /><About label="Experience" value={text(profile.years_of_experience)} /><About label="Specialties" value={text(profile.specialties)} /><About label="Education & certifications" value={text(profile.education_certifications)} /></Card>
        </div>
      </div>
      {editing ? <ProfileDialog draft={draft} busy={busy} error={error} onChange={(key, value) => setDraft((current) => ({ ...current, [key]: value }))} onClose={() => setEditing(false)} onSave={() => void saveProfile()} /> : null}
    </div>
  </TeacherShell>;
}

function MobileHeader({ title }: { title: string }) { return <header className="flex items-center gap-3 border-b border-[#E2E8F0] bg-white px-4 py-3 lg:hidden"><button type="button" aria-label="Open teacher menu" onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl"><Menu size={22} /></button><p className="font-extrabold text-[#111827]">{title}</p></header>; }
function Card({ title, children }: { title: string; children: React.ReactNode }) { return <section className="rounded-2xl border border-[#E2E8F0] bg-white p-5 shadow-sm"><h2 className="mb-4 text-lg font-extrabold text-[#111827]">{title}</h2><div className="space-y-4">{children}</div></section>; }
function Info({ icon: Icon, label, value }: { icon: typeof Mail; label: string; value: string }) { return <div className="flex items-center gap-3"><span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-[#EAF4FF] text-[#0386FF]"><Icon size={19} /></span><div className="min-w-0"><p className="text-xs font-semibold text-[#64748B]">{label}</p><p className="break-words font-bold text-[#334155]">{value}</p></div></div>; }
function About({ label, value }: { label: string; value: string }) { return value ? <div><p className="text-xs font-bold uppercase tracking-wide text-[#64748B]">{label}</p><p className="mt-1 whitespace-pre-wrap text-sm leading-6 text-[#334155]">{value}</p></div> : null; }

function ProfileDialog({ draft, busy, error, onChange, onClose, onSave }: { draft: ProfileDraft; busy: boolean; error: string; onChange: (key: keyof ProfileDraft, value: string) => void; onClose: () => void; onSave: () => void }) {
  const fields: Array<[keyof ProfileDraft, string, number]> = [["full_name", "Full name", 1], ["professional_title", "Professional title", 1], ["biography", "Biography", 4], ["years_of_experience", "Years of experience", 1], ["specialties", "Specialties", 1], ["education_certifications", "Education & certifications", 3]];
  return <section className="fixed inset-0 z-[90] grid items-end bg-black/45 sm:place-items-center" role="dialog" aria-modal="true" aria-label="Edit teacher profile"><form onSubmit={(event) => { event.preventDefault(); onSave(); }} className="max-h-[92vh] w-full overflow-y-auto rounded-t-3xl bg-white p-5 shadow-2xl sm:max-w-xl sm:rounded-3xl sm:p-6"><header className="mb-5 flex items-center gap-3"><span className="grid h-11 w-11 place-items-center rounded-xl bg-emerald-100 text-emerald-700"><UserRound size={21} /></span><div className="min-w-0 flex-1"><h2 className="text-xl font-extrabold text-[#111827]">Complete Profile</h2><p className="text-sm text-[#64748B]">Keep your teaching information accurate.</p></div><button type="button" onClick={onClose} aria-label="Close profile editor" className="grid h-10 w-10 place-items-center rounded-xl"><X size={20} /></button></header><p className="mb-5 rounded-xl bg-blue-50 p-3 text-sm text-blue-900">This profile is private to the app. Public website profiles are managed separately by an administrator.</p><div className="space-y-4">{fields.map(([key, label, rows]) => <label key={key} className="block text-sm font-bold text-[#374151]">{label}{rows > 1 ? <textarea value={draft[key]} rows={rows} onChange={(event) => onChange(key, event.target.value)} className="mt-2 w-full rounded-xl border border-[#CBD5E1] p-3 font-normal outline-none focus:border-emerald-500" /> : <input value={draft[key]} required={key === "full_name"} onChange={(event) => onChange(key, event.target.value)} className="mt-2 h-11 w-full rounded-xl border border-[#CBD5E1] px-3 font-normal outline-none focus:border-emerald-500" />}</label>)}</div>{error ? <p role="alert" className="mt-4 text-sm font-semibold text-red-700">{error}</p> : null}<div className="mt-6 flex justify-end gap-3"><button type="button" disabled={busy} onClick={onClose} className="min-h-11 rounded-xl px-4 font-bold text-[#64748B]">Cancel</button><button type="submit" disabled={busy} className="inline-flex min-h-11 items-center gap-2 rounded-xl bg-emerald-600 px-5 font-bold text-white disabled:opacity-60"><Save size={18} />{busy ? "Saving…" : "Save Profile"}</button></div></form></section>;
}

async function loadProfile(user: User, setRecord: (value: RecordData) => void, setProfile: (value: RecordData) => void, setDraft: (value: ProfileDraft) => void) { const [record, profileSnap] = await Promise.all([getCurrentUserRecord(user), getDoc(doc(db, "teacher_profiles", user.uid))]); const profile = profileSnap.exists() ? profileSnap.data() : {}; setRecord(record ?? {}); setProfile(profile); setDraft(Object.fromEntries(Object.keys(emptyDraft).map((key) => [key, text(profile[key])])) as unknown as ProfileDraft); }
function text(value: unknown) { return typeof value === "string" ? value.trim() : ""; }
function initials(value: string) { return value.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "TE"; }
function safeName(value: string) { return value.replace(/[^a-zA-Z0-9._-]+/g, "-"); }
function actionError(cause: unknown, fallback: string) { const code = typeof cause === "object" && cause && "code" in cause ? String((cause as { code: unknown }).code) : ""; if (code.includes("permission-denied") || code.includes("unauthorized")) return "You do not have permission to update this profile."; if (code.includes("network") || code.includes("unavailable")) return "You appear to be offline. Check your connection and try again."; return fallback; }
