"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { collection, getDocs, limit, query, Timestamp, where } from "firebase/firestore";
import type { ReactNode } from "react";
import { useEffect, useMemo, useState } from "react";
import { BookOpen, ChevronLeft, Clock3, Copy, Info, Link as LinkIcon, Menu, Mic, Play, Shuffle, UserRound, Users, VideoIcon, VideoOff, X } from "lucide-react";
import { auth, db, functions } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell, openTeacherMobileMenu } from "@/components/TeacherDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type UserRecord = Record<string, unknown>;

type TeacherSummary = {
  displayName: string;
  firstName: string;
  initials: string;
};

type TeacherClass = {
  id: string;
  title: string;
  teacherName: string;
  studentNames: string[];
  subject: string;
  start: Date | null;
  end: Date | null;
  status: string;
  category: string;
  videoProvider: string;
  livekitRoomName: string;
  realtimekitMeetingId: string;
  zoomMeetingId: string;
  isClockedIn: boolean;
  clockInTime: Date | null;
  durationHours: number;
  notes: string;
};

type ClassPresenceParticipant = {
  identity: string;
  name: string;
  role: string;
  joinedAt: Date | null;
  isPublisher: boolean;
};

type ClassPresence = {
  success: boolean;
  participantCount: number;
  participants: ClassPresenceParticipant[];
  error: string;
};

export function TeacherClassesPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [summary, setSummary] = useState<TeacherSummary>({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [classes, setClasses] = useState<TeacherClass[]>([]);
  const [presenceByShiftId, setPresenceByShiftId] = useState<Record<string, ClassPresence>>({});
  const [selectedClass, setSelectedClass] = useState<TeacherClass | null>(null);
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState("");

  const showNotice = (message: string) => {
    setNotice(message);
    window.setTimeout(() => setNotice(""), 3000);
  };

  const openDetails = (classItem: TeacherClass) => {
    setSelectedClass(classItem);
    void loadClassPresence(classItem.id).then((presence) => {
      setPresenceByShiftId((current) => ({ ...current, [classItem.id]: presence }));
    });
  };

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      if (!nextUser) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }

      setAccess("checking");
      setLoading(true);
      try {
        const allowed = await isCurrentUserTeacher(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          setLoading(false);
          return;
        }
        const userRecord = await getCurrentUserRecord(nextUser);
        if (!mounted) return;
        setSummary(summaryForUser(nextUser, userRecord));
        setAccess("allowed");
        const loaded = await loadTeacherClasses(nextUser.uid);
        if (mounted) setClasses(loaded);
      } catch {
        if (mounted) setClasses([]);
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const visibleClasses = useMemo(() => {
    const now = new Date();
    const futureLimit = addDays(now, 365);
    return classes
      .filter((classItem) => classItem.category.toLowerCase() === "teaching")
      .filter((classItem) => classItem.end === null || classItem.end > now)
      .filter((classItem) => classItem.start === null || classItem.start < futureLimit)
      .sort((a, b) => compareClasses(a, b, now));
  }, [classes]);

  const groupedClasses = useMemo(() => groupClassesByDay(visibleClasses), [visibleClasses]);

  useEffect(() => {
    if (access !== "allowed" || visibleClasses.length === 0) return;
    let cancelled = false;
    const refresh = async () => {
      const activeClasses = visibleClasses.filter((classItem) => shouldLoadPresence(classItem, new Date()));
      if (activeClasses.length === 0) return;
      const entries = await Promise.all(
        activeClasses.map(async (classItem) => [classItem.id, await loadClassPresence(classItem.id)] as const),
      );
      if (!cancelled) {
        setPresenceByShiftId((current) => ({ ...current, ...Object.fromEntries(entries) }));
      }
    };
    void refresh();
    const timer = window.setInterval(() => void refresh(), 15000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, [access, visibleClasses]);

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  return (
    <TeacherShell activeLabel="Classes" breadcrumb="Communication / Classes" summary={summary}>
      <main className="min-h-screen bg-[#F8FAFC] text-[#1E293B] lg:min-h-[calc(100vh-56px)]">
        <MobileTeacherTopBar summary={summary} />
        <header className="border-b border-[#EEF2F7] bg-white">
          <div className="grid min-h-14 grid-cols-[48px_1fr_48px] items-center px-3 sm:px-4">
            <Link href="/teacher/" aria-label="Back to dashboard" className="grid h-11 w-11 place-items-center rounded-xl text-[#64748B] hover:bg-[#F8FAFC]">
              <ChevronLeft size={24} />
            </Link>
            <h1 className="truncate text-center text-[21px] font-black text-[#111827]">Classes</h1>
            <Link href="/teacher/recordings/" aria-label="Class Recordings" className="grid h-11 w-11 place-items-center rounded-xl text-[#64748B] hover:bg-[#F8FAFC]">
              <VideoIcon size={23} />
            </Link>
          </div>
        </header>

        {loading ? (
          <LoadingClasses />
        ) : visibleClasses.length === 0 ? (
          <NoClassesState />
        ) : (
          <section className="mx-auto grid max-w-6xl gap-3 px-4 py-4">
            <ClassesHeaderCard />
            {groupedClasses.map((group) => (
              <div key={group.key} className="grid gap-2">
                <h2 className="px-0.5 pt-2 text-sm font-bold text-[#64748B]">{group.label}</h2>
                {group.items.map((classItem) => (
                  <ClassCard
                    key={classItem.id}
                    classItem={classItem}
                    presence={presenceByShiftId[classItem.id]}
                    onCopied={showNotice}
                    onDetails={openDetails}
                  />
                ))}
              </div>
            ))}
          </section>
        )}
        {notice ? <div className="fixed bottom-5 right-5 z-50 rounded-xl bg-[#111827] px-4 py-3 text-sm font-semibold text-white shadow-lg">{notice}</div> : null}
        {selectedClass ? (
          <ClassDetailsDialog
            classItem={selectedClass}
            presence={presenceByShiftId[selectedClass.id]}
            onClose={() => setSelectedClass(null)}
          />
        ) : null}
      </main>
    </TeacherShell>
  );
}

function MobileTeacherTopBar({ summary }: { summary: TeacherSummary }) {
  return (
    <header className="grid min-h-14 grid-cols-[56px_1fr_96px] items-center bg-white px-4 lg:hidden">
      <button type="button" aria-label="Open teacher menu" onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl text-[#111827]">
        <Menu size={24} />
      </button>
      <div className="min-w-0 text-center text-base font-bold text-[#111827]">Alluwal Education Hub</div>
      <div className="flex items-center justify-end gap-3">
        <button type="button" aria-label="Open teacher account options" onClick={openTeacherMobileMenu} className="grid h-10 w-10 place-items-center rounded-xl text-[#111827]"><Shuffle size={20} /></button>
        <span className="grid h-9 w-9 place-items-center rounded-full bg-[#009688] text-xs font-black text-white">{summary.initials}</span>
      </div>
    </header>
  );
}

function NoClassesState() {
  return (
    <section className="grid min-h-[calc(100vh-112px)] place-items-center px-6 py-10 text-center lg:min-h-[calc(100vh-168px)]">
      <div>
        <div className="mx-auto grid h-24 w-24 place-items-center rounded-full bg-[#DCEEFF] text-[#0E72ED]">
          <VideoOff size={44} />
        </div>
        <h2 className="mt-5 text-xl font-bold text-[#1E293B]">No Classes Right Now</h2>
        <p className="mt-2 text-sm leading-6 text-[#64748B]">Your Scheduled Classes Will Appear Here</p>
      </div>
    </section>
  );
}

function LoadingClasses() {
  return (
    <section className="grid min-h-[calc(100vh-112px)] place-items-center px-6 py-10 text-center lg:min-h-[calc(100vh-168px)]">
      <div>
        <div className="mx-auto h-11 w-11 animate-spin rounded-full border-4 border-[#DCEEFF] border-t-[#0E72ED]" />
        <p className="mt-4 text-sm font-semibold text-[#64748B]">Loading classes...</p>
      </div>
    </section>
  );
}

function ClassesHeaderCard() {
  return (
    <section className="flex items-start gap-3 rounded-2xl bg-white p-4 shadow-[0_4px_10px_rgba(15,23,42,0.04)]">
      <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-[#E7F3FF] text-[#0E72ED]">
        <VideoIcon size={24} />
      </span>
      <div className="min-w-0">
        <h2 className="text-base font-bold text-[#1E293B]">Your classes</h2>
        <p className="mt-1 text-sm leading-5 text-[#64748B]">Join your classes directly in the app. The Join button becomes active 10 minutes before the class starts.</p>
      </div>
    </section>
  );
}

function ClassCard({
  classItem,
  presence,
  onCopied,
  onDetails,
}: {
  classItem: TeacherClass;
  presence?: ClassPresence;
  onCopied: (message: string) => void;
  onDetails: (classItem: TeacherClass) => void;
}) {
  const now = new Date();
  const action = classAction(classItem, now);
  const status = statusLabel(classItem, now);
  const copyGuestLink = async () => {
    const link = buildGuestJoinLink(classItem.id);
    try {
      await navigator.clipboard.writeText(link);
      onCopied("Guest class link copied");
    } catch {
      onCopied(link);
    }
  };
  return (
    <article className="rounded-xl border border-[#E2E8F0] bg-white p-3.5 shadow-[0_2px_8px_rgba(15,23,42,0.03)]">
      <div className="flex items-start gap-3">
        <span className={`grid h-10 w-10 shrink-0 place-items-center rounded-[10px] ${action.kind === "join" ? "bg-[#D1FAE5] text-[#10B981]" : action.kind === "notReady" ? "bg-[#FEF3C7] text-[#B45309]" : "bg-[#E7F3FF] text-[#64748B]"}`}>
          {action.kind === "join" ? <Play size={22} fill="currentColor" /> : action.kind === "notReady" ? <VideoOff size={21} /> : <Clock3 size={21} />}
        </span>
        <div className="flex min-w-0 flex-1 items-start gap-2 sm:gap-4">
          <div className="min-w-0 flex-1">
            <h3 className="truncate text-sm font-bold text-[#1E293B]">{classItem.title || "Class"}</h3>
            <div className="mt-1.5 grid gap-1 text-xs text-[#374151]">
              <span className="flex min-w-0 items-center gap-1.5">
                <UserRound size={14} className="shrink-0 text-[#6B7280]" />
                <span className="truncate">Teacher: {classItem.teacherName || "Unknown"}</span>
              </span>
              <span className="flex min-w-0 items-center gap-1.5">
                <BookOpen size={14} className="shrink-0 text-[#6B7280]" />
                <span className="truncate">{classItem.subject || "Class"}</span>
              </span>
              <span className="flex min-w-0 items-center gap-1.5">
                <Users size={14} className="shrink-0 text-[#6B7280]" />
                <span className="truncate">{studentNamesDisplay(classItem.studentNames)}</span>
              </span>
              <span className="flex min-w-0 items-center gap-1.5 text-[#6B7280]">
                <Clock3 size={14} className="shrink-0" />
                <span className="truncate">{formatClassTime(classItem)}</span>
              </span>
            </div>
            <div className="mt-2 flex flex-wrap items-center gap-2 text-xs font-semibold">
              <span className="rounded-lg bg-[#F8FAFC] px-2 py-1 text-[#64748B]">{status}</span>
              {classItem.subject ? <span className="rounded-lg bg-[#E7F3FF] px-2 py-1 text-[#0E72ED]">{classItem.subject}</span> : null}
            </div>
          </div>
          <div className="flex shrink-0 items-center gap-1.5 sm:gap-2">
            <button
              type="button"
              aria-label={`Class details for ${classItem.title}`}
              onClick={() => onDetails(classItem)}
              className="grid h-9 w-9 place-items-center rounded-xl text-[#64748B] hover:bg-[#F8FAFC]"
            >
              <Info size={18} />
            </button>
            <button
              type="button"
              aria-label={`Copy class link for ${classItem.title}`}
              onClick={copyGuestLink}
              className="grid h-9 w-9 place-items-center rounded-xl text-[#0E72ED] hover:bg-[#E7F3FF]"
            >
              <Copy size={18} />
            </button>
            {action.kind === "join" ? (
              <Link
                href={`/teacher/classroom/?shiftId=${encodeURIComponent(classItem.id)}`}
                className="inline-flex min-h-9 items-center gap-2 rounded-xl bg-[#0E72ED] px-3 text-sm font-bold text-white hover:bg-[#0369F6] sm:px-4"
              >
                <LinkIcon size={16} />
                Join
              </Link>
            ) : (
              <button type="button" disabled className="min-h-9 cursor-not-allowed rounded-xl bg-[#E2E8F0] px-4 text-sm font-bold text-[#64748B]">
                {action.label}
              </button>
            )}
          </div>
        </div>
      </div>
      {shouldLoadPresence(classItem, now) ? <PresenceStrip presence={presence} /> : null}
    </article>
  );
}

function PresenceStrip({ presence }: { presence?: ClassPresence }) {
  const participants = presence?.participants ?? [];
  return (
    <section className="mt-3 rounded-xl border border-[#BBF7D0] bg-[#F0FDF4] p-3">
      <div className="flex items-center gap-2">
        <span className="h-2 w-2 rounded-full bg-[#10B981]" />
        <span className="text-xs font-bold text-[#047857]">Live participants</span>
        <span className="ml-auto text-xs font-bold text-[#047857]">
          {presence ? `${presence.participantCount} in class` : "Loading..."}
        </span>
      </div>
      {presence?.error ? (
        <p className="mt-2 text-xs font-semibold text-[#B45309]">{presence.error}</p>
      ) : participants.length > 0 ? (
        <div className="mt-2 grid gap-2">
          {participants.slice(0, 3).map((participant) => (
            <ParticipantRow key={participant.identity || participant.name} participant={participant} compact />
          ))}
          {participants.length > 3 ? <p className="text-xs font-semibold text-[#64748B]">+{participants.length - 3} more in class</p> : null}
        </div>
      ) : presence ? (
        <p className="mt-2 text-xs italic text-[#64748B]">No one has joined yet</p>
      ) : null}
    </section>
  );
}

function ClassDetailsDialog({ classItem, presence, onClose }: { classItem: TeacherClass; presence?: ClassPresence; onClose: () => void }) {
  const now = new Date();
  const action = classAction(classItem, now);
  const canJoin = action.kind === "join";
  return (
    <div className="fixed inset-0 z-50 grid place-items-end bg-black/35 p-0 sm:place-items-center sm:p-6" role="dialog" aria-modal="true" aria-label="Class details">
      <section className="max-h-[88vh] w-full overflow-hidden rounded-t-3xl bg-white shadow-2xl sm:max-w-xl sm:rounded-2xl">
        <header className="flex items-start gap-3 border-b border-[#EEF2F7] p-5">
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-xl font-black text-[#1E293B]">{classItem.title || "Class Details"}</h2>
            <p className="mt-1 text-sm text-[#64748B]">{formatClassDateTime(classItem)}</p>
          </div>
          <button type="button" aria-label="Close class details" onClick={onClose} className="grid h-10 w-10 place-items-center rounded-xl text-[#64748B] hover:bg-[#F8FAFC]">
            <X size={20} />
          </button>
        </header>
        <div className="max-h-[calc(88vh-88px)] overflow-y-auto p-5">
          <DetailSection title="Teacher" icon={<Users size={18} />}>
            <InfoRow label="Name" value={classItem.teacherName || "Unknown"} />
            {classItem.clockInTime ? <InfoRow label="Clocked in" value={shortTime(classItem.clockInTime)} /> : null}
          </DetailSection>
          <DetailSection title={`Assigned Students (${classItem.studentNames.length})`} icon={<Users size={18} />}>
            {classItem.studentNames.length > 0 ? classItem.studentNames.map((name) => <InfoRow key={name} label="" value={name} />) : <InfoRow label="Students" value="No students assigned" />}
          </DetailSection>
          <DetailSection title={`Currently in Class (${presence?.participantCount ?? 0})`} icon={<VideoIcon size={18} />}>
            {presence?.error ? (
              <p className="rounded-xl bg-[#FEF3C7] px-3 py-2 text-sm font-semibold text-[#92400E]">{presence.error}</p>
            ) : presence?.participants.length ? (
              presence.participants.map((participant) => <ParticipantRow key={participant.identity || participant.name} participant={participant} />)
            ) : presence ? (
              <p className="text-sm italic text-[#64748B]">No one has joined yet</p>
            ) : (
              <p className="text-sm text-[#64748B]">Loading participants...</p>
            )}
          </DetailSection>
          <DetailSection title="Class Information" icon={<Info size={18} />}>
            <InfoRow label="Duration" value={`${classItem.durationHours.toFixed(1)} hours`} />
            <InfoRow label="Subject" value={classItem.subject || "Class"} />
            <InfoRow label="Status" value={statusLabel(classItem, now)} />
            {classItem.notes ? <InfoRow label="Notes" value={classItem.notes} /> : null}
          </DetailSection>
          {canJoin ? (
            <Link href={`/teacher/classroom/?shiftId=${encodeURIComponent(classItem.id)}`} className="mt-5 inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-xl bg-[#10B981] px-4 text-sm font-black text-white hover:bg-[#059669]">
              <VideoIcon size={18} />
              Join Class Now
            </Link>
          ) : null}
        </div>
      </section>
    </div>
  );
}

function DetailSection({ title, icon, children }: { title: string; icon: ReactNode; children: ReactNode }) {
  return (
    <section className="mb-5">
      <h3 className="mb-3 flex items-center gap-2 text-sm font-black text-[#1E293B]">
        <span className="text-[#0E72ED]">{icon}</span>
        {title}
      </h3>
      <div className="grid gap-2">{children}</div>
    </section>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex gap-3 rounded-xl bg-[#F8FAFC] px-3 py-2 text-sm">
      {label ? <span className="w-24 shrink-0 font-bold text-[#64748B]">{label}</span> : null}
      <span className="min-w-0 flex-1 text-[#1E293B]">{value}</span>
    </div>
  );
}

function ParticipantRow({ participant, compact = false }: { participant: ClassPresenceParticipant; compact?: boolean }) {
  return (
    <div className={`flex items-center gap-3 ${compact ? "" : "rounded-xl bg-[#F8FAFC] px-3 py-2"}`}>
      <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-[#DCFCE7] text-[#047857]">
        <Mic size={14} />
      </span>
      <div className="min-w-0 flex-1">
        <p className={`${compact ? "text-xs" : "text-sm"} truncate font-bold text-[#1E293B]`}>{participant.name || participant.identity || "Participant"}</p>
        {participant.role ? <p className="truncate text-xs text-[#64748B]">{participant.role}</p> : null}
      </div>
      {participant.joinedAt ? <span className="rounded-lg bg-white px-2 py-1 text-xs font-bold text-[#64748B]">{durationLabel(new Date().getTime() - participant.joinedAt.getTime())}</span> : null}
    </div>
  );
}

async function loadTeacherClasses(uid: string) {
  const snapshots = await Promise.all([
    getDocs(query(collection(db, "teaching_shifts"), where("teacher_id", "==", uid), limit(250))).catch(() => null),
    getDocs(query(collection(db, "teaching_shifts"), where("teacherId", "==", uid), limit(250))).catch(() => null),
  ]);
  const byId = new Map<string, TeacherClass>();
  snapshots.forEach((snap) => {
    snap?.docs.forEach((entry) => byId.set(entry.id, normalizeClass(entry.id, entry.data() as Record<string, unknown>)));
  });
  return Array.from(byId.values());
}

function normalizeClass(id: string, data: Record<string, unknown>): TeacherClass {
  const subject = stringValue(data.subject_display_name ?? data.subjectDisplayName ?? data.subject);
  const teacherName = stringValue(data.teacher_name ?? data.teacherName) || "Teacher";
  const studentNames = arrayOfStrings(data.student_names ?? data.studentNames);
  const title =
    stringValue(data.custom_name ?? data.customName) ||
    stringValue(data.auto_generated_name ?? data.autoGeneratedName) ||
    subject ||
    [teacherName, studentNames.join(", ")].filter(Boolean).join(" - ") ||
    "Class";
  return {
    id,
    title,
    teacherName,
    studentNames,
    subject,
    start: dateValue(data.shift_start ?? data.shiftStart ?? data.start_time ?? data.startTime),
    end: dateValue(data.shift_end ?? data.shiftEnd ?? data.end_time ?? data.endTime),
    status: stringValue(data.status) || "scheduled",
    category: stringValue(data.category) || "teaching",
    videoProvider: stringValue(data.video_provider ?? data.videoProvider),
    livekitRoomName: stringValue(data.livekit_room_name ?? data.livekitRoomName),
    realtimekitMeetingId: stringValue(data.realtimekit_meeting_id ?? data.realtimekitMeetingId),
    zoomMeetingId: stringValue(data.zoom_meeting_id ?? data.zoomMeetingId),
    isClockedIn: data.is_clocked_in === true || data.isClockedIn === true || Boolean(data.clock_in_time && !data.clock_out_time && stringValue(data.status) === "active"),
    clockInTime: dateValue(data.clock_in_time ?? data.clockInTime),
    durationHours: numberValue(data.shift_duration_hours ?? data.shiftDurationHours) || durationHours(dateValue(data.shift_start ?? data.shiftStart ?? data.start_time ?? data.startTime), dateValue(data.shift_end ?? data.shiftEnd ?? data.end_time ?? data.endTime)),
    notes: stringValue(data.notes),
  };
}

async function loadClassPresence(shiftId: string): Promise<ClassPresence> {
  try {
    const callable = httpsCallable(functions, "getRealtimeKitRoomPresence");
    const result = await callable({ shiftId });
    return normalizePresence(result.data as Record<string, unknown>);
  } catch (error) {
    return { success: false, participantCount: 0, participants: [], error: error instanceof Error ? error.message : "Failed to fetch participants" };
  }
}

function normalizePresence(data: Record<string, unknown>): ClassPresence {
  const rawParticipants = Array.isArray(data.participants) ? data.participants : [];
  const participants = rawParticipants
    .map((item) => normalizeParticipant(item as Record<string, unknown>))
    .filter((item): item is ClassPresenceParticipant => item !== null);
  return {
    success: data.success === true,
    participantCount: numberValue(data.participantCount) || participants.length,
    participants,
    error: stringValue(data.error),
  };
}

function normalizeParticipant(data: Record<string, unknown>): ClassPresenceParticipant | null {
  const identity = stringValue(data.identity);
  const name = stringValue(data.name);
  if (!identity && !name) return null;
  return {
    identity,
    name,
    role: stringValue(data.role),
    joinedAt: dateValue(data.joinedAtIso ?? data.joinedAt),
    isPublisher: data.isPublisher === true,
  };
}

function summaryForUser(user: User, data: UserRecord | null): TeacherSummary {
  const displayName =
    data
      ? [stringValue(data.first_name ?? data["first-name"]), stringValue(data.last_name ?? data["last-name"])].filter(Boolean).join(" ")
      : "";
  const fallback = user.displayName?.trim() || user.email?.replace(/@.*/, "") || "Teacher";
  const name = displayName || fallback;
  return {
    displayName: name,
    firstName: name.split(/\s+/)[0] || "Teacher",
    initials: initialsFromName(name),
  };
}

function compareClasses(a: TeacherClass, b: TeacherClass, now: Date) {
  const aJoinable = canJoinClass(a, now);
  const bJoinable = canJoinClass(b, now);
  if (aJoinable && !bJoinable) return -1;
  if (!aJoinable && bJoinable) return 1;
  const aEnded = a.end ? a.end < now : false;
  const bEnded = b.end ? b.end < now : false;
  if (aEnded && !bEnded) return 1;
  if (!aEnded && bEnded) return -1;
  return (a.start?.getTime() ?? 0) - (b.start?.getTime() ?? 0);
}

type ClassAction =
  | { kind: "join"; label: string }
  | { kind: "wait"; label: string }
  | { kind: "notReady"; label: string }
  | { kind: "ended"; label: string };

function classAction(classItem: TeacherClass, now: Date): ClassAction {
  const hasVideoCall = hasClassVideoCall(classItem);
  if (!classItem.start || !classItem.end) return { kind: hasVideoCall ? "wait" : "notReady", label: hasVideoCall ? "Not available" : "Meeting not ready" };
  const joinWindowStart = addMinutes(classItem.start, -10);
  const joinWindowEnd = addMinutes(classItem.end, 10);
  const withinJoinWindow = joinWindowStart <= now && joinWindowEnd >= now;
  if (hasVideoCall && withinJoinWindow) return { kind: "join", label: "Join" };
  if (!hasVideoCall && withinJoinWindow) return { kind: "notReady", label: "Meeting not ready" };
  if (now < joinWindowStart) return { kind: "wait", label: `Join (${formatTimeUntil(joinWindowStart.getTime() - now.getTime())})` };
  return { kind: "ended", label: "Class Ended" };
}

function canJoinClass(classItem: TeacherClass, now: Date) {
  return classAction(classItem, now).kind === "join";
}

function hasClassVideoCall(classItem: TeacherClass) {
  return classItem.category.toLowerCase() === "teaching" || Boolean(classItem.realtimekitMeetingId || classItem.livekitRoomName || classItem.zoomMeetingId || classItem.videoProvider);
}

function statusLabel(classItem: TeacherClass, now: Date) {
  const normalized = classItem.status.toLowerCase().replace(/[_\s-]+/g, "");
  if (classItem.isClockedIn || normalized === "active") return "In Progress";
  if (["completed", "partiallycompleted", "fullycompleted"].includes(normalized)) return "Completed";
  if (normalized === "cancelled") return "Cancelled";
  if (normalized === "missed") return "Missed";
  if (classItem.start && classItem.start > now) return "Upcoming";
  if (classItem.end && classItem.end < now) return "Past";
  return "Scheduled";
}

function shouldLoadPresence(classItem: TeacherClass, now: Date) {
  return classItem.isClockedIn || classItem.status.toLowerCase() === "active" || canJoinClass(classItem, now);
}

function formatClassTime(classItem: TeacherClass) {
  if (!classItem.start || !classItem.end) return "Time not set";
  return `${shortDate(classItem.start)} ${shortTime(classItem.start)} - ${shortTime(classItem.end)}`;
}

function shortDate(date: Date) {
  const today = new Date();
  const tomorrow = addDays(today, 1);
  if (sameDate(date, today)) return "Today";
  if (sameDate(date, tomorrow)) return "Tomorrow";
  return new Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(date);
}

function shortTime(date: Date) {
  return new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit" }).format(date);
}

function formatClassDateTime(classItem: TeacherClass) {
  if (!classItem.start) return "Time not set";
  const date = new Intl.DateTimeFormat("en", { weekday: "long", month: "long", day: "numeric", year: "numeric" }).format(classItem.start);
  return classItem.end ? `${date} • ${shortTime(classItem.start)}` : `${date} • Time not set`;
}

function sameDate(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function studentNamesDisplay(names: string[]) {
  if (names.length === 0) return "No students";
  if (names.length === 1) return names[0];
  if (names.length <= 2) return names.join(", ");
  return `${names.slice(0, 2).join(", ")} +${names.length - 2}`;
}

function groupClassesByDay(items: TeacherClass[]) {
  const groups = new Map<string, { key: string; label: string; items: TeacherClass[] }>();
  items.forEach((item) => {
    const date = item.start ?? item.end ?? new Date(0);
    const key = `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
    const existing = groups.get(key);
    if (existing) {
      existing.items.push(item);
      return;
    }
    groups.set(key, { key, label: groupLabel(date), items: [item] });
  });
  return Array.from(groups.values());
}

function groupLabel(date: Date) {
  const today = new Date();
  const tomorrow = addDays(today, 1);
  if (sameDate(date, today)) return "Today";
  if (sameDate(date, tomorrow)) return "Tomorrow";
  return new Intl.DateTimeFormat("en", { weekday: "short", month: "short", day: "numeric" }).format(date);
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

function numberValue(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function durationHours(start: Date | null, end: Date | null) {
  if (!start || !end) return 0;
  return Math.max(0, (end.getTime() - start.getTime()) / 3600000);
}

function initialsFromName(name: string) {
  const parts = name.split(/\s+/).filter(Boolean);
  return (parts[0]?.[0] ?? "T").concat(parts[1]?.[0] ?? parts[0]?.[1] ?? "E").toUpperCase();
}

function addDays(date: Date, days: number) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function addMinutes(date: Date, minutes: number) {
  const next = new Date(date);
  next.setMinutes(next.getMinutes() + minutes);
  return next;
}

function formatTimeUntil(durationMs: number) {
  const totalMinutes = Math.max(1, Math.ceil(durationMs / 60000));
  if (totalMinutes < 60) return `${totalMinutes}m`;
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  return minutes === 0 ? `${hours}h` : `${hours}h ${minutes}m`;
}

function durationLabel(durationMs: number) {
  const totalMinutes = Math.max(0, Math.floor(durationMs / 60000));
  if (totalMinutes < 1) return "now";
  if (totalMinutes < 60) return `${totalMinutes}m`;
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  return minutes === 0 ? `${hours}h` : `${hours}h ${minutes}m`;
}

function buildGuestJoinLink(shiftId: string) {
  const params = new URLSearchParams({ guestShift: shiftId });
  const origin = typeof window === "undefined" ? "" : window.location.origin;
  return `${origin}/classroom/join/?${params.toString()}`;
}
