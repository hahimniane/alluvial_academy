import { collection, getDocs, limit, query, where } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, functions } from "@/lib/firebase";
import { mergeTrades, normalizeTrade, offerOutcome, type OfferFailure, type ShiftTrade } from "@/lib/shiftTrading";

/**
 * Offer classes to other teachers, or take the offers back. The server judges
 * each class on its own, so the answer says which went through and which did
 * not (and why).
 */
export async function setShiftOffers(shiftIds: string[], offered: boolean): Promise<{ okIds: string[]; failures: OfferFailure[] }> {
  const response = await httpsCallable(functions, "setShiftOffers")({ shiftIds, offered });
  const results = (response.data as { results?: unknown } | null)?.results;
  return offerOutcome(shiftIds, results, offered);
}

/**
 * A teacher's own trades, newest first. Two single-field queries — the classes
 * they gave away and the ones they received — joined here, because the rules
 * only let a teacher read rows they took part in and ordering on the server
 * would need a composite index per field.
 */
export async function loadTeacherTrades(uid: string): Promise<ShiftTrade[]> {
  const snapshots = await Promise.all(
    ["from_teacher_id", "to_teacher_id"].map((field) => getDocs(query(collection(db, "shift_trades"), where(field, "==", uid), limit(100)))),
  );
  return mergeTrades(
    snapshots.map((snap) =>
      snap.docs
        .map((entry) => normalizeTrade(entry.id, entry.data() as Record<string, unknown>))
        .filter((trade): trade is ShiftTrade => trade !== null),
    ),
  );
}
