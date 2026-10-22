"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { fetchMonthSummaries } from "@/lib/finance/summaryClient";
import type { MonthSummary } from "@/lib/finance/summary";

/**
 * Month summaries for the months a page needs, loaded in the order given and
 * kept by month, so choosing another period only fetches the months not seen
 * yet. A month that fails keeps its error until the next reload.
 */
export function useMonthSummaries(months: string[]) {
  const [rows, setRows] = useState<Map<string, MonthSummary>>(() => new Map());
  const [errors, setErrors] = useState<Map<string, string>>(() => new Map());
  const [token, setToken] = useState(0);
  const [fresh, setFresh] = useState(false);
  const key = months.join(",");
  const wanted = useMemo(() => (key ? key.split(",") : []), [key]);

  useEffect(() => {
    let cancelled = false;
    const missing = wanted.filter((m) => fresh || !rows.has(m));
    if (missing.length === 0) return;
    setErrors((prev) => {
      if (!missing.some((m) => prev.has(m))) return prev;
      const next = new Map(prev);
      for (const m of missing) next.delete(m);
      return next;
    });
    void fetchMonthSummaries(
      missing,
      (month, result) => {
        if ("summary" in result) {
          setRows((prev) => new Map(prev).set(month, result.summary));
        } else {
          setErrors((prev) => new Map(prev).set(month, result.error));
        }
      },
      { fresh, cancelled: () => cancelled },
    ).then(() => {
      if (!cancelled && fresh) setFresh(false);
    });
    return () => {
      cancelled = true;
    };
    // `rows` is read only to skip months already loaded; adding it would refetch on every arrival.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [wanted, token]);

  const reload = useCallback(() => {
    setFresh(true);
    setToken((t) => t + 1);
  }, []);

  const loaded = wanted.filter((m) => rows.has(m)).length;
  return { rows, errors, reload, loading: loaded + wanted.filter((m) => errors.has(m)).length < wanted.length, loaded, total: wanted.length };
}
