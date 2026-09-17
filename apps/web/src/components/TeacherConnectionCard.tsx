"use client";

import { httpsCallable } from "firebase/functions";
import { Wifi } from "lucide-react";
import { useEffect, useState } from "react";
import { functions } from "@/lib/firebase";
import { tr } from "@/lib/i18n";
import {
  describeConnection,
  formatDuration,
  platformDrops,
  standingOf,
  tallyOf,
  type PresenceReport,
} from "@/lib/presenceReport";

type Period = "weekly" | "monthly";

const TONE: Record<string, string> = {
  steady: "bg-[#DCFCE7] text-[#166534]",
  unsettled: "bg-[#FEF3C7] text-[#92400E]",
  struggling: "bg-[#FEE2E2] text-[#991B1B]",
};

const TONE_LABEL: Record<string, string> = {
  steady: "Steady",
  unsettled: "Unsettled",
  struggling: "Struggling",
};

/**
 * A teacher's own connection during class.
 *
 * Shown to the teacher so they can act before the next lesson — move rooms, use
 * a hotspot, switch to mobile data. Everything here is their own connection:
 * interruptions we caused are counted apart and named as ours, because a
 * teacher should never read our hub restarting as their line failing.
 */
export default function TeacherConnectionCard({ uid }: { uid: string }) {
  const [period, setPeriod] = useState<Period>("weekly");
  const [report, setReport] = useState<PresenceReport | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "error">("loading");

  useEffect(() => {
    let cancelled = false;
    setState("loading");
    const callable = httpsCallable(functions, "getPresenceReport");
    callable({ uid, periodType: period })
      .then((result) => {
        if (cancelled) return;
        const data = result.data as { report?: PresenceReport | null };
        setReport(data?.report ?? null);
        setState("ready");
      })
      .catch(() => {
        if (!cancelled) setState("error");
      });
    return () => { cancelled = true; };
  }, [uid, period]);

  const tally = tallyOf(report);
  const standing = standingOf(report);
  const sentence = describeConnection(report, tr);
  const ours = platformDrops(report);

  return (
    <section className="rounded-3xl border border-[#E2E8F0] bg-white p-6">
      <header className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <span className="grid h-10 w-10 place-items-center rounded-2xl bg-[#0386FF]/10 text-[#0386FF]">
            <Wifi size={20} />
          </span>
          <div>
            <h2 className="text-lg font-extrabold text-[#111827]">{tr("Your class connection")}</h2>
            <p className="text-sm text-[#64748B]">
              {tr("How often you dropped out of class, and for how long.")}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {report ? (
            <span className={`rounded-full px-3 py-1 text-xs font-bold ${TONE[standing]}`}>
              {tr(TONE_LABEL[standing])}
            </span>
          ) : null}
          <div className="flex rounded-xl border border-[#CBD5E1] p-1">
            {(["weekly", "monthly"] as Period[]).map((option) => (
              <button
                key={option}
                type="button"
                onClick={() => setPeriod(option)}
                className={`rounded-lg px-3 py-1 text-xs font-bold ${
                  period === option ? "bg-[#0386FF] text-white" : "text-[#64748B]"
                }`}
              >
                {tr(option === "weekly" ? "This week" : "This month")}
              </button>
            ))}
          </div>
        </div>
      </header>

      {state === "loading" ? (
        <p className="mt-6 text-sm text-[#64748B]">{tr("Checking your classes...")}</p>
      ) : state === "error" ? (
        <p className="mt-6 text-sm text-[#64748B]">
          {tr("Your connection report is not available right now.")}
        </p>
      ) : !report ? (
        <p className="mt-6 text-sm text-[#64748B]">
          {tr("Nothing recorded yet. This fills in as you teach.")}
        </p>
      ) : (
        <>
          {sentence ? <p className="mt-5 text-sm leading-6 text-[#334155]">{sentence}</p> : null}

          <div className="mt-5 grid gap-4 sm:grid-cols-3">
            <Stat label={tr("Times dropped")} value={String(tally.drops)} />
            <Stat label={tr("Lesson time lost")} value={formatDuration(tally.secondsLost)} />
            <Stat label={tr("Longest single drop")} value={formatDuration(tally.longestSeconds)} />
          </div>

          {tally.neverReturned > 0 ? (
            <p className="mt-4 rounded-2xl bg-[#FEF3C7] px-4 py-3 text-sm text-[#92400E]">
              {tr("{n} class(es) ended without you getting back in.", { n: tally.neverReturned })}
            </p>
          ) : null}

          {ours > 0 ? (
            <p className="mt-4 text-sm text-[#64748B]">
              {tr("A further {n} interruption(s) came from the classroom system itself. Those are ours, and are not counted above.", { n: ours })}
            </p>
          ) : null}
        </>
      )}
    </section>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl bg-[#F8FAFC] p-4">
      <p className="text-sm text-[#64748B]">{label}</p>
      <p className="mt-1 text-2xl font-extrabold text-[#111827]">{value}</p>
    </div>
  );
}
