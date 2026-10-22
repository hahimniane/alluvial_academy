"use client";

import { httpsCallable } from "firebase/functions";
import { functions } from "@/lib/firebase";
import type { MonthSummary } from "./summary";

/**
 * Month summaries from the `getFinanceMonthSummary` callable. Summaries are
 * kept for a short while so moving between finance pages does not ask again,
 * and a month asked for twice at once is fetched once. Pages that change money
 * call `forgetSummaries()` so the next read is fresh.
 */

const KEEP_MS = 30 * 1000;
const CONCURRENCY = 6;

type Entry = { at: number; promise: Promise<MonthSummary> };
const cache = new Map<string, Entry>();

export function forgetSummaries(): void {
  cache.clear();
}

export function fetchMonthSummary(month: string, options: { fresh?: boolean } = {}): Promise<MonthSummary> {
  const hit = cache.get(month);
  if (!options.fresh && hit && Date.now() - hit.at < KEEP_MS) return hit.promise;
  const call = httpsCallable<{ month: string }, MonthSummary>(functions, "getFinanceMonthSummary");
  const promise = call({ month }).then((result) => result.data);
  const entry: Entry = { at: Date.now(), promise };
  cache.set(month, entry);
  // A failed request must not stay cached.
  promise.catch(() => {
    if (cache.get(month) === entry) cache.delete(month);
  });
  return promise;
}

/**
 * Fetches `months` in order, a few at a time, calling `onEach` as each one
 * arrives (or fails) so a page can fill in while the rest load.
 */
export async function fetchMonthSummaries(
  months: string[],
  onEach: (month: string, result: { summary: MonthSummary } | { error: string }) => void,
  options: { fresh?: boolean; cancelled?: () => boolean } = {},
): Promise<void> {
  const queue = [...new Set(months)];
  const worker = async () => {
    for (let month = queue.shift(); month !== undefined; month = queue.shift()) {
      if (options.cancelled?.()) return;
      try {
        const summary = await fetchMonthSummary(month, { fresh: options.fresh });
        if (!options.cancelled?.()) onEach(month, { summary });
      } catch (err) {
        if (!options.cancelled?.()) onEach(month, { error: errorMessage(err) });
      }
    }
  };
  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, queue.length) }, worker));
}

export function errorMessage(err: unknown): string {
  if (err && typeof err === "object" && "message" in err && typeof (err as { message: unknown }).message === "string") {
    return (err as { message: string }).message;
  }
  return "Something went wrong. Try again.";
}
