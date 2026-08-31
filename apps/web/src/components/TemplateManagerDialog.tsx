"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { CalendarCheck, CalendarOff, CalendarSync, ChevronDown, Loader2, Pause, Pencil, Play, Search, X } from "lucide-react";
import { ActionButton } from "@/components/ActionButton";
import { PersonSelectDialog, type PersonOption } from "@/components/PersonSelect";
import type { StaffMember } from "@/lib/shifts";
import {
  type PausableShift,
  type TemplateRecord,
  cancelShiftsForPause,
  clearTemplatePause,
  findOneOffShiftsInPauseWindow,
  restoreShiftsFromPause,
  deactivateTemplate,
  loadTemplates,
  pauseTemplateForPeriod,
  reactivateTemplate,
  reassignTemplate,
  updateTemplateDays,
} from "@/lib/templates";

/**
 * Port of the Flutter TemplateManagementDialog: every recurring rule, grouped
 * by teacher + student the way Flutter groups them, with the weekdays each
 * rule generates on. Admins can change the days/time, hand the series to
 * another teacher, or pause generation entirely.
 */

const WEEKDAYS: { iso: number; label: string }[] = [
  { iso: 1, label: "Mon" },
  { iso: 2, label: "Tue" },
  { iso: 3, label: "Wed" },
  { iso: 4, label: "Thu" },
  { iso: 5, label: "Fri" },
  { iso: 6, label: "Sat" },
  { iso: 7, label: "Sun" },
];

type Group = {
  key: string;
  teacherId: string;
  teacherName: string;
  studentName: string;
  studentIds: string[];
  subject: string;
  startTime: string;
  endTime: string;
  isActive: boolean;
  pauseStart: string;
  pauseEnd: string;
  timezone: string;
  templateIds: string[];
  /** weekday -> the template that generates it */
  weekdayOwner: Map<number, string>;
};

function groupTemplates(rows: TemplateRecord[], search: string): Group[] {
  const q = search.trim().toLowerCase();
  const map = new Map<string, Group>();
  for (const t of rows) {
    if (q) {
      const hit =
        t.teacherName.toLowerCase().includes(q) || t.studentNames.some((n) => n.toLowerCase().includes(q));
      if (!hit) continue;
    }
    const students = t.studentNames.length ? t.studentNames : [""];
    for (const studentName of students) {
      const key = `${t.teacherName}|${studentName}|${t.startTime}`;
      let group = map.get(key);
      if (!group) {
        group = {
          key,
          teacherId: t.teacherId,
          teacherName: t.teacherName,
          studentName,
          studentIds: t.studentIds,
          subject: t.subjectDisplayName,
          startTime: t.startTime,
          endTime: t.endTime,
          isActive: t.isActive,
          pauseStart: t.pauseStart,
          pauseEnd: t.pauseEnd,
          timezone: t.adminTimezone,
          templateIds: [],
          weekdayOwner: new Map(),
        };
        map.set(key, group);
      }
      group.templateIds.push(t.id);
      for (const day of t.weekdays) group.weekdayOwner.set(day, t.id);
    }
  }
  return [...map.values()].sort(
    (a, b) => a.teacherName.localeCompare(b.teacherName) || a.studentName.localeCompare(b.studentName),
  );
}

/** Day after a yyyy-mm-dd date — the pause window is inclusive of its end. */
function nextDay(day: string): string {
  const [y, m, d] = day.split("-").map(Number);
  const next = new Date(Date.UTC(y, m - 1, d + 1));
  return next.toISOString().slice(0, 10);
}

function to12h(hm: string): string {
  const [h, m] = hm.split(":").map(Number);
  if (!Number.isFinite(h)) return hm;
  const period = h >= 12 ? "PM" : "AM";
  const hour = h % 12 === 0 ? 12 : h % 12;
  return `${hour}:${String(m ?? 0).padStart(2, "0")} ${period}`;
}

export function TemplateManagerDialog({
  staff,
  adminName,
  studentCodeById,
  onOpenSeries,
  onClose,
  onChanged,
}: {
  staff: StaffMember[];
  adminName: string;
  studentCodeById?: Map<string, string>;
  /** Hands off to the one series editor — no second edit UI in here. */
  onOpenSeries: (templateId: string) => void;
  onClose: () => void;
  onChanged: () => void;
}) {
  const [rows, setRows] = useState<TemplateRecord[] | null>(null);
  const [search, setSearch] = useState("");
  const [teacherFilter, setTeacherFilter] = useState("");
  const [showInactive, setShowInactive] = useState(false);
  const [busyKey, setBusyKey] = useState("");
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");
  const [pausing, setPausing] = useState<Group | null>(null);
  const [pauseFrom, setPauseFrom] = useState("");
  const [pauseTo, setPauseTo] = useState("");
  const [pickerFor, setPickerFor] = useState<null | "filter">(null);
  const [oneOffs, setOneOffs] = useState<PausableShift[] | null>(null);
  const [scanning, setScanning] = useState(false);

  const refresh = useCallback(async () => {
    try {
      setRows(await loadTemplates({ teacherId: teacherFilter || null, activeOnly: !showInactive }));
      setError("");
    } catch {
      setError("Could not load templates.");
      setRows([]);
    }
  }, [teacherFilter, showInactive]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const groups = useMemo(() => (rows ? groupTemplates(rows, search) : []), [rows, search]);

  // A break covers every class in the window, so show the hand-made ones that
  // will be cancelled alongside the generated ones before anything is applied.
  useEffect(() => {
    if (!pausing || !pauseFrom) {
      setOneOffs(null);
      return;
    }
    let alive = true;
    setScanning(true);
    findOneOffShiftsInPauseWindow(pausing.teacherId, pausing.studentIds, pauseFrom, pauseTo, pausing.timezone)
      .then((found) => {
        if (alive) setOneOffs(found);
      })
      .catch(() => {
        if (alive) setOneOffs([]);
      })
      .finally(() => {
        if (alive) setScanning(false);
      });
    return () => {
      alive = false;
    };
  }, [pausing, pauseFrom, pauseTo]);

  const run = async (key: string, work: () => Promise<void>, message: string) => {
    setBusyKey(key);
    setError("");
    try {
      await work();
      setToast(message);
      await refresh();
      onChanged();
    } catch (err) {
      setError(err instanceof Error ? err.message : "That action failed.");
    } finally {
      setBusyKey("");
    }
  };

  const savePause = async () => {
    if (!pausing) return;
    await run(
      pausing.key,
      async () => {
        for (const templateId of pausing.templateIds) {
          await pauseTemplateForPeriod(templateId, pauseFrom, pauseTo, pausing.timezone);
        }
        // One-off classes are not regenerated, so cancel them explicitly.
        const extra = oneOffs ?? [];
        if (extra.length) {
          await cancelShiftsForPause(extra.map((s) => s.id), pausing.templateIds[0], adminName);
        }
      },
      pauseTo
        ? `Paused through ${pauseTo}. Classes resume automatically on ${nextDay(pauseTo)}.`
        : "Paused from that date until you resume it.",
    );
    setPausing(null);
  };

  return (
    <div className="fixed inset-0 z-[70] grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true">
      <div className="flex max-h-[90vh] w-full max-w-3xl flex-col overflow-hidden rounded-2xl bg-white shadow-2xl">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] px-6 py-4">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#EAF5FF] text-[#0386FF]">
            <CalendarSync size={18} />
          </span>
          <div className="min-w-0 flex-1">
            <h2 className="text-lg font-bold text-[#0F172A]">Repeating classes</h2>
            <p className="text-xs text-[#64748B]">Every class that repeats, including ones paused or stopped</p>
          </div>
          <button type="button" onClick={onClose} className="grid h-8 w-8 place-items-center rounded-full text-[#334155] hover:bg-[#F1F5F9]" aria-label="Close">
            <X size={18} />
          </button>
        </header>

        {pausing ? (
          <div className="space-y-3 px-6 py-5">
            <p className="text-sm font-bold text-[#111827]">Pause this repeating class</p>
            <p className="text-xs text-[#64748B]">
              {pausing.teacherName}
              {pausing.studentName ? ` · ${pausing.studentName}` : ""}
            </p>
            <div className="grid grid-cols-2 gap-3">
              <label className="text-xs font-bold uppercase tracking-wide text-[#64748B]">
                First day off
                <input
                  type="date"
                  value={pauseFrom}
                  onChange={(event) => setPauseFrom(event.target.value)}
                  className="mt-1 w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm font-normal normal-case tracking-normal text-[#0F172A]"
                />
              </label>
              <label className="text-xs font-bold uppercase tracking-wide text-[#64748B]">
                Last day off
                <input
                  type="date"
                  value={pauseTo}
                  onChange={(event) => setPauseTo(event.target.value)}
                  className="mt-1 w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm font-normal normal-case tracking-normal text-[#0F172A]"
                />
              </label>
            </div>
            <p className="rounded-xl border border-[#BFDBFE] bg-[#EFF6FF] px-3.5 py-2.5 text-xs font-semibold text-[#1D4ED8]">
              {pauseTo
                ? `No classes from ${pauseFrom || "…"} through ${pauseTo}. They start again on their own on ${nextDay(pauseTo)} — you don't have to come back and switch it on.`
                : "Leave the last day empty to pause until you resume it yourself."}
            </p>
            <div className="rounded-xl border border-[#E2E8F0] px-3.5 py-2.5 text-xs text-[#64748B]">
              <p className="font-bold text-[#111827]">What this covers</p>
              <p className="mt-1">· Generated classes in the window are removed and come back when the pause ends.</p>
              {!pauseFrom ? (
                <p className="mt-1">· Pick the dates to see any one-off classes that are also affected.</p>
              ) : scanning ? (
                <p className="mt-1 flex items-center gap-1.5">
                  <Loader2 size={11} className="animate-spin" />
                  Checking for one-off classes in that window…
                </p>
              ) : oneOffs && oneOffs.length > 0 ? (
                <>
                  <p className="mt-1 font-semibold text-[#C2410C]">
                    · {oneOffs.length} one-off class{oneOffs.length === 1 ? "" : "es"} booked by hand will be cancelled
                    too (restored if you lift the pause):
                  </p>
                  <ul className="mt-1 space-y-0.5 pl-3">
                    {oneOffs.slice(0, 5).map((s) => (
                      <li key={s.id}>· {s.start.toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" })} — {s.title}</li>
                    ))}
                    {oneOffs.length > 5 ? <li>· + {oneOffs.length - 5} more</li> : null}
                  </ul>
                </>
              ) : (
                <p className="mt-1">· No one-off classes in that window.</p>
              )}
              <p className="mt-1">· Completed and in-progress classes are never touched.</p>
            </div>
            {error ? (
              <p className="rounded-xl border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#B91C1C]">{error}</p>
            ) : null}
            <div className="flex items-center gap-2 pt-1">
              <button type="button" onClick={() => setPausing(null)} className="rounded-xl px-4 py-2 text-sm font-semibold text-[#64748B]">
                Back
              </button>
              <ActionButton
                variant="primary"
                className="ml-auto"
                label="Pause it"
                busyLabel="Pausing…"
                disabled={busyKey !== "" || !pauseFrom}
                onAction={() => savePause()}
              />
            </div>
          </div>
        ) : (
          <>
            <div className="flex flex-wrap items-center gap-2 border-b border-[#E2E8F0] px-6 py-3">
              <label className="flex min-w-[180px] flex-1 items-center gap-2 rounded-xl border border-[#E2E8F0] px-3 py-2">
                <Search size={14} className="shrink-0 text-[#94A3B8]" />
                <input
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                  placeholder="Search teacher or student"
                  className="w-full bg-transparent text-sm outline-none"
                />
              </label>
              <button
                type="button"
                onClick={() => setPickerFor("filter")}
                className="flex min-w-[150px] items-center gap-2 rounded-xl border border-[#E2E8F0] px-3 py-2 text-left text-sm"
              >
                <span className="min-w-0 flex-1 truncate">
                  {staff.find((m) => m.id === teacherFilter)?.displayName ?? "All teachers"}
                </span>
                <ChevronDown size={14} className="shrink-0 text-[#6B7280]" />
              </button>
              <label className="flex items-center gap-2 text-sm font-semibold text-[#374151]">
                <input type="checkbox" checked={showInactive} onChange={(event) => setShowInactive(event.target.checked)} />
                Show paused
              </label>
            </div>

            <div className="min-h-0 flex-1 overflow-y-auto px-4 py-3">
              {rows === null ? (
                <p className="px-2 py-6 text-center text-sm text-[#64748B]">Loading templates…</p>
              ) : groups.length === 0 ? (
                <p className="px-2 py-6 text-center text-sm text-[#64748B]">No repeat patterns match.</p>
              ) : (
                groups.map((group) => {
                  const days = [...group.weekdayOwner.keys()].sort((a, b) => a - b);
                  const busy = busyKey === group.key;
                  return (
                    <div
                      key={group.key}
                      className={`mb-2 rounded-xl border px-3.5 py-3 ${
                        group.isActive ? "border-[#E2E8F0] bg-white" : "border-[#E2E8F0] bg-[#F8FAFC]"
                      }`}
                    >
                      <div className="flex items-start gap-3">
                        <span className="min-w-0 flex-1">
                          <span className="flex flex-wrap items-center gap-2">
                            <span className={`text-sm font-bold ${group.isActive ? "text-[#111827]" : "text-[#94A3B8]"}`}>
                              {group.teacherName}
                            </span>
                            {group.studentName ? (
                              <span className="text-xs text-[#64748B]">
                                · {group.studentName}
                                {group.studentIds.length === 1 && studentCodeById?.get(group.studentIds[0])
                                  ? ` (${studentCodeById.get(group.studentIds[0])})`
                                  : ""}
                              </span>
                            ) : null}
                            {!group.isActive ? (
                              <span className="rounded-full bg-[#F1F5F9] px-2 py-0.5 text-[10px] font-bold uppercase text-[#64748B]">
                                Stopped
                              </span>
                            ) : group.pauseStart ? (
                              <span className="rounded-full bg-[#FFF7ED] px-2 py-0.5 text-[10px] font-bold text-[#C2410C]">
                                {group.pauseEnd
                                  ? `Paused thru ${group.pauseEnd} → resumes ${nextDay(group.pauseEnd)}`
                                  : `Paused from ${group.pauseStart}`}
                              </span>
                            ) : null}
                          </span>
                          <span className="block text-xs text-[#64748B]">
                            {group.subject ? `${group.subject} · ` : ""}
                            {group.startTime ? `${to12h(group.startTime)} – ${to12h(group.endTime)}` : "No time set"}
                            {group.templateIds.length > 1 ? ` · ${group.templateIds.length} rules` : ""}
                          </span>
                        </span>
                        <div className="flex shrink-0 items-center gap-1">
                          <button
                            type="button"
                            onClick={() => onOpenSeries(group.templateIds[0])}
                            title="Open it to edit"
                            className="inline-flex h-8 items-center gap-1.5 rounded-lg px-2.5 text-xs font-bold text-[#0386FF] hover:bg-[#EAF5FF]"
                          >
                            <Pencil size={13} />
                            Edit
                          </button>
                          {group.isActive ? (
                            group.pauseStart ? (
                              <button
                                type="button"
                                disabled={busy}
                                onClick={() =>
                                  void run(
                                    group.key,
                                    async () => {
                                      for (const id of group.templateIds) await clearTemplatePause(id);
                                      await restoreShiftsFromPause(group.templateIds[0]);
                                    },
                                    "Pause cleared — classes are back on the calendar.",
                                  )
                                }
                                title="Resume now (clear the pause)"
                                className="grid h-8 w-8 place-items-center rounded-lg text-[#059669] hover:bg-[#ECFDF5] disabled:opacity-50"
                              >
                                <CalendarCheck size={15} />
                              </button>
                            ) : (
                              <button
                                type="button"
                                disabled={busy}
                                onClick={() => {
                                  setPausing(group);
                                  setPauseFrom("");
                                  setPauseTo("");
                                  setError("");
                                }}
                                title="Pause for a period"
                                className="grid h-8 w-8 place-items-center rounded-lg text-[#C2410C] hover:bg-[#FFF7ED] disabled:opacity-50"
                              >
                                <CalendarOff size={15} />
                              </button>
                            )
                          ) : null}
                          <ActionButton
                            variant="subtle"
                            className="px-2.5 py-1.5 text-xs"
                            label={group.isActive ? "Stop" : "Start again"}
                            busyLabel={group.isActive ? "Stopping…" : "Starting…"}
                            title={group.isActive ? "Stop repeating (no end date)" : "Start repeating again"}
                            disabled={busy}
                            onAction={() =>
                              run(
                                group.key,
                                async () => {
                                  for (const id of group.templateIds) {
                                    if (group.isActive) await deactivateTemplate(id);
                                    else await reactivateTemplate(id);
                                  }
                                },
                                group.isActive
                                  ? "Stopped repeating — no new classes will be created."
                                  : "Repeating again — future classes will be created.",
                              )
                            }
                          />
                        </div>
                      </div>
                      <div className="mt-2 flex flex-wrap gap-1.5">
                        {WEEKDAYS.map((day) => {
                          const on = days.includes(day.iso);
                          return (
                            <span
                              key={day.iso}
                              className={`rounded-full px-2 py-0.5 text-[10px] font-bold ${
                                on ? "bg-[#EAF5FF] text-[#0386FF]" : "bg-[#F8FAFC] text-[#CBD5E1]"
                              }`}
                            >
                              {day.label}
                            </span>
                          );
                        })}
                      </div>
                    </div>
                  );
                })
              )}
            </div>

            {error ? (
              <p className="mx-6 mb-3 rounded-xl border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#B91C1C]">{error}</p>
            ) : null}
            {toast ? <p className="mx-6 mb-3 text-xs font-semibold text-[#059669]">{toast}</p> : null}

            <footer className="flex justify-end border-t border-[#E2E8F0] px-6 py-3.5">
              <button type="button" onClick={onClose} className="rounded-xl px-4 py-2 text-sm font-semibold text-[#64748B]">
                Done
              </button>
            </footer>
          </>
        )}
      </div>
    </div>
  );
}
