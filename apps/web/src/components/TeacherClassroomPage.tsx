"use client";

import Link from "next/link";
import { onAuthStateChanged } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { doc, getDoc, Timestamp } from "firebase/firestore";
import { useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { ArrowLeft, Loader2, Video } from "lucide-react";
import { auth, db, functions } from "@/lib/firebase";
import { isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt } from "@/components/TeacherDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type RoomStatus = "idle" | "token" | "connecting" | "ready" | "error";

type JoinResult = {
  success?: boolean;
  authToken?: string;
  displayName?: string;
  shiftName?: string;
  error?: string;
};

type ClassroomShift = {
  title: string;
  start: Date | null;
  end: Date | null;
};

export function TeacherClassroomPage() {
  const searchParams = useSearchParams();
  const shiftId = searchParams.get("shiftId")?.trim() ?? "";
  const [access, setAccess] = useState<AccessState>("checking");
  const [status, setStatus] = useState<RoomStatus>("idle");
  const [message, setMessage] = useState("Preparing class...");
  const [shiftName, setShiftName] = useState("Class");
  const [meetingUrl, setMeetingUrl] = useState("");

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (user) => {
      if (!mounted) return;
      if (!user) {
        setAccess("signedOut");
        return;
      }
      setAccess("checking");
      try {
        const allowed = await isCurrentUserTeacher(user);
        if (!mounted) return;
        setAccess(allowed ? "allowed" : "denied");
      } catch {
        if (mounted) setAccess("denied");
      }
    });
  }, []);

  useEffect(() => {
    if (access !== "allowed") return;
    if (!shiftId) {
      setStatus("error");
      setMessage("Missing class id.");
      return;
    }

    let cancelled = false;
    async function connect() {
      setStatus("token");
      setMessage("Checking class access...");
      try {
        const shift = await loadClassroomShift(shiftId);
        if (cancelled) return;
        if (shift) {
          setShiftName(shift.title);
          const availability = classAvailability(shift);
          if (availability.kind !== "ready") {
            setStatus("error");
            setMessage(availability.message);
            return;
          }
        }
        setMessage("Getting class access...");
        const callable = httpsCallable(functions, "getRealtimeKitJoinToken");
        const result = await callable({ shiftId });
        if (cancelled) return;
        const data = result.data as JoinResult;
        if (!data.success || !data.authToken) {
          throw new Error(data.error || "Class video is unavailable.");
        }
        setShiftName(data.shiftName || "Class");
        setStatus("connecting");
        setMessage("Connecting to class...");
        setMeetingUrl(`/realtimekit_meeting.html#token=${encodeURIComponent(data.authToken)}`);
        setStatus("ready");
        setMessage("");
      } catch (error) {
        if (!cancelled) {
          setStatus("error");
          setMessage(classroomErrorMessage(error));
        }
      }
    }

    void connect();
    return () => {
      cancelled = true;
      setMeetingUrl("");
    };
  }, [access, shiftId]);

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  return (
    <main className="min-h-screen bg-black text-white">
      <header className="fixed left-0 right-0 top-0 z-20 flex min-h-14 items-center gap-3 bg-black/70 px-3 backdrop-blur">
        <Link href="/teacher/classes/" aria-label="Back to classes" className="grid h-10 w-10 place-items-center rounded-xl text-white hover:bg-white/10">
          <ArrowLeft size={22} />
        </Link>
        <div className="min-w-0 flex-1">
          <h1 className="truncate text-sm font-bold">{shiftName}</h1>
          <p className="truncate text-xs text-white/70">{status === "ready" ? "Connected" : message}</p>
        </div>
      </header>

      <section className="min-h-screen bg-black pt-14">
        {status === "ready" && meetingUrl ? (
          <iframe
            title={shiftName}
            src={meetingUrl}
            allow="camera; microphone; display-capture; fullscreen; autoplay; clipboard-write"
            allowFullScreen
            className="h-[calc(100vh-56px)] w-full border-0 bg-black"
          />
        ) : null}
      </section>

      {status !== "ready" ? (
        <div className="fixed inset-0 z-10 grid place-items-center bg-[#020617] px-6 text-center">
          <div className="max-w-sm">
            <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-[#0E72ED]/20 text-[#60A5FA]">
              {status === "error" ? <Video size={32} /> : <Loader2 size={32} className="animate-spin" />}
            </div>
            <h2 className="mt-5 text-xl font-bold">{status === "error" ? "Could not join class" : "Connecting to Class"}</h2>
            <p className="mt-2 text-sm leading-6 text-white/70">{message}</p>
            {status === "error" ? (
              <Link href="/teacher/classes/" className="mt-5 inline-flex min-h-11 items-center justify-center rounded-xl bg-[#0E72ED] px-5 text-sm font-bold text-white">
                Back to Classes
              </Link>
            ) : null}
          </div>
        </div>
      ) : null}
    </main>
  );
}

async function loadClassroomShift(shiftId: string): Promise<ClassroomShift | null> {
  const snap = await getDoc(doc(db, "teaching_shifts", shiftId));
  if (!snap.exists()) return null;
  const data = snap.data() as Record<string, unknown>;
  const subject = stringValue(data.subject_display_name ?? data.subjectDisplayName ?? data.subject);
  const studentNames = arrayOfStrings(data.student_names ?? data.studentNames);
  const teacherName = stringValue(data.teacher_name ?? data.teacherName);
  const title =
    stringValue(data.custom_name ?? data.customName) ||
    stringValue(data.auto_generated_name ?? data.autoGeneratedName) ||
    subject ||
    [teacherName, studentNames.join(", ")].filter(Boolean).join(" - ") ||
    "Class";
  return {
    title,
    start: dateValue(data.shift_start ?? data.shiftStart ?? data.start_time ?? data.startTime),
    end: dateValue(data.shift_end ?? data.shiftEnd ?? data.end_time ?? data.endTime),
  };
}

function classAvailability(shift: ClassroomShift) {
  if (!shift.start || !shift.end) return { kind: "blocked", message: "Class time is not set." } as const;
  const now = new Date();
  const joinWindowStart = addMinutes(shift.start, -10);
  const joinWindowEnd = addMinutes(shift.end, 10);
  if (now < joinWindowStart) {
    return { kind: "blocked", message: `Class opens in ${Math.max(1, Math.ceil((joinWindowStart.getTime() - now.getTime()) / 60000))} minutes` } as const;
  }
  if (now > joinWindowEnd) return { kind: "blocked", message: "This class has ended" } as const;
  return { kind: "ready" } as const;
}

function classroomErrorMessage(error: unknown) {
  const raw = error instanceof Error ? error.message : String(error || "");
  const normalized = raw.toLowerCase();
  if (
    normalized.includes("cors") ||
    normalized.includes("failed to fetch") ||
    normalized === "internal" ||
    normalized.includes("internal")
  ) {
    return "Class video is unavailable in this Firebase project. RealtimeKit functions or secrets are not configured.";
  }
  return raw.trim() || "Unable to join this class.";
}

function addMinutes(date: Date, minutes: number) {
  const next = new Date(date);
  next.setMinutes(next.getMinutes() + minutes);
  return next;
}

function dateValue(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string" || typeof value === "number") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (value && typeof value === "object" && "toDate" in value && typeof value.toDate === "function") {
    const parsed = value.toDate();
    return parsed instanceof Date && !Number.isNaN(parsed.getTime()) ? parsed : null;
  }
  return null;
}

function arrayOfStrings(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => stringValue(item)).filter(Boolean);
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}
