"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { AlertCircle, Loader2, RotateCcw, Video } from "lucide-react";
import { firebaseProjectId } from "@/lib/firebase";

type JoinState = "joining" | "ready" | "error";

type GuestJoinResult = {
  success?: boolean;
  authToken?: string;
  token?: string;
  shiftName?: string;
  displayName?: string;
  error?: string;
};

export function GuestClassroomJoinPage() {
  const searchParams = useSearchParams();
  const shiftId = (searchParams.get("guestShift") || searchParams.get("shiftId") || "").trim();
  const displayName = (searchParams.get("name") || "").trim();
  const [state, setState] = useState<JoinState>("joining");
  const [message, setMessage] = useState("Please wait while we connect you.");
  const [shiftName, setShiftName] = useState("Class");
  const [meetingUrl, setMeetingUrl] = useState("");
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let cancelled = false;
    async function join() {
      if (!shiftId) {
        setState("error");
        setMessage("This class link is invalid.");
        return;
      }
      setState("joining");
      setMessage("Please wait while we connect you.");
      setMeetingUrl("");
      try {
        const result = await requestGuestJoinToken(shiftId, displayName);
        if (cancelled) return;
        const token = result.authToken || result.token;
        if (!result.success || !token) {
          throw new Error(result.error || "Unable to join this class.");
        }
        setShiftName(result.shiftName || "Class");
        setMeetingUrl(`/realtimekit_meeting.html#token=${encodeURIComponent(token)}`);
        setState("ready");
        setMessage("");
      } catch (error) {
        if (!cancelled) {
          setState("error");
          setMessage(error instanceof Error ? error.message : "Unable to join this class.");
        }
      }
    }

    void join();
    return () => {
      cancelled = true;
    };
  }, [attempt, displayName, shiftId]);

  if (state === "ready" && meetingUrl) {
    return (
      <main className="min-h-screen bg-black text-white">
        <header className="fixed left-0 right-0 top-0 z-20 flex min-h-14 items-center gap-3 bg-black/70 px-4 backdrop-blur">
          <Video size={20} className="shrink-0 text-[#60A5FA]" />
          <div className="min-w-0 flex-1">
            <h1 className="truncate text-sm font-bold">{shiftName}</h1>
            <p className="truncate text-xs text-white/70">Connected</p>
          </div>
        </header>
        <section className="min-h-screen bg-black pt-14">
          <iframe
            title={shiftName}
            src={meetingUrl}
            allow="camera; microphone; display-capture; fullscreen; autoplay; clipboard-write"
            allowFullScreen
            className="h-[calc(100vh-56px)] w-full border-0 bg-black"
          />
        </section>
      </main>
    );
  }

  return (
    <main className="grid min-h-screen place-items-center bg-[#F8FAFC] px-6 py-10 text-[#0F172A]">
      <section className="w-full max-w-[420px] text-center">
        {state === "joining" ? (
          <span className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-[#0E72ED]/10 text-[#0E72ED]">
            <Loader2 size={32} className="animate-spin" />
          </span>
        ) : (
          <span className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-red-50 text-red-500">
            <AlertCircle size={34} />
          </span>
        )}
        <h1 className="mt-5 text-xl font-bold">{state === "joining" ? "Joining Class" : "Unable to Join"}</h1>
        <p className="mt-2 text-sm leading-6 text-[#475569]">{message}</p>
        {state === "error" ? (
          <div className="mt-6 flex flex-wrap justify-center gap-3">
            <button
              type="button"
              onClick={() => setAttempt((current) => current + 1)}
              className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl border border-[#CBD5E1] bg-white px-4 text-sm font-bold text-[#334155] hover:bg-[#F8FAFC]"
            >
              <RotateCcw size={16} />
              Try Again
            </button>
            <Link href="/" className="inline-flex min-h-11 items-center justify-center rounded-xl bg-[#0E72ED] px-5 text-sm font-bold text-white hover:bg-[#0B5FC7]">
              Go to Site
            </Link>
          </div>
        ) : null}
      </section>
    </main>
  );
}

async function requestGuestJoinToken(shiftId: string, displayName: string): Promise<GuestJoinResult> {
  const projectId = firebaseProjectId || "alluwal-dev";
  const params = new URLSearchParams({ shiftId });
  if (displayName) params.set("name", displayName);
  const response = await fetch(`https://us-central1-${projectId}.cloudfunctions.net/getRealtimeKitGuestJoin?${params.toString()}`, {
    cache: "no-store",
  });
  const data = (await response.json().catch(() => ({}))) as GuestJoinResult;
  if (!response.ok) {
    throw new Error(data.error || "Unable to join this class.");
  }
  return data;
}
