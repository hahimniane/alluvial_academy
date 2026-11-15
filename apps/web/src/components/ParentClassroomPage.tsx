"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import { doc, getDoc } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { AlertCircle, Loader2 } from "lucide-react";
import ClassroomReconnecting from "@/components/ClassroomReconnecting";
import { useParentSession } from "@/components/ParentArea";
import { ParentAppBar } from "@/components/ParentUi";
import { readClassroomReconnect } from "@/lib/classroomReconnect";
import { db, functions } from "@/lib/firebase";
import { useLocale, useT } from "@/lib/i18n";
import { joinCheck, joinErrorKind, zoomInfoUsable, zoomMeetingUrl, type ZoomJoinInfo } from "@/lib/parentClasses";
import { parentClassesText, type ParentClassesText } from "@/lib/parentClassesText";
import { parseShift } from "@/lib/parentHome";

type State =
  | { kind: "connecting" }
  | { kind: "reconnecting"; expectedBackAt: Date | null }
  | { kind: "message"; text: string; tone: "warning" | "error" }
  | { kind: "realtimekit"; token: string; title: string };

const CLASSES_HREF = "/parent/classes/";

/**
 * Joining a class (ClassVideoService.joinClass, C-019…C-027), as its own page.
 * Same checks in the same order, the same callables with `activeRole:
 * 'parent'`, the same waiting room when the classroom is coming back, and —
 * for Zoom classes — the same cross-origin-isolated meeting page Flutter web
 * opens (/app/zoom_meeting.html) with the same parameters. Nothing about the
 * class or Zoom changes; only the page that starts the join is new.
 */
export default function ParentClassroomPage() {
  const session = useParentSession();
  const shiftId = useSearchParams()?.get("shiftId") ?? "";
  const fr = useLocale() === "fr";
  const text = parentClassesText(fr);
  const t = useT();
  const [state, setState] = useState<State>({ kind: "connecting" });
  const attempt = useRef(0);

  const join = useCallback(
    async (quiet: boolean) => {
      const run = ++attempt.current;
      if (!quiet) setState({ kind: "connecting" });
      const set = (next: State) => {
        if (run === attempt.current) setState(next);
      };
      try {
        const snap = shiftId ? await getDoc(doc(db, "teaching_shifts", shiftId)) : null;
        const shift = snap?.exists() ? parseShift(snap.id, snap.data()) : null;
        if (!shift) return set({ kind: "message", text: text.linkGone, tone: "error" });

        const check = joinCheck(shift, new Date());
        if (check.kind === "noVideo") return set({ kind: "message", text: text.noVideo, tone: "warning" });
        if (check.kind === "opensIn") return set({ kind: "message", text: check.minutes === 1 ? text.opensIn1 : text.opensInN.replace("{count}", String(check.minutes)), tone: "warning" });
        if (check.kind === "ended") return set({ kind: "message", text: text.ended, tone: "warning" });

        if (shift.videoProvider === "zoom") {
          const result = await httpsCallable(functions, "getZoomJoinInfo")({ shiftId: shift.id, activeRole: "parent" });
          const data = result.data as ZoomJoinInfo;
          if (!zoomInfoUsable(data)) return set({ kind: "message", text: data?.error?.trim() || text.connectFailed, tone: "error" });
          if (run !== attempt.current) return;
          window.location.assign(
            zoomMeetingUrl(data, {
              uid: session.uid,
              returnUrl: `${window.location.origin}${CLASSES_HREF}`,
              cacheBust: String(Date.now() * 1000),
              texts: {
                connecting: text.connecting,
                loadError: text.meetingLoadError,
                joinError: text.meetingJoinError,
                initError: text.meetingInitError,
                left: text.leaveClass,
                leaveMeeting: text.leaveMeeting,
                routingStillConnecting: text.routingStillConnecting,
                routingHelp: text.routingHelp,
                classEndingSoon: text.classEndingSoon,
                classEnded: text.classEnded,
              },
            }),
          );
          return;
        }

        const result = await httpsCallable(functions, "getRealtimeKitJoinToken")({ shiftId: shift.id, activeRole: "parent" });
        const data = (result.data ?? {}) as { success?: boolean; authToken?: string; shiftName?: string; error?: string };
        if (!data.success || !data.authToken) return set({ kind: "message", text: data.error?.trim() || text.connectFailed, tone: "error" });
        set({ kind: "realtimekit", token: data.authToken, title: data.shiftName || "Class" });
      } catch (error) {
        const reconnect = readClassroomReconnect(error);
        if (reconnect) return set({ kind: "reconnecting", expectedBackAt: reconnect.expectedBackAt });
        const kind = joinErrorKind(error);
        set({ kind: "message", tone: "error", text: kind.kind === "server" ? kind.message : kind.kind === "slow" ? text.slow : text.connectFailed });
      }
    },
    [shiftId, session.uid, text],
  );

  useEffect(() => {
    void join(false);
  }, [join]);

  if (state.kind === "realtimekit") {
    return (
      <div className="flex h-screen flex-col bg-black">
        <ParentAppBar title={state.title} backHref={CLASSES_HREF} backLabel={text.back} />
        <iframe
          title={state.title}
          src={`/app/realtimekit_meeting.html#token=${encodeURIComponent(state.token)}`}
          allow="camera; microphone; display-capture; fullscreen; autoplay; clipboard-write"
          allowFullScreen
          className="min-h-0 w-full flex-1 border-0 bg-black"
        />
      </div>
    );
  }

  return (
    <div className="flex min-h-full flex-col bg-[#F8FAFC]">
      <ParentAppBar title={text.classes} backHref={CLASSES_HREF} backLabel={text.back} />
      <div className="grid flex-1 place-items-center p-6">
        {state.kind === "connecting" ? (
          <div className="flex items-center gap-5 rounded-[28px] bg-white px-6 py-6 shadow-[0_8px_24px_rgba(0,0,0,0.12)]" role="status">
            <Loader2 size={36} className="animate-spin text-[#0386FF]" />
            <span className="text-base text-[#1F2937]">{text.connecting}</span>
          </div>
        ) : state.kind === "reconnecting" ? (
          <div className="w-full max-w-md rounded-2xl bg-[#020617] p-6 text-white">
            <ClassroomReconnecting expectedBackAt={state.expectedBackAt} onRetry={() => void join(true)} t={t} backHref={CLASSES_HREF} backLabel={text.backToClasses} />
          </div>
        ) : (
          <JoinMessage state={state} text={text} onRetry={() => void join(false)} />
        )}
      </div>
    </div>
  );
}

function JoinMessage({ state, text, onRetry }: { state: Extract<State, { kind: "message" }>; text: ParentClassesText; onRetry: () => void }) {
  const warning = state.tone === "warning";
  return (
    <div className="w-full max-w-md text-center">
      <div
        role="alert"
        className={`flex items-center gap-3 rounded-xl border px-4 py-3 text-left text-sm font-semibold ${warning ? "border-[#FED7AA] bg-[#FFF7ED] text-[#9A3412]" : "border-[#FECACA] bg-[#FEF2F2] text-[#991B1B]"}`}
      >
        <AlertCircle size={20} className="shrink-0" />
        <span className="min-w-0">{state.text}</span>
      </div>
      <div className="mt-4 flex flex-wrap justify-center gap-3">
        {!warning ? (
          <button type="button" onClick={onRetry} className="min-h-11 rounded-xl bg-[#0386FF] px-5 text-sm font-bold text-white hover:bg-[#0276E0]">
            {text.tryAgain}
          </button>
        ) : null}
        <Link href={CLASSES_HREF} className="inline-flex min-h-11 items-center rounded-xl border border-[#E5E7EB] bg-white px-5 text-sm font-bold text-[#111827] hover:bg-[#F9FAFB]">
          {text.backToClasses}
        </Link>
      </div>
    </div>
  );
}
