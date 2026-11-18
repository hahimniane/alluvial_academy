"use client";

import { useRef, useState } from "react";
import { Printer, X } from "lucide-react";
import { displayNameOf, loginEmailOf, type ListRow } from "@/lib/adminUsers";
import { errorReason } from "@/lib/adminUsersActions";
import { archiveUser, resetStudentPassword, restoreUser, setUserSwitch } from "@/lib/adminUsersActionsData";
import { BULK_LABELS, confirmText, planBulk, resultSummary, runBulk, type BulkKind, type BulkPlan, type BulkResult } from "@/lib/bulkActions";
import type { LoginFacts } from "@/lib/loginDetails";
import { BTN_SECONDARY, DialogShell } from "./UserDialogs";
import { LoginCards } from "./LoginDetails";

const ACTIONS: BulkKind[] = ["archive", "restore", "resetPassword", "aiTutorOn", "aiTutorOff", "export"];

/** The bar under the list while people are selected. Disabled while a run is going. */
export function BulkBar({
  count,
  busy,
  onAction,
  onClear,
}: {
  count: number;
  busy: boolean;
  onAction: (kind: BulkKind) => void;
  onClear: () => void;
}) {
  return (
    <div role="region" aria-label="Selected people" className="fixed inset-x-0 bottom-0 z-[45] border-t border-[#E2E8F0] bg-white/95 px-4 py-3 shadow-[0_-8px_24px_rgba(15,23,42,0.08)] backdrop-blur md:px-8">
      <div className="mx-auto flex max-w-[1440px] flex-wrap items-center gap-2">
        <span className="mr-1 font-semibold" aria-live="polite">
          {count} selected
        </span>
        {ACTIONS.map((kind) => (
          <button
            key={kind}
            type="button"
            disabled={busy}
            onClick={() => onAction(kind)}
            className={`min-h-10 rounded-[10px] border px-3 text-[13px] font-semibold disabled:cursor-not-allowed disabled:opacity-60 ${
              kind === "archive" ? "border-[#FED7AA] bg-[#FFF7ED] text-[#C2410C]" : "border-[#CBD5E1] bg-white text-[#334155] hover:bg-[#F8FAFC]"
            }`}
          >
            {BULK_LABELS[kind]}
          </button>
        ))}
        <button type="button" onClick={onClear} disabled={busy} className="ml-auto flex min-h-10 items-center gap-1 rounded-[10px] px-3 text-[13px] font-semibold text-[#475569] hover:bg-[#F1F5F9] disabled:opacity-60">
          <X size={14} aria-hidden="true" /> Clear
        </button>
      </div>
    </div>
  );
}

type ResetValue = { password: string; studentCode: string };
type Phase =
  | { step: "confirm" }
  | { step: "running"; done: number; total: number }
  | { step: "done"; results: BulkResult<unknown>[]; stopped: boolean };

const CONFIRM_COLOR: Record<BulkKind, string> = {
  archive: "#C2410C",
  restore: "#047857",
  resetPassword: "#0369D9",
  aiTutorOn: "#0369D9",
  aiTutorOff: "#0369D9",
  export: "#0369D9",
};

/**
 * Confirm → run (one person at a time, Stop between people) → results with a
 * line for every person. New passwords appear only here, and are gone once
 * the dialog closes.
 */
export function BulkDialog({
  kind,
  selected,
  viewerUid,
  onRunningChange,
  onExport,
  onClose,
}: {
  kind: BulkKind;
  selected: ListRow[];
  viewerUid: string;
  onRunningChange: (running: boolean) => void;
  onExport: (rows: ListRow[]) => void;
  onClose: (changed: boolean) => void;
}) {
  const [plan] = useState<BulkPlan<ListRow>>(() => planBulk(kind, selected, viewerUid));
  const [phase, setPhase] = useState<Phase>({ step: "confirm" });
  const [emailGuardians, setEmailGuardians] = useState(false);
  const [cards, setCards] = useState<LoginFacts[] | null>(null);
  const stopRef = useRef(false);
  const startedRef = useRef(false);
  const { title, skippedLine } = confirmText(plan);
  const running = phase.step === "running";
  const n = plan.targets.length;

  const start = async () => {
    if (startedRef.current || n === 0) return;
    startedRef.current = true;
    if (kind === "export") {
      onExport(plan.targets);
      onClose(false);
      return;
    }
    onRunningChange(true);
    setPhase({ step: "running", done: 0, total: n });
    const work = async (row: ListRow): Promise<unknown> => {
      switch (kind) {
        case "archive":
          return archiveUser(row.id);
        case "restore":
          return restoreUser(row.id);
        case "aiTutorOn":
          return setUserSwitch(row.id, "ai_tutor_enabled", true);
        case "aiTutorOff":
          return setUserSwitch(row.id, "ai_tutor_enabled", false);
        case "resetPassword": {
          const r = await resetStudentPassword(row.id, "", emailGuardians);
          return { password: r.newPassword, studentCode: r.studentCode } satisfies ResetValue;
        }
        default:
          return undefined;
      }
    };
    try {
      const results = await runBulk(
        plan.targets,
        work,
        (e) => errorReason(e),
        (done, total) => setPhase({ step: "running", done, total }),
        () => stopRef.current,
      );
      setPhase({ step: "done", results, stopped: results.length < n });
    } finally {
      onRunningChange(false);
    }
  };

  if (cards) return <LoginCards cards={cards} onClose={() => setCards(null)} />;

  if (phase.step === "done") {
    const ok = phase.results.filter((r) => r.ok);
    const bad = phase.results.filter((r): r is Extract<BulkResult, { ok: false }> => !r.ok);
    const byId = new Map(plan.targets.map((r) => [r.id, r]));
    const resets = kind === "resetPassword" ? ok.map((r) => ({ row: byId.get(r.id)!, value: (r as Extract<BulkResult<unknown>, { ok: true }>).value as ResetValue })) : [];
    const resetCards: LoginFacts[] = resets.map(({ row, value }) => ({
      studentName: displayNameOf(row),
      studentCode: value.studentCode || row.storedStudentCode,
      loginEmail: value.studentCode ? `${value.studentCode.toLowerCase()}@alluwaleducationhub.org` : loginEmailOf(row),
      password: value.password,
    }));
    return (
      <DialogShell label={`${BULK_LABELS[kind]} results`} title={`${BULK_LABELS[kind]}: done`} onClose={() => onClose(true)}>
        <p className="m-0 font-semibold" role="status">
          {resultSummary(kind, phase.results, plan.skipped.length, phase.stopped)}
        </p>
        {resets.length > 0 ? (
          <div className="flex flex-col gap-1.5">
            <span className="text-[13px] text-[#475569]">New passwords. They are shown here once; each student&apos;s Login section has theirs.</span>
            <table className="w-full border-collapse text-[13px]" data-testid="bulk-reset-results">
              <thead>
                <tr className="text-left text-xs text-[#64748B]">
                  <th className="py-1 pr-2 font-semibold">Student</th>
                  <th className="py-1 pr-2 font-semibold">Student ID</th>
                  <th className="py-1 font-semibold">Password</th>
                </tr>
              </thead>
              <tbody>
                {resetCards.map((c, i) => (
                  <tr key={`${c.studentCode}-${i}`} className="border-t border-[#F1F5F9]">
                    <td className="py-1.5 pr-2">{c.studentName}</td>
                    <td className="py-1.5 pr-2 font-mono text-xs">{c.studentCode}</td>
                    <td className="select-all py-1.5 font-mono">{c.password}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <button type="button" onClick={() => setCards(resetCards)} className={`${BTN_SECONDARY} flex items-center gap-2 self-start`}>
              <Printer size={16} aria-hidden="true" /> Print login cards
            </button>
          </div>
        ) : null}
        {bad.length > 0 ? (
          <div className="flex flex-col gap-1 rounded-xl bg-[#FEF2F2] px-3.5 py-2.5 text-[13px] text-[#991B1B]" role="alert">
            <span className="font-semibold">Not done</span>
            <ul className="m-0 pl-4">
              {bad.map((r) => (
                <li key={r.id}>
                  {r.name}: {r.error}
                </li>
              ))}
            </ul>
          </div>
        ) : null}
        <SkippedList plan={plan} />
        <button type="button" data-autofocus onClick={() => onClose(true)} className="min-h-11 self-end rounded-[10px] bg-[#0369D9] px-4 font-semibold text-white">
          Done
        </button>
      </DialogShell>
    );
  }

  return (
    <DialogShell label={BULK_LABELS[kind]} title={n === 0 ? `${BULK_LABELS[kind]}: nobody to change` : title} busy={running} onClose={() => onClose(false)}>
      {n === 0 ? <p className="m-0 text-[#475569]">None of the selected people can take this action.</p> : <ActionNote kind={kind} />}
      {kind === "resetPassword" && n > 0 ? (
        <label className="flex items-start gap-2.5 rounded-xl border border-[#E2E8F0] p-3">
          <input type="checkbox" checked={emailGuardians} disabled={running} onChange={(e) => setEmailGuardians(e.target.checked)} className="mt-0.5 h-[18px] w-[18px]" />
          <span className="flex flex-col">
            <span className="font-semibold">Email each student&apos;s guardians the new password</span>
            <span className="text-xs text-[#64748B]">Off: hand out the printed cards from the results instead.</span>
          </span>
        </label>
      ) : null}
      <SkippedList plan={plan} line={skippedLine} />
      {running ? (
        <div className="flex flex-col gap-1.5" role="status">
          <span className="text-[13px] font-semibold">
            {phase.done} of {phase.total} done…
          </span>
          <span className="h-2 overflow-hidden rounded-full bg-[#E2E8F0]">
            <span className="block h-full bg-[#0369D9] transition-[width]" style={{ width: `${(phase.done / Math.max(1, phase.total)) * 100}%` }} />
          </span>
        </div>
      ) : null}
      <div className="flex flex-wrap justify-end gap-2.5">
        {running ? (
          <button type="button" className={BTN_SECONDARY} onClick={() => (stopRef.current = true)}>
            Stop after this one
          </button>
        ) : (
          <button type="button" className={BTN_SECONDARY} onClick={() => onClose(false)}>
            {n === 0 ? "Close" : "Cancel"}
          </button>
        )}
        {n > 0 ? (
          <button
            type="button"
            data-autofocus
            disabled={running}
            onClick={start}
            className="min-h-11 rounded-[10px] px-4 font-semibold text-white disabled:cursor-not-allowed disabled:opacity-60"
            style={{ background: CONFIRM_COLOR[kind] }}
          >
            {running ? "Working…" : kind === "export" ? `Export ${n}` : `${BULK_LABELS[kind]} (${n})`}
          </button>
        ) : null}
      </div>
    </DialogShell>
  );
}

function ActionNote({ kind }: { kind: BulkKind }) {
  const text: Record<BulkKind, string> = {
    archive: "They can't sign in from their next login. Nothing is deleted, and you can restore them at any time.",
    restore: "They can sign in again, with their classes, pay and history as they were.",
    resetPassword: "Each student gets a new easy-to-type password. Their old password stops working.",
    aiTutorOn: "They can use the AI Tutor.",
    aiTutorOff: "They can no longer use the AI Tutor.",
    export: "The same 13 columns as Export, for the selected people only.",
  };
  return <p className="m-0 text-[#475569]">{text[kind]}</p>;
}

function SkippedList({ plan, line }: { plan: BulkPlan; line?: string }) {
  if (plan.skipped.length === 0) return null;
  return (
    <details className="rounded-xl border border-[#E2E8F0] px-3.5 py-2.5 text-[13px]" open={plan.skipped.length <= 5}>
      <summary className="cursor-pointer font-semibold text-[#334155]">{line || `Left out (${plan.skipped.length})`}</summary>
      <ul className="m-0 mt-1.5 pl-4 text-[#475569]">
        {plan.skipped.map((s) => (
          <li key={s.id}>
            {s.name}: {s.reason}
          </li>
        ))}
      </ul>
    </details>
  );
}
