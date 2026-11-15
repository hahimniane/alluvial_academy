/**
 * Pure rules behind the parent Classes page and joining a class (inventory C,
 * C-001…C-030). No Firebase imports; each rule mirrors the Dart and is
 * unit-tested:
 *
 *   lib/features/parent/screens/parent_classes_screen.dart  (grouping, order)
 *   lib/core/services/class_video_service.dart              (join checks, errors)
 *   lib/core/widgets/zoom_meeting_screen_web.dart           (meeting page address)
 *
 * Nothing here changes how classes or Zoom behave: the parent joins through
 * the same callables, with the same role, on the same meeting page as today.
 */
import { inJoinWindow, isLive, type ParentShift } from "./parentHome.ts";

// ─── Grouping siblings in the same class (C-008) ───────────────────────────

/** `_classGroupKey`: the room a class meets in, so siblings share one card. */
export function classGroupKey(shift: ParentShift): string {
  const clean = (value: string | null | undefined) => (value ?? "").trim();
  const livekit = clean(shift.livekitRoomName);
  if (livekit) return `livekit:${livekit}`;
  const roomKey = clean(shift.breakoutRoomKey) || clean(shift.breakoutRoomName);
  const zoom = clean(shift.zoomMeetingId);
  if (zoom) return `zoom:${zoom}:${roomKey}`;
  const hub = clean(shift.hubMeetingId);
  if (hub) return `hub:${hub}:${roomKey}`;
  const subject = clean(shift.subjectId) || clean(shift.subjectDisplayName).toLowerCase() || shift.subject;
  return `fallback:${shift.teacherId}:${subject}:${shift.shiftStart.getTime()}:${shift.shiftEnd.getTime()}`;
}

export type ClassGroup = { key: string; shift: ParentShift; childIds: string[]; childNames: string[] };

export type ChildClasses = { childId: string; childName: string; shifts: ParentShift[] };

/**
 * `_buildClassGroups`: one card per room. The card keeps the first class of
 * the group, replaced by a later one only when the later one can be joined
 * now and the kept one cannot.
 */
export function groupClasses(children: ChildClasses[], now: Date): ClassGroup[] {
  const groups = new Map<string, ClassGroup>();
  for (const child of children) {
    const name = child.childName.trim() || child.childId;
    for (const shift of child.shifts) {
      const key = classGroupKey(shift);
      let group = groups.get(key);
      if (!group) {
        group = { key, shift, childIds: [], childNames: [] };
        groups.set(key, group);
      }
      if (!group.childIds.includes(child.childId)) {
        group.childIds.push(child.childId);
        group.childNames.push(name);
      }
      if (inJoinWindow(shift, now) && !inJoinWindow(group.shift, now)) group.shift = shift;
    }
  }
  return [...groups.values()];
}

/** C-010: not yet ended; live first, then joinable now, then by start. */
export function upcomingGroups(groups: ClassGroup[], now: Date) {
  return groups
    .filter((g) => g.shift.shiftEnd.getTime() > now.getTime())
    .sort((a, b) => {
      const live = Number(isLive(b.shift)) - Number(isLive(a.shift));
      if (live !== 0) return live;
      const join = Number(inJoinWindow(b.shift, now)) - Number(inJoinWindow(a.shift, now));
      if (join !== 0) return join;
      return a.shift.shiftStart.getTime() - b.shift.shiftStart.getTime();
    });
}

/** C-012: ended; newest start first. */
export function historyGroups(groups: ClassGroup[], now: Date) {
  return groups.filter((g) => g.shift.shiftEnd.getTime() <= now.getTime()).sort((a, b) => b.shift.shiftStart.getTime() - a.shift.shiftStart.getTime());
}

// ─── Joining (C-019…C-027) ─────────────────────────────────────────────────

export type JoinCheck = { kind: "ok" } | { kind: "noVideo" } | { kind: "opensIn"; minutes: number } | { kind: "ended" };

/**
 * `joinClass` checks before the server is asked. The role check passes for a
 * parent opening as parent (the shell only admits that), so it is not
 * repeated; the server decides whether this parent may enter (C-021).
 */
export function joinCheck(shift: ParentShift, now: Date): JoinCheck {
  if (!(shift.category === "teaching" && shift.studentIds.length > 0)) return { kind: "noVideo" };
  if (inJoinWindow(shift, now)) return { kind: "ok" };
  const opensAt = shift.shiftStart.getTime() - 10 * 60_000;
  if (now.getTime() < opensAt) return { kind: "opensIn", minutes: Math.floor((opensAt - now.getTime()) / 60_000) };
  return { kind: "ended" };
}

/** `ZoomClassJoinInfo` must carry a meeting number, a signature and an SDK key. */
export type ZoomJoinInfo = {
  success?: boolean;
  error?: string;
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
};

export function zoomInfoUsable(data: ZoomJoinInfo | null | undefined): data is ZoomJoinInfo & { meetingNumber: string; signature: string; sdkKey: string } {
  return !!data && data.success === true && !!data.meetingNumber && !!data.signature && !!data.sdkKey;
}

export type MeetingTexts = {
  connecting: string;
  loadError: string;
  joinError: string;
  initError: string;
  left: string;
  leaveMeeting: string;
  routingStillConnecting: string;
  routingHelp: string;
  classEndingSoon: string;
  classEnded: string;
};

/**
 * The meeting page address, built exactly as ZoomMeetingScreen (web) builds
 * it: Flutter's own `/app/zoom_meeting.html` — the cross-origin-isolated copy
 * parents use today (C-024) — with the same hash parameters. Leaving the
 * meeting comes back to `returnUrl`.
 */
export function zoomMeetingUrl(data: ZoomJoinInfo & { meetingNumber: string; signature: string; sdkKey: string }, opts: { uid: string; returnUrl: string; texts: MeetingTexts; cacheBust: string }) {
  const params: Array<[string, string]> = [
    ["sdkKey", data.sdkKey],
    ["signature", data.signature],
    ["meetingNumber", data.meetingNumber],
    ["password", data.password ?? ""],
    ["displayName", data.displayName || "Participant"],
    ["customerKey", data.customerKey || opts.uid],
    ["returnUrl", opts.returnUrl],
    ["embedded", "0"],
    ["connectingText", opts.texts.connecting],
    ["loadErrorText", opts.texts.loadError],
    ["joinErrorText", opts.texts.joinError],
    ["initErrorText", opts.texts.initError],
    ["leftText", opts.texts.left],
    ["leaveMeetingText", opts.texts.leaveMeeting],
    ["routingStillConnectingText", opts.texts.routingStillConnecting],
    ["routingHelpText", opts.texts.routingHelp],
  ];
  if (data.classEndsAtIso) {
    const ends = new Date(data.classEndsAtIso);
    if (!Number.isNaN(ends.getTime())) params.push(["classEndsAt", ends.toISOString()]);
  }
  params.push(["classEndingSoonText", opts.texts.classEndingSoon], ["classEndedText", opts.texts.classEnded]);
  if ((data.breakoutRoomName ?? "").trim()) params.push(["breakoutRoomName", data.breakoutRoomName!.trim()]);
  if ((data.breakoutRoomKey ?? "").trim()) params.push(["breakoutRoomKey", data.breakoutRoomKey!.trim()]);
  if (data.autoJoinBreakoutRoom) params.push(["autoJoinBreakoutRoom", "1"]);
  const hash = params.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join("&");
  return `/app/zoom_meeting.html?join=${opts.cacheBust}#${hash}`;
}

/**
 * `joinErrorText`: a sentence the server wrote is kept; a bare code (a
 * timeout, no network) becomes the slow-connection sentence for
 * deadline-exceeded / unavailable, else the generic failure.
 */
export function joinErrorKind(error: unknown): { kind: "server"; message: string } | { kind: "slow" } | { kind: "failed" } {
  const raw = error as { code?: unknown; message?: unknown } | null;
  const code = String(raw?.code ?? "").toLowerCase();
  const message = String(raw?.message ?? "")
    .replace(/^Firebase:\s*/i, "")
    .trim();
  const normalized = message.toLowerCase().replace(/_/g, "-");
  const bare = !message || normalized === code || normalized === code.replace(/^functions\//, "") || normalized === "internal";
  if (!bare) return { kind: "server", message };
  if (code.endsWith("deadline-exceeded") || code.endsWith("unavailable")) return { kind: "slow" };
  return { kind: "failed" };
}
