"use client";

import { collection, getDocs, query, where } from "firebase/firestore";
import { useEffect, useMemo, useRef, useState } from "react";
import { db } from "@/lib/firebase";
import { addMonths, currentMonth, monthLabel, recentMonths } from "@/lib/finance/months";
import { openMonthOptions, previewText, termHistoryLines, termInForce, type AdminTerms, type StaffSummary } from "@/lib/finance/staff";
import { BTN, BTN_PRIMARY, ErrorText, Field, INPUT, Modal, callFinance } from "./staffUi";

const startOptions = (closed: Set<string>) => openMonthOptions(recentMonths(14, addMonths(currentMonth(), 1)), closed);

type Candidate = { uid: string; name: string; title: string };

async function loadCandidates(exclude: Set<string>): Promise<Candidate[]> {
  const snap = await getDocs(query(collection(db, "users"), where("user_type", "in", ["admin", "super_admin", "teacher"])));
  return snap.docs
    .filter((d) => !exclude.has(d.id) && d.data().is_active !== false)
    .map((d) => {
      const x = d.data();
      const name = `${x.first_name ?? ""} ${x.last_name ?? ""}`.trim() || String(x["e-mail"] ?? x.email ?? d.id);
      return { uid: d.id, name, title: String(x.title ?? "") };
    })
    .sort((a, b) => a.name.localeCompare(b.name));
}

/** Edit an administrator's pay, or add one. Terms start in an open month and never rewrite a closed one. */
export function AdminPayDialog({
  summary,
  existing,
  terms,
  closedMonths,
  knownUids,
  onClose,
  onDone,
}: {
  summary: StaffSummary;
  /** The administrator being edited; null to add a new one. */
  existing: { uid: string; name: string; role_title: string } | null;
  terms: AdminTerms | null;
  closedMonths: Set<string>;
  knownUids: Set<string>;
  onClose: () => void;
  onDone: (message: string) => void;
}) {
  const options = useMemo(() => startOptions(closedMonths), [closedMonths]);
  const inForce = termInForce(terms?.terms, summary.month);
  const defaultFrom = options.includes(summary.month) ? summary.month : (options.find((m) => m >= summary.month) ?? options[options.length - 1] ?? summary.month);
  const [uid, setUid] = useState(existing?.uid ?? "");
  const [name, setName] = useState(existing?.name ?? "");
  const [roleTitle, setRoleTitle] = useState(existing?.role_title ?? "");
  const [fixed, setFixed] = useState(inForce ? String(inForce.fixed) : "");
  const [pct, setPct] = useState(inForce ? String(inForce.pct) : "0");
  const [from, setFrom] = useState(defaultFrom);
  const [note, setNote] = useState("");
  const [candidates, setCandidates] = useState<Candidate[]>([]);
  const [filter, setFilter] = useState("");
  const [bases, setBases] = useState<Record<string, number>>({ [summary.month]: summary.admin_base ?? 0 });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const asked = useRef(new Set<string>([summary.month]));

  useEffect(() => {
    if (existing) return;
    loadCandidates(knownUids)
      .then(setCandidates)
      .catch(() => setError("The list of people could not be loaded."));
  }, [existing, knownUids]);

  // The share preview needs the profit base of the month the terms start in.
  useEffect(() => {
    if (asked.current.has(from)) return;
    asked.current.add(from);
    callFinance<StaffSummary>("getFinanceMonthSummary", { month: from })
      .then((s) => setBases((b) => ({ ...b, [from]: s.admin_base ?? 0 })))
      .catch(() => undefined);
  }, [from]);

  const fixedNum = Number(fixed);
  const pctNum = pct.trim() === "" ? 0 : Number(pct);
  const hasHistory = Boolean(terms && terms.terms.length > 0);
  const shown = candidates.filter((c) => c.name.toLowerCase().includes(filter.trim().toLowerCase()));

  const pick = (id: string) => {
    setUid(id);
    const c = candidates.find((x) => x.uid === id);
    if (c) {
      setName(c.name);
      setRoleTitle(c.title || "Administrator");
    }
  };

  const submit = async () => {
    setError("");
    if (!uid) return setError("Choose who to add.");
    if (fixed.trim() === "" || !Number.isFinite(fixedNum) || fixedNum < 0) return setError("Add a monthly amount of $0 or more.");
    if (!Number.isFinite(pctNum) || pctNum < 0 || pctNum > 100) return setError("The share must be between 0 and 100%.");
    if (hasHistory && !note.trim()) return setError("Say why the pay is changing.");
    setBusy(true);
    try {
      await callFinance("setAdminPayTerms", {
        uid,
        ...(existing ? {} : { name: name.trim(), role_title: roleTitle.trim() || "Administrator" }),
        from_month: from,
        fixed: fixedNum,
        pct: pctNum,
        note: note.trim(),
      });
      onDone(`${existing ? `${name}’s pay saved` : `${name} added`} from ${monthLabel(from)}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save.");
      setBusy(false);
    }
  };

  return (
    <Modal title={existing ? `Pay for ${existing.name}` : "Add administrator"} onClose={onClose} wide>
      {!existing ? (
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Find a person">
            <input className={INPUT} type="search" value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="Type a name" />
          </Field>
          <Field label="Person">
            <select className={INPUT} value={uid} onChange={(e) => pick(e.target.value)}>
              <option value="">Choose…</option>
              {shown.map((c) => (
                <option key={c.uid} value={c.uid}>
                  {c.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Role">
            <input className={INPUT} type="text" value={roleTitle} onChange={(e) => setRoleTitle(e.target.value)} placeholder="e.g. Coordinator" />
          </Field>
        </div>
      ) : null}
      <div className="grid gap-3 sm:grid-cols-2">
        <Field label="Monthly fixed pay ($)">
          <input className={INPUT} type="number" inputMode="decimal" min="0" step="0.01" value={fixed} onChange={(e) => setFixed(e.target.value)} placeholder="0.00" />
        </Field>
        <Field label="Profit share (%), 0 for none">
          <input className={INPUT} type="number" inputMode="decimal" min="0" max="100" step="0.1" value={pct} onChange={(e) => setPct(e.target.value)} placeholder="0" />
        </Field>
      </div>
      <Field label="Starts">
        <select className={INPUT} value={from} onChange={(e) => setFrom(e.target.value)}>
          {options.map((m) => (
            <option key={m} value={m}>
              {monthLabel(m)} onward
            </option>
          ))}
        </select>
      </Field>
      {hasHistory ? (
        <Field label="Why is the pay changing? (required)">
          <input className={INPUT} type="text" maxLength={300} value={note} onChange={(e) => setNote(e.target.value)} placeholder="e.g. Raise agreed with the owner" />
        </Field>
      ) : null}
      <div aria-live="polite" className="rounded-xl bg-slate-50 p-3 text-sm text-slate-700">
        {previewText(fixedNum, pctNum, bases[from] ?? 0, from)}
      </div>
      <p className="text-xs text-slate-600">The share is a % of what is left after all other costs that month. A month that loses money pays the fixed amount only. Closed months keep the pay they had.</p>
      {hasHistory && terms ? (
        <div className="flex flex-col gap-1">
          <div className="text-sm font-bold">Pay history</div>
          {termHistoryLines(terms.terms, terms.pauses).map((line, i) => (
            <div key={i} className="text-sm text-slate-700">
              • {line}
            </div>
          ))}
        </div>
      ) : null}
      <ErrorText message={error} />
      <div className="flex gap-2">
        <button type="button" className={BTN_PRIMARY} disabled={busy} onClick={submit}>
          {busy ? "Saving…" : "Save"}
        </button>
        <button type="button" className={BTN} onClick={onClose}>
          Cancel
        </button>
      </div>
    </Modal>
  );
}

/** Pause an administrator's pay from a month, or restart it. */
export function PauseDialog({
  mode,
  uid,
  name,
  summaryMonth,
  closedMonths,
  onClose,
  onDone,
}: {
  mode: "pause" | "resume";
  uid: string;
  name: string;
  summaryMonth: string;
  closedMonths: Set<string>;
  onClose: () => void;
  onDone: (message: string) => void;
}) {
  const options = useMemo(() => startOptions(closedMonths), [closedMonths]);
  const [from, setFrom] = useState(options.includes(summaryMonth) ? summaryMonth : (options.find((m) => m >= summaryMonth) ?? options[0] ?? summaryMonth));
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const pause = mode === "pause";
  const title = `${pause ? "Pause" : "Resume"} pay for ${name}`;

  const submit = async () => {
    if (!reason.trim()) return setError(pause ? "Say why the pay is paused." : "Say why the pay restarts.");
    setBusy(true);
    try {
      await callFinance(pause ? "pauseAdminPay" : "resumeAdminPay", { uid, from_month: from, reason: reason.trim() });
      onDone(pause ? `${name}’s pay paused from ${monthLabel(from)}` : `${name}’s pay resumes in ${monthLabel(from)}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save.");
      setBusy(false);
    }
  };

  return (
    <Modal title={title} onClose={onClose}>
      <Field label={pause ? "Starting" : "Pay restarts in"}>
        <select className={INPUT} value={from} onChange={(e) => setFrom(e.target.value)}>
          {options.map((m) => (
            <option key={m} value={m}>
              {monthLabel(m)}
            </option>
          ))}
        </select>
      </Field>
      <Field label="Reason (required)">
        <input className={INPUT} type="text" maxLength={300} value={reason} onChange={(e) => setReason(e.target.value)} placeholder={pause ? "e.g. On leave until January" : "e.g. Back from leave"} />
      </Field>
      <div className="rounded-xl bg-slate-50 p-3 text-sm text-slate-700">
        {pause
          ? `From ${monthLabel(from)} they get no fixed pay and no share, and they cannot be marked paid. Months before stay as they are.`
          : `Pay restarts in ${monthLabel(from)} at their saved terms.`}
      </div>
      <ErrorText message={error} />
      <div className="flex gap-2">
        <button type="button" className={BTN_PRIMARY} disabled={busy || !reason.trim()} onClick={submit}>
          {busy ? "Saving…" : title}
        </button>
        <button type="button" className={BTN} onClick={onClose}>
          Cancel
        </button>
      </div>
    </Modal>
  );
}
