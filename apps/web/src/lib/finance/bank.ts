/**
 * Pure helpers for the Bank deposits page: how stored bank transactions and
 * WhatsApp payment proofs are grouped, worded and shown. No Firebase here so
 * the rules can be tested on their own (src/lib/__tests__/finance_bank.test.ts).
 *
 * The matching itself happens on the server; the page only shows it and sends
 * the admin's decision back (docs/finance/SPEC.md, rule 15).
 */

import { monthLabel, monthName } from "./months.ts";

export type Allocation = {
  invoice_id: string;
  amount: number;
  number?: string;
  month?: string;
  family?: string;
  student?: string;
};

export type BankMatch = {
  status: "suggested" | "confirmed" | "manual" | "ignored" | "none";
  level?: "exact" | "likely" | "split" | "auto" | "none";
  kind?: string;
  why?: string;
  allocations?: Allocation[];
  unallocated?: number;
  parent_id?: string | null;
  new_payer?: boolean;
  payer_key?: string;
  recurring_cost_id?: string | null;
  recurring_cost_name?: string;
};

export type BankTxn = {
  id: string;
  date: string;
  month: string;
  amount: number;
  direction: "in" | "out";
  description: string;
  memo?: string;
  payer_name?: string;
  account_mask?: string;
  match: BankMatch;
  needs_action?: boolean;
  removed?: boolean;
  proof_id?: string;
};

export type ProofStatus = "waiting_bank" | "matched" | "confirmed" | "unknown_sender" | "duplicate" | "not_payment" | "unreadable";

export type Proof = {
  id: string;
  from_phone: string;
  parent_id?: string;
  parent_name?: string;
  profile_name?: string;
  image_path?: string;
  received_at?: Date | null;
  extracted: { amount?: number | null; date?: string; sender?: string; recipient?: string; confirmation?: string };
  status: ProofStatus;
  bank_transaction_id?: string;
  invoice_id?: string;
  replies: { at: string; text: string }[];
};

export type Tone = "ok" | "warn" | "bad" | "info" | "mute";

export const TONE_CLASS: Record<Tone, string> = {
  ok: "bg-green-100 text-green-900",
  warn: "bg-amber-100 text-amber-900",
  bad: "bg-red-100 text-red-900",
  info: "bg-blue-100 text-blue-900",
  mute: "bg-slate-200 text-slate-800",
};

export function usd(n: number): string {
  const s = Math.abs(n).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return `${n < 0 ? "−" : ""}$${s}`;
}

export function signedUsd(txn: Pick<BankTxn, "amount" | "direction">): string {
  return `${txn.direction === "out" ? "−" : "+"}${usd(Math.abs(txn.amount))}`;
}

/** "2026-10-20" -> "Oct 20" */
export function shortDate(iso: string): string {
  const [, m, d] = iso.split("-").map(Number);
  if (!m || !d) return iso;
  return `${monthName(`2000-${String(m).padStart(2, "0")}`).slice(0, 3)} ${d}`;
}

/** The monthly invoice's month as a word ("2026-10" -> "October"); other text passes through. */
export function monthWord(month?: string): string {
  return month && /^\d{4}-\d{2}$/.test(month) ? monthName(month) : month || "";
}

export function levelLabel(match: BankMatch): { text: string; tone: Tone } {
  if (match.level === "exact") return { text: "Exact match", tone: "ok" };
  if (match.level === "split") return { text: "Likely — split", tone: "info" };
  if (match.level === "likely") return { text: match.new_payer ? "Likely — new payer" : "Likely", tone: "info" };
  return { text: "No match", tone: "warn" };
}

export function allocationText(a: Allocation): string {
  const parts = [a.number || a.invoice_id, a.family, a.month ? monthWord(a.month) : "", usd(a.amount)].filter(Boolean);
  return parts.join(" · ");
}

/** A suggestion for an invoice, a suggestion for a recurring cost, or nothing to suggest. */
export type WaitingKind = "invoice" | "recurring" | "unmatched";

export function waitingKind(txn: BankTxn): WaitingKind {
  if (txn.direction === "out") return "recurring";
  return txn.match.status === "suggested" ? "invoice" : "unmatched";
}

export function isWaiting(txn: BankTxn): boolean {
  if (txn.removed) return false;
  if (txn.match.status === "suggested") return true;
  return txn.match.status === "none" && txn.direction === "in";
}

/** What the "Matched" table says about a decided or automatic transaction. */
export function doneText(txn: BankTxn): string {
  const m = txn.match;
  if (m.level === "auto") return m.why || "Handled automatically";
  if (m.status === "ignored") return "Marked as not tuition (other income)";
  if (txn.direction === "out") {
    return m.status === "confirmed" ? `Used as ${monthWord(txn.month)}’s ${m.recurring_cost_name || "cost"} amount` : m.why || "Not matched to a recurring cost";
  }
  const lines = (m.allocations || []).map((a) => `${a.number || a.invoice_id} (${usd(a.amount)})`);
  if (m.status === "manual") return `Matched by hand to ${lines.join(" + ") || "an invoice"}`;
  if (m.status === "confirmed") return `Matched to ${lines.join(" + ") || "an invoice"}`;
  return m.why || "";
}

export type Split = {
  waiting: BankTxn[];
  done: BankTxn[];
  /** Charges that match no recurring cost and need nothing. */
  other: BankTxn[];
  moneyIn: number;
  depositCount: number;
};

/**
 * Splits the loaded transactions. Waiting items come from any month (an old
 * unmatched deposit still needs someone); the totals and the matched table
 * cover only the selected month.
 */
export function splitTransactions(txns: BankTxn[], month: string): Split {
  const seen = new Set<string>();
  const unique = txns.filter((t) => !t.removed && !seen.has(t.id) && (seen.add(t.id), true));
  const byDate = (a: BankTxn, b: BankTxn) => b.date.localeCompare(a.date) || a.id.localeCompare(b.id);
  const waiting = unique.filter(isWaiting).sort(byDate);
  const inMonth = unique.filter((t) => t.month === month);
  const deposits = inMonth.filter((t) => t.direction === "in");
  const resolved = inMonth.filter((t) => !isWaiting(t));
  return {
    waiting,
    done: resolved.filter((t) => t.match.status !== "none").sort(byDate),
    other: resolved.filter((t) => t.match.status === "none").sort(byDate),
    moneyIn: deposits.reduce((s, t) => s + t.amount, 0),
    depositCount: deposits.length,
  };
}

export type ProofView = { status: string; tone: Tone; detail: string; canConfirm: boolean; canLink: boolean };

/** What a proof card says, from the proof and (when linked) its bank deposit. */
export function proofView(proof: Proof, txn?: BankTxn | null, invoiceLabel = ""): ProofView {
  const amount = proof.extracted.amount != null ? usd(proof.extracted.amount) : "";
  const forInvoice = invoiceLabel ? `For ${invoiceLabel}. ` : "";
  switch (proof.status) {
    case "matched":
      return {
        status: txn ? `Matches the bank deposit of ${shortDate(txn.date)}` : "Matches a bank deposit",
        tone: "info",
        detail: `${forInvoice}The bank shows ${txn ? `${signedUsd(txn)} from ${txn.payer_name || "the sender"} on ${shortDate(txn.date)}` : `${amount} from this sender`}. Confirm once you have checked it.`,
        canConfirm: true,
        canLink: false,
      };
    case "waiting_bank":
      return {
        status: "Waiting for the bank",
        tone: "warn",
        detail: `${forInvoice}Nothing has reached the bank yet; it is matched as soon as it does, usually within a day.`,
        canConfirm: false,
        canLink: false,
      };
    case "confirmed":
      return { status: "Confirmed · invoice paid", tone: "ok", detail: `${forInvoice}The payment is recorded from the bank deposit.`, canConfirm: false, canLink: false };
    case "unknown_sender":
      return {
        status: "Who sent this?",
        tone: "bad",
        detail: "This number is not on any account. Pick the family once and it is remembered.",
        canConfirm: false,
        canLink: true,
      };
    case "duplicate":
      return { status: "Duplicate · already received", tone: "mute", detail: "Same confirmation number as an earlier proof. Nothing to do.", canConfirm: false, canLink: false };
    case "not_payment":
      return { status: "Not a payment", tone: "mute", detail: "The picture is not a payment. It went to the admin inbox as a normal message.", canConfirm: false, canLink: false };
    default:
      return { status: "Could not read this picture", tone: "bad", detail: "Open the original picture to see what it is.", canConfirm: false, canLink: false };
  }
}

export type ChatBubble = { mine: boolean; kind: "image" | "text"; text: string; time: string };

function timeText(value: Date | string | null | undefined): string {
  if (!value) return "";
  const d = typeof value === "string" ? new Date(value) : value;
  if (Number.isNaN(d.getTime())) return "";
  return d.toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit", timeZone: "America/New_York" });
}

/** The WhatsApp panel: the picture the parent sent, then what Alluwal replied. */
export function chatFor(proof: Proof): ChatBubble[] {
  const out: ChatBubble[] = [{ mine: false, kind: "image", text: "", time: timeText(proof.received_at) }];
  for (const r of proof.replies) out.push({ mine: true, kind: "text", text: r.text, time: timeText(r.at) });
  return out;
}

export function whoText(proof: Proof): string {
  if (proof.parent_name) return `${proof.parent_name} (parent)`;
  if (proof.status === "unknown_sender") return "Unknown number";
  return proof.profile_name || "Unknown sender";
}

/** "+16465550143" -> "+1 (646) 555-0143"; other countries keep a plain "+code digits". */
export function formatPhone(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (digits.length === 11 && digits.startsWith("1")) return `+1 (${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7)}`;
  return digits ? `+${digits}` : phone;
}

export type Option = { id: string; label: string };

/** Option text for the manual-match list. */
export function invoiceOption(inv: { id: string; number?: string; month?: string; balance: number; family?: string }): Option {
  const when = inv.month && /^\d{4}-\d{2}$/.test(inv.month) ? monthLabel(inv.month) : inv.month || "";
  return { id: inv.id, label: [inv.number || inv.id, inv.family, when, `owes ${usd(inv.balance)}`].filter(Boolean).join(" · ") };
}
