"use client";

import { useMemo, useState } from "react";
import { money } from "@/lib/finance/model";
import { monthLabel } from "@/lib/finance/months";
import { callRemoveFromBilling, errorMessage, type NotAttendingRow } from "./data";
import { Badge, Field, Notice, dangerButton, inputClass, outlineButton } from "./ui";

/**
 * Children still on a family's monthly billing who no longer attend — archived,
 * or with no weekly class and no upcoming class. Removing one takes them off
 * billing and their share off the family's monthly amount.
 */
export function NotAttendingPanel({
  rows,
  loading,
  error,
  onChanged,
}: {
  rows: NotAttendingRow[];
  loading: boolean;
  error: string;
  onChanged: () => void;
}) {
  const [q, setQ] = useState("");
  const [confirm, setConfirm] = useState<NotAttendingRow | null>(null);
  const [reason, setReason] = useState("No longer attends classes");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ tone: "ok" | "error"; text: string } | null>(null);

  const view = useMemo(() => {
    const needle = q.trim().toLowerCase();
    if (!needle) return rows;
    return rows.filter((r) => r.student_name.toLowerCase().includes(needle) || r.parent_name.toLowerCase().includes(needle));
  }, [rows, q]);

  const monthlyTotal = view.reduce((sum, r) => sum + r.share, 0);

  const remove = async () => {
    if (!confirm) return;
    setBusy(true);
    setMessage(null);
    try {
      const out = await callRemoveFromBilling({ parent_id: confirm.parent_id, student_id: confirm.student_id, reason: reason.trim() });
      setMessage({
        tone: "ok",
        text: out.family_active
          ? `${confirm.student_name} is off billing. ${confirm.parent_name} pays ${money(out.new)} a month from ${monthLabel(out.from_month)} (was ${money(out.old)}).`
          : `${confirm.student_name} is off billing. ${confirm.parent_name} has no other child on billing, so no monthly invoice is made for them from ${monthLabel(out.from_month)}.`,
      });
      setConfirm(null);
      onChanged();
    } catch (e) {
      setMessage({ tone: "error", text: errorMessage(e, "Could not remove the student from billing.") });
    } finally {
      setBusy(false);
    }
  };

  if (error) return <Notice tone="error">{error}</Notice>;
  if (loading) return <p className="rounded-xl border border-slate-200 bg-white p-6 text-center text-slate-600">Checking every family&apos;s students…</p>;

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-end gap-3 rounded-xl border border-slate-200 bg-white p-3.5">
        <div className="min-w-0 flex-1">
          <div className="text-lg font-extrabold">
            {view.length} {view.length === 1 ? "student" : "students"} on billing who no longer attend
          </div>
          <div className="text-[13px] text-slate-600">
            {money(monthlyTotal)} a month billed for them. Archived students are never invoiced. Students with no class still are,
            until you remove them here.
          </div>
        </div>
        <Field label="Search" className="w-full sm:w-72">
          <input className={inputClass} type="text" value={q} placeholder="Student or family" onChange={(e) => setQ(e.target.value)} />
        </Field>
      </div>

      {message ? <Notice tone={message.tone}>{message.text}</Notice> : null}

      {view.length === 0 ? (
        <p className="rounded-xl border border-slate-200 bg-white p-6 text-center text-slate-600">
          {rows.length ? "No student matches this search." : "Every student on billing has classes."}
        </p>
      ) : (
        <ul className="flex flex-col gap-2.5">
          {view.map((r) => {
            const open = confirm && confirm.parent_id === r.parent_id && confirm.student_id === r.student_id;
            return (
              <li key={`${r.parent_id}_${r.student_id}`} className="flex flex-col gap-2 rounded-xl border border-slate-200 bg-white p-3.5">
                <div className="flex flex-wrap items-start gap-2">
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2 font-extrabold">
                      {r.student_name}
                      <Badge tone={r.reason === "archived" ? "mute" : "warn"}>{r.reason === "archived" ? "Archived" : "No classes"}</Badge>
                    </div>
                    <div className="text-[13px] text-slate-600">
                      Family: {r.parent_name} · {r.children} {r.children === 1 ? "child" : "children"} on billing · {money(r.family_amount)} a month
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="font-extrabold">{money(r.share)}</div>
                    <div className="text-xs text-slate-600">this student&apos;s share</div>
                  </div>
                </div>

                {open ? (
                  <div className="flex flex-col gap-2 rounded-lg border border-red-200 bg-red-50 p-3">
                    <p className="text-[13px] text-red-900">
                      Remove {r.student_name} from {r.parent_name}&apos;s billing? The monthly amount goes from {money(r.family_amount)} to{" "}
                      {money(r.children > 1 ? Math.max(0, r.family_amount - r.share) : 0)} from the next invoice not yet made.
                      {r.children === 1 ? " The family is no longer invoiced each month." : ""}
                    </p>
                    <Field label="Reason">
                      <input className={inputClass} type="text" value={reason} onChange={(e) => setReason(e.target.value)} />
                    </Field>
                    <div className="flex flex-wrap gap-2">
                      <button type="button" className={dangerButton} disabled={busy || !reason.trim()} onClick={remove}>
                        {busy ? "Removing…" : "Yes, remove from billing"}
                      </button>
                      <button type="button" className={outlineButton} disabled={busy} onClick={() => setConfirm(null)}>
                        Keep
                      </button>
                    </div>
                  </div>
                ) : (
                  <div>
                    <button type="button" className={outlineButton} disabled={busy} onClick={() => { setMessage(null); setConfirm(r); }}>
                      Remove from billing
                    </button>
                  </div>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
