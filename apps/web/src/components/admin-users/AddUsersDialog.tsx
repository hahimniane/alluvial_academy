"use client";

import { useMemo, useRef, useState } from "react";
import type { ParentChoice, UserRow } from "@/lib/adminUsers";
import {
  MAX_ROWS,
  USER_TYPES,
  createLabel,
  emptyRow,
  existingChildOf,
  existingPeople,
  isStaffType,
  isMinorRow,
  kioskCodeFits,
  loginNote,
  makeKioskCode,
  outcomeSummary,
  predictStudentCode,
  repeatedEmails,
  rowCounts,
  rowProblems,
  takenKioskCodes,
  takenStudentCodes,
  type DraftRow,
  type NewUserType,
  type RowErrors,
  type RowOutcome,
} from "@/lib/addUsers";
import { createPeople } from "@/lib/addUsersData";
import { toE164 } from "@/lib/phoneNumbers";
import { buildDuplicateIndex, findDuplicates } from "@/lib/userDuplicates";
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

const signatureOf = (rows: readonly DraftRow[]) =>
  JSON.stringify(rows.map((r) => [r.type, r.firstName.trim(), r.lastName.trim(), r.email.trim().toLowerCase(), toE164(r.countryIso, r.phone), r.adult, r.parentId]));

/** Keeps the kiosk code while it still fits the row's initials and type; makes a new one when it no longer does. */
function withKiosk(r: DraftRow): DraftRow {
  if (r.type === "student") return r.kioskCode ? { ...r, kioskCode: "" } : r;
  if (kioskCodeFits(r.kioskCode, r.firstName, r.lastName, r.type)) return r;
  return { ...r, kioskCode: makeKioskCode(r.firstName, r.lastName, r.type) };
}

/**
 * Add users (U-060…U-105): one card per person, any mix of admins, teachers,
 * students and parents, created with one press.
 */
export function AddUsersDialog({
  rows,
  parents,
  hidden,
  onClose,
  onOpenUser,
}: {
  rows: UserRow[];
  /** Active parents, for a minor's parent / guardian. */
  parents: ParentChoice[];
  hidden: boolean;
  onClose: () => void;
  onOpenUser: (id: string) => void;
}) {
  const nextKey = useRef(2);
  const [drafts, setDrafts] = useState<DraftRow[]>(() => [emptyRow(1, "student")]);
  const [errors, setErrors] = useState<Record<number, RowErrors>>({});
  const [banner, setBanner] = useState("");
  const [duplicates, setDuplicates] = useState<DuplicateGroup[] | null>(null);
  const [acknowledged, setAcknowledged] = useState("");
  const [outcomes, setOutcomes] = useState<{ row: DraftRow; outcome: RowOutcome }[] | null>(null);
  const [busy, setBusy] = useState(false);
  const running = useRef(false);

  const dirty = drafts.some(rowCounts) && !outcomes;
  const guard = useDiscardGuard(dirty, onClose);

  const parentsById = useMemo(() => new Map(parents.map((p) => [p.id, p])), [parents]);
  const parentEmail = useMemo(() => new Map(rows.filter((r) => r.parentPick).map((r) => [r.id, r.email.trim() || r.otherEmail.trim()])), [rows]);
  const dupIndex = useMemo(() => buildDuplicateIndex(existingPeople(rows)), [rows]);

  /** Student ID the server will give each student row, in row order (earlier rows take codes first). */
  const previews = useMemo(() => {
    const taken = takenStudentCodes(rows);
    const out = new Map<number, { code: string; existingCode: string | null }>();
    for (const r of drafts) {
      if (r.type !== "student" || !r.firstName.trim() || !r.lastName.trim()) continue;
      const existing = r.parentId ? existingChildOf([r.parentId], r.firstName, r.lastName, rows) : null;
      if (existing) {
        out.set(r.key, { code: "", existingCode: existing.storedStudentCode });
        continue;
      }
      const code = predictStudentCode(r.firstName, r.lastName, taken);
      if (code) taken.add(code);
      out.set(r.key, { code, existingCode: null });
    }
    return out;
  }, [drafts, rows]);

  const patch = (key: number, change: Partial<DraftRow>) => {
    setDrafts((list) =>
      list.map((r) => {
        if (r.key !== key) return r;
        let next = { ...r, ...change };
        if (change.type && change.type !== r.type) next = { ...next, adult: false, parentId: null };
        return withKiosk(next);
      }),
    );
    setErrors((e) => {
      if (!e[key]) return e;
      const copy = { ...e };
      delete copy[key];
      return copy;
    });
    setBanner("");
    setDuplicates(null);
  };

  const addRow = () => {
    if (drafts.length >= MAX_ROWS) return;
    const last = drafts[drafts.length - 1];
    setDrafts((list) => [...list, emptyRow(nextKey.current++, last?.type ?? "student", last?.countryIso ?? "US")]);
    setDuplicates(null);
  };

  const removeRow = (key: number) => {
    setDrafts((list) => list.filter((r) => r.key !== key));
    setDuplicates(null);
    setBanner("");
  };

  const counted = drafts.filter(rowCounts);

  const submit = async () => {
    if (running.current) return;
    setBanner("");
    if (counted.length === 0) {
      setBanner("Fill in at least one person to create.");
      return;
    }
    const nextErrors: Record<number, RowErrors> = {};
    counted.forEach((r) => {
      const e = rowProblems(r);
      if (Object.keys(e).length) nextErrors[r.key] = e;
    });
    for (const [i, first] of repeatedEmails(counted)) {
      const r = counted[i];
      nextErrors[r.key] = { ...nextErrors[r.key], email: `Same email as Person ${drafts.indexOf(counted[first]) + 1}. Each account needs its own.` };
    }
    if (Object.keys(nextErrors).length) {
      setErrors(nextErrors);
      const people = drafts.flatMap((r, i) => (nextErrors[r.key] ? [i + 1] : []));
      setBanner(`Check ${people.length === 1 ? `Person ${people[0]}` : `Persons ${people.join(", ")}`}: some details are missing or wrong.`);
      return;
    }

    // Kiosk codes: unique among everyone already here and within this save.
    const taken = takenKioskCodes(rows);
    const ready = counted.map((r) => {
      if (r.type === "student") return r;
      let code = r.kioskCode || makeKioskCode(r.firstName, r.lastName, r.type);
      for (let i = 0; taken.has(code) && i < 20; i += 1) code = makeKioskCode(r.firstName, r.lastName, r.type);
      taken.add(code);
      return code === r.kioskCode ? r : { ...r, kioskCode: code };
    });

    const signature = signatureOf(ready);
    if (signature !== acknowledged) {
      const groups: DuplicateGroup[] = [];
      ready.forEach((r) => {
        const matches = findDuplicates({ firstName: r.firstName, lastName: r.lastName, email: r.email, phoneE164: toE164(r.countryIso, r.phone) }, dupIndex);
        if (matches.length) groups.push({ key: String(r.key), who: `Person ${drafts.findIndex((d) => d.key === r.key) + 1}: ${r.firstName.trim()} ${r.lastName.trim()}`, matches });
      });
      if (groups.length) {
        setDrafts((list) => list.map((d) => ready.find((r) => r.key === d.key) ?? d));
        setDuplicates(groups);
        setAcknowledged(signature);
        return;
      }
    }

    running.current = true;
    setBusy(true);
    setDuplicates(null);
    try {
      const results = await createPeople(ready);
      setOutcomes(ready.map((row, i) => ({ row, outcome: results[i] })));
    } finally {
      running.current = false;
      setBusy(false);
    }
  };

  const retryFailed = () => {
    if (!outcomes) return;
    const failed = outcomes.filter((o) => o.outcome.kind === "failed").map((o) => o.row);
    setDrafts(failed.length ? failed : [emptyRow(nextKey.current++, "student")]);
    setOutcomes(null);
    setAcknowledged("");
    setErrors({});
  };

  if (outcomes) {
    const anyFailed = outcomes.some((o) => o.outcome.kind === "failed");
    return (
      <BigModal
        label="Add users"
        title={outcomeSummary(outcomes.map((o) => o.outcome))}
        hidden={hidden}
        busy={false}
        onClose={onClose}
        footer={
          <>
            {anyFailed ? (
              <button type="button" onClick={retryFailed} className={BTN_SECONDARY}>
                Fix the ones not created
              </button>
            ) : null}
            <button type="button" onClick={onClose} className={BTN_PRIMARY}>
              Done
            </button>
          </>
        }
      >
        <OutcomeList outcomes={outcomes.map((o) => o.outcome)} />
      </BigModal>
    );
  }

  return (
    <BigModal
      label="Add users"
      title="Add users"
      subtitle="Admins, teachers and parents get a welcome email with their login. Students log in with a Student ID; a minor's parent gets the details by email."
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
              {busy ? "Creating…" : duplicates ? "Create anyway" : createLabel(Math.max(1, counted.length))}
            </button>
          </>
        )
      }
    >
      {duplicates ? (
        <DuplicateWarning
          groups={duplicates}
          onOpen={(id) => {
            onOpenUser(id);
          }}
        />
      ) : null}
      {drafts.map((r, i) => (
        <PersonCard
          key={r.key}
          n={i + 1}
          row={r}
          errors={errors[r.key] ?? {}}
          canRemove={drafts.length > 1}
          parents={parents}
          parentHasEmail={r.parentId ? (parentsById.has(r.parentId) ? !!parentEmail.get(r.parentId) : null) : null}
          preview={previews.get(r.key)}
          disabled={busy}
          onPatch={(change) => patch(r.key, change)}
          onRemove={() => removeRow(r.key)}
        />
      ))}
      {drafts.length < MAX_ROWS ? (
        <button
          type="button"
          onClick={addRow}
          disabled={busy}
          className="min-h-12 flex-none rounded-[14px] border-[1.5px] border-dashed border-[#93C5FD] bg-white font-semibold text-[#0369D9] disabled:opacity-60"
        >
          + Add another person
        </button>
      ) : (
        <p className="m-0 text-center text-[13px] text-[#64748B]">You can add up to {MAX_ROWS} people at a time.</p>
      )}
    </BigModal>
  );
}

function PersonCard({
  n,
  row: r,
  errors,
  canRemove,
  parents,
  parentHasEmail,
  preview,
  disabled,
  onPatch,
  onRemove,
}: {
  n: number;
  row: DraftRow;
  errors: RowErrors;
  canRemove: boolean;
  parents: ParentChoice[];
  parentHasEmail: boolean | null;
  preview: { code: string; existingCode: string | null } | undefined;
  disabled: boolean;
  onPatch: (change: Partial<DraftRow>) => void;
  onRemove: () => void;
}) {
  const minor = isMinorRow(r);
  return (
    <fieldset disabled={disabled} className="m-0 flex min-w-0 flex-none flex-col gap-3.5 rounded-[14px] border border-[#E2E8F0] bg-white p-4 md:p-[18px]">
      <legend className="sr-only">Person {n}</legend>
      <div className="flex items-center justify-between">
        <span className="font-bold text-[#334155]">Person {n}</span>
        {canRemove ? (
          <button type="button" onClick={onRemove} className="min-h-9 px-3 font-semibold text-[#B91C1C]">
            Remove
          </button>
        ) : null}
      </div>
      <div className="flex flex-wrap gap-1.5" role="group" aria-label={`Person ${n} type`}>
        {USER_TYPES.map(([v, label]) => (
          <button
            key={v}
            type="button"
            aria-pressed={r.type === v}
            onClick={() => onPatch({ type: v as NewUserType })}
            className={`min-h-9 rounded-full border px-3.5 text-[13px] font-semibold ${
              r.type === v ? "border-[#0369D9] bg-[#0369D9] text-white" : "border-[#CBD5E1] bg-white text-[#334155]"
            }`}
          >
            {label}
          </button>
        ))}
      </div>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <TextField label="First name" value={r.firstName} error={errors.firstName} onChange={(v) => onPatch({ firstName: v })} />
        <TextField label="Last name" value={r.lastName} error={errors.lastName} onChange={(v) => onPatch({ lastName: v })} />
        <TextField
          label={minor ? "Email (optional for minors)" : "Email"}
          type="email"
          inputMode="email"
          placeholder="name@example.org"
          value={r.email}
          error={errors.email}
          onChange={(v) => onPatch({ email: v })}
        />
        <PhoneField iso={r.countryIso} value={r.phone} error={errors.phone} onIso={(iso) => onPatch({ countryIso: iso })} onChange={(v) => onPatch({ phone: v })} />
      </div>
      {isStaffType(r.type) ? (
        <div className="max-w-[220px]">
          <TextField label="Hourly rate ($, optional)" inputMode="decimal" placeholder="e.g. 4.00" value={r.hourlyRate} error={errors.hourlyRate} onChange={(v) => onPatch({ hourlyRate: v })} />
        </div>
      ) : null}
      {r.type === "student" ? (
        <>
          <div className="flex flex-wrap items-start gap-4">
            <Segmented
              label="Student type"
              value={r.adult ? "adult" : "minor"}
              options={[
                ["minor", "Minor"],
                ["adult", "Adult"],
              ]}
              onChange={(v) => onPatch({ adult: v === "adult", parentId: v === "adult" ? null : r.parentId })}
            />
            {minor ? <ParentField parents={parents} selectedId={r.parentId} error={errors.parent} onPick={(id) => onPatch({ parentId: id })} /> : null}
          </div>
          {errors.studentId ? <span className="text-xs font-semibold text-[#B91C1C]">{errors.studentId}</span> : null}
          {preview ? <LoginPreview code={preview.code} existingCode={preview.existingCode} note={loginNote(r, parentHasEmail)} /> : null}
        </>
      ) : null}
      {r.type !== "student" && r.kioskCode ? (
        <div className="text-xs text-[#64748B]">
          Kiosk code <span className="font-mono font-semibold text-[#334155]">{r.kioskCode}</span> · made automatically
        </div>
      ) : null}
    </fieldset>
  );
}
