"use client";

import { useEffect, useMemo, useState } from "react";
import { Globe2, Plus, Search, StickyNote, Trash2, Users } from "lucide-react";
import { ActionButton } from "@/components/ActionButton";
import { TIME_BLOCKS, blockRangeLabel, normalizeBlock } from "@/lib/enrollmentDomain";
import { broadcastProblem, formatSlot, slotProblem, sortSlots } from "@/lib/broadcastSlots";
import { loadBroadcastTeachers, type BroadcastInput, type TeacherOption } from "@/lib/jobBoardAdmin";

const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

/**
 * The last look before teachers see a request.
 *
 * Admin can correct the days, the exact slots, the window and the timezone the
 * times are stated in, add a note, and choose whether every teacher sees it or
 * only named ones. What the family originally asked for is kept separately, so
 * an edit here never overwrites the record of the request.
 */
export function PrepareBroadcastDialog({
  studentName,
  subject,
  familyNotes,
  initial,
  onBroadcast,
  onClose,
}: {
  studentName: string;
  subject: string;
  familyNotes: string;
  initial: { days: string[]; timeSlots: string[]; block: string; timeZone: string };
  onBroadcast: (input: BroadcastInput) => Promise<void>;
  onClose: () => void;
}) {
  const [days, setDays] = useState<string[]>(initial.days);
  const [slots, setSlots] = useState<string[]>(sortSlots(initial.timeSlots));
  const [block, setBlock] = useState(normalizeBlock(initial.block) ?? "");
  const [timezoneRef, setTimezoneRef] = useState(initial.timeZone);
  const [notes, setNotes] = useState("");
  const [start, setStart] = useState("");
  const [end, setEnd] = useState("");
  const [slotError, setSlotError] = useState("");
  const [everyone, setEveryone] = useState(true);
  const [teachers, setTeachers] = useState<TeacherOption[]>([]);
  const [teacherSearch, setTeacherSearch] = useState("");
  const [picked, setPicked] = useState<Set<string>>(new Set());
  const [loadingTeachers, setLoadingTeachers] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (everyone || teachers.length > 0) return;
    setLoadingTeachers(true);
    loadBroadcastTeachers()
      .then(setTeachers)
      .catch((issue) => setError(issue instanceof Error ? issue.message : "Could not load teachers."))
      .finally(() => setLoadingTeachers(false));
  }, [everyone, teachers.length]);

  const visibleTeachers = useMemo(() => {
    const needle = teacherSearch.trim().toLowerCase();
    if (!needle) return teachers;
    return teachers.filter((t) => `${t.name} ${t.email}`.toLowerCase().includes(needle));
  }, [teachers, teacherSearch]);

  const toggleDay = (day: string) =>
    setDays((current) => (current.includes(day) ? current.filter((d) => d !== day) : [...current, day]));

  const addSlot = () => {
    const startMinutes = start ? hhmmToMinutes(start) : null;
    const endMinutes = end ? hhmmToMinutes(end) : null;
    const problem = slotProblem(startMinutes, endMinutes, slots);
    if (problem) {
      setSlotError(problem);
      return;
    }
    setSlots((current) => sortSlots([...current, formatSlot(startMinutes!, endMinutes!)]));
    setStart("");
    setEnd("");
    setSlotError("");
  };

  const blocked = broadcastProblem(days, slots) ?? (!everyone && picked.size === 0 ? "Choose at least one teacher, or broadcast to everyone." : null);

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true" aria-label="Prepare and broadcast">
      <div className="flex max-h-[90vh] w-full max-w-[620px] flex-col overflow-hidden rounded-2xl bg-white shadow-[0_24px_60px_rgba(0,0,0,0.32)]">
        <header className="shrink-0 border-b border-[#E5E7EB] px-5 py-4">
          <h2 className="text-lg font-bold text-[#111827]">Prepare &amp; broadcast</h2>
          <p className="mt-0.5 text-xs text-[#64748B]">
            Review and adjust the schedule before teachers see it · {studentName}
            {subject ? ` · ${subject}` : ""}
          </p>
        </header>

        <div className="min-h-0 flex-1 space-y-4 overflow-y-auto px-5 py-4">
          {familyNotes ? (
            <section className="rounded-lg border border-[#E2E8F0] bg-[#F8FAFC] p-3">
              <div className="flex items-center gap-1.5">
                <StickyNote size={15} className="text-[#64748B]" />
                <p className="text-[11px] font-bold text-[#475569]">Parent / student notes</p>
              </div>
              <p className="mt-1 whitespace-pre-wrap text-xs leading-5 text-[#334155]">{familyNotes}</p>
            </section>
          ) : null}

          <section>
            <p className="text-[11px] font-bold text-[#1E293B]">Days</p>
            <div className="mt-1.5 flex flex-wrap gap-1.5">
              {DAYS.map((day) => {
                const on = days.includes(day);
                return (
                  <button
                    key={day}
                    type="button"
                    aria-pressed={on}
                    onClick={() => toggleDay(day)}
                    className={`min-h-[32px] rounded-lg px-3 text-xs font-semibold transition ${
                      on ? "bg-gradient-to-r from-[#3B82F6] to-[#2563EB] text-white" : "bg-[#F1F5F9] text-[#64748B]"
                    }`}
                  >
                    {day}
                  </button>
                );
              })}
            </div>
          </section>

          <section>
            <p className="text-[11px] font-bold text-[#1E293B]">Time slots</p>
            {slots.length === 0 ? (
              <p className="mt-1 text-[11px] text-[#B45309]">
                No time slots specified. Add at least one so teachers know when.
              </p>
            ) : (
              <ul className="mt-1.5 grid gap-1.5">
                {slots.map((slot) => (
                  <li key={slot} className="flex items-center gap-2 rounded-lg border border-[#E2E8F0] px-2.5 py-1.5">
                    <span className="flex-1 text-xs font-semibold text-[#1E293B]">{slot}</span>
                    <button
                      type="button"
                      aria-label={`Remove ${slot}`}
                      onClick={() => setSlots((current) => current.filter((item) => item !== slot))}
                      className="grid h-6 w-6 place-items-center rounded text-[#94A3B8] hover:bg-[#FEE2E2] hover:text-[#DC2626]"
                    >
                      <Trash2 size={14} />
                    </button>
                  </li>
                ))}
              </ul>
            )}

            <div className="mt-2 flex flex-wrap items-center gap-2">
              <label className="sr-only" htmlFor="slot-start">Start time</label>
              <input
                id="slot-start"
                type="time"
                value={start}
                onChange={(event) => setStart(event.target.value)}
                className="h-9 rounded-lg border border-[#E2E8F0] px-2 text-xs text-[#111827]"
              />
              <span className="text-xs text-[#64748B]">to</span>
              <label className="sr-only" htmlFor="slot-end">End time</label>
              <input
                id="slot-end"
                type="time"
                value={end}
                onChange={(event) => setEnd(event.target.value)}
                className="h-9 rounded-lg border border-[#E2E8F0] px-2 text-xs text-[#111827]"
              />
              <button
                type="button"
                onClick={addSlot}
                className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-[#BFDBFE] bg-[#EFF6FF] px-3 text-xs font-semibold text-[#1D4ED8]"
              >
                <Plus size={15} />
                Add slot
              </button>
            </div>
            {slotError ? <p className="mt-1.5 text-[11px] font-semibold text-[#DC2626]">{slotError}</p> : null}
          </section>

          <section>
            <p className="text-[11px] font-bold text-[#1E293B]">General preference</p>
            <div className="mt-1.5 flex flex-wrap gap-1.5">
              {TIME_BLOCKS.map((option) => {
                const on = block === option.id;
                return (
                  <button
                    key={option.id}
                    type="button"
                    aria-pressed={on}
                    onClick={() => setBlock(on ? "" : option.id)}
                    className={`rounded-lg border-[1.5px] px-2.5 py-1.5 text-left text-[11px] transition ${
                      on ? "border-[#4F46E5] bg-[#EEF2FF] font-bold text-[#4338CA]" : "border-[#E2E8F0] bg-[#FAFBFC] font-medium text-[#475569]"
                    }`}
                  >
                    {option.label}
                    <span className="mt-0.5 block text-[9px] text-[#94A3B8]">{blockRangeLabel(option)}</span>
                  </button>
                );
              })}
            </div>
          </section>

          <section>
            <label htmlFor="timezone-ref" className="flex items-center gap-1.5 text-[11px] font-bold text-[#1E293B]">
              <Globe2 size={14} className="text-[#3B82F6]" />
              The times above are in
            </label>
            <input
              id="timezone-ref"
              value={timezoneRef}
              onChange={(event) => setTimezoneRef(event.target.value)}
              className="mt-1 h-9 w-full rounded-lg border border-[#E2E8F0] px-2.5 text-xs text-[#111827]"
            />
            <p className="mt-1 text-[10px] text-[#64748B]">
              Student&apos;s timezone from the form. Edit if you know it&apos;s different.
            </p>
          </section>

          <section>
            <label htmlFor="admin-notes" className="text-[11px] font-bold text-[#1E293B]">Notes for teachers</label>
            <textarea
              id="admin-notes"
              rows={2}
              value={notes}
              onChange={(event) => setNotes(event.target.value)}
              placeholder='Optional notes visible to teachers (e.g. "Parent prefers afternoon, exact times flexible")'
              className="mt-1 w-full rounded-lg border border-[#E2E8F0] px-2.5 py-2 text-xs text-[#111827] placeholder:text-[#9CA3AF]"
            />
          </section>

          <section>
            <p className="flex items-center gap-1.5 text-[11px] font-bold text-[#1E293B]">
              <Users size={14} className="text-[#64748B]" />
              Broadcast to
            </p>
            <div className="mt-1.5 grid gap-1.5">
              {[
                { value: true, label: "All teachers" },
                { value: false, label: "Specific teachers" },
              ].map((option) => (
                <label key={String(option.value)} className="flex items-center gap-2 text-xs font-medium text-[#334155]">
                  <input
                    type="radio"
                    name="broadcast-audience"
                    checked={everyone === option.value}
                    onChange={() => setEveryone(option.value)}
                    className="h-[18px] w-[18px] accent-[#3B82F6]"
                  />
                  {option.label}
                </label>
              ))}
            </div>

            {!everyone ? (
              <div className="mt-2 rounded-lg border border-[#E2E8F0]">
                <div className="relative border-b border-[#E2E8F0]">
                  <Search size={15} className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-[#9CA3AF]" />
                  <input
                    value={teacherSearch}
                    onChange={(event) => setTeacherSearch(event.target.value)}
                    placeholder="Search teachers..."
                    aria-label="Search teachers"
                    className="h-9 w-full rounded-t-lg pl-8 pr-2 text-xs text-[#111827] placeholder:text-[#9CA3AF]"
                  />
                </div>
                <div className="max-h-44 overflow-y-auto">
                  {loadingTeachers ? (
                    <p className="px-3 py-3 text-[11px] text-[#64748B]">Loading teachers…</p>
                  ) : visibleTeachers.length === 0 ? (
                    <p className="px-3 py-3 text-[11px] text-[#64748B]">No teachers found</p>
                  ) : (
                    visibleTeachers.map((teacher) => (
                      <label key={teacher.id} className="flex items-center gap-2 border-b border-[#F1F5F9] px-3 py-2 last:border-0">
                        <input
                          type="checkbox"
                          checked={picked.has(teacher.id)}
                          onChange={(event) =>
                            setPicked((current) => {
                              const next = new Set(current);
                              if (event.target.checked) next.add(teacher.id);
                              else next.delete(teacher.id);
                              return next;
                            })
                          }
                          className="h-4 w-4 accent-[#3B82F6]"
                        />
                        <span className="min-w-0 flex-1">
                          <span className="block truncate text-xs font-semibold text-[#1E293B]">{teacher.name}</span>
                          {teacher.email ? <span className="block truncate text-[10px] text-[#64748B]">{teacher.email}</span> : null}
                        </span>
                      </label>
                    ))
                  )}
                </div>
                {picked.size > 0 ? (
                  <p className="border-t border-[#E2E8F0] px-3 py-1.5 text-[11px] font-semibold text-[#1D4ED8]">
                    {picked.size} selected
                  </p>
                ) : null}
              </div>
            ) : null}
          </section>

          {error ? <p role="alert" className="text-xs font-semibold text-[#DC2626]">{error}</p> : null}
        </div>

        <footer className="shrink-0 border-t border-[#E5E7EB] px-5 py-3">
          {blocked ? <p className="mb-2 text-[11px] font-semibold text-[#B45309]">{blocked}</p> : null}
          <div className="flex items-center gap-3">
            <span className="flex-1" />
            <button type="button" onClick={onClose} className="px-3 py-2 text-sm font-semibold text-[#475569]">
              Cancel
            </button>
            <ActionButton
              label="Broadcast to teachers"
              busyLabel="Broadcasting…"
              disabled={Boolean(blocked)}
              onAction={async () => {
                setError("");
                try {
                  await onBroadcast({
                    days,
                    timeSlots: slots,
                    timeOfDay: block,
                    timezoneRef,
                    adminNotesForTeachers: notes,
                    targetTeacherIds: everyone ? [] : [...picked],
                    targetTeacherNames: everyone
                      ? []
                      : teachers.filter((t) => picked.has(t.id)).map((t) => t.name),
                  });
                } catch (issue) {
                  setError(issue instanceof Error ? issue.message : "Could not broadcast.");
                }
              }}
            />
          </div>
        </footer>
      </div>
    </div>
  );
}

/** `<input type="time">` gives 24-hour "HH:MM". */
function hhmmToMinutes(value: string): number | null {
  const match = value.match(/^(\d{2}):(\d{2})$/);
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

export { hhmmToMinutes };
