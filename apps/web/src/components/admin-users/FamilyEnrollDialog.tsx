"use client";

import { useMemo, useRef, useState } from "react";
import { auth } from "@/lib/firebase";
import type { ParentChoice, UserRow } from "@/lib/adminUsers";
import {
  emptyRow,
  existingChildOf,
  existingPeople,
  loginNote,
  makeKioskCode,
  outcomeLine,
  predictStudentCode,
  rowProblems,
  takenKioskCodes,
  takenStudentCodes,
  type DraftRow,
  type RowErrors,
  type RowOutcome,
} from "@/lib/addUsers";
import { createOne } from "@/lib/addUsersData";
import { toE164 } from "@/lib/phoneNumbers";
import { buildDuplicateIndex, findDuplicates, normalizeEmail } from "@/lib/userDuplicates";
import { loadAdminProfile, loadStaff, loadStudents, loadSubjects, type StaffMember, type StudentOption, type SubjectOption } from "@/lib/shifts";
import { ShiftEditorDialog } from "@/components/ShiftEditorDialog";
import {
  BTN_PRIMARY,
  BTN_SECONDARY,
  BigModal,
  DuplicateWarning,
  LoginPreview,
  OutcomeList,
  ParentField,
  PhoneField,
  Segmented,
  TextField,
  useDiscardGuard,
  type DuplicateGroup,
} from "./AddParts";

type ParentMode = "new" | "existing" | "none";

type Editor = {
  staff: StaffMember[];
  students: StudentOption[];
  subjects: SubjectOption[];
  adminName: string;
  adminTimezone: string;
};

const signatureOf = (...rows: (DraftRow | null)[]) =>
  JSON.stringify(rows.map((r) => (r ? [r.firstName.trim(), r.lastName.trim(), normalizeEmail(r.email), toE164(r.countryIso, r.phone), r.adult, r.parentId] : null)));

/**
 * Enroll a family in one go (F6): the student, their parent (new or already
 * here) and the link, then optionally their first class through the same
 * class editor the schedule uses.
 *
 * Order: a new parent is created first, then the student with that parent as
 * guardian, so the server links both sides and emails the parent the child's
 * login. A class can only be added once the student's account exists. If one
 * step fails, the steps already done are shown and kept: trying again never
 * creates the parent twice, and the server returns a child the parent already
 * has instead of making a second account.
 */
export function FamilyEnrollDialog({
  rows,
  parents,
  hidden,
  onClose,
  onOpenUser,
}: {
  rows: UserRow[];
  parents: ParentChoice[];
  hidden: boolean;
  onClose: () => void;
  onOpenUser: (id: string) => void;
}) {
  const [student, setStudent] = useState<DraftRow>(() => emptyRow(1, "student"));
  const [parent, setParent] = useState<DraftRow>(() => emptyRow(2, "parent"));
  const [mode, setMode] = useState<ParentMode>("new");
  const [existingId, setExistingId] = useState<string | null>(null);
  const [errors, setErrors] = useState<{ student: RowErrors; parent: RowErrors }>({ student: {}, parent: {} });
  const [duplicates, setDuplicates] = useState<DuplicateGroup[] | null>(null);
  const [acknowledged, setAcknowledged] = useState("");
  const [banner, setBanner] = useState("");
  const [busy, setBusy] = useState(false);
  const running = useRef(false);

  // What has been done so far; kept across a failed step.
  const [createdParent, setCreatedParent] = useState<{ id: string; outcome: RowOutcome } | null>(null);
  const [studentDone, setStudentDone] = useState<{ id: string; outcome: RowOutcome } | null>(null);
  const [failure, setFailure] = useState<{ outcome: RowOutcome; useExisting: UserRow | null } | null>(null);
  const [editor, setEditor] = useState<Editor | null>(null);
  const [classMessage, setClassMessage] = useState<string | null>(null);
  const [finished, setFinished] = useState(false);

  const dirty = !studentDone && !!(student.firstName || student.lastName || parent.firstName || parent.email || existingId);
  const guard = useDiscardGuard(dirty || (!!createdParent && !studentDone), onClose);

  const index = useMemo(() => buildDuplicateIndex(existingPeople(rows)), [rows]);
  const parentMode: ParentMode = student.adult ? mode : mode === "none" ? "new" : mode;
  const guardianId = createdParent?.id ?? (parentMode === "existing" ? existingId : null);
  const parentLocked = !!createdParent;

  const preview = useMemo(() => {
    if (!student.firstName.trim() || !student.lastName.trim()) return null;
    const existing = guardianId ? existingChildOf([guardianId], student.firstName, student.lastName, rows) : null;
    if (existing) return { code: "", existingCode: existing.storedStudentCode };
    return { code: predictStudentCode(student.firstName, student.lastName, takenStudentCodes(rows)), existingCode: null };
  }, [student.firstName, student.lastName, guardianId, rows]);

  const editStudent = (change: Partial<DraftRow>) => {
    setStudent((s) => ({ ...s, ...change }));
    setErrors((e) => ({ ...e, student: {} }));
    setDuplicates(null);
    setBanner("");
  };
  const editParent = (change: Partial<DraftRow>) => {
    setParent((p) => ({ ...p, ...change }));
    setErrors((e) => ({ ...e, parent: {} }));
    setDuplicates(null);
    setBanner("");
  };

  const studentRow = (): DraftRow => ({
    ...student,
    // A minor's own email is not asked for here: it would usually be the parent's, and lookups by email would then find the child.
    email: student.adult ? student.email : "",
    parentId: guardianId ?? (parentMode === "new" ? "pending-new-parent" : null),
  });

  const run = async (fn: () => Promise<void>) => {
    if (running.current) return;
    running.current = true;
    setBusy(true);
    try {
      await fn();
    } finally {
      running.current = false;
      setBusy(false);
    }
  };

  const submit = () =>
    run(async () => {
      setBanner("");
      setFailure(null);
      const sRow = studentRow();
      const sErr = rowProblems(sRow);
      if (parentMode === "existing" && !existingId) sErr.parent = "Pick the parent.";
      const needNewParent = parentMode === "new" && !parentLocked;
      const pRow: DraftRow | null = needNewParent ? { ...parent, kioskCode: parent.kioskCode || makeKioskCode(parent.firstName, parent.lastName, "parent") } : null;
      const pErr = pRow ? rowProblems(pRow) : {};
      if (Object.keys(sErr).length || Object.keys(pErr).length) {
        setErrors({ student: sErr, parent: pErr });
        setBanner("Some details are missing or wrong.");
        return;
      }
      if (pRow) {
        const taken = takenKioskCodes(rows);
        for (let i = 0; taken.has(pRow.kioskCode) && i < 20; i += 1) pRow.kioskCode = makeKioskCode(pRow.firstName, pRow.lastName, "parent");
      }

      const signature = signatureOf(sRow, pRow);
      if (signature !== acknowledged) {
        const groups: DuplicateGroup[] = [];
        const check = (r: DraftRow, who: string) => {
          const matches = findDuplicates({ firstName: r.firstName, lastName: r.lastName, email: r.email, phoneE164: toE164(r.countryIso, r.phone) }, index);
          if (matches.length) groups.push({ key: who, who, matches });
        };
        if (!studentDone) check(sRow, `Student: ${sRow.firstName.trim()} ${sRow.lastName.trim()}`);
        if (pRow) check(pRow, `Parent: ${pRow.firstName.trim()} ${pRow.lastName.trim()}`);
        if (groups.length) {
          setDuplicates(groups);
          setAcknowledged(signature);
          return;
        }
      }
      setDuplicates(null);

      // 1. The new parent, once.
      let parentId = guardianId;
      if (pRow) {
        const outcome = await createOne(pRow);
        if (outcome.kind !== "created") {
          const email = normalizeEmail(pRow.email);
          const holder = rows.find((r) => r.parentPick && r.isActive && (normalizeEmail(r.email) === email || normalizeEmail(r.otherEmail) === email)) ?? null;
          setFailure({ outcome, useExisting: holder });
          setAcknowledged("");
          return;
        }
        setCreatedParent({ id: outcome.userId, outcome });
        parentId = outcome.userId;
      }

      // 2. The student, with the parent as guardian (the server links both sides).
      const outcome = await createOne({ ...sRow, parentId: parentId ?? null });
      if (outcome.kind !== "student" || !outcome.userId) {
        setFailure({ outcome, useExisting: null });
        setAcknowledged("");
        return;
      }
      setStudentDone({ id: outcome.userId, outcome });
    });

  const openClassEditor = () =>
    run(async () => {
      setBanner("");
      const user = auth.currentUser;
      if (!user || !studentDone) return;
      try {
        const [profile, staff, students, subjects] = await Promise.all([loadAdminProfile(user), loadStaff(), loadStudents(), loadSubjects()]);
        if (!students.some((s) => s.id === studentDone.id)) {
          setBanner("The new student is not in the class list yet. Try again in a moment.");
          return;
        }
        setEditor({ staff, students, subjects, adminName: profile.name, adminTimezone: profile.timezone });
      } catch {
        setBanner("The class editor could not be opened. Try again.");
      }
    });

  const parentChosen = parentMode === "existing" && existingId ? parents.find((p) => p.id === existingId) : undefined;
  const parentHasEmail = createdParent ? true : parentChosen ? !!parentChosen.email : parentMode === "new" ? true : null;

  // ── Done / class step ──
  if (studentDone) {
    const lines: RowOutcome[] = [...(createdParent ? [createdParent.outcome] : []), studentDone.outcome];
    const studentName = `${student.firstName.trim()} ${student.lastName.trim()}`;
    return (
      <>
        <BigModal
          label="Enroll a family"
          title={finished || classMessage ? "Family enrolled" : "Add a class?"}
          hidden={hidden || !!editor}
          busy={busy}
          onClose={onClose}
          footer={
            finished || classMessage ? (
              <button type="button" onClick={onClose} className={BTN_PRIMARY}>
                Done
              </button>
            ) : (
              <>
                {banner ? (
                  <span role="alert" className="mr-auto text-[13px] font-semibold text-[#B91C1C]">
                    {banner}
                  </span>
                ) : null}
                <button type="button" onClick={() => setFinished(true)} disabled={busy} className={BTN_SECONDARY}>
                  Skip for now
                </button>
                <button type="button" onClick={() => void openClassEditor()} disabled={busy} className={BTN_PRIMARY}>
                  {busy ? "Opening…" : "Add a class"}
                </button>
              </>
            )
          }
        >
          <OutcomeList outcomes={lines} />
          {classMessage ? (
            <p className="m-0 rounded-[10px] border border-[#BBF7D0] bg-[#F0FDF4] px-3 py-2.5 text-[13px] font-semibold text-[#166534]">{classMessage}</p>
          ) : finished ? (
            <p className="m-0 text-[13px] text-[#475569]">No class yet. Add one later from Shifts.</p>
          ) : (
            <p className="m-0 text-[#475569]">
              Last step: book {studentName}&apos;s class with a teacher and a subject, in the same editor as the schedule.
            </p>
          )}
        </BigModal>
        {editor && auth.currentUser ? (
          <ShiftEditorDialog
            mode="create"
            shift={null}
            prefill={{ staffId: null, date: null, studentIds: [studentDone.id] }}
            staff={editor.staff}
            students={editor.students}
            subjects={editor.subjects}
            admin={auth.currentUser}
            adminName={editor.adminName}
            adminTimezone={editor.adminTimezone}
            onClose={() => setEditor(null)}
            onSaved={(message) => {
              setEditor(null);
              setClassMessage(message);
            }}
          />
        ) : null}
      </>
    );
  }

  const createLabelText = failure ? (createdParent ? "Try the student again" : "Try again") : duplicates ? "Create anyway" : "Enroll";

  return (
    <BigModal
      label="Enroll a family"
      title="Enroll a family"
      subtitle="The student and their parent in one go, linked to each other. You can add their class at the end."
      hidden={hidden}
      busy={busy}
      onClose={guard.request}
      footer={
        guard.bar ?? (
          <>
            {banner ? (
              <span role="alert" className="mr-auto text-[13px] font-semibold text-[#B91C1C]">
                {banner}
              </span>
            ) : null}
            <button type="button" onClick={guard.request} disabled={busy} className={BTN_SECONDARY}>
              Cancel
            </button>
            <button type="button" onClick={() => void submit()} disabled={busy} className={BTN_PRIMARY}>
              {busy ? "Creating…" : createLabelText}
            </button>
          </>
        )
      }
    >
      {createdParent || failure ? (
        <div className="flex flex-col gap-2">
          {createdParent ? <OutcomeList outcomes={[createdParent.outcome]} /> : null}
          {failure ? (
            <div role="alert" className="flex flex-col gap-2 rounded-[10px] border border-[#FECACA] bg-[#FEF2F2] px-3 py-2.5 text-[13px] font-semibold text-[#B91C1C]">
              <span>
                {createdParent ? "The student was not created. " : "Nothing was created. "}
                {outcomeLine(failure.outcome).replace(/^.*?: not created\. /, "")}
              </span>
              {failure.useExisting ? (
                <button
                  type="button"
                  onClick={() => {
                    setMode("existing");
                    setExistingId(failure.useExisting!.id);
                    setFailure(null);
                  }}
                  className="w-max min-h-9 rounded-lg border border-[#FCA5A5] bg-white px-3 text-[#B91C1C]"
                >
                  Use {failure.useExisting.parentPick?.name || "the parent"}, who has this email
                </button>
              ) : null}
            </div>
          ) : null}
        </div>
      ) : null}
      {duplicates ? <DuplicateWarning groups={duplicates} onOpen={onOpenUser} /> : null}

      <fieldset disabled={busy} className="m-0 flex min-w-0 flex-col gap-3.5 rounded-[14px] border border-[#E2E8F0] bg-white p-4 md:p-[18px]">
        <legend className="float-left mb-1 font-bold text-[#334155]">Student</legend>
        <div className="clear-both grid grid-cols-1 gap-3 sm:grid-cols-2">
          <TextField label="First name" value={student.firstName} error={errors.student.firstName} onChange={(v) => editStudent({ firstName: v })} />
          <TextField label="Last name" value={student.lastName} error={errors.student.lastName} onChange={(v) => editStudent({ lastName: v })} />
        </div>
        <Segmented
          label="Student type"
          value={student.adult ? "adult" : "minor"}
          options={[
            ["minor", "Minor"],
            ["adult", "Adult"],
          ]}
          onChange={(v) => editStudent({ adult: v === "adult" })}
        />
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          {student.adult ? (
            <TextField label="Email" type="email" inputMode="email" placeholder="name@example.org" value={student.email} error={errors.student.email} onChange={(v) => editStudent({ email: v })} />
          ) : null}
          <PhoneField iso={student.countryIso} value={student.phone} error={errors.student.phone} onIso={(iso) => editStudent({ countryIso: iso })} onChange={(v) => editStudent({ phone: v })} />
        </div>
        {errors.student.studentId ? <span className="text-xs font-semibold text-[#B91C1C]">{errors.student.studentId}</span> : null}
        {preview ? <LoginPreview code={preview.code} existingCode={preview.existingCode} note={loginNote({ ...student, parentId: guardianId ?? (parentMode === "new" ? "new" : null) }, parentHasEmail)} /> : null}
      </fieldset>

      <fieldset disabled={busy || parentLocked} className="m-0 flex min-w-0 flex-col gap-3.5 rounded-[14px] border border-[#E2E8F0] bg-white p-4 md:p-[18px]">
        <legend className="float-left mb-1 font-bold text-[#334155]">Parent / guardian</legend>
        {parentLocked ? (
          <p className="clear-both m-0 text-[13px] text-[#475569]">The parent above is created; the student will be linked to them.</p>
        ) : (
          <>
            <div className="clear-both">
              <Segmented<ParentMode>
                label="Parent"
                value={parentMode}
                options={student.adult ? [["new", "New parent"], ["existing", "Already here"], ["none", "No parent"]] : [["new", "New parent"], ["existing", "Already here"]]}
                onChange={(v) => {
                  setMode(v);
                  setErrors((e) => ({ ...e, parent: {}, student: { ...e.student, parent: undefined } }));
                  setDuplicates(null);
                }}
              />
            </div>
            {parentMode === "existing" ? (
              <ParentField parents={parents} selectedId={existingId} error={errors.student.parent} onPick={(id) => setExistingId(id)} />
            ) : parentMode === "new" ? (
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <TextField label="First name" value={parent.firstName} error={errors.parent.firstName} onChange={(v) => editParent({ firstName: v })} />
                <TextField label="Last name" value={parent.lastName} error={errors.parent.lastName} onChange={(v) => editParent({ lastName: v })} />
                <TextField label="Email" type="email" inputMode="email" placeholder="name@example.org" value={parent.email} error={errors.parent.email} onChange={(v) => editParent({ email: v })} />
                <PhoneField iso={parent.countryIso} value={parent.phone} error={errors.parent.phone} onIso={(iso) => editParent({ countryIso: iso })} onChange={(v) => editParent({ phone: v })} />
                <p className="m-0 text-[13px] text-[#64748B] sm:col-span-2">They get a welcome email with their own login, and the student&apos;s login.</p>
              </div>
            ) : (
              <p className="m-0 text-[13px] text-[#64748B]">The adult student is enrolled on their own.</p>
            )}
          </>
        )}
      </fieldset>
    </BigModal>
  );
}
