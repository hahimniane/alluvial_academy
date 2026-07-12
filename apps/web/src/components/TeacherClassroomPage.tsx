"use client";

import Link from "next/link";
import { onAuthStateChanged } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { doc, getDoc, Timestamp } from "firebase/firestore";
import { useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { ArrowLeft, Loader2, Lock, LockOpen, RefreshCw, UserMinus, Users, Video, X } from "lucide-react";
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
  roomLocked?: boolean;
  error?: string;
};

type ZoomJoinResult = {
  success?: boolean;
  meetingNumber?: string;
  password?: string;
  signature?: string;
  sdkKey?: string;
  displayName?: string;
  customerKey?: string;
  shiftName?: string;
  breakoutRoomName?: string;
  breakoutRoomKey?: string;
  autoJoinBreakoutRoom?: boolean;
  classEndsAtIso?: string;
  error?: string;
};

type ClassroomParticipant = {
  identity: string;
  name: string;
  role: string;
};

type ClassroomShift = {
  title: string;
  videoProvider: string;
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
  const [roomLocked, setRoomLocked] = useState(false);
  const [participants, setParticipants] = useState<ClassroomParticipant[]>([]);
  const [rosterOpen, setRosterOpen] = useState(false);
  const [controlBusy, setControlBusy] = useState("");
  const [controlError, setControlError] = useState("");
  const [connectAttempt, setConnectAttempt] = useState(0);

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
          if (shift.videoProvider === "zoom") {
            setMessage("Getting Zoom class access...");
            const callable = httpsCallable(functions, "getZoomJoinInfo");
            const result = await callable({ shiftId, clientPlatform: "web" });
            if (cancelled) return;
            const data = result.data as ZoomJoinResult;
            if (!data.success || !data.meetingNumber || !data.signature || !data.sdkKey) {
              throw new Error(data.error || "Zoom class is unavailable.");
            }
            setShiftName(data.shiftName || shift.title);
            window.location.assign(buildZoomMeetingUrl(data));
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
        setRoomLocked(data.roomLocked === true);
        setStatus("connecting");
        setMessage("Connecting to class...");
        setMeetingUrl(`/realtimekit_meeting.html#token=${encodeURIComponent(data.authToken)}`);
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
  }, [access, shiftId, connectAttempt]);

  useEffect(() => {
    if (status !== "ready" || !shiftId) return;
    let cancelled = false;
    const refresh = async () => {
      try {
        const callable = httpsCallable(functions, "getRealtimeKitRoomPresence");
        const result = await callable({ shiftId });
        if (!cancelled) setParticipants(normalizeParticipants(result.data));
      } catch (error) {
        if (!cancelled && rosterOpen) setControlError(functionErrorMessage(error, "Could not refresh participants."));
      }
    };
    void refresh();
    const timer = window.setInterval(() => void refresh(), 10000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, [rosterOpen, shiftId, status]);

  useEffect(() => {
    if (!meetingUrl) return;
    const onMeetingMessage = (event: MessageEvent) => {
      if (event.origin !== window.location.origin || !event.data || event.data.source !== "alluwal-realtimekit") return;
      if (event.data.type === "ready") {
        setStatus("ready");
        setMessage("");
      } else if (event.data.type === "error") {
        setStatus("error");
        setMessage(stringValue(event.data.message) || "Unable to initialize the class meeting.");
      }
    };
    window.addEventListener("message", onMeetingMessage);
    const timeout = window.setTimeout(() => {
      setStatus((current) => {
        if (current !== "connecting") return current;
        setMessage("The class is taking longer than expected. Try reconnecting.");
        return "error";
      });
    }, 20000);
    return () => {
      window.removeEventListener("message", onMeetingMessage);
      window.clearTimeout(timeout);
    };
  }, [meetingUrl]);

  const toggleRoomLock = async () => {
    if (controlBusy) return;
    const nextLocked = !roomLocked;
    setControlBusy("lock");
    setControlError("");
    try {
      const callable = httpsCallable(functions, "setRealtimeKitRoomLock");
      const result = await callable({ shiftId, locked: nextLocked });
      const data = result.data as { locked?: boolean };
      setRoomLocked(data.locked === true);
    } catch (error) {
      setControlError(functionErrorMessage(error, "Could not update the class lock."));
    } finally {
      setControlBusy("");
    }
  };

  const removeParticipant = async (participant: ClassroomParticipant) => {
    if (!participant.identity || controlBusy) return;
    setControlBusy(participant.identity);
    setControlError("");
    try {
      const callable = httpsCallable(functions, "kickRealtimeKitParticipant");
      await callable({ shiftId, identity: participant.identity });
      setParticipants((current) => current.filter((item) => item.identity !== participant.identity));
    } catch (error) {
      setControlError(functionErrorMessage(error, "Could not remove this participant."));
    } finally {
      setControlBusy("");
    }
  };

  const reconnect = () => {
    setRosterOpen(false);
    setParticipants([]);
    setControlError("");
    setMeetingUrl("");
    setConnectAttempt((attempt) => attempt + 1);
  };

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  return (
    <main className="min-h-screen bg-black text-white">
      <header className="fixed left-0 right-0 top-0 z-20 flex min-h-14 items-center gap-2 bg-black/70 px-3 backdrop-blur">
        <Link href="/teacher/classes/" aria-label="Back to classes" className="grid h-10 w-10 place-items-center rounded-xl text-white hover:bg-white/10">
          <ArrowLeft size={22} />
        </Link>
        <div className="min-w-0 flex-1">
          <h1 className="truncate text-sm font-bold">{shiftName}</h1>
          <p className="truncate text-xs text-white/70">{status === "ready" ? "Connected" : message}</p>
        </div>
        {status === "ready" ? (
          <>
            <button type="button" aria-label="Reconnect to class" onClick={reconnect} className="grid h-10 w-10 place-items-center rounded-xl text-white hover:bg-white/10">
              <RefreshCw size={19} />
            </button>
            <button type="button" aria-label={roomLocked ? "Unlock class" : "Lock class"} onClick={toggleRoomLock} disabled={controlBusy === "lock"} className="grid h-10 w-10 place-items-center rounded-xl text-white hover:bg-white/10 disabled:opacity-50">
              {controlBusy === "lock" ? <Loader2 size={19} className="animate-spin" /> : roomLocked ? <Lock size={19} /> : <LockOpen size={19} />}
            </button>
            <button type="button" aria-label="Show class participants" onClick={() => setRosterOpen(true)} className="relative grid h-10 w-10 place-items-center rounded-xl text-white hover:bg-white/10">
              <Users size={20} />
              <span className="absolute right-0 top-0 grid h-5 min-w-5 place-items-center rounded-full bg-[#0E72ED] px-1 text-[10px] font-black">{participants.length}</span>
            </button>
          </>
        ) : null}
      </header>

      <section className="min-h-screen bg-black pt-14">
        {meetingUrl ? (
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
              <div className="mt-5 flex flex-wrap justify-center gap-3">
                <button type="button" onClick={reconnect} className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-[#0E72ED] px-5 text-sm font-bold text-white">
                  <RefreshCw size={18} />
                  Reconnect
                </button>
                <Link href="/teacher/classes/" className="inline-flex min-h-11 items-center justify-center rounded-xl border border-white/25 px-5 text-sm font-bold text-white">
                  Back to Classes
                </Link>
              </div>
            ) : null}
          </div>
        </div>
      ) : null}

      {controlError && !rosterOpen ? (
        <div className="fixed bottom-5 left-1/2 z-30 w-[calc(100%-2rem)] max-w-md -translate-x-1/2 rounded-xl bg-red-600 px-4 py-3 text-center text-sm font-semibold text-white shadow-xl" role="alert">
          {controlError}
        </div>
      ) : null}

      {rosterOpen ? (
        <div className="fixed inset-0 z-40 flex justify-end bg-black/45" role="dialog" aria-modal="true" aria-label="Class participants">
          <section className="flex h-full w-full max-w-sm flex-col bg-[#0F172A] shadow-2xl">
            <header className="flex min-h-16 items-center gap-3 border-b border-white/10 px-4">
              <Users size={21} className="text-[#60A5FA]" />
              <div className="min-w-0 flex-1">
                <h2 className="font-bold">Class participants</h2>
                <p className="text-xs text-white/60">{participants.length} currently connected</p>
              </div>
              <button type="button" aria-label="Close participants" onClick={() => setRosterOpen(false)} className="grid h-10 w-10 place-items-center rounded-xl hover:bg-white/10">
                <X size={20} />
              </button>
            </header>
            <div className="flex-1 overflow-y-auto p-4">
              {controlError ? <p className="mb-3 rounded-xl bg-red-500/15 px-3 py-2 text-sm text-red-200">{controlError}</p> : null}
              {participants.length ? (
                <div className="grid gap-2">
                  {participants.map((participant) => {
                    const isCurrentTeacher = participant.identity === auth.currentUser?.uid;
                    return (
                      <div key={participant.identity || participant.name} className="flex items-center gap-3 rounded-xl bg-white/5 px-3 py-3">
                        <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#0E72ED]/25 text-sm font-black text-[#93C5FD]">{participantInitials(participant.name)}</span>
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-bold">{participant.name || "Participant"}</p>
                          <p className="truncate text-xs capitalize text-white/55">{participant.role || "participant"}{isCurrentTeacher ? " · You" : ""}</p>
                        </div>
                        {!isCurrentTeacher ? (
                          <button type="button" aria-label={`Remove ${participant.name || "participant"}`} onClick={() => void removeParticipant(participant)} disabled={Boolean(controlBusy)} className="grid h-10 w-10 place-items-center rounded-xl text-red-300 hover:bg-red-500/15 disabled:opacity-40">
                            {controlBusy === participant.identity ? <Loader2 size={18} className="animate-spin" /> : <UserMinus size={18} />}
                          </button>
                        ) : null}
                      </div>
                    );
                  })}
                </div>
              ) : (
                <div className="grid min-h-48 place-items-center text-center text-sm text-white/55">No participants are visible yet.</div>
              )}
            </div>
          </section>
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
    videoProvider: stringValue(data.video_provider ?? data.videoProvider).toLowerCase(),
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

function functionErrorMessage(error: unknown, fallback: string) {
  const raw = error instanceof Error ? error.message : String(error || "");
  return raw.replace(/^Firebase:\s*/i, "").trim() || fallback;
}

function normalizeParticipants(value: unknown): ClassroomParticipant[] {
  if (!value || typeof value !== "object") return [];
  const raw = (value as { participants?: unknown }).participants;
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((item) => {
    if (!item || typeof item !== "object") return [];
    const data = item as Record<string, unknown>;
    const identity = stringValue(data.identity);
    const name = stringValue(data.name);
    if (!identity && !name) return [];
    return [{ identity, name, role: stringValue(data.role) }];
  });
}

function participantInitials(name: string) {
  const parts = name.split(/\s+/).filter(Boolean);
  return `${parts[0]?.[0] ?? "P"}${parts[1]?.[0] ?? ""}`.toUpperCase();
}

function buildZoomMeetingUrl(data: ZoomJoinResult) {
  const params = new URLSearchParams({
    sdkKey: data.sdkKey || "",
    signature: data.signature || "",
    meetingNumber: data.meetingNumber || "",
    password: data.password || "",
    displayName: data.displayName || "Participant",
    customerKey: data.customerKey || auth.currentUser?.uid || "",
    returnUrl: `${window.location.origin}/teacher/classes/`,
    embedded: "0",
    connectingText: "Connecting to class",
    loadErrorText: "Unable to load the class meeting.",
    joinErrorText: "Unable to join the class meeting.",
    initErrorText: "Unable to initialize the class meeting.",
    leftText: "Leave class",
    leaveMeetingText: "Leave meeting",
    routingStillConnectingText: "Still connecting to your private classroom...",
    routingHelpText: "Please leave and rejoin, or ask an administrator for help.",
    classEndingSoonText: "Class ends in {minutes} minutes",
    classEndedText: "This class has ended",
  });
  if (data.breakoutRoomName) params.set("breakoutRoomName", data.breakoutRoomName);
  if (data.breakoutRoomKey) params.set("breakoutRoomKey", data.breakoutRoomKey);
  if (data.autoJoinBreakoutRoom) params.set("autoJoinBreakoutRoom", "1");
  if (data.classEndsAtIso) params.set("classEndsAt", data.classEndsAtIso);
  return `/zoom_meeting.html?join=${Date.now()}#${params.toString()}`;
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
