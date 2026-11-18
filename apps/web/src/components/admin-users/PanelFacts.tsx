"use client";

import { useEffect, useState, type ReactNode } from "react";
import { isStudentType, type UserRow } from "@/lib/adminUsers";
import {
  attendanceDetail,
  attendanceText,
  localTime,
  monthAttendance,
  nextClass,
  nextClassDetail,
  nextClassText,
  owedDetail,
  owedFromInvoices,
  owedText,
  type MonthAttendance,
  type Owed,
  type PanelShift,
} from "@/lib/panelFacts";
import { loadInvoicesFor, loadStudentMonthShifts, loadUpcomingShifts } from "@/lib/usersExtrasData";

type Load<T> = { state: "loading" } | { state: "ready"; value: T } | { state: "error" };

function useLoad<T>(enabled: boolean, load: () => Promise<T>, key: string): Load<T> | null {
  const [state, setState] = useState<Load<T>>({ state: "loading" });
  useEffect(() => {
    if (!enabled) return;
    let live = true;
    setState({ state: "loading" });
    load()
      .then((value) => live && setState({ state: "ready", value }))
      .catch(() => live && setState({ state: "error" }));
    return () => {
      live = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled, key]);
  return enabled ? state : null;
}

function Fact({ label, load, render }: { label: string; load: Load<unknown> | null; render: () => { main: ReactNode; detail?: string; tone?: "warn" | "ok" } }) {
  if (!load) return null;
  let main: ReactNode;
  let detail = "";
  let tone: "warn" | "ok" | undefined;
  if (load.state === "loading") main = <span className="text-[#94A3B8]">…</span>;
  else if (load.state === "error") main = <span className="text-[#B91C1C]">Could not be loaded</span>;
  else {
    const r = render();
    main = r.main;
    detail = r.detail ?? "";
    tone = r.tone;
  }
  return (
    <div className="flex min-w-0 flex-col gap-0.5">
      <span className="text-xs text-[#64748B]">{label}</span>
      <span className={`break-words font-semibold ${tone === "warn" ? "text-[#B45309]" : ""}`}>{main}</span>
      {detail ? <span className="text-xs text-[#64748B]">{detail}</span> : null}
    </div>
  );
}

const viewerZone = () => {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
  } catch {
    return "UTC";
  }
};

/**
 * "At a glance" in the side panel (F5), read only when the panel opens:
 * amount owed (students and parents), attendance this month (students), next
 * class (students and teachers), local time (teachers).
 */
export function PanelFacts({ row }: { row: UserRow }) {
  const type = row.userType.trim().toLowerCase();
  const student = isStudentType(row);
  const parent = type === "parent";
  const teacher = type === "teacher";
  const [now] = useState(() => new Date());
  const [tick, setTick] = useState(() => new Date());
  useEffect(() => {
    if (!teacher) return;
    const id = window.setInterval(() => setTick(new Date()), 30_000);
    return () => window.clearInterval(id);
  }, [teacher]);

  const owed = useLoad<Owed>(
    student || parent,
    async () => {
      const r = await loadInvoicesFor(row.id, parent ? "parent" : "student");
      return owedFromInvoices(r.docs, new Date(), r.capped);
    },
    `owed:${row.id}`,
  );
  const attendance = useLoad<MonthAttendance>(student, async () => monthAttendance(await loadStudentMonthShifts(row.id, now), now), `att:${row.id}`);
  const upcoming = useLoad<PanelShift[]>(student || teacher, () => loadUpcomingShifts(row.id, student ? "student" : "teacher", now), `next:${row.id}`);

  if (!student && !parent && !teacher) return null;
  const local = teacher ? localTime(row.timezone, tick, viewerZone()) : null;

  return (
    <div className="flex flex-col gap-2 border-b border-[#F1F5F9] px-5 py-4" data-testid="panel-facts">
      <div className="font-bold">At a glance</div>
      <div className="grid grid-cols-2 gap-x-4 gap-y-3">
        <Fact
          label={student ? "Owed on invoices for this student" : "Amount owed"}
          load={owed}
          render={() => {
            const o = (owed as { value: Owed }).value;
            return { main: owedText(o), detail: owedDetail(o), tone: o.owed.size > 0 ? "warn" : undefined };
          }}
        />
        <Fact
          label="Attendance this month"
          load={attendance}
          render={() => {
            const a = (attendance as { value: MonthAttendance }).value;
            return { main: attendanceText(a), detail: attendanceDetail(a), tone: a.rate !== null && a.rate < 0.6 ? "warn" : undefined };
          }}
        />
        <Fact
          label="Next class"
          load={upcoming}
          render={() => {
            const n = nextClass((upcoming as { value: PanelShift[] }).value, now);
            return { main: nextClassText(n), detail: nextClassDetail(n, teacher) };
          }}
        />
        {teacher ? (
          <div className="flex min-w-0 flex-col gap-0.5">
            <span className="text-xs text-[#64748B]">Their local time</span>
            {local === null ? (
              <span className="font-semibold text-[#64748B]">No time zone on their profile</span>
            ) : "invalid" in local ? (
              <span className="font-semibold text-[#B45309]">Unknown time zone “{local.invalid}”</span>
            ) : (
              <>
                <span className="font-semibold" data-testid="teacher-local-time">
                  {local.time}
                </span>
                <span className="text-xs text-[#64748B]">
                  {local.zone} · {local.offset} · {local.relative}
                </span>
              </>
            )}
          </div>
        ) : null}
      </div>
      {student ? <span className="text-[11px] text-[#94A3B8]">Attendance: classes attended out of attended, missed and cancelled, as on the parent&apos;s Progress tab.</span> : null}
    </div>
  );
}
