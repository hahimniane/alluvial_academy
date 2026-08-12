"use client";

import { onAuthStateChanged } from "firebase/auth";
import { doc, getDoc, serverTimestamp, setDoc } from "firebase/firestore";
import { deleteObject, getDownloadURL, ref, uploadBytes } from "firebase/storage";
import { useEffect, useRef, useState } from "react";
import { Camera, Clock3, IdCard, Loader2, Mail, Phone, UserRound } from "lucide-react";
import { auth, db, storage } from "@/lib/firebase";
import { cachedStudentSession, resolveStudentSession, updateStudentSessionPhoto } from "@/lib/studentSession";
import { StudentAccessPrompt, StudentShell } from "@/components/StudentDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";

/**
 * Student ID, email, phone and timezone come from the user document, read-only
 * — those are school-managed, as in the app. The profile photo is the one thing
 * a student may change: the Flutter screen disables that for students, but it
 * is a client-side choice only (Storage and Firestore rules both permit it),
 * and the owner asked for it to be allowed here. The photo is written to the
 * same fields the app reads, so it shows up there too.
 */
type ProfileData = {
  photoUrl: string;
  studentCode: string;
  email: string;
  phone: string;
  timezone: string;
};

export default function StudentProfilePage() {
  const [access, setAccess] = useState<AccessState>(() => (cachedStudentSession() ? "allowed" : "checking"));
  const [summary, setSummary] = useState(() => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" });
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);
  const [profile, setProfile] = useState<ProfileData | null>(null);
  const [photoBusy, setPhotoBusy] = useState(false);
  const [photoError, setPhotoError] = useState("");
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!nextUser) {
        setAccess("signedOut");
        return;
      }
      const session = await resolveStudentSession(nextUser);
      if (!session.isStudent) {
        setAccess("denied");
        return;
      }
      setSummary(session.summary);
      setIsAdultStudent(session.isAdultStudent);
      setAccess("allowed");
      const snap = await getDoc(doc(db, "users", nextUser.uid)).catch(() => null);
      const data = (snap?.data() ?? {}) as Record<string, unknown>;
      setProfile({
        photoUrl: text(data.profile_picture_url ?? data.profilePictureUrl),
        studentCode: text(data.student_code ?? data.studentCode),
        email: text(data["e-mail"] ?? data.email) || nextUser.email || "",
        phone: text(data.phone_number ?? data.phone),
        timezone: text(data.timezone),
      });
    });
  }, []);

  async function uploadPhoto(file: File) {
    const user = auth.currentUser;
    if (!user || photoBusy) return;
    if (!file.type.startsWith("image/")) {
      setPhotoError("Choose an image file.");
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      setPhotoError("Profile images must be smaller than 10 MB.");
      return;
    }
    setPhotoBusy(true);
    setPhotoError("");
    const objectRef = ref(storage, `profile_pictures/${user.uid}/${Date.now()}-${file.name.replace(/[^a-zA-Z0-9._-]+/g, "_").slice(-80)}`);
    try {
      await uploadBytes(objectRef, file, { contentType: file.type });
      const url = await getDownloadURL(objectRef);
      const previous = profile?.photoUrl ?? "";
      // Same fields the teacher page writes, so the app shows the new photo too.
      await setDoc(doc(db, "users", user.uid), { profile_picture_url: url, profile_picture_updated_at: serverTimestamp() }, { merge: true });
      setProfile((current) => (current ? { ...current, photoUrl: url } : current));
      // The header avatar and every other page read the session copy.
      updateStudentSessionPhoto(url);
      setSummary((current) => ({ ...current, photoUrl: url }));
      if (previous) await deleteObject(ref(storage, previous)).catch(() => undefined);
    } catch {
      await deleteObject(objectRef).catch(() => undefined);
      setPhotoError("Could not upload your photo. Please try again.");
    } finally {
      setPhotoBusy(false);
    }
  }

  if (access !== "allowed") return <StudentAccessPrompt access={access} />;

  return (
    <StudentShell activeLabel="Profile" breadcrumb="Account / Profile" summary={summary} isAdultStudent={isAdultStudent}>
      <div className="mx-auto w-full max-w-[640px] px-4 py-8 md:px-6">
        <section className="overflow-hidden rounded-3xl border border-black/5 bg-white shadow-[0_10px_28px_rgba(15,23,42,0.06)]">
          <div className="bg-[linear-gradient(120deg,#43e97b_0%,#38f9d7_100%)] px-6 pb-14 pt-8 text-center" />
          <div className="-mt-12 px-6 pb-7 text-center">
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="sr-only"
              aria-label="Choose a profile photo"
              onChange={(event) => {
                const file = event.target.files?.[0];
                event.target.value = "";
                if (file) void uploadPhoto(file);
              }}
            />
            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              disabled={photoBusy}
              aria-label="Change profile photo"
              className="group relative mx-auto block h-24 w-24 rounded-full disabled:opacity-70"
            >
              {profile?.photoUrl ? (
                <img src={profile.photoUrl} alt="" className="h-24 w-24 rounded-full border-4 border-white object-cover shadow-lg" />
              ) : (
                <span className="grid h-24 w-24 place-items-center rounded-full border-4 border-white bg-[#009688] text-2xl font-black text-white shadow-lg">
                  {summary.initials}
                </span>
              )}
              <span className="absolute bottom-0 right-0 grid h-8 w-8 place-items-center rounded-full border-2 border-white bg-[#2563EB] text-white shadow transition group-hover:bg-[#1D4ED8]">
                {photoBusy ? <Loader2 className="animate-spin" size={14} /> : <Camera size={14} />}
              </span>
            </button>
            {photoError ? <p className="mt-2 text-xs font-bold text-[#DC2626]">{photoError}</p> : null}
            <h1 className="mt-3 text-xl font-black text-[#0F172A]">{summary.displayName}</h1>
            <p className="mt-0.5 inline-flex items-center gap-1.5 rounded-full bg-[#D1FAE5] px-3 py-1 text-[11px] font-black uppercase tracking-wide text-[#047857]">
              <UserRound size={12} />
              Student
            </p>

            {profile === null ? (
              <p className="mt-8 inline-flex items-center gap-2 text-sm font-bold text-[#64748B]">
                <Loader2 className="animate-spin" size={16} />
                Loading your profile…
              </p>
            ) : (
              <dl className="mt-7 grid gap-1 text-left">
                <Row icon={IdCard} label="Student ID" value={profile.studentCode || "Not set"} />
                <Row icon={Mail} label="Email" value={profile.email || "Not set"} />
                <Row icon={Phone} label="Phone" value={profile.phone || "Not set"} />
                {profile.timezone ? <Row icon={Clock3} label="Timezone" value={profile.timezone} /> : null}
              </dl>
            )}

            <p className="mt-7 rounded-xl bg-[#F8FAFC] px-4 py-3 text-xs leading-5 text-[#64748B]">
              Need your name, email or phone changed? Ask your teacher or the school administrators —
              those details are updated by the school.
            </p>
          </div>
        </section>
      </div>
    </StudentShell>
  );
}

function Row({ icon: Icon, label, value }: { icon: typeof Mail; label: string; value: string }) {
  return (
    <div className="flex items-center gap-3 border-b border-dashed border-[#E2E8F0] px-1 py-3 last:border-b-0">
      <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-[#EFF6FF] text-[#2563EB]">
        <Icon size={17} />
      </span>
      <div className="min-w-0">
        <dt className="text-[11px] font-black uppercase tracking-wide text-[#94A3B8]">{label}</dt>
        <dd className="truncate text-sm font-bold text-[#0F172A]">{value}</dd>
      </div>
    </div>
  );
}

function text(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}
