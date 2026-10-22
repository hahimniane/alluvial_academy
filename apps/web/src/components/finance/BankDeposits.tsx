"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { collection, getDocs, limit, orderBy, query, where } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { getDownloadURL, ref as storageRef } from "firebase/storage";
import { db, functions, storage } from "@/lib/firebase";
import { useT } from "@/lib/i18n";
import { useFinance } from "@/components/finance/FinanceShell";
import { monthLabel, monthName } from "@/lib/finance/months";
import {
  allocationText,
  chatFor,
  doneText,
  formatPhone,
  invoiceOption,
  levelLabel,
  monthWord,
  proofView,
  shortDate,
  signedUsd,
  splitTransactions,
  TONE_CLASS,
  usd,
  waitingKind,
  whoText,
  type BankTxn,
  type Option,
  type Proof,
  type ProofStatus,
  type Tone,
} from "@/lib/finance/bank";

/**
 * Bank deposits + WhatsApp payment proofs. Everything shown is a suggestion;
 * an admin confirms (SPEC rule 15). Matching runs on the server after each
 * bank sync, this page reads this month's transactions and the ones still
 * waiting, and sends decisions to decideBankMatch / decidePaymentProof.
 */

type Status = {
  plaid_available: boolean;
  plaid_connected: boolean;
  institution: string;
  mask: string;
  last_sync_at: string | null;
  needs_attention: string | null;
  whatsapp_available: boolean;
  whatsapp_connected: boolean;
  parent_messages_enabled: boolean;
};

type PlaidMetadata = { institution?: { name?: string } | null; accounts?: { id: string; mask?: string | null }[] };
type PlaidHandler = { open: () => void };
type PlaidGlobal = {
  create: (config: { token: string; onSuccess: (publicToken: string, metadata: PlaidMetadata) => void; onExit: (error: { display_message?: string } | null) => void }) => PlaidHandler;
};

const PLAID_SCRIPT = "https://cdn.plaid.com/link/v2/stable/link-initialize.js";

function loadPlaid(): Promise<PlaidGlobal> {
  const w = window as unknown as { Plaid?: PlaidGlobal };
  if (w.Plaid) return Promise.resolve(w.Plaid);
  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = PLAID_SCRIPT;
    script.async = true;
    script.onload = () => (w.Plaid ? resolve(w.Plaid) : reject(new Error("Plaid did not load")));
    script.onerror = () => reject(new Error("Plaid could not be loaded"));
    document.head.appendChild(script);
  });
}

async function call<T>(name: string, data: unknown): Promise<T> {
  const res = await httpsCallable(functions, name)(data);
  return res.data as T;
}

function errorText(e: unknown): string {
  const message = (e as { message?: string } | null)?.message || "Something went wrong.";
  return message.replace(/^.*?:\s*(?=[A-Z])/, (m) => (m.length < 30 ? "" : m));
}

function asDate(v: unknown): Date | null {
  if (!v) return null;
  if (v instanceof Date) return v;
  const t = (v as { toDate?: () => Date }).toDate;
  return typeof t === "function" ? t.call(v) : null;
}

function readTxn(id: string, d: Record<string, unknown>): BankTxn {
  const match = (d.match as BankTxn["match"] | undefined) ?? { status: "none" };
  return {
    id,
    date: String(d.date ?? ""),
    month: String(d.month ?? String(d.date ?? "").slice(0, 7)),
    amount: Number(d.amount ?? 0),
    direction: d.direction === "out" ? "out" : "in",
    description: String(d.description ?? ""),
    memo: String(d.memo ?? ""),
    payer_name: String(d.payer_name ?? ""),
    account_mask: String(d.account_mask ?? ""),
    match,
    needs_action: d.needs_action === true,
    removed: d.removed === true,
    proof_id: d.proof_id ? String(d.proof_id) : undefined,
  };
}

function readProof(id: string, d: Record<string, unknown>): Proof {
  const replies = Array.isArray(d.replies) ? (d.replies as { at?: string; text?: string }[]) : [];
  return {
    id,
    from_phone: String(d.from_phone ?? ""),
    parent_id: d.parent_id ? String(d.parent_id) : undefined,
    parent_name: d.parent_name ? String(d.parent_name) : undefined,
    profile_name: d.profile_name ? String(d.profile_name) : undefined,
    image_path: d.image_path ? String(d.image_path) : undefined,
    received_at: asDate(d.received_at),
    extracted: (d.extracted as Proof["extracted"]) ?? {},
    status: (d.status as ProofStatus) ?? "not_payment",
    bank_transaction_id: d.bank_transaction_id ? String(d.bank_transaction_id) : undefined,
    invoice_id: d.invoice_id ? String(d.invoice_id) : undefined,
    replies: replies.filter((r) => r.text).map((r) => ({ at: String(r.at ?? ""), text: String(r.text) })),
  };
}

function Pill({ tone, children }: { tone: Tone; children: React.ReactNode }) {
  return <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-bold ${TONE_CLASS[tone]}`}>{children}</span>;
}

const primaryBtn = "min-h-11 rounded-lg bg-[#0386FF] px-4 text-sm font-bold text-white disabled:cursor-not-allowed disabled:opacity-50";
const quietBtn = "min-h-11 rounded-lg border border-slate-300 bg-white px-3.5 text-sm font-semibold text-slate-900 disabled:cursor-not-allowed disabled:opacity-50";
const selectCls = "h-11 rounded-lg border border-slate-300 bg-white px-2 text-sm";
const card = "rounded-xl border border-slate-200 bg-white";

export function BankDeposits() {
  const t = useT();
  const { month } = useFinance();
  const [status, setStatus] = useState<Status | null>(null);
  const [txns, setTxns] = useState<BankTxn[]>([]);
  const [proofs, setProofs] = useState<Proof[]>([]);
  const [payers, setPayers] = useState<{ id: string; name: string; family: string }[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [loadError, setLoadError] = useState("");
  const [invoiceOptions, setInvoiceOptions] = useState<Option[]>([]);
  const [familyOptions, setFamilyOptions] = useState<Option[]>([]);
  const [pickersLoaded, setPickersLoaded] = useState(false);
  const [picks, setPicks] = useState<Record<string, string>>({});
  const [remember, setRemember] = useState<Record<string, boolean>>({});
  const [busy, setBusy] = useState("");
  const [notice, setNotice] = useState("");
  const [needSetup, setNeedSetup] = useState(false);
  const [selectedProof, setSelectedProof] = useState("");
  const [imageUrls, setImageUrls] = useState<Record<string, string>>({});

  const load = useCallback(async () => {
    setLoadError("");
    try {
      const [st, monthSnap, waitingSnap, proofSnap, payerSnap] = await Promise.all([
        call<Status>("linkBankAccount", { action: "status" }).catch(() => null),
        getDocs(query(collection(db, "bank_transactions"), where("month", "==", month), orderBy("date", "desc"), limit(400))),
        getDocs(query(collection(db, "bank_transactions"), where("needs_action", "==", true), limit(100))),
        getDocs(query(collection(db, "payment_proofs"), orderBy("created_at", "desc"), limit(40))),
        getDocs(query(collection(db, "known_payers"), limit(500))),
      ]);
      if (st) setStatus(st);
      const merged = new Map<string, BankTxn>();
      [...monthSnap.docs, ...waitingSnap.docs].forEach((d) => merged.set(d.id, readTxn(d.id, d.data())));
      setTxns([...merged.values()]);
      setProofs(proofSnap.docs.map((d) => readProof(d.id, d.data())));
      setPayers(payerSnap.docs.map((d) => ({ id: d.id, name: String(d.data().name ?? d.id), family: String(d.data().family_name ?? "") })));
      setLoaded(true);
    } catch (e) {
      setLoadError(errorText(e));
      setLoaded(true);
    }
  }, [month]);

  useEffect(() => {
    void load();
  }, [load]);

  const split = useMemo(() => splitTransactions(txns, month), [txns, month]);
  const txById = useMemo(() => new Map(txns.map((x) => [x.id, x])), [txns]);

  const needsPickers = split.waiting.some((x) => x.direction === "in" && x.match.status === "none") || proofs.some((p) => p.status === "unknown_sender");
  useEffect(() => {
    if (!needsPickers || pickersLoaded) return;
    setPickersLoaded(true);
    (async () => {
      try {
        const [inv, par] = await Promise.all([
          getDocs(query(collection(db, "invoices"), where("status", "in", ["pending", "overdue"]), limit(400))),
          getDocs(query(collection(db, "users"), where("user_type", "==", "parent"), limit(1500))),
        ]);
        const names = new Map<string, string>();
        const fams: Option[] = [];
        par.docs.forEach((d) => {
          const x = d.data();
          const name = [x.first_name, x.last_name].filter(Boolean).join(" ").trim();
          if (name) {
            names.set(d.id, name);
            fams.push({ id: d.id, label: name });
          }
        });
        fams.sort((a, b) => a.label.localeCompare(b.label));
        setFamilyOptions(fams);
        const opts: Option[] = [];
        inv.docs.forEach((d) => {
          const x = d.data();
          const balance = Number(x.total_amount ?? 0) - Number(x.paid_amount ?? 0);
          if (balance <= 0.004) return;
          const m = typeof x.billing_month === "string" ? x.billing_month : asDate(x.due_date)?.toISOString().slice(0, 7);
          opts.push({ ...invoiceOption({ id: d.id, number: String(x.invoice_number ?? d.id), month: m, balance, family: names.get(String(x.parent_id ?? "")) }) });
        });
        opts.sort((a, b) => a.label.localeCompare(b.label));
        setInvoiceOptions(opts);
      } catch {
        setPickersLoaded(false);
      }
    })();
  }, [needsPickers, pickersLoaded]);

  const act = async (key: string, run: () => Promise<string>) => {
    setBusy(key);
    setNotice("");
    try {
      setNotice(await run());
      await load();
    } catch (e) {
      setNotice(errorText(e));
    } finally {
      setBusy("");
    }
  };

  const decide = (x: BankTxn, action: "confirm" | "reject" | "manual" | "ignore", doneMessage: string) =>
    act(x.id, async () => {
      const data: Record<string, unknown> = { transaction_id: x.id, action };
      if (action === "manual") data.allocations = [{ invoice_id: picks[x.id], amount: x.amount }];
      if (action === "confirm" && remember[x.id]) data.remember_payer = true;
      await call("decideBankMatch", data);
      return doneMessage;
    });

  const connectBank = async () => {
    setBusy("connect");
    setNotice("");
    try {
      const res = await call<{ available: boolean; link_token?: string; message?: string }>("linkBankAccount", { action: "create_link_token" });
      if (!res.available || !res.link_token) {
        setNeedSetup(true);
        return;
      }
      const Plaid = await loadPlaid();
      const handler = Plaid.create({
        token: res.link_token,
        onSuccess: (publicToken, metadata) => {
          void act("connect", async () => {
            await call("linkBankAccount", {
              action: "exchange",
              public_token: publicToken,
              institution: metadata.institution?.name ?? "",
              mask: metadata.accounts?.[0]?.mask ?? "",
              account_ids: (metadata.accounts ?? []).map((a) => a.id),
            });
            return t("The bank is connected. Deposits show up here within a day.");
          });
        },
        onExit: (error) => {
          if (error?.display_message) setNotice(error.display_message);
        },
      });
      handler.open();
    } catch (e) {
      setNotice(errorText(e));
    } finally {
      setBusy("");
    }
  };

  const checkNow = () =>
    act("sync", async () => {
      const out = await call<{ connected: boolean; added?: number; skipped?: string }>("syncBankTransactions", { rematch_month: month });
      if (!out.connected) return t("The bank is not connected yet.");
      if (out.skipped) return t("A check is already running. Try again in a minute.");
      return out.added ? t("{n} new transactions", { n: out.added }) : t("Nothing new at the bank.");
    });

  const openOriginal = async (p: Proof) => {
    if (!p.image_path) return;
    try {
      const url = await getDownloadURL(storageRef(storage, p.image_path));
      setImageUrls((prev) => ({ ...prev, [p.id]: url }));
    } catch {
      setNotice(t("The original picture can be opened only by an administrator signed in on the web."));
    }
  };

  const bankConnected = status?.plaid_connected === true;
  const showBank = bankConnected || txns.length > 0;
  const showProofs = status?.whatsapp_connected === true || proofs.length > 0;
  const selected = proofs.find((p) => p.id === selectedProof) ?? proofs[0];

  const proofLinkLabel = (p: Proof): string => {
    const tx = p.bank_transaction_id ? txById.get(p.bank_transaction_id) : undefined;
    const first = tx?.match.allocations?.[0];
    if (!first) return "";
    return `${first.number || first.invoice_id} (${monthWord(first.month)}, ${usd(first.amount)})`;
  };

  if (!loaded) return <p className="p-2 text-sm text-slate-600">{t("Loading…")}</p>;

  return (
    <section className="flex flex-col gap-3" aria-labelledby="bank-title">
      <div className="flex flex-wrap items-center gap-3">
        <h2 id="bank-title" className="text-2xl font-extrabold">{t("Bank deposits")}</h2>
        <Pill tone={bankConnected ? "ok" : "mute"}>{bankConnected ? t("Connected") : t("Not connected")}</Pill>
        <div className="flex-1" />
        {bankConnected ? (
          <span className="text-xs text-slate-600">
            {[status?.institution, status?.mask ? `••${status.mask}` : "", t("through Plaid · read-only"), status?.last_sync_at ? t("last synced {when}", { when: new Date(status.last_sync_at).toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit", timeZone: "America/New_York" }) }) : ""].filter(Boolean).join(" · ")}
          </span>
        ) : null}
        {bankConnected ? (
          <button type="button" className={quietBtn} onClick={checkNow} disabled={busy === "sync"}>
            {busy === "sync" ? t("Checking…") : t("Check the bank now")}
          </button>
        ) : null}
      </div>

      <div aria-live="polite" className={notice ? "rounded-lg bg-slate-900 px-3 py-2 text-sm font-semibold text-white" : "sr-only"}>{notice}</div>
      {loadError ? <p role="alert" className="rounded-lg bg-red-100 px-3 py-2 text-sm text-red-900">{loadError}</p> : null}
      {status?.needs_attention ? (
        <p role="alert" className="rounded-lg bg-amber-100 px-3 py-2 text-sm text-amber-900">
          {t("The bank asks Alluwal to sign in again. New deposits stop coming in until that is done.")}
        </p>
      ) : null}

      {!bankConnected && !showBank ? (
        <div className={`${card} flex flex-col gap-3 p-4`}>
          <h3 className="text-base font-bold">{t("Connect your bank")}</h3>
          <p className="text-sm text-slate-700">
            {t("Every deposit and charge on the bank account shows up here within a day. Zelle payments from parents are matched to their invoices; you confirm each match. The connection can only read; it can never move money.")}
          </p>
          <div>
            <button type="button" className={primaryBtn} onClick={connectBank} disabled={busy === "connect"}>
              {busy === "connect" ? t("Opening…") : t("Connect your bank")}
            </button>
          </div>
          {needSetup || status?.plaid_available === false ? (
            <div role="status" className="rounded-lg bg-amber-100 p-3 text-sm text-amber-900">
              <p className="font-semibold">{t("Alluwal needs to finish the bank setup (Plaid) first.")}</p>
              <p className="mt-1">
                {t("Once the setup is done, this button opens your bank’s sign-in. The setup guide is with your developer.")}
              </p>
            </div>
          ) : null}
        </div>
      ) : null}

      <div className={`${card} flex flex-wrap items-center gap-3 p-3`}>
        <h3 className="text-sm font-bold">{t("WhatsApp payment proofs")}</h3>
        <Pill tone={status?.whatsapp_connected ? "ok" : "mute"}>{status?.whatsapp_connected ? t("Connected") : t("Not connected")}</Pill>
        <span className="min-w-[240px] flex-1 text-xs text-slate-600">
          {status?.whatsapp_connected
            ? status.parent_messages_enabled
              ? t("Parents get a reply on WhatsApp for each screenshot.")
              : t("Parent messages are off in Settings, so nothing is sent back to parents.")
            : status?.whatsapp_available
              ? t("The WhatsApp number is set up but Meta has not confirmed the webhook yet.")
              : t("Parents will send their Zelle screenshot to the Alluwal WhatsApp number once it is connected. The setup guide is with your developer.")}
        </span>
      </div>

      {showBank ? (
        <>
          <p className="text-sm text-slate-700">
            {t("Every deposit and charge on the bank account shows up here within a day. Zelle payments from parents are matched to their invoices; you confirm each match. The connection can only read; it can never move money.")}
          </p>
          <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-3">
            {[
              { label: t("Money in this month"), value: usd(split.moneyIn), sub: t("{n} deposits", { n: split.depositCount }) },
              { label: t("Waiting for you"), value: String(split.waiting.length), sub: t("Suggested matches and unknown deposits") },
              { label: t("Matched"), value: String(split.done.length), sub: t("Tied to an invoice or a cost") },
            ].map((c) => (
              <div key={c.label} className={`${card} p-3`}>
                <div className="text-xs font-semibold text-slate-600">{c.label}</div>
                <div className="text-xl font-extrabold">{c.value}</div>
                <div className="text-xs text-slate-600">{c.sub}</div>
              </div>
            ))}
          </div>

          <h3 className="mt-1.5 text-base font-bold">{t("Waiting for you")}</h3>
          {split.waiting.length === 0 ? <div className={`${card} p-4 font-semibold text-green-800`}>{t("Every deposit is matched.")}</div> : null}
          {split.waiting.map((x) => {
            const kind = waitingKind(x);
            const lvl = levelLabel(x.match);
            const isBusy = busy === x.id;
            return (
              <article key={x.id} className={`${card} flex flex-col gap-2.5 p-3.5`} aria-label={`${x.description} ${signedUsd(x)}`}>
                <div className="flex flex-wrap items-baseline gap-2.5">
                  <span className={`text-lg font-extrabold ${x.direction === "out" ? "text-red-700" : "text-green-700"}`}>{signedUsd(x)}</span>
                  <span className="font-bold">{x.description}</span>
                  <span className="text-xs text-slate-600">{shortDate(x.date)} · {x.memo ? `${t("Memo")}: “${x.memo}”` : t("No memo")}</span>
                </div>

                {kind === "invoice" ? (
                  <>
                    <div className="flex flex-col gap-1.5 rounded-lg bg-slate-50 p-3">
                      <div className="flex flex-wrap items-center gap-2">
                        <Pill tone={lvl.tone}>{t(lvl.text)}</Pill>
                        <span className="text-sm text-slate-700">{x.match.why}</span>
                      </div>
                      {(x.match.allocations ?? []).map((a) => (
                        <div key={a.invoice_id} className="text-sm font-semibold">→ {allocationText(a)}</div>
                      ))}
                      {(x.match.unallocated ?? 0) > 0.004 ? (
                        <div className="text-sm text-amber-900">{t("{amount} is left over after these invoices.", { amount: usd(x.match.unallocated ?? 0) })}</div>
                      ) : null}
                      {x.match.new_payer && x.match.payer_key ? (
                        <label className="flex min-h-11 items-center gap-2 text-sm">
                          <input type="checkbox" className="h-5 w-5" checked={Boolean(remember[x.id])} onChange={(e) => setRemember({ ...remember, [x.id]: e.target.checked })} />
                          {t("Remember that {payer} pays for the {family} family", { payer: x.payer_name || "", family: x.match.allocations?.[0]?.family || "" })}
                        </label>
                      ) : null}
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <button type="button" className={primaryBtn} disabled={isBusy} onClick={() => decide(x, "confirm", t("{amount} matched", { amount: usd(x.amount) }))}>{t("Confirm match")}</button>
                      <button type="button" className={quietBtn} disabled={isBusy} onClick={() => decide(x, "reject", t("Pick the right invoice for this deposit."))}>{t("Not this one")}</button>
                    </div>
                  </>
                ) : null}

                {kind === "unmatched" ? (
                  <>
                    <div className="rounded-lg bg-amber-100 p-3 text-sm text-amber-900">{x.match.why || t("No family with this name owes {amount}", { amount: usd(x.amount) })}</div>
                    <div className="flex flex-wrap items-end gap-2">
                      <label className="flex min-w-[240px] flex-[1_1_320px] flex-col gap-1 text-xs font-semibold text-slate-700">
                        {t("Match to an invoice")}
                        <select className={selectCls} value={picks[x.id] ?? ""} onChange={(e) => setPicks({ ...picks, [x.id]: e.target.value })}>
                          <option value="">{pickersLoaded && invoiceOptions.length === 0 ? t("No unpaid invoices") : t("Choose an unpaid invoice…")}</option>
                          {invoiceOptions.map((o) => <option key={o.id} value={o.id}>{o.label}</option>)}
                        </select>
                      </label>
                      <button type="button" className={primaryBtn} disabled={isBusy || !picks[x.id]} onClick={() => decide(x, "manual", t("{amount} matched", { amount: usd(x.amount) }))}>{t("Match")}</button>
                      <button type="button" className={quietBtn} disabled={isBusy} onClick={() => decide(x, "ignore", t("Marked as other income"))}>{t("Not tuition")}</button>
                    </div>
                  </>
                ) : null}

                {kind === "recurring" ? (
                  <>
                    <div className="rounded-lg bg-slate-50 p-3 text-sm text-slate-700">{x.match.why}</div>
                    <div className="flex flex-wrap gap-2">
                      {x.match.recurring_cost_id ? (
                        <button type="button" className={primaryBtn} disabled={isBusy} onClick={() => decide(x, "confirm", t("{cost} confirmed for {month} at {amount}", { cost: x.match.recurring_cost_name || "", month: monthName(x.month), amount: usd(x.amount) }))}>
                          {t("Use as {month}’s {cost} bill", { month: monthName(x.month), cost: x.match.recurring_cost_name || "" })}
                        </button>
                      ) : null}
                      <button type="button" className={quietBtn} disabled={isBusy} onClick={() => decide(x, "ignore", t("Left alone"))}>{t("Not this cost")}</button>
                    </div>
                  </>
                ) : null}
              </article>
            );
          })}
        </>
      ) : null}

      {showProofs ? (
        <>
          <div className="mt-1.5 flex flex-wrap items-baseline gap-2.5">
            <h3 className="text-base font-bold">{t("Payment proofs from WhatsApp")}</h3>
            <span className="text-xs text-slate-600">{t("Parents send their Zelle screenshot to the Alluwal WhatsApp number. A screenshot alone never marks an invoice paid; the bank deposit does.")}</span>
          </div>
          {proofs.length === 0 ? <div className={`${card} p-4 text-sm text-slate-700`}>{t("No screenshots yet.")}</div> : (
            <div className="flex flex-wrap items-start gap-4">
              <div className="flex min-w-0 flex-[3_1_480px] flex-col gap-2.5">
                {proofs.map((p) => {
                  const tx = p.bank_transaction_id ? txById.get(p.bank_transaction_id) : undefined;
                  const view = proofView(p, tx, proofLinkLabel(p));
                  const on = selected?.id === p.id;
                  const isPayment = !["not_payment", "unreadable"].includes(p.status);
                  const pickKey = `fam_${p.id}`;
                  return (
                    <article key={p.id} className={`flex flex-col gap-2.5 rounded-xl bg-white p-3.5 ${on ? "border-2 border-[#0386FF]" : "border border-slate-200"}`} aria-label={`${whoText(p)} ${view.status}`}>
                      <div className="flex flex-wrap items-start gap-3">
                        {isPayment ? (
                          <div role="img" aria-label={t("Zelle screenshot")} className="w-[150px] shrink-0 overflow-hidden rounded-[10px] border border-slate-200 bg-white text-[11px]">
                            <div className="bg-[#6D1ED4] px-2 py-1.5 font-extrabold tracking-wide text-white">Zelle</div>
                            <div className="flex flex-col gap-0.5 p-2">
                              <div className="text-base font-extrabold">{p.extracted.amount != null ? usd(p.extracted.amount) : "—"}</div>
                              <div className="text-slate-700">{t("Sent to {name}", { name: p.extracted.recipient || "Alluwal Education Hub" })}</div>
                              <div className="text-slate-700">{t("From {name}", { name: p.extracted.sender || "—" })}</div>
                              <div className="text-slate-600">{p.extracted.date ? shortDate(p.extracted.date) : ""}</div>
                              <div className="text-slate-600">Conf# {p.extracted.confirmation || "—"}</div>
                            </div>
                          </div>
                        ) : (
                          <div role="img" aria-label={t("Picture that is not a payment")} className="flex h-24 w-[150px] shrink-0 items-center justify-center rounded-[10px] border border-dashed border-slate-300 p-2 text-center text-xs text-slate-600">
                            {t("Picture")}
                          </div>
                        )}
                        <div className="flex min-w-[220px] flex-1 flex-col gap-1.5">
                          <div className="flex flex-wrap items-center gap-2"><span className="font-bold">{whoText(p)}</span><Pill tone={view.tone}>{t(view.status)}</Pill></div>
                          <div className="text-xs text-slate-600">WhatsApp {formatPhone(p.from_phone)}{p.received_at ? ` · ${p.received_at.toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit", timeZone: "America/New_York" })}` : ""}</div>
                          <div className="text-sm text-slate-700">{view.detail}</div>
                        </div>
                      </div>
                      <div className="flex flex-wrap items-end gap-2">
                        {view.canConfirm ? (
                          <button type="button" className={primaryBtn} disabled={busy === p.id} onClick={() => act(p.id, async () => { await call("decidePaymentProof", { proof_id: p.id, action: "confirm" }); return t("Payment confirmed"); })}>{t("Confirm payment")}</button>
                        ) : null}
                        {view.canLink ? (
                          <>
                            <label className="flex min-w-[220px] flex-[1_1_240px] flex-col gap-1 text-xs font-semibold text-slate-700">
                              {t("Which family is this?")}
                              <select className={selectCls} value={picks[pickKey] ?? ""} onChange={(e) => setPicks({ ...picks, [pickKey]: e.target.value })}>
                                <option value="">{t("Choose a family…")}</option>
                                {familyOptions.map((o) => <option key={o.id} value={o.id}>{o.label}</option>)}
                              </select>
                            </label>
                            <button type="button" className={primaryBtn} disabled={busy === p.id || !picks[pickKey]} onClick={() => act(p.id, async () => { await call("decidePaymentProof", { proof_id: p.id, action: "link_family", parent_id: picks[pickKey] }); return t("Number saved to the family"); })}>{t("Save number to family")}</button>
                          </>
                        ) : null}
                        <button type="button" className={quietBtn} onClick={() => setSelectedProof(p.id)} aria-pressed={on}>{t("See the WhatsApp chat")}</button>
                        {p.image_path ? <button type="button" className={quietBtn} onClick={() => openOriginal(p)}>{t("Open the original picture")}</button> : null}
                      </div>
                      {imageUrls[p.id] ? (
                        <img src={imageUrls[p.id]} alt={t("Picture sent on WhatsApp")} className="max-h-96 w-auto max-w-full rounded-lg border border-slate-200 object-contain" />
                      ) : null}
                    </article>
                  );
                })}
              </div>

              {selected ? (
                <aside className="min-w-0 flex-[2_1_300px] overflow-hidden rounded-xl border border-slate-200 bg-[#ECE5DD]" aria-label={t("WhatsApp chat")}>
                  <div className="bg-[#075E54] px-3 py-2.5 text-white">
                    <div className="text-sm font-bold">Alluwal Education Hub</div>
                    <div className="text-xs opacity-90">{t("Chat with {who}", { who: `${whoText(selected)} · ${formatPhone(selected.from_phone)}` })}</div>
                  </div>
                  <div className="flex min-h-[260px] flex-col gap-2 p-3">
                    {chatFor(selected).map((m, i) => (
                      <div key={i} className={`flex ${m.mine ? "justify-end" : "justify-start"}`}>
                        <div className={`max-w-[78%] rounded-[10px] px-2.5 py-2 text-[13px] leading-snug text-slate-900 ${m.mine ? "bg-[#DCF8C6]" : "border border-slate-200 bg-white"}`}>
                          {m.kind === "image" ? (
                            ["not_payment", "unreadable"].includes(selected.status) ? (
                              <div className="flex h-[70px] w-[150px] items-center justify-center rounded-lg border border-dashed border-slate-300 text-[11px] text-slate-600">{t("Picture")}</div>
                            ) : (
                              <div className="w-[150px] overflow-hidden rounded-lg border border-slate-200 text-[11px]"><div className="bg-[#6D1ED4] px-2 py-1 font-extrabold text-white">Zelle</div><div className="p-1.5 text-slate-700">{t("Payment screenshot")}</div></div>
                            )
                          ) : <div>{m.text}</div>}
                          <div className="mt-0.5 text-right text-[11px] text-slate-600">{m.time}</div>
                        </div>
                      </div>
                    ))}
                    {selected.replies.length === 0 ? (
                      <p className="mt-1 text-xs text-slate-700">{status?.parent_messages_enabled ? t("No reply was sent for this picture.") : t("Parent messages are off, so nothing was sent back.")}</p>
                    ) : null}
                  </div>
                </aside>
              ) : null}
            </div>
          )}
        </>
      ) : null}

      {showBank ? (
        <div className="flex flex-wrap items-start gap-4">
          <div className={`${card} min-w-0 flex-[2_1_420px] relative overflow-x-auto`}>
            <table className="w-full min-w-[560px] border-collapse text-[13px]">
              <caption className="sr-only">{t("Matched deposits and charges for {month}", { month: monthLabel(month) })}</caption>
              <thead>
                <tr className="bg-slate-50 text-left text-slate-700">
                  <th scope="col" className="p-2.5">{t("Date")}</th>
                  <th scope="col" className="p-2.5">{t("Bank description")}</th>
                  <th scope="col" className="p-2.5 text-right">{t("Amount")}</th>
                  <th scope="col" className="p-2.5">{t("Matched to")}</th>
                </tr>
              </thead>
              <tbody>
                {[...split.done, ...split.other].map((x) => (
                  <tr key={x.id} className="border-t border-slate-200">
                    <td className="whitespace-nowrap p-2.5">{shortDate(x.date)}</td>
                    <td className="p-2.5 font-semibold">{x.description}</td>
                    <td className={`p-2.5 text-right font-bold ${x.direction === "out" ? "text-red-700" : "text-green-700"}`}>{signedUsd(x)}</td>
                    <td className="p-2.5 text-slate-700">{x.match.status === "none" ? t("Not matched to a recurring cost") : doneText(x)}</td>
                  </tr>
                ))}
                {split.done.length + split.other.length === 0 ? <tr className="border-t border-slate-200"><td colSpan={4} className="p-3 text-slate-600">{t("Nothing matched yet this month.")}</td></tr> : null}
              </tbody>
            </table>
          </div>
          <div className={`${card} flex min-w-0 flex-[1_1_260px] flex-col gap-1.5 p-3.5`}>
            <h3 className="text-[15px] font-bold">{t("Known payers")}</h3>
            <p className="text-xs text-slate-600">{t("Deposits from these names match on their own next time.")}</p>
            {payers.length === 0 ? <p className="text-[13px] text-slate-600">{t("No payers saved yet.")}</p> : null}
            {payers.map((k) => <div key={k.id} className="text-[13px]">{k.family ? `${k.name} → ${t("{name} family", { name: k.family })}` : k.name}</div>)}
          </div>
        </div>
      ) : null}
    </section>
  );
}
