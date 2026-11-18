"use client";

import { useMemo, useState } from "react";
import { Link2, Search } from "lucide-react";
import { displayNameOf, type UserRow } from "@/lib/adminUsers";
import { failed } from "@/lib/adminUsersActions";
import { linkGuardian, unlinkGuardian } from "@/lib/editUserData";
import {
  MINOR_BLOCKED,
  UNLINK_REASON_MAX,
  UNLINK_STUDENT_SUCCESS,
  UNLINK_SUCCESS,
  adultOverrideBody,
  guardianCandidates,
  guardianLine,
  guardiansOfStudent,
  isLastGuardianOfMinor,
  isParentAccount,
  linkBody,
  linkMessage,
  sideNote,
  studentCandidates,
  studentLine,
  studentsOfParent,
  unlinkBody,
  type LinkCandidate,
  type LinkedPerson,
} from "@/lib/guardians";
import { BTN_SECONDARY, DialogShell, useOnce } from "./UserDialogs";
import type { Say } from "./UserPanel";

const BTN = "min-h-11 rounded-[10px] px-4 font-semibold disabled:cursor-not-allowed disabled:opacity-60";
const SHOWN_MAX = 60;

type Mode = "student" | "parent";

type Dialog =
  | null
  | { kind: "unlink"; person: LinkedPerson }
  | { kind: "adult"; person: LinkedPerson; reason: string }
  | { kind: "link" };

/**
 * Linked guardians (on a student) or Linked students (on a parent): the list,
 * Unlink with a reason and the adult override, Fix for a one-sided link, and
 * Link a guardian / Link a student. Every change goes through the server and
 * is in effect at once (it is not part of Save changes).
 */
export function GuardianSection({
  mode,
  row,
  rows,
  byId,
  say,
  onOpen,
}: {
  mode: Mode;
  row: UserRow;
  rows: readonly UserRow[];
  byId: Map<string, UserRow>;
  say: Say;
  onOpen: (id: string) => void;
}) {
  const people = useMemo(
    () => (mode === "student" ? guardiansOfStudent(row, rows, byId) : studentsOfParent(row, rows, byId)),
    [mode, row, rows, byId],
  );
  const [dialog, setDialog] = useState<Dialog>(null);
  const [fixing, setFixing] = useState<string | null>(null);
  const name = displayNameOf(row);
  const pair = (person: LinkedPerson) =>
    mode === "student" ? { studentUid: row.id, parentUid: person.id, student: name, guardian: person.name } : { studentUid: person.id, parentUid: row.id, student: person.name, guardian: name };
  const canLink = mode === "student" || isParentAccount(row);

  const fix = async (person: LinkedPerson) => {
    if (fixing) return;
    setFixing(person.id);
    const p = pair(person);
    try {
      const r = await linkGuardian(p.studentUid, p.parentUid);
      say(linkMessage(r, p.student, p.guardian));
    } catch (e) {
      say(failed("The link could not be fixed", e), "error");
    } finally {
      setFixing(null);
    }
  };

  const title = mode === "student" ? "Linked guardians" : "Linked students";
  const help =
    mode === "student"
      ? "Unlinking removes their access to this student's classes, chat and invoices. Both accounts stay."
      : `Removing one keeps both accounts but ends ${name}'s access to that student's classes, chat and invoices.`;

  return (
    <section aria-label={title} className="flex flex-col gap-3 rounded-[14px] border border-[#E2E8F0] bg-white p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex min-w-0 flex-col gap-1">
          <h2 className="m-0 text-base font-bold">{title}</h2>
          <span className="text-[#64748B]">{help}</span>
        </div>
        {canLink ? (
          <button
            type="button"
            onClick={() => setDialog({ kind: "link" })}
            className="flex min-h-10 flex-none items-center gap-1.5 rounded-[10px] border border-[#BFDBFE] bg-[#EFF6FF] px-3.5 font-semibold text-[#0369D9] hover:bg-[#DBEAFE]"
          >
            <Link2 size={15} aria-hidden="true" />
            {mode === "student" ? "Link a guardian" : "Link a student"}
          </button>
        ) : null}
      </div>
      {people.length === 0 ? (
        <div className="text-[#64748B]">{mode === "student" ? "No guardians are linked to this student yet." : "No students are linked to this parent yet."}</div>
      ) : (
        <ul className="m-0 flex list-none flex-col gap-2 p-0">
          {people.map((person) => {
            const note = sideNote(person.side, mode);
            const sub = person.row ? (mode === "student" ? guardianLine(person.row) : studentLine(person.row)) : "Account not found";
            return (
              <li key={person.id} className="flex flex-wrap items-center gap-3 rounded-xl border border-[#F1F5F9] p-3">
                <span aria-hidden="true" className="grid h-9 w-9 flex-none place-items-center rounded-[10px] bg-[#F5F3FF] font-bold text-[#6D28D9]">
                  {(person.name.trim().charAt(0) || "?").toUpperCase()}
                </span>
                <span className="flex min-w-0 flex-1 flex-col">
                  {person.row ? (
                    <button type="button" onClick={() => onOpen(person.id)} className="self-start text-left font-semibold text-[#0F172A] hover:text-[#0369D9] hover:underline">
                      {person.name}
                      {!person.row.isActive ? <span className="ml-1.5 text-[11px] font-semibold text-[#B91C1C]">Archived</span> : null}
                    </button>
                  ) : (
                    <span className="break-all font-semibold">{person.name}</span>
                  )}
                  {sub ? <span className="break-words text-xs text-[#64748B]">{sub}</span> : null}
                  {note ? <span className="text-xs font-semibold text-[#B45309]">{note}</span> : null}
                </span>
                <span className="flex flex-none gap-1">
                  {person.side !== "both" ? (
                    <button
                      type="button"
                      disabled={!!fixing}
                      onClick={() => fix(person)}
                      className="min-h-10 rounded-[10px] px-3 font-semibold text-[#0369D9] hover:bg-[#EFF6FF] disabled:opacity-60"
                    >
                      {fixing === person.id ? "Fixing…" : "Fix link"}
                    </button>
                  ) : null}
                  <button
                    type="button"
                    disabled={!!fixing}
                    onClick={() => setDialog({ kind: "unlink", person })}
                    className="min-h-10 rounded-[10px] px-3 font-semibold text-[#B91C1C] hover:bg-[#FEF2F2] disabled:opacity-60"
                  >
                    Unlink
                  </button>
                </span>
              </li>
            );
          })}
        </ul>
      )}

      {dialog?.kind === "unlink" ? (
        <UnlinkDialog
          guardian={pair(dialog.person).guardian}
          student={pair(dialog.person).student}
          onClose={() => setDialog(null)}
          onUnlink={async (reason) => {
            const p = pair(dialog.person);
            try {
              await unlinkGuardian({ studentUid: p.studentUid, parentUid: p.parentUid, reason, convertStudentToAdult: false });
              say(mode === "student" ? UNLINK_SUCCESS : UNLINK_STUDENT_SUCCESS);
              setDialog(null);
              return null;
            } catch (e) {
              if (isLastGuardianOfMinor(e)) {
                setDialog({ kind: "adult", person: dialog.person, reason });
                return null;
              }
              return failed("This guardian could not be unlinked", e);
            }
          }}
        />
      ) : null}

      {dialog?.kind === "adult" ? (
        <AdultOverrideDialog
          student={pair(dialog.person).student}
          guardian={pair(dialog.person).guardian}
          onCancel={() => {
            setDialog(null);
            say(MINOR_BLOCKED, "error");
          }}
          onConfirm={async () => {
            const p = pair(dialog.person);
            try {
              await unlinkGuardian({ studentUid: p.studentUid, parentUid: p.parentUid, reason: dialog.reason, convertStudentToAdult: true });
              say(mode === "student" ? UNLINK_SUCCESS : UNLINK_STUDENT_SUCCESS);
              setDialog(null);
              return null;
            } catch (e) {
              return failed("This guardian could not be unlinked", e);
            }
          }}
        />
      ) : null}

      {dialog?.kind === "link" ? (
        <LinkDialog
          mode={mode}
          row={row}
          rows={rows}
          byId={byId}
          onClose={() => setDialog(null)}
          onLink={async (other) => {
            const studentUid = mode === "student" ? row.id : other.row.id;
            const parentUid = mode === "student" ? other.row.id : row.id;
            const student = mode === "student" ? name : other.name;
            const guardian = mode === "student" ? other.name : name;
            try {
              const r = await linkGuardian(studentUid, parentUid);
              say(linkMessage(r, student, guardian));
              setDialog(null);
              return null;
            } catch (e) {
              return failed("Failed to link parent and student", e);
            }
          }}
        />
      ) : null}
    </section>
  );
}

function ErrorLine({ text }: { text: string }) {
  return text ? (
    <p role="alert" className="m-0 rounded-[10px] bg-[#FEF2F2] px-3 py-2 text-[13px] font-semibold text-[#B91C1C]">
      {text}
    </p>
  ) : null;
}

function UnlinkDialog({
  guardian,
  student,
  onClose,
  onUnlink,
}: {
  guardian: string;
  student: string;
  onClose: () => void;
  onUnlink: (reason: string) => Promise<string | null>;
}) {
  const { busy, run } = useOnce();
  const [reason, setReason] = useState("");
  const [error, setError] = useState("");
  return (
    <DialogShell label="Unlink guardian" title={`Unlink ${guardian}?`} busy={busy} onClose={onClose}>
      <p className="m-0 text-[#475569]">{unlinkBody(guardian, student)}</p>
      <label className="flex flex-col gap-1.5">
        <span className="text-[13px] font-semibold text-[#334155]">Reason (optional)</span>
        <textarea
          rows={2}
          value={reason}
          maxLength={UNLINK_REASON_MAX}
          placeholder="e.g. Linked to the wrong family"
          onChange={(e) => setReason(e.target.value)}
          className="resize-y rounded-[10px] border border-[#CBD5E1] px-3 py-2.5 text-sm"
        />
        <span className="self-end text-xs text-[#64748B]">
          {reason.length}/{UNLINK_REASON_MAX}
        </span>
      </label>
      <ErrorLine text={error} />
      <div className="flex flex-wrap justify-end gap-2.5">
        <button type="button" className={BTN_SECONDARY} disabled={busy} onClick={onClose}>
          Cancel
        </button>
        <button
          type="button"
          disabled={busy}
          className={`${BTN} bg-[#B91C1C] text-white`}
          onClick={() =>
            run(async () => {
              setError("");
              const problem = await onUnlink(reason);
              if (problem) setError(problem);
            })
          }
        >
          {busy ? "Unlinking…" : "Unlink"}
        </button>
      </div>
    </DialogShell>
  );
}

function AdultOverrideDialog({
  student,
  guardian,
  onCancel,
  onConfirm,
}: {
  student: string;
  guardian: string;
  onCancel: () => void;
  onConfirm: () => Promise<string | null>;
}) {
  const { busy, run } = useOnce();
  const [error, setError] = useState("");
  return (
    <DialogShell label="Convert student to adult" title="Convert student to adult?" danger busy={busy} onClose={onCancel}>
      <p className="m-0 text-[#475569]">{adultOverrideBody(student, guardian)}</p>
      <ErrorLine text={error} />
      <div className="flex flex-wrap justify-end gap-2.5">
        <button type="button" className={BTN_SECONDARY} disabled={busy} onClick={onCancel}>
          Cancel
        </button>
        <button
          type="button"
          data-autofocus
          disabled={busy}
          className={`${BTN} bg-[#B91C1C] text-white`}
          onClick={() =>
            run(async () => {
              const problem = await onConfirm();
              if (problem) setError(problem);
            })
          }
        >
          {busy ? "Unlinking…" : "Mark adult and unlink"}
        </button>
      </div>
    </DialogShell>
  );
}

function LinkDialog({
  mode,
  row,
  rows,
  byId,
  onClose,
  onLink,
}: {
  mode: Mode;
  row: UserRow;
  rows: readonly UserRow[];
  byId: Map<string, UserRow>;
  onClose: () => void;
  onLink: (other: LinkCandidate) => Promise<string | null>;
}) {
  const { busy, run } = useOnce();
  const [q, setQ] = useState("");
  const [picked, setPicked] = useState<LinkCandidate | null>(null);
  const [error, setError] = useState("");
  const name = displayNameOf(row);
  const candidates = useMemo(
    () => (mode === "student" ? guardianCandidates(row, rows, byId, q) : studentCandidates(row, rows, byId, q)),
    [mode, row, rows, byId, q],
  );
  const existing = useMemo(
    () => (mode === "student" ? guardiansOfStudent(row, rows, byId).filter((g) => g.side === "both").map((g) => g.name) : []),
    [mode, row, rows, byId],
  );
  const shown = candidates.slice(0, SHOWN_MAX);

  if (picked) {
    const guardian = mode === "student" ? picked.name : name;
    const student = mode === "student" ? name : picked.name;
    const others = mode === "student" ? existing : guardiansOfStudent(picked.row, rows, byId).filter((g) => g.side === "both").map((g) => g.name);
    return (
      <DialogShell label="Link guardian" title={`Link ${guardian} to ${student}?`} busy={busy} onClose={onClose}>
        <p className="m-0 text-[#475569]">{linkBody(guardian, student)}</p>
        {others.length > 0 ? (
          <p className="m-0 rounded-[10px] bg-[#F8FAFC] px-3 py-2 text-[13px] text-[#475569]">
            {student} is already linked to {others.join(", ")}. {others.length > 1 ? "They stay" : "That link stays"} as well.
          </p>
        ) : null}
        {picked.partial ? <p className="m-0 text-[13px] font-semibold text-[#B45309]">They are linked on one account only; this writes the other side.</p> : null}
        <ErrorLine text={error} />
        <div className="flex flex-wrap justify-end gap-2.5">
          <button type="button" className={BTN_SECONDARY} disabled={busy} onClick={() => setPicked(null)}>
            Back
          </button>
          <button
            type="button"
            data-autofocus
            disabled={busy}
            className={`${BTN} bg-[#0369D9] text-white hover:bg-[#024E96]`}
            onClick={() =>
              run(async () => {
                setError("");
                const problem = await onLink(picked);
                if (problem) setError(problem);
              })
            }
          >
            {busy ? "Linking…" : "Link"}
          </button>
        </div>
      </DialogShell>
    );
  }

  return (
    <DialogShell label={mode === "student" ? "Link a guardian" : "Link a student"} title={mode === "student" ? `Link a guardian to ${name}` : `Link a student to ${name}`} onClose={onClose}>
      <label className="relative flex items-center">
        <span className="pointer-events-none absolute left-3 flex text-[#64748B]">
          <Search size={16} aria-hidden="true" />
        </span>
        <input
          type="search"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          aria-label={mode === "student" ? "Search parents" : "Search students"}
          placeholder="Search name, email, phone or ID"
          className="min-h-11 w-full rounded-[10px] border border-[#CBD5E1] pl-9 pr-3 text-sm"
        />
      </label>
      <div className="text-xs text-[#64748B]">
        {candidates.length === 1 ? "1 match" : `${candidates.length} matches`}
        {candidates.length > SHOWN_MAX ? ` · showing the first ${SHOWN_MAX}, type to narrow` : ""}
      </div>
      <div className="-mx-1 flex max-h-[50vh] flex-col gap-1.5 overflow-y-auto px-1">
        {shown.length === 0 ? (
          <div className="py-8 text-center text-[#64748B]">{mode === "student" ? "No parents found" : "No students found"}</div>
        ) : (
          shown.map((c) => (
            <button
              key={c.row.id}
              type="button"
              onClick={() => setPicked(c)}
              className="flex min-h-12 w-full items-center gap-2.5 rounded-[10px] border border-[#F1F5F9] p-2 text-left hover:bg-[#F8FAFC]"
            >
              <span aria-hidden="true" className="grid h-[34px] w-[34px] flex-none place-items-center rounded-[10px] bg-[#EDE9FE] font-bold text-[#5B21B6]">
                {(c.name.charAt(0) || "?").toUpperCase()}
              </span>
              <span className="flex min-w-0 flex-1 flex-col">
                <span className="truncate font-semibold">
                  {c.name}
                  {!c.row.isActive ? <span className="ml-1.5 text-[11px] font-semibold text-[#B91C1C]">Archived</span> : null}
                </span>
                <span className="truncate text-xs text-[#64748B]">{c.detail}</span>
                {c.partial ? <span className="text-xs font-semibold text-[#B45309]">Linked on one account only</span> : null}
              </span>
            </button>
          ))
        )}
      </div>
      <div className="flex justify-end">
        <button type="button" className={BTN_SECONDARY} onClick={onClose}>
          Cancel
        </button>
      </div>
    </DialogShell>
  );
}
