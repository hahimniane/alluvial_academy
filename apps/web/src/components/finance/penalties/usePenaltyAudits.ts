"use client";

import { httpsCallable } from "firebase/functions";
import { useEffect, useState } from "react";
import { functions } from "@/lib/firebase";
import { auditMonthsToRead, summarizeAudit, type AuditSummary } from "@/lib/finance/penalties";

type PenaltyAuditRows = { audits: Array<{ id: string; data: Record<string, unknown> }> };

/**
 * Reads teacher audits for the selected year (and the months the trend needs).
 * The server sends only each audit's pay summary; a full audit is ~70 KB, so
 * reading them whole took seconds for a year.
 */
export function usePenaltyAudits(month: string) {
  const [audits, setAudits] = useState<AuditSummary[] | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    let live = true;
    setAudits(null);
    setError("");
    (async () => {
      try {
        const call = httpsCallable<{ months: string[] }, PenaltyAuditRows>(functions, "getFinancePenaltyAudits");
        const { data } = await call({ months: auditMonthsToRead(month) });
        const out: AuditSummary[] = [];
        for (const row of data.audits) {
          const s = summarizeAudit({ id: row.id, data: row.data });
          if (s) out.push(s);
        }
        if (live) setAudits(out);
      } catch (e) {
        if (live) setError(e instanceof Error ? e.message : "Penalties could not be loaded.");
      }
    })();
    return () => {
      live = false;
    };
  }, [month]);

  return { audits, error };
}
