"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent, type ReactNode } from "react";
import {
  AlertTriangle,
  Calendar,
  CheckCircle2,
  Clock,
  Info,
  Mic,
  MicOff,
  PlayCircle,
  User,
  Users,
  Video,
  XCircle,
} from "lucide-react";
import { alpha } from "@/components/ParentUi";
import { fetchRoomPresence } from "@/lib/parentData";
import {
  canJoin as canJoinNow,
  cardStatus,
  formatCardDate,
  formatSheetDate,
  formatTime,
  isLive,
  presenceDuration,
  STATUS_WORDS,
  subjectLabel,
  type ParentShift,
  type RoomPresence,
} from "@/lib/parentHome";
import type { ParentHomeText } from "@/lib/parentHomeText";
import { PARENT_ROUTES } from "@/lib/parentWeb";

const STATUS_ICONS = { play: PlayCircle, check: CheckCircle2, cancel: XCircle, warning: AlertTriangle, schedule: Clock } as const;
const PRESENCE_POLL_MS = 15_000;
const HOLD_MS = 500;

/**
 * ParentPresenceCard (A-064…A-070): status badge, subject, teacher and date,
 * the live participants panel for a class in progress, and Join. Press and
 * hold (or the Class details button for keyboards) opens the details sheet.
 * Unlike Flutter, polling starts whenever the class becomes live, so a card
 * that turns live while on screen does not stay on a spinner (A-070).
 */
export function ParentClassCard({ shift, now, text, childNames }: { shift: ParentShift; now: Date; text: ParentHomeText; childNames?: string[] }) {
  const router = useRouter();
  const live = isLive(shift);
  const presence = useLivePresence(shift.id, live);
  const [sheetOpen, setSheetOpen] = useState(false);
  const holdTimer = useRef<number | null>(null);
  const held = useRef(false);
  const status = cardStatus(shift, now);
  const StatusIcon = STATUS_ICONS[status.icon];
  const joinable = canJoinNow(shift, now);
  const count = presence?.participantCount ?? 0;
  const join = () => router.push(PARENT_ROUTES.classroom(shift.id));

  const cancelHold = () => {
    if (holdTimer.current !== null) window.clearTimeout(holdTimer.current);
    holdTimer.current = null;
  };
  const startHold = (event: ReactPointerEvent) => {
    if (event.button !== 0) return;
    held.current = false;
    cancelHold();
    holdTimer.current = window.setTimeout(() => {
      held.current = true;
      setSheetOpen(true);
    }, HOLD_MS);
  };

  return (
    <>
      <div
        role={joinable ? "button" : undefined}
        tabIndex={joinable ? 0 : undefined}
        onPointerDown={startHold}
        onPointerUp={cancelHold}
        onPointerLeave={cancelHold}
        onPointerCancel={cancelHold}
        onContextMenu={(event) => {
          if (held.current) event.preventDefault();
        }}
        onClick={() => {
          if (held.current) {
            held.current = false;
            return;
          }
          if (joinable) join();
        }}
        onKeyDown={(event) => {
          if (joinable && (event.key === "Enter" || event.key === " ") && event.target === event.currentTarget) {
            event.preventDefault();
            join();
          }
        }}
        className={`relative rounded-2xl bg-white p-4 ${joinable ? "cursor-pointer" : ""}`}
        style={{ border: live ? `2px solid ${alpha(status.color, 0.5)}` : "1px solid #EEEEEE" }}
      >
        <div className="flex items-center gap-2">
          <span className="inline-flex items-center gap-1 rounded-full px-2.5 py-1" style={{ backgroundColor: alpha(status.color, 0.1) }}>
            <StatusIcon size={14} style={{ color: status.color }} />
            <span className="text-xs font-semibold" style={{ color: status.color }}>
              {status.label}
            </span>
          </span>
          {live && count > 0 ? (
            <span className="inline-flex items-center gap-1 rounded-full border border-[#10B981]/30 bg-[#10B981]/10 px-2 py-1">
              <span className="h-1.5 w-1.5 rounded-full bg-[#10B981]" />
              <span className="text-[11px] font-semibold text-[#10B981]">{count} in class</span>
            </span>
          ) : null}
          <span className="ml-auto text-sm font-semibold text-[#1E293B]">{formatTime(shift.shiftStart)}</span>
        </div>

        <p className="mt-3 text-base font-semibold text-[#1E293B]">{subjectLabel(shift)}</p>
        <p className="mt-2 flex items-center gap-1.5 text-[13px] text-[#64748B]">
          <User size={16} className="shrink-0" />
          <span className="min-w-0">Teacher: {shift.teacherName || "Unknown"}</span>
        </p>
        <p className="mt-1 flex items-center gap-1.5 text-[13px] text-[#64748B]">
          <Calendar size={16} className="shrink-0" />
          {formatCardDate(shift.shiftStart)}
        </p>
        {childNames ? (
          <p className="mt-1 flex items-center gap-1.5 text-[13px] text-[#64748B]">
            <Users size={16} className="shrink-0" />
            <span className="min-w-0">{childNames.join(", ")}</span>
          </p>
        ) : null}

        {live ? (
          <>
            <div className="mt-3 rounded-xl border border-[#10B981]/20 bg-[#10B981]/5 p-3">
              <div className="flex items-center gap-2">
                <span className="h-2 w-2 rounded-full bg-[#10B981]" />
                <span className="text-xs font-semibold text-[#10B981]">{text.liveParticipants}</span>
                <span className="ml-auto">
                  {presence ? (
                    <span className="text-xs font-semibold text-[#10B981]">{presence.participantCount} in class</span>
                  ) : (
                    <span className="block h-3 w-3 animate-spin rounded-full border-2 border-[#10B981] border-t-transparent" aria-label={text.loading} />
                  )}
                </span>
              </div>
              {presence && presence.participants.length > 0 ? (
                <ul className="mt-2.5 grid gap-2">
                  {presence.participants.map((p, index) => (
                    <li key={`${p.identity}-${index}`} className="flex items-center gap-2.5">
                      <span className={`grid h-7 w-7 shrink-0 place-items-center rounded-full ${p.isPublisher ? "bg-[#10B981]/20 text-[#10B981]" : "bg-[#EEEEEE] text-[#9CA3AF]"}`}>
                        {p.isPublisher ? <Mic size={14} /> : <MicOff size={14} />}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-[13px] font-medium text-[#1E293B]">{p.name || p.identity}</span>
                        {p.role ? <span className="block text-[11px] text-[#64748B]">{p.role}</span> : null}
                      </span>
                      {p.joinedAt ? (
                        <span className="rounded-lg bg-white px-2 py-0.5 text-[11px] font-medium text-[#64748B]">{presenceDuration(now.getTime() - p.joinedAt.getTime())}</span>
                      ) : null}
                    </li>
                  ))}
                </ul>
              ) : presence ? (
                <p className="mt-2 text-xs italic text-[#64748B]">{text.noOneJoined}</p>
              ) : null}
            </div>
            <p className="mt-1.5 text-[10px] text-[#94A3B8]">{text.holdForDetails}</p>
          </>
        ) : null}

        {joinable ? (
          <button
            type="button"
            onClick={(event) => {
              event.stopPropagation();
              join();
            }}
            onPointerDown={(event) => event.stopPropagation()}
            className="mt-4 flex w-full items-center justify-center gap-2 rounded-xl bg-[#10B981] py-3 text-sm font-semibold text-white hover:bg-[#0EA371]"
          >
            <Video size={20} />
            {live ? "Join Now" : "Join Class"}
          </button>
        ) : null}

        <button
          type="button"
          onClick={(event) => {
            event.stopPropagation();
            setSheetOpen(true);
          }}
          onPointerDown={(event) => event.stopPropagation()}
          className="sr-only focus:not-sr-only focus:absolute focus:right-3 focus:top-12 focus:rounded-lg focus:bg-white focus:px-3 focus:py-1.5 focus:text-xs focus:font-semibold focus:text-[#0E72ED] focus:shadow"
        >
          {text.classDetails}
        </button>
      </div>

      {sheetOpen ? (
        <ClassDetailsSheet
          shift={shift}
          presence={presence}
          now={now}
          text={text}
          onJoin={joinable ? join : null}
          onClose={() => setSheetOpen(false)}
        />
      ) : null}
    </>
  );
}

/** Live participants every 15 s while the class is live (D8). */
function useLivePresence(shiftId: string, live: boolean): RoomPresence | null {
  const [presence, setPresence] = useState<RoomPresence | null>(null);
  useEffect(() => {
    if (!live) return;
    let active = true;
    let busy = false;
    const load = async () => {
      if (busy) return;
      busy = true;
      const result = await fetchRoomPresence(shiftId);
      busy = false;
      if (active) setPresence(result);
    };
    void load();
    const timer = window.setInterval(() => void load(), PRESENCE_POLL_MS);
    return () => {
      active = false;
      window.clearInterval(timer);
    };
  }, [shiftId, live]);
  return live ? presence : null;
}

/**
 * `_PresenceDetailSheet`: a bottom sheet at 60 % of the screen, draggable
 * between 40 % and 90 %. Presence is the card's last answer (not refreshed).
 */
function ClassDetailsSheet({
  shift,
  presence,
  now,
  text,
  onJoin,
  onClose,
}: {
  shift: ParentShift;
  presence: RoomPresence | null;
  now: Date;
  text: ParentHomeText;
  onJoin: (() => void) | null;
  onClose: () => void;
}) {
  const live = isLive(shift);
  const [height, setHeight] = useState(60);
  const drag = useRef<{ startY: number; startHeight: number } | null>(null);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const onDragMove = (event: ReactPointerEvent) => {
    if (!drag.current) return;
    const deltaVh = ((drag.current.startY - event.clientY) / window.innerHeight) * 100;
    setHeight(Math.min(90, Math.max(40, drag.current.startHeight + deltaVh)));
  };

  const hours = ((shift.shiftEnd.getTime() - shift.shiftStart.getTime()) / 60_000 / 60).toFixed(1);

  return (
    <div className="fixed inset-0 z-[90]" role="dialog" aria-modal="true" aria-label={subjectLabel(shift)}>
      <button type="button" aria-label={text.close} onClick={onClose} className="absolute inset-0 bg-black/50" />
      <div className="absolute inset-x-0 bottom-0 flex flex-col rounded-t-3xl bg-white" style={{ height: `${height}vh` }}>
        <div
          className="flex cursor-grab touch-none justify-center pt-3 pb-1"
          onPointerDown={(event) => {
            drag.current = { startY: event.clientY, startHeight: height };
            event.currentTarget.setPointerCapture(event.pointerId);
          }}
          onPointerMove={onDragMove}
          onPointerUp={() => (drag.current = null)}
          onPointerCancel={() => (drag.current = null)}
        >
          <span className="h-1 w-10 rounded-sm bg-[#E0E0E0]" />
        </div>
        <div className="p-5">
          <div className="flex items-center gap-2">
            <h2 className="min-w-0 flex-1 text-xl font-bold text-[#1E293B]">{subjectLabel(shift)}</h2>
            {live ? (
              <span className="inline-flex items-center gap-1.5 rounded-full bg-[#10B981]/10 px-2.5 py-1">
                <span className="h-2 w-2 rounded-full bg-[#10B981]" />
                <span className="text-xs font-bold text-[#10B981]">{text.live}</span>
              </span>
            ) : null}
          </div>
          <p className="mt-2 text-sm text-[#64748B]">{formatSheetDate(shift.shiftStart)}</p>
        </div>
        <hr className="border-[#E0E0E0]" />
        <div className="min-h-0 flex-1 overflow-y-auto p-5">
          <SheetSection title="Teacher" icon={User}>
            <SheetRow label="Name" value={shift.teacherName || "Unknown"} />
            {shift.clockInTime ? <SheetRow label="Clocked in" value={formatTime(shift.clockInTime)} /> : null}
            {shift.clockInTime && live ? <SheetRow label="Time in class" value={presenceDuration(now.getTime() - shift.clockInTime.getTime())} /> : null}
          </SheetSection>

          <SheetSection title={`Assigned Students (${shift.studentIds.length})`} icon={Users}>
            {shift.studentNames.length === 0 ? (
              <SheetRow label="Students" value={`${shift.studentIds.length} assigned`} />
            ) : (
              shift.studentNames.map((name, index) => <SheetRow key={`${name}-${index}`} label="" value={name} />)
            )}
          </SheetSection>

          {presence && presence.participants.length > 0 ? (
            <SheetSection title={`Currently in Class (${presence.participantCount})`} icon={Video}>
              {presence.participants.map((p, index) => (
                <div key={`${p.identity}-${index}`} className="flex items-center gap-3 py-1.5">
                  <span className={`grid h-8 w-8 shrink-0 place-items-center rounded-full ${p.isPublisher ? "bg-[#10B981]/10 text-[#10B981]" : "bg-[#64748B]/10 text-[#64748B]"}`}>
                    {p.isPublisher ? <Mic size={16} /> : <MicOff size={16} />}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[13px] font-medium text-[#1E293B]">{p.name || p.identity}</span>
                    <span className="block text-[11px] text-[#64748B]">{p.role ?? "Participant"}</span>
                  </span>
                  <span className="rounded-lg bg-[#F5F5F5] px-2 py-1 text-[11px] font-medium text-[#64748B]">
                    {p.joinedAt ? `Joined ${formatTime(p.joinedAt)} · ${presenceDuration(now.getTime() - p.joinedAt.getTime())}` : text.unknown}
                  </span>
                </div>
              ))}
            </SheetSection>
          ) : null}

          <SheetSection title="Class Information" icon={Info}>
            <SheetRow label="Duration" value={`${hours} hours`} />
            <SheetRow label="Subject" value={subjectLabel(shift)} />
            <SheetRow label="Status" value={STATUS_WORDS[shift.status]} />
            {shift.notes ? <SheetRow label="Notes" value={shift.notes} /> : null}
          </SheetSection>

          {onJoin ? (
            <button
              type="button"
              onClick={() => {
                onClose();
                onJoin();
              }}
              className="mt-3 flex w-full items-center justify-center gap-2 rounded-xl bg-[#10B981] py-4 text-base font-semibold text-white hover:bg-[#0EA371]"
            >
              <Video size={22} />
              {live ? "Join Class Now" : "Join Class"}
            </button>
          ) : null}
        </div>
      </div>
    </div>
  );
}

function SheetSection({ title, icon: Icon, children }: { title: string; icon: typeof User; children: ReactNode }) {
  return (
    <section className="mb-5">
      <h3 className="flex items-center gap-2 text-sm font-semibold text-[#1E293B]">
        <Icon size={18} className="text-[#0E72ED]" />
        {title}
      </h3>
      <div className="mt-3 rounded-xl bg-[#F8FAFC] p-3">{children}</div>
    </section>
  );
}

function SheetRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-start py-1">
      {label ? <span className="w-[100px] shrink-0 text-[13px] text-[#64748B]">{label}</span> : null}
      <span className="min-w-0 flex-1 whitespace-pre-wrap break-words text-[13px] font-medium text-[#1E293B]">{value}</span>
    </div>
  );
}
