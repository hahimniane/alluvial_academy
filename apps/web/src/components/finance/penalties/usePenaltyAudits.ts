"use client";

import { collection, getDocs, query, where } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "@/lib/firebase";
import { auditMonthsToRead, chunk, summarizeAudit, type AuditSummary } from "@/lib/finance/penalties";

/**
 * Reads teacher audits for the selected year (and the months the trend needs).
 * Bounded: `yearMonth in [..]` in chunks, never the whole collection.
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
        const snaps = await Promise.all(
          chunk(auditMonthsToRead(month), 10).map((months) => getDocs(query(collection(db, "teacher_audits"), where("yearMonth", "in", months))))
        );
        const out: AuditSummary[] = [];
        for (const snap of snaps) {
          for (const d of snap.docs) {
            const s = summarizeAudit({ id: d.id, data: d.data() });
            if (s) out.push(s);
          }
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
