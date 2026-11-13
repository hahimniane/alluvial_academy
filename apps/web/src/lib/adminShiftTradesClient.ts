import { collection, doc, getDoc, getDocs, limit, orderBy, query, where } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, functions } from "@/lib/firebase";
import {
  type OpenOffer,
  type TradeEvent,
  buildOpenOffers,
  offerRefusal,
  parseTradeEvent,
  tradeErrorMessage,
} from "@/lib/adminShiftTrades";

/** Firestore reads and the callables behind the admin "Offered classes" panel. */

const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");

/** Every class on offer. Past and finished ones are dropped client-side. */
export async function loadOpenOffers(): Promise<OpenOffer[]> {
  const snap = await getDocs(query(collection(db, "teaching_shifts"), where("is_published", "==", true)));
  return buildOpenOffers(snap.docs.map((entry) => ({ id: entry.id, data: entry.data() as Record<string, unknown> })));
}

/** The latest 100 trade events, newest first. */
export async function loadTradeHistory(): Promise<TradeEvent[]> {
  const snap = await getDocs(query(collection(db, "shift_trades"), orderBy("created_at", "desc"), limit(100)));
  return snap.docs
    .map((entry) => parseTradeEvent(entry.id, entry.data() as Record<string, unknown>))
    .filter((event): event is TradeEvent => event !== null);
}

/** Names for the few people the rows know only by id. A missing user maps to "". */
export async function loadUserNames(ids: string[]): Promise<Map<string, string>> {
  const names = new Map<string, string>();
  await Promise.all(
    ids.map(async (id) => {
      try {
        const snap = await getDoc(doc(db, "users", id));
        const data = snap.exists() ? (snap.data() as Record<string, unknown>) : {};
        names.set(id, [str(data.first_name), str(data.last_name)].filter(Boolean).join(" "));
      } catch {
        names.set(id, "");
      }
    }),
  );
  return names;
}

/** Offers a class to others, or takes the offer back. Throws with the reason shown to the admin. */
export async function setShiftOffer(shiftId: string, offered: boolean): Promise<void> {
  const fallback = offered ? "Could not offer this class. Try again." : "Could not take the offer back. Try again.";
  let data: unknown;
  try {
    data = (await httpsCallable(functions, "setShiftOffers")({ shiftIds: [shiftId], offered })).data;
  } catch (error) {
    throw new Error(tradeErrorMessage(error, fallback));
  }
  const refusal = offerRefusal(data, shiftId, fallback);
  if (refusal) throw new Error(refusal);
}

/** Gives an offered class to a teacher. Throws with the reason shown to the admin. */
export async function assignOfferedShift(shiftId: string, teacherId: string): Promise<void> {
  try {
    await httpsCallable(functions, "assignOfferedShift")({ shiftId, teacherId });
  } catch (error) {
    throw new Error(tradeErrorMessage(error, "Could not assign this class. Try again."));
  }
}
