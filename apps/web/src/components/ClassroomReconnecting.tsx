"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { Loader2, RefreshCw } from "lucide-react";
import { formatCountdown, secondsUntil } from "@/lib/classroomReconnect";

type Translate = (en: string, vars?: Record<string, string | number>) => string;

type Props = {
  /** When the classroom should be usable again; null when that is not knowable. */
  expectedBackAt: Date | null;
  /** Try the join again. Safe to call repeatedly. */
  onRetry: () => void;
  t: Translate;
  backHref: string;
  backLabel: string;
};

/** How often to try again while there is no estimate to count down to. */
const BLIND_RETRY_MS = 15000;
/** How long to keep promising a quick return before admitting we were wrong. */
const OVERDUE_GRACE_MS = 20000;

/**
 * The waiting room for a classroom that is coming back.
 *
 * Two rules shape this. The countdown only ever runs toward a time the bot
 * actually published, because a number invented to look reassuring is a
 * promise nobody made. And it never sits at zero: when the moment passes, this
 * says so plainly and keeps trying, rather than leaving a teacher staring at
 * 0:00 wondering whether anything is still happening.
 */
export default function ClassroomReconnecting({
  expectedBackAt,
  onRetry,
  t,
  backHref,
  backLabel,
}: Props) {
  const [now, setNow] = useState(() => Date.now());
  const lastRetryRef = useRef(Date.now());
  const retryRef = useRef(onRetry);
  retryRef.current = onRetry;

  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(id);
  }, []);

  // Retrying is this component's job, so nobody has to sit and tap a button.
  useEffect(() => {
    const id = window.setInterval(() => {
      const sinceLast = Date.now() - lastRetryRef.current;
      const due = expectedBackAt
        ? Date.now() >= expectedBackAt.getTime() && sinceLast >= 5000
        : sinceLast >= BLIND_RETRY_MS;
      if (!due) return;
      lastRetryRef.current = Date.now();
      retryRef.current();
    }, 1000);
    return () => window.clearInterval(id);
  }, [expectedBackAt]);

  const remaining = secondsUntil(expectedBackAt, now);
  const overdue = Boolean(
    expectedBackAt && now > expectedBackAt.getTime() + OVERDUE_GRACE_MS,
  );
  const counting = remaining !== null && remaining > 0;

  const detail = counting
    ? t("Your class is coming back. This usually takes a couple of minutes, and it will open by itself.")
    : overdue
      ? t("This is taking longer than expected. We are still trying, and an administrator has been told.")
      : t("Your class is reconnecting. It will open by itself as soon as it is ready.");

  return (
    <div className="max-w-sm">
      <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-[#0E72ED]/20 text-[#60A5FA]">
        <Loader2 size={32} className="animate-spin" />
      </div>
      <h2 className="mt-5 text-xl font-bold">{t("Reconnecting your class")}</h2>

      {counting ? (
        <p
          className="mt-4 font-mono text-4xl font-bold tabular-nums text-white"
          aria-live="off"
        >
          {formatCountdown(remaining as number)}
        </p>
      ) : null}

      <p className="mt-3 text-sm leading-6 text-white/70" aria-live="polite">
        {detail}
      </p>

      <div className="mt-5 flex flex-wrap justify-center gap-3">
        <button
          type="button"
          onClick={() => {
            lastRetryRef.current = Date.now();
            onRetry();
          }}
          className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-[#0E72ED] px-5 text-sm font-bold text-white"
        >
          <RefreshCw size={18} />
          {t("Try now")}
        </button>
        <Link
          href={backHref}
          className="inline-flex min-h-11 items-center justify-center rounded-xl border border-white/25 px-5 text-sm font-bold text-white"
        >
          {backLabel}
        </Link>
      </div>
    </div>
  );
}
