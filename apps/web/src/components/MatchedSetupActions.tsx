"use client";

import { useEffect, useRef, useState } from "react";
import { CalendarPlus, Check, KeyRound, Link2, Lock, UserPlus } from "lucide-react";
import { ActionButton } from "@/components/ActionButton";
import { ShiftEditorDialog } from "@/components/ShiftEditorDialog";
import { auth } from "@/lib/firebase";
import {
  createStudentAccount,
  inviteParentForEnrollment,
  lookupParentByEmail,
  type ExistingParent,
} from "@/lib/enrollmentSetup";
import { parentInviteProblem, type ParentInvite } from "@/lib/enrollmentSetupRules";
import { setupSteps, type SetupStepStatus } from "@/lib/applicantTriage";
import {
  loadAdminProfile,
  loadStaff,
  loadStudents,
  loadSubjects,
  type StaffMember,
  type StudentOption,
  type SubjectOption,
} from "@/lib/shifts";
import { shiftPrefillFor, type MatchSchedule } from "@/lib/matchSchedule";

/**
 * The three steps that move a match forward, shown as the sequence they are:
 * a login for the student, their classes on the calendar, then the parent.
 * Only the current step can be pressed; the ones after it sit greyed out and
 * open the moment their turn comes.
 *
 * "Finalize schedule" opens the same editor the Shifts screen uses, already
 * filled in from the match — the matched teacher, this student, the subject,
 * the teacher's first-ranked slot, weekly on the days the family gave — so
 * the admin confirms rather than re-enters. Everything that editor enforces
 * (teacher conflicts, Zoom capacity, the series creation) applies unchanged.
 *
 * The parent step looks the application's email up first. A parent who is
 * already in the system is not invited again: one press links the child and
 * emails them that the account is ready under their existing login. Only an
 * email nobody has opens the invite form.
 */
export type Classmate = { enrollmentId: string; studentName: string; studentUserId: string };

const errorText = (err: unknown, fallback: string) => (err instanceof Error ? err.message : fallback);

export function MatchedSetupActions({
  enrollmentId,
  studentName,
  classmates,
  studentUserId,
  parentLinked,
  hasSchedule,
  defaultParentEmail,
  defaultParentName,
  defaultParentPhone,
  schedule,
  onChanged,
  onMessage,
}: {
  enrollmentId: string;
  studentName: string;
  /** Every child in an exclusive family class, or null for a single student. */
  classmates: Classmate[] | null;
  studentUserId: string;
  parentLinked: boolean;
  hasSchedule: boolean;
  defaultParentEmail: string;
  defaultParentName: string;
  defaultParentPhone: string;
  schedule: MatchSchedule;
  onChanged: () => void;
  onMessage: (text: string) => void;
}) {
  const [inviting, setInviting] = useState(false);
  const [inviteNote, setInviteNote] = useState("");
  const [editor, setEditor] = useState<{
    studentIds: string[];
    staff: StaffMember[];
    students: StudentOption[];
    subjects: SubjectOption[];
    adminName: string;
    adminTimezone: string;
  } | null>(null);
  // undefined: not looked up yet; null: no usable answer (no email, or the lookup failed).
  const [existingParent, setExistingParent] = useState<ExistingParent | null | undefined>(undefined);
  const [linking, setLinking] = useState(false);
  const lookup = useRef<Promise<ExistingParent | null> | null>(null);

  const steps = setupSteps({ hasAccount: studentUserId.trim().length > 0, hasSchedule, hasParent: parentLinked });
  const statusOf = (id: "account" | "schedule" | "parent"): SetupStepStatus =>
    steps.find((step) => step.id === id)?.status ?? "locked";

  const family = classmates
    ? {
        enrollmentIds: classmates.map((mate) => mate.enrollmentId),
        studentUids: classmates.map((mate) => mate.studentUserId).filter(Boolean),
      }
    : undefined;

  /** One lookup per card, shared by the button label and the auto-advance. */
  const findExistingParent = (): Promise<ExistingParent | null> => {
    if (!lookup.current) {
      lookup.current = lookupParentByEmail(defaultParentEmail)
        .then((parent) => (parent.found ? parent : null))
        .catch(() => null);
      void lookup.current.then((parent) => setExistingParent(parent));
    }
    return lookup.current;
  };

  useEffect(() => {
    if (statusOf("parent") === "active" && existingParent === undefined) void findExistingParent();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [studentUserId, hasSchedule, parentLinked]);

  const linkExistingParent = async (parent: ExistingParent) => {
    const words = defaultParentName.trim().split(/\s+/).filter(Boolean);
    const invite: ParentInvite = {
      email: defaultParentEmail,
      firstName: parent.firstName || words[0] || "",
      lastName: parent.lastName || words.slice(1).join(" "),
      phone: defaultParentPhone,
      countryCode: "",
    };
    setLinking(true);
    try {
      const result = await inviteParentForEnrollment(enrollmentId, studentUserId, invite, family);
      const who = parent.name || defaultParentEmail;
      onMessage(`${who} already had an account, so no invite was sent. ${result.message}`);
      onChanged();
    } catch (err) {
      onMessage(errorText(err, "Could not link the parent."));
    } finally {
      setLinking(false);
    }
  };

  /** The parent step, the moment it becomes current: link silently or ask for the invite. */
  const advanceToParent = async () => {
    const parent = await findExistingParent();
    if (parent?.canLink) {
      await linkExistingParent(parent);
      return;
    }
    setInviteNote(
      parent && !parent.canLink
        ? `${defaultParentEmail} belongs to a ${parent.role || "staff"} account and cannot be made a parent. Enter the parent's own email.`
        : "",
    );
    setInviting(true);
  };

  const openScheduleEditor = async (studentIds: string[]) => {
    const user = auth.currentUser;
    if (!user) throw new Error("You must be signed in as an admin.");
    const [profile, staff, students, subjects] = await Promise.all([
      loadAdminProfile(user),
      loadStaff(),
      loadStudents(),
      loadSubjects(),
    ]);
    if (!staff.some((member) => member.id === schedule.teacherId)) {
      throw new Error(`${schedule.teacherName || "The matched teacher"} is not an active teacher, so a shift cannot be booked for them.`);
    }
    const missing = studentIds.filter((id) => !students.some((student) => student.id === id));
    if (studentIds.length === 0 || missing.length > 0) {
      throw new Error("The student accounts were created but are not listed yet. Try again in a moment.");
    }
    setEditor({ studentIds, staff, students, subjects, adminName: profile.name, adminTimezone: profile.timezone });
  };

  const user = auth.currentUser;
  const accountLabel = classmates ? "Create accounts" : "Create account";
  const parentStatus = statusOf("parent");
  const parentPending = parentStatus === "active" && existingParent === undefined;
  const parentIsExisting = parentStatus === "active" && !!existingParent?.canLink;

  return (
    <div className="mb-3">
      <ol className="flex flex-wrap items-stretch gap-2" aria-label="Setup steps">
        <Step
          number={1}
          status={statusOf("account")}
          doneLabel={classmates ? "Accounts created" : "Account created"}
        >
          <ActionButton
            label={accountLabel}
            busyLabel="Creating…"
            icon={<KeyRound size={16} />}
            onAction={async () => {
              // An exclusive family class needs a login per child, but they are
              // taught together, so one shift follows for all of them.
              // The same child can appear on several rows (one per program), and
              // the server hands back the existing account for a child the parent
              // already has — so ids are de-duplicated before the schedule is made.
              try {
                const targets = classmates ?? [{ enrollmentId, studentName, studentUserId }];
                const ids = new Set<string>();
                let created = 0;
                let reused = 0;
                for (const target of targets) {
                  if (target.studentUserId) { ids.add(target.studentUserId); continue; }
                  const account = await createStudentAccount(target.enrollmentId);
                  ids.add(account.studentId);
                  if (account.existing) reused += 1; else created += 1;
                }
                const parts = [
                  created ? `${created} account${created === 1 ? "" : "s"} created` : "",
                  reused ? `${reused} existing account${reused === 1 ? "" : "s"} linked` : "",
                ].filter(Boolean);
                onMessage(`${parts.join(", ") || "Accounts ready"} for ${studentName}. Now confirm the schedule.`);
                onChanged();
                await openScheduleEditor([...ids]);
              } catch (err) {
                onMessage(errorText(err, "Could not create the account."));
              }
            }}
          />
        </Step>

        <Step number={2} status={statusOf("schedule")} doneLabel="Schedule confirmed" lockedHint="After the account">
          <ActionButton
            label="Finalize schedule"
            busyLabel="Preparing…"
            icon={<CalendarPlus size={16} />}
            onAction={async () => {
              try {
                await openScheduleEditor(
                  (classmates ?? [{ enrollmentId, studentName, studentUserId }])
                    .map((c) => c.studentUserId)
                    .filter(Boolean),
                );
              } catch (err) {
                onMessage(errorText(err, "Could not open the schedule."));
              }
            }}
          />
        </Step>

        <Step number={3} status={parentStatus} doneLabel="Parent linked" lockedHint="After the schedule">
          <ActionButton
            label={parentPending ? "Checking parent…" : parentIsExisting ? "Link parent & notify" : "Invite parent"}
            busyLabel={parentIsExisting ? "Linking…" : "Opening…"}
            icon={parentIsExisting ? <Link2 size={16} /> : <UserPlus size={16} />}
            disabled={parentPending || linking}
            title={parentIsExisting ? `${existingParent?.name || defaultParentEmail} already has an account` : undefined}
            onAction={advanceToParent}
          />
        </Step>
      </ol>

      {editor && user ? (
        <ShiftEditorDialog
          mode="create"
          shift={null}
          prefill={shiftPrefillFor(schedule, editor.studentIds, editor.subjects.map((s) => ({ id: s.id, name: s.name })))}
          staff={editor.staff}
          students={editor.students}
          subjects={editor.subjects}
          admin={user}
          adminName={editor.adminName}
          adminTimezone={schedule.familyTimeZone || editor.adminTimezone}
          onClose={() => setEditor(null)}
          onSaved={(savedMessage) => {
            setEditor(null);
            onMessage(parentLinked ? savedMessage : `${savedMessage} Next, the parent.`);
            onChanged();
            // The parent is the last piece of the setup and its turn has come:
            // link a parent who is already in the system, or open the invite.
            if (!parentLinked) void advanceToParent();
          }}
        />
      ) : null}

      {inviting ? (
        <InviteParentDialog
          studentName={studentName}
          note={inviteNote}
          initial={{
            email: existingParent && !existingParent.canLink ? "" : defaultParentEmail,
            firstName: defaultParentName.split(/\s+/)[0] ?? "",
            lastName: defaultParentName.split(/\s+/).slice(1).join(" "),
            phone: defaultParentPhone,
            countryCode: "",
          }}
          onSend={async (invite) => {
            const result = await inviteParentForEnrollment(enrollmentId, studentUserId, invite, family);
            onMessage(
              result.message ||
                (result.status === "linked"
                  ? "Parent account linked."
                  : "Invite sent. The parent can set a password from the email."),
            );
            setInviting(false);
            onChanged();
          }}
          onClose={() => setInviting(false)}
        />
      ) : null}
    </div>
  );
}

/**
 * One step of the sequence. Done steps read as a quiet green fact, the active
 * step carries the only pressable control, and locked steps say what has to
 * happen before they open.
 */
function Step({
  number,
  status,
  doneLabel,
  lockedHint,
  children,
}: {
  number: number;
  status: SetupStepStatus;
  doneLabel: string;
  lockedHint?: string;
  children: React.ReactNode;
}) {
  const badge =
    status === "done"
      ? "bg-[#059669] text-white"
      : status === "active"
        ? "bg-[#0386FF] text-white"
        : "bg-[#E2E8F0] text-[#94A3B8]";
  return (
    <li
      className={`flex min-w-[180px] flex-1 items-center gap-2 rounded-xl border px-2.5 py-2 ${
        status === "done"
          ? "border-[#A7F3D0] bg-[#ECFDF5]"
          : status === "active"
            ? "border-[#BFDBFE] bg-white"
            : "border-[#E2E8F0] bg-[#F8FAFC]"
      }`}
      aria-current={status === "active" ? "step" : undefined}
    >
      <span className={`grid h-6 w-6 shrink-0 place-items-center rounded-full text-[11px] font-black ${badge}`} aria-hidden="true">
        {status === "done" ? <Check size={13} /> : number}
      </span>
      {status === "done" ? (
        <span className="text-xs font-semibold text-[#065F46]">{doneLabel}</span>
      ) : status === "active" ? (
        <div className="min-w-0 flex-1 [&>button]:w-full [&>button]:px-3 [&>button]:py-2 [&>button]:text-xs">{children}</div>
      ) : (
        <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#94A3B8]">
          <Lock size={12} />
          {lockedHint ?? "Locked"}
        </span>
      )}
    </li>
  );
}

function InviteParentDialog({
  studentName,
  note,
  initial,
  onSend,
  onClose,
}: {
  studentName: string;
  note: string;
  initial: ParentInvite;
  onSend: (invite: ParentInvite) => Promise<void>;
  onClose: () => void;
}) {
  const [invite, setInvite] = useState<ParentInvite>(initial);
  const [error, setError] = useState("");
  const problem = parentInviteProblem(invite);
  const set = (patch: Partial<ParentInvite>) => setInvite((current) => ({ ...current, ...patch }));

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true" aria-label="Invite parent">
      <div className="w-full max-w-[480px] rounded-[20px] bg-white p-5 shadow-[0_24px_60px_rgba(0,0,0,0.32)]">
        <h2 className="text-lg font-bold text-[#111827]">Invite parent</h2>
        <p className="mt-1 text-[13px] text-[#64748B]">
          Creates a parent account linked to {studentName}. The parent gets an email to set a password.
        </p>
        {note ? (
          <p className="mt-3 rounded-lg bg-[#FEF3C7] px-3 py-2 text-xs font-semibold text-[#92400E]">{note}</p>
        ) : null}
        <div className="mt-4 grid gap-3">
          <Field label="Parent email" value={invite.email} onChange={(v) => set({ email: v })} type="email" />
          <div className="grid grid-cols-2 gap-3">
            <Field label="First name" value={invite.firstName} onChange={(v) => set({ firstName: v })} />
            <Field label="Last name" value={invite.lastName} onChange={(v) => set({ lastName: v })} />
          </div>
          <div className="grid grid-cols-[1fr_2fr] gap-3">
            <Field label="Country code" value={invite.countryCode} onChange={(v) => set({ countryCode: v })} placeholder="+1" />
            <Field label="Phone" value={invite.phone} onChange={(v) => set({ phone: v })} />
          </div>
        </div>
        {error ? <p role="alert" className="mt-3 text-xs font-semibold text-[#DC2626]">{error}</p> : null}
        <div className="mt-5 flex items-center justify-end gap-2">
          <button type="button" onClick={onClose} className="px-3 py-2 text-sm font-semibold text-[#475569]">
            Cancel
          </button>
          <ActionButton
            label="Send invite"
            busyLabel="Sending…"
            icon={<UserPlus size={16} />}
            onAction={async () => {
              if (problem) {
                setError(problem);
                return;
              }
              setError("");
              try {
                await onSend(invite);
              } catch (err) {
                setError(err instanceof Error ? err.message : "Could not send the invite.");
              }
            }}
          />
        </div>
      </div>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
  type = "text",
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: string;
  placeholder?: string;
}) {
  return (
    <label className="grid gap-1">
      <span className="text-[11px] font-semibold text-[#1E293B]">{label}</span>
      <input
        type={type}
        value={value}
        placeholder={placeholder}
        onChange={(event) => onChange(event.target.value)}
        className="h-10 rounded-lg border border-[#CBD5E1] px-3 text-sm text-[#111827] outline-none focus:border-[#3B82F6]"
      />
    </label>
  );
}
