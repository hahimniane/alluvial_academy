"use client";

import { useState } from "react";
import { CalendarPlus, KeyRound, UserPlus } from "lucide-react";
import { ActionButton } from "@/components/ActionButton";
import { ShiftEditorDialog } from "@/components/ShiftEditorDialog";
import { auth } from "@/lib/firebase";
import { createStudentAccount, inviteParentForEnrollment } from "@/lib/enrollmentSetup";
import { parentInviteProblem, type ParentInvite } from "@/lib/enrollmentSetupRules";
import { shiftSubjectSlugForTrack } from "@/lib/enrollmentDomain";
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
 * The actions that move a match forward, in the order the setup needs them:
 * a login for the student, their classes on the calendar, a parent linked.
 *
 * "Finalize schedule" opens the same editor the Shifts screen uses, already
 * filled in from the match — the matched teacher, this student, the subject,
 * the teacher's first-ranked slot, weekly on the days the family gave — so
 * the admin confirms rather than re-enters. Everything that editor enforces
 * (teacher conflicts, Zoom capacity, the series creation) applies unchanged.
 * When the student has no account yet, one is created first; when no parent
 * is linked afterwards, the invite opens next.
 */
export function MatchedSetupActions({
  enrollmentId,
  studentName,
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
  const [editor, setEditor] = useState<{
    studentId: string;
    staff: StaffMember[];
    students: StudentOption[];
    subjects: SubjectOption[];
    adminName: string;
    adminTimezone: string;
  } | null>(null);

  const openScheduleEditor = async (studentId: string) => {
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
    if (!students.some((student) => student.id === studentId)) {
      throw new Error("The student's account was created but is not listed yet. Try again in a moment.");
    }
    setEditor({ studentId, staff, students, subjects, adminName: profile.name, adminTimezone: profile.timezone });
  };

  const user = auth.currentUser;

  return (
    <div className="mb-3 flex flex-wrap items-center gap-2">
      {!studentUserId ? (
        <ActionButton
          label="Create account & schedule"
          busyLabel="Creating account…"
          icon={<KeyRound size={16} />}
          onAction={async () => {
            const created = await createStudentAccount(enrollmentId);
            onMessage(
              created.studentCode
                ? `Account created for ${studentName}. Student ID ${created.studentCode}. Now confirm the schedule.`
                : `Account created for ${studentName}. Now confirm the schedule.`,
            );
            onChanged();
            await openScheduleEditor(created.studentId);
          }}
        />
      ) : !hasSchedule ? (
        <ActionButton
          label="Finalize schedule"
          busyLabel="Preparing…"
          icon={<CalendarPlus size={16} />}
          onAction={() => openScheduleEditor(studentUserId)}
        />
      ) : null}

      {studentUserId && !parentLinked ? (
        <button
          type="button"
          onClick={() => setInviting(true)}
          className="inline-flex min-h-9 items-center gap-2 rounded-lg border border-black/10 px-3 text-xs font-semibold text-[#1D4ED8] hover:bg-[#EFF6FF]"
        >
          <UserPlus size={16} />
          Invite parent
        </button>
      ) : null}

      {editor && user ? (
        <ShiftEditorDialog
          mode="create"
          shift={null}
          prefill={shiftPrefillFor(schedule, editor.studentId, editor.subjects.map((s) => ({ id: s.id, name: s.name })))}
          staff={editor.staff}
          students={editor.students}
          subjects={editor.subjects}
          admin={user}
          adminName={editor.adminName}
          adminTimezone={schedule.familyTimeZone || editor.adminTimezone}
          onClose={() => setEditor(null)}
          onSaved={(savedMessage) => {
            setEditor(null);
            onMessage(parentLinked ? savedMessage : `${savedMessage} Next, invite the parent.`);
            onChanged();
            // The parent is the last piece of the setup; open it straight away
            // rather than leaving the admin to find the button.
            if (!parentLinked) setInviting(true);
          }}
        />
      ) : null}

      {inviting ? (
        <InviteParentDialog
          studentName={studentName}
          initial={{
            email: defaultParentEmail,
            firstName: defaultParentName.split(/\s+/)[0] ?? "",
            lastName: defaultParentName.split(/\s+/).slice(1).join(" "),
            phone: defaultParentPhone,
            countryCode: "",
          }}
          onSend={async (invite) => {
            const result = await inviteParentForEnrollment(enrollmentId, studentUserId, invite);
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

function InviteParentDialog({
  studentName,
  initial,
  onSend,
  onClose,
}: {
  studentName: string;
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
          Links a parent account to {studentName}. If the email is new, the parent gets an email to set a password.
        </p>
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
