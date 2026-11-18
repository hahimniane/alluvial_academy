import { httpsCallable } from "firebase/functions";
import { functions } from "@/lib/firebase";
import {
  accountOutcome,
  batchOutcomes,
  createFailureReason,
  draftName,
  payloadOf,
  studentOutcome,
  type DraftRow,
  type RowOutcome,
} from "@/lib/addUsers";
import { errorReason } from "@/lib/adminUsersActions";

/**
 * The three account callables the Flutter Add Users sheet uses. One person:
 * createStudentAccount or createUserWithEmail; two or more: createMultipleUsers,
 * which answers row by row. Answers are reduced to outcomes at once; nothing
 * else of them is kept.
 */

type Data = Record<string, unknown>;

const call = (name: string) => httpsCallable<Data, Data>(functions, name);

/** A failed call as a row outcome, in the admin's words. */
export function failureOutcome(row: DraftRow, error: unknown): RowOutcome {
  const message = String((error as { message?: unknown })?.message ?? "");
  const code = String((error as { code?: unknown })?.code ?? "");
  const reason = /internal|invalid-argument/.test(code) && message && !/^internal$/i.test(message) ? createFailureReason(message) : `${errorReason(error).replace(/^./, (c) => c.toUpperCase())}.`;
  return { kind: "failed", name: draftName(row), reason };
}

export async function createOne(row: DraftRow): Promise<RowOutcome> {
  try {
    if (row.type === "student") {
      const result = await call("createStudentAccount")(payloadOf(row));
      return studentOutcome(row, result.data);
    }
    const result = await call("createUserWithEmail")(payloadOf(row));
    return accountOutcome(row, result.data);
  } catch (error) {
    return failureOutcome(row, error);
  }
}

/**
 * Two or more people. A failure of the whole call (offline, refused) fails
 * every row with that reason; the server never creates part of a refused call.
 */
export async function createMany(rows: readonly DraftRow[]): Promise<RowOutcome[]> {
  try {
    const result = await call("createMultipleUsers")({ users: rows.map(payloadOf) });
    return batchOutcomes(rows, result.data, createFailureReason);
  } catch (error) {
    const code = String((error as { code?: unknown })?.code ?? "");
    if (/unavailable|deadline-exceeded|cancelled|unknown/.test(code)) {
      // The call may have run without its answer arriving: never invite a blind retry.
      return rows.map((row) => ({
        kind: "failed" as const,
        name: draftName(row),
        reason: "The answer did not arrive, so some may have been created. Check the list before trying again.",
      }));
    }
    return rows.map((row) => failureOutcome(row, error));
  }
}

export const createPeople = async (rows: readonly DraftRow[]): Promise<RowOutcome[]> =>
  rows.length === 1 ? [await createOne(rows[0])] : createMany(rows);
