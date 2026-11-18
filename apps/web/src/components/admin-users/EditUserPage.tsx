"use client";

import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { ChevronLeft, Lock } from "lucide-react";
import { displayNameOf, isStudentType, type ListRow, type UserRow } from "@/lib/adminUsers";
import { decisionActor, decisionLabel, failed, fallbackDecisions, mergeDecisions, type Decision } from "@/lib/adminUsersActions";
import { listenDecisions } from "@/lib/adminUsersActionsData";
import {
  FIELD_LABELS,
  MAIN_ROLES,
  NOTHING_TO_SAVE,
  SAVED_MESSAGE,
  changedFields,
  conflictNotice,
  conflictingFields,
  editProblems,
  editValuesOf,
  formValues,
  formatDayTime,
  hasSecondary,
  mainRoleOf,
  pickMainRole,
  reviewRoleChange,
  roleLabelOf,
  secondaryChoices,
  touch,
  withSecondary,
  type Draft,
  type EditField,
  type EditValues,
  type MainRole,
} from "@/lib/editUser";
import { saveUserEdits } from "@/lib/editUserData";
import { isParentAccount } from "@/lib/guardians";
import { GuardianSection } from "./GuardianSections";
import { BTN_SECONDARY, DialogShell, useOnce } from "./UserDialogs";
import type { Say } from "./UserPanel";
import { Avatar, Pill, TypePill } from "./ui";

const INPUT = "min-h-11 w-full rounded-[10px] border bg-white px-3 text-sm text-[#0F172A]";
const BTN = "min-h-11 rounded-[10px] px-4 font-semibold disabled:cursor-not-allowed disabled:opacity-60";

const ROLE_TONE: Record<MainRole, { border: string; bg: string; fg: string }> = {
  student: { border: "#059669", bg: "#ECFDF5", fg: "#047857" },
  teacher: { border: "#2563EB", bg: "#EFF6FF", fg: "#1D4ED8" },
  parent: { border: "#7C3AED", bg: "#F5F3FF", fg: "#6D28D9" },
  admin: { border: "#D97706", bg: "#FFFBEB", fg: "#B45309" },
};

function Card({ title, help, children }: { title?: string; help?: string; children: ReactNode }) {
  return (
    <section className="flex flex-col gap-3.5 rounded-[14px] border border-[#E2E8F0] bg-white p-5">
      {title ? (
        <div className="flex flex-col gap-1">
          <h2 className="m-0 text-base font-bold">{title}</h2>
          {help ? <span className="text-[#64748B]">{help}</span> : null}
        </div>
      ) : null}
      {children}
    </section>
  );
}

function Field({
  label,
  hint,
  value,
  onChange,
  error,
  placeholder,
  inputMode,
  changed,
}: {
  label: string;
  hint?: string;
  value: string;
  onChange: (v: string) => void;
  error?: string;
  placeholder?: string;
  inputMode?: "tel" | "text";
  changed: boolean;
}) {
  return (
    <label className="flex min-w-0 flex-col gap-1.5">
      <span className="text-[13px] font-semibold text-[#334155]">
        {label}
        {hint ? <span className="font-normal text-[#64748B]"> ({hint})</span> : null}
        {changed ? <span className="ml-1.5 text-xs font-semibold text-[#C2410C]">Changed</span> : null}
      </span>
      <input
        value={value}
        placeholder={placeholder}
        inputMode={inputMode}
        autoComplete="off"
        aria-invalid={!!error}
        onChange={(e) => onChange(e.target.value)}
        className={`${INPUT} ${error ? "border-[#DC2626]" : changed ? "border-[#FDBA74]" : "border-[#CBD5E1]"}`}
      />
      {error ? <span className="text-xs font-semibold text-[#B91C1C]">{error}</span> : null}
    </label>
  );
}

function Toggle({ label, help, on, onFlip }: { label: string; help: string; on: boolean; onFlip: () => void }) {
  return (
    <div className="flex min-h-[52px] items-center justify-between gap-3">
      <span className="flex flex-col">
        <span className="font-semibold">{label}</span>
        <span className="text-xs text-[#64748B]">{help}</span>
      </span>
      <button
        type="button"
        role="switch"
        aria-checked={on}
        aria-label={label}
        onClick={onFlip}
        className={`flex h-7 w-12 flex-none rounded-full p-[3px] transition-colors ${on ? "bg-[#059669]" : "bg-[#CBD5E1]"}`}
      >
        <span className={`h-[22px] w-[22px] rounded-full bg-white shadow-[0_1px_2px_rgba(0,0,0,0.2)] transition-transform ${on ? "translate-x-5" : ""}`} />
      </button>
    </div>
  );
}

function DecisionHistory({ row, byId }: { row: UserRow; byId: Map<string, UserRow> }) {
  const [recorded, setRecorded] = useState<Decision[] | null>(null);
  const [loadFailed, setLoadFailed] = useState(false);
  useEffect(() => {
    setRecorded(null);
    setLoadFailed(false);
    return listenDecisions(row.id, 20, setRecorded, () => {
      setRecorded([]);
      setLoadFailed(true);
    });
  }, [row.id]);
  const events = useMemo(() => mergeDecisions(recorded ?? [], fallbackDecisions(row), 20), [recorded, row]);
  return (
    <Card title="Decision history">
      {recorded === null ? (
        <div className="text-[13px] text-[#64748B]">Loading…</div>
      ) : events.length === 0 ? (
        <div className="text-[13px] text-[#64748B]">{loadFailed ? "Decisions could not be loaded." : "No decisions recorded yet."}</div>
      ) : (
        <ol className="m-0 flex list-none flex-col gap-2.5 p-0">
          {events.map((e) => {
            const known = byId.get(e.actorUid);
            const actor = decisionActor(e.actorName || (known ? displayNameOf(known) : ""), e.actorUid, e.actorKind);
            const by = actor === "System" ? "System automation" : actor ? `By ${actor}` : "";
            return (
              <li key={e.id} className="flex flex-col gap-0.5">
                <span className="font-semibold">{decisionLabel(e.action)}</span>
                <span className="text-xs text-[#64748B]">{[by, e.at ? formatDayTime(e.at) : ""].filter(Boolean).join(" · ")}</span>
              </li>
            );
          })}
        </ol>
      )}
    </Card>
  );
}

/**
 * Edit user (S7): one person's details, addressed by their document id.
 * Only what the admin changes is saved; guardians are linked and unlinked
 * at once, on the server.
 */
export function EditUserPage({
  row,
  rows,
  byId,
  viewerUid,
  say,
  onBack,
  onSaved,
  onOpenPerson,
  onDirtyChange,
}: {
  row: ListRow;
  rows: readonly UserRow[];
  byId: Map<string, UserRow>;
  viewerUid: string;
  say: Say;
  onBack: () => void;
  onSaved: (id: string) => void;
  onOpenPerson: (id: string) => void;
  onDirtyChange: (dirty: boolean) => void;
}) {
  const live = useMemo(() => editValuesOf(row), [row]);
  const liveRef = useRef(live);
  liveRef.current = live;
  const [draft, setDraft] = useState<Draft>({});
  const [error, setError] = useState("");
  const [review, setReview] = useState<string[] | null>(null);
  const { busy, run } = useOnce();

  const values = formValues(live, draft);
  const changed = changedFields(live, draft);
  const conflicts = conflictingFields(live, draft);
  const problems = editProblems(values, changed);
  const dirty = changed.length > 0;
  const name = displayNameOf(row);
  const pickedMain = mainRoleOf(values.userType);

  useEffect(() => {
    onDirtyChange(dirty);
  }, [dirty, onDirtyChange]);
  useEffect(() => () => onDirtyChange(false), [onDirtyChange]);

  const set = <F extends EditField>(field: F, value: EditValues[F]) => {
    setError("");
    setDraft((d) => touch(d, liveRef.current, field, value));
  };
  const setRole = (role: MainRole) => {
    setError("");
    setDraft((d) => {
      const picked = pickMainRole(formValues(liveRef.current, d), role);
      return touch(touch(d, liveRef.current, "userType", picked.userType), liveRef.current, "secondaryRoles", picked.secondaryRoles);
    });
  };

  const save = () =>
    run(async () => {
      setError("");
      const only: Draft = {};
      for (const f of changed) (only as Record<string, unknown>)[f] = draft[f];
      try {
        const result = await saveUserEdits(row.id, only);
        onDirtyChange(false);
        setDraft({});
        if (result.saved) {
          say(SAVED_MESSAGE);
          onSaved(row.id);
        } else {
          say(NOTHING_TO_SAVE);
        }
      } catch (e) {
        setError(failed("Changes could not be saved", e));
      }
    });

  const requestSave = () => {
    if (!dirty || busy || Object.keys(problems).length > 0) return;
    if (changed.includes("userType")) {
      const r = reviewRoleChange(row, live.userType, values.userType, viewerUid);
      if (r.refusal) {
        setError(r.refusal);
        return;
      }
      setReview(r.lines);
      return;
    }
    save();
  };

  const canSave = dirty && !busy && Object.keys(problems).length === 0;
  const aiTutorShown = pickedMain === "student" || pickedMain === "teacher";
  const choices = secondaryChoices(values.userType);

  return (
    <div className="users-area min-h-screen bg-[#F8FAFC] font-sans text-sm text-[#0F172A]">
      <div className="sticky top-0 z-20 border-b border-[#E2E8F0] bg-white">
        <div className="mx-auto flex max-w-[1200px] flex-wrap items-center justify-between gap-3 px-4 py-3 md:px-8 md:py-4">
          <div className="flex min-w-0 items-center gap-3">
            <button type="button" onClick={onBack} aria-label="Back to users" className="grid h-10 w-10 flex-none place-items-center rounded-[10px] bg-[#F1F5F9] text-[#334155] hover:bg-[#E2E8F0]">
              <ChevronLeft size={18} aria-hidden="true" />
            </button>
            <div className="flex min-w-0 flex-col">
              <span className="text-xs text-[#64748B]">Users</span>
              <h1 className="m-0 truncate text-lg font-bold md:text-xl">Edit {name}</h1>
            </div>
            {dirty ? <span className="flex-none rounded-full bg-[#FFF7ED] px-2.5 py-[3px] text-xs font-semibold text-[#C2410C]">Unsaved changes</span> : null}
          </div>
          <div className="flex gap-2.5">
            <button type="button" onClick={onBack} disabled={busy} className={BTN_SECONDARY}>
              Cancel
            </button>
            <button type="button" onClick={requestSave} disabled={!canSave} className={`${BTN} bg-[#0369D9] px-5 text-white hover:bg-[#024E96]`}>
              {busy ? "Saving…" : "Save changes"}
            </button>
          </div>
        </div>
      </div>

      <div className="mx-auto flex max-w-[1200px] flex-wrap items-start gap-6 px-4 pb-12 pt-5 md:px-8 md:pt-6">
        <div className="flex min-w-0 flex-[999_1_560px] flex-col gap-4">
          {conflicts.length > 0 ? (
            <div role="status" className="rounded-xl border border-[#FDE68A] bg-[#FFFBEB] px-4 py-3 font-semibold text-[#92400E]">
              {conflictNotice(conflicts)}
            </div>
          ) : null}
          {error ? (
            <div role="alert" className="rounded-xl border border-[#FECACA] bg-[#FEF2F2] px-4 py-3 font-semibold text-[#B91C1C]">
              {error}
            </div>
          ) : null}

          <Card title="Name">
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <Field label="First name" value={values.firstName} onChange={(v) => set("firstName", v)} error={problems.firstName} changed={changed.includes("firstName")} />
              <Field label="Last name" value={values.lastName} onChange={(v) => set("lastName", v)} error={problems.lastName} changed={changed.includes("lastName")} />
            </div>
            <Field
              label="Job title"
              hint="optional · shown in chat for staff"
              placeholder="e.g. Finance Leader"
              value={values.title}
              onChange={(v) => set("title", v)}
              changed={changed.includes("title")}
            />
          </Card>

          <Card title="Contact">
            <div className="flex flex-col gap-1.5">
              <span className="text-[13px] font-semibold text-[#334155]">Email</span>
              <div className="flex min-h-11 items-center gap-2 break-all rounded-[10px] bg-[#F1F5F9] px-3 py-2 text-[#475569]">
                <Lock size={15} aria-hidden="true" className="flex-none" />
                {row.email || "No email"}
              </div>
              <span className="text-xs text-[#64748B]">Used to log in, so it can&apos;t be changed here.</span>
            </div>
            <div className="grid grid-cols-[110px_minmax(0,1fr)] gap-3 sm:grid-cols-[140px_minmax(0,1fr)]">
              <Field
                label="Country code"
                placeholder="+1"
                inputMode="tel"
                value={values.countryCode}
                onChange={(v) => set("countryCode", v)}
                error={problems.countryCode}
                changed={changed.includes("countryCode")}
              />
              <Field label="Phone" placeholder="646 555 0100" inputMode="tel" value={values.phone} onChange={(v) => set("phone", v)} error={problems.phone} changed={changed.includes("phone")} />
            </div>
          </Card>

          <Card title="Main role" help="Decides which dashboard they see first.">
            {!mainRoleOf(live.userType) ? (
              <div className="rounded-[10px] bg-[#F8FAFC] px-3 py-2 text-[13px] text-[#475569]">
                Saved as <span className="font-semibold">{roleLabelOf(live.userType)}</span>.{" "}
                {pickedMain ? `Saving makes them ${roleLabelOf(values.userType)}.` : "Pick a card only to change it."}
              </div>
            ) : null}
            <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4" role="group" aria-label="Main role">
              {MAIN_ROLES.map((r) => {
                const on = pickedMain === r.value;
                const tone = ROLE_TONE[r.value];
                return (
                  <button
                    key={r.value}
                    type="button"
                    aria-pressed={on}
                    onClick={() => setRole(r.value)}
                    className="min-h-[72px] rounded-xl font-semibold"
                    style={on ? { border: `2px solid ${tone.border}`, background: tone.bg, color: tone.fg, fontWeight: 700 } : { border: "1px solid #E2E8F0", background: "#FFFFFF", color: "#334155" }}
                  >
                    {r.label}
                  </button>
                );
              })}
            </div>
            <div className="mt-1.5 flex flex-col gap-1">
              <h3 className="m-0 text-sm font-bold">
                Also works as
                {changed.includes("secondaryRoles") ? <span className="ml-1.5 text-xs font-semibold text-[#C2410C]">Changed</span> : null}
              </h3>
              <span className="text-[#64748B]">They can switch between these from their dashboard.</span>
            </div>
            <div className="flex flex-wrap gap-2">
              {choices.map((role) => {
                const label = MAIN_ROLES.find((r) => r.value === role)!.label;
                const admin = role === "admin";
                return (
                  <label
                    key={role}
                    className={`flex min-h-11 items-center gap-2 rounded-[10px] px-3.5 ${admin ? "border border-dashed border-[#F59E0B] text-[#92400E]" : "border border-[#E2E8F0]"}`}
                  >
                    <input
                      type="checkbox"
                      aria-label={`Also works as ${label}`}
                      className="h-[18px] w-[18px]"
                      checked={hasSecondary(values.secondaryRoles, role)}
                      onChange={(e) => set("secondaryRoles", withSecondary(values.secondaryRoles, role, e.target.checked))}
                    />
                    {label}
                  </label>
                );
              })}
            </div>
            {choices.includes("admin") ? (
              <span className="text-xs text-[#92400E]">
                Admin here opens the admin screens from their dashboard but gives no admin permissions, so their changes there are refused. For admin access, make
                Admin the main role or use Make admin-teacher.
              </span>
            ) : null}
          </Card>

          {isStudentType(row) ? <GuardianSection mode="student" row={row} rows={rows} byId={byId} say={say} onOpen={onOpenPerson} /> : null}
          {isParentAccount(row) ? <GuardianSection mode="parent" row={row} rows={rows} byId={byId} say={say} onOpen={onOpenPerson} /> : null}
        </div>

        <div className="flex w-full min-w-0 flex-[1_1_320px] flex-col gap-4 md:max-w-[400px]">
          <section className="flex items-center gap-3.5 rounded-[14px] border border-[#E2E8F0] bg-white p-5">
            <Avatar row={row} size={56} />
            <div className="flex min-w-0 flex-col gap-1.5">
              <span className={`break-words text-base font-bold ${row.isActive ? "" : "text-[#64748B] line-through"}`}>{name}</span>
              <span className="flex flex-wrap gap-1.5">
                <TypePill row={row} />
                {row.isAdminTeacher ? <Pill bg="#FFF7ED" fg="#C2410C">Admin-teacher</Pill> : null}
                {row.isActive ? <Pill bg="#ECFDF5" fg="#047857">Active</Pill> : <Pill bg="#FEF2F2" fg="#B91C1C">Archived</Pill>}
              </span>
            </div>
          </section>

          <Card title="Access">
            <div className="-mt-1 flex flex-col">
              {aiTutorShown ? (
                <Toggle label="AI Tutor" help="Can use the AI Tutor" on={values.aiTutorEnabled} onFlip={() => set("aiTutorEnabled", !values.aiTutorEnabled)} />
              ) : null}
              <Toggle label="Tontine" help="Savings circles in the phone app" on={values.tontineEnabled} onFlip={() => set("tontineEnabled", !values.tontineEnabled)} />
            </div>
            {changed.includes("aiTutorEnabled") || changed.includes("tontineEnabled") ? (
              <span className="text-xs font-semibold text-[#C2410C]">Saved with Save changes.</span>
            ) : null}
          </Card>

          <Card title="Codes">
            <div className="flex flex-col gap-1.5">
              {isStudentType(row) ? (
                <div className="flex justify-between gap-3">
                  <span className="text-[#64748B]">Student ID</span>
                  <span className="break-all text-right font-mono">{row.storedStudentCode || "Not set"}</span>
                </div>
              ) : null}
              <div className="flex justify-between gap-3">
                <span className="text-[#64748B]">Kiosk code</span>
                <span className="break-all text-right font-mono">{row.storedKioskCode || "Not assigned"}</span>
              </div>
            </div>
            <span className="text-xs text-[#64748B]">Codes are set once and can&apos;t be changed.</span>
          </Card>

          <DecisionHistory row={row} byId={byId} />
        </div>
      </div>

      {review ? (
        <DialogShell label="Change main role" title={`Change ${name}'s main role?`} busy={busy} onClose={() => setReview(null)}>
          <ul className="m-0 flex flex-col gap-1 pl-[18px] text-[#475569]">
            {review.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
          {changed.length > 1 ? (
            <p className="m-0 text-[13px] text-[#64748B]">
              Also saved: {changed.filter((f) => f !== "userType").map((f) => FIELD_LABELS[f]).join(", ")}.
            </p>
          ) : null}
          <div className="flex flex-wrap justify-end gap-2.5">
            <button type="button" className={BTN_SECONDARY} disabled={busy} onClick={() => setReview(null)}>
              Keep editing
            </button>
            <button
              type="button"
              data-autofocus
              disabled={busy}
              className={`${BTN} bg-[#0369D9] text-white hover:bg-[#024E96]`}
              onClick={() => {
                setReview(null);
                save();
              }}
            >
              Save changes
            </button>
          </div>
        </DialogShell>
      ) : null}
    </div>
  );
}
