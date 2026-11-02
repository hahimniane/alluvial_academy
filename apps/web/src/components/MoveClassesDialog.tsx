"use client";

import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, ArrowDownUp, Loader2, Undo2, X } from "lucide-react";
import { ActionButton } from "@/components/ActionButton";
import { PersonPickerField, PersonSelectDialog, type PersonOption } from "@/components/PersonSelect";
import type { StaffMember, StudentOption } from "@/lib/shifts";
import { timezoneAbbreviation } from "@/lib/timezones";
import {
  type MovePick,
  type MovePlan,
  type MoveRecord,
  applyMove,
  describeMinutes,
  listMoves,
  moveErrorMessage,
  previewMove,
  undoMove,
} from "@/lib/moveClasses";

const AMOUNTS = [
  { minutes: 30, label: "30 min" },
  { minutes: 60, label: "1 hour" },
  { minutes: 90, label: "1 h 30" },
  { minutes: 120, label: "2 hours" },
];

/**
 * Move classes earlier or later — every class of a teacher, every class of a
 * student (any teacher), or one teacher's classes with one student. Shows
 * exactly what moves and what it would collide with before anything changes.
 */
export function MoveClassesDialog({
  staff,
  students,
  onClose,
  onChanged,
}: {
  staff: StaffMember[];
  students: StudentOption[];
  onClose: () => void;
  onChanged: () => void;
}) {
  const [picker, setPicker] = useState<"teacher" | "student" | null>(null);
  const [teacherId, setTeacherId] = useState<string | null>(null);
  const [studentId, setStudentId] = useState<string | null>(null);
  const [direction, setDirection] = useState<-1 | 1>(-1);
  const [amount, setAmount] = useState(60);
  const [plan, setPlan] = useState<MovePlan | null>(null);
  const [pick, setPick] = useState<MovePick | null>(null);
  const [scanning, setScanning] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");
  const [moves, setMoves] = useState<MoveRecord[] | null>(null);

  const minutes = direction * amount;
  const teacher = staff.find((s) => s.id === teacherId) ?? null;
  const student = students.find((s) => s.id === studentId) ?? null;

  const staffOptions: PersonOption[] = useMemo(
    () => staff.map((s) => ({ id: s.id, name: s.displayName, email: s.email })),
    [staff],
  );
  const studentOptions: PersonOption[] = useMemo(
    () => students.map((s) => ({ id: s.id, name: s.displayName, email: s.email, code: s.studentCode, isStudent: true })),
    [students],
  );

  const refreshMoves = () => {
    listMoves()
      .then(setMoves)
      .catch(() => setMoves([]));
  };
  useEffect(refreshMoves, []);

  // A new person or amount starts from "everything ticked".
  useEffect(() => {
    setPick(null);
  }, [teacherId, studentId, minutes]);

  const pickKey = pick ? `${pick.templateIds.join(",")}|${pick.shiftIds.join(",")}` : "all";
  useEffect(() => {
    if (!teacherId && !studentId) {
      setPlan(null);
      return;
    }
    let alive = true;
    setScanning(true);
    setError("");
    previewMove({ teacherId, studentId, minutes }, pick)
      .then((result) => alive && setPlan(result))
      .catch((err) => {
        if (!alive) return;
        setPlan(null);
        setError(moveErrorMessage(err, "Could not look up those classes."));
      })
      .finally(() => alive && setScanning(false));
    return () => {
      alive = false;
    };
    // pickKey stands in for pick
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [teacherId, studentId, minutes, pickKey]);

  const currentPick = (): MovePick => ({
    templateIds: (plan?.schedules ?? []).filter((s) => s.selected).map((s) => s.id),
    shiftIds: (plan?.singles ?? []).filter((s) => s.selected).map((s) => s.id),
  });
  const toggle = (kind: "templateIds" | "shiftIds", id: string, on: boolean) => {
    const next = currentPick();
    next[kind] = on ? [...next[kind], id] : next[kind].filter((x) => x !== id);
    setPick(next);
  };

  const selectedSchedules = plan?.schedules.filter((s) => s.selected) ?? [];
  const selectedSingles = plan?.singles.filter((s) => s.selected) ?? [];
  const blocked = (plan?.teacherConflicts.length ?? 0) > 0;
  const nothing = selectedSchedules.length === 0 && selectedSingles.length === 0;

  const scopeText = teacher && student
    ? `Only ${teacher.displayName}'s classes with ${student.displayName}.`
    : teacher
      ? `Every class ${teacher.displayName} teaches.`
      : student
        ? `Every class ${student.displayName} takes, with any teacher.`
        : "Pick a teacher, a student, or both.";

  const apply = async () => {
    if (!plan) return;
    setBusy(true);
    setError("");
    try {
      const result = await applyMove({ teacherId, studentId, minutes }, currentPick());
      const parts = [
        result.schedules ? `${result.schedules} weekly class${result.schedules === 1 ? "" : "es"}` : "",
        result.classesMovedInPlace ? `${result.classesMovedInPlace} single class${result.classesMovedInPlace === 1 ? "" : "es"}` : "",
      ].filter(Boolean);
      setToast(`Moved ${describeMinutes(minutes)}: ${parts.join(" and ") || "nothing to move"}.`);
      setTeacherId(null);
      setStudentId(null);
      setPlan(null);
      refreshMoves();
      onChanged();
    } catch (err) {
      setError(moveErrorMessage(err, "Could not move the classes."));
    } finally {
      setBusy(false);
    }
  };

  const undo = async (record: MoveRecord) => {
    setBusy(true);
    setError("");
    try {
      await undoMove(record.id);
      setToast(`Undone: ${record.label} is back to its previous time.`);
      refreshMoves();
      onChanged();
    } catch (err) {
      setError(moveErrorMessage(err, "Could not undo that move."));
    } finally {
      setBusy(false);
    }
  };

  const zoneLabel = (zone: string) => timezoneAbbreviation(zone);

  return (
    <div className="fixed inset-0 z-[70] grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true">
      <div className="flex max-h-[90vh] w-full max-w-2xl flex-col overflow-hidden rounded-2xl bg-white shadow-2xl">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] px-6 py-4">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#EEF2FF] text-[#4F46E5]">
            <ArrowDownUp size={18} />
          </span>
          <div className="min-w-0 flex-1">
            <h2 className="text-lg font-bold text-[#0F172A]">Move classes earlier or later</h2>
            <p className="text-xs text-[#64748B]">For daylight saving, or when someone&apos;s clock changes</p>
          </div>
          <button type="button" onClick={onClose} className="grid h-8 w-8 place-items-center rounded-full text-[#334155] hover:bg-[#F1F5F9]" aria-label="Close">
            <X size={18} />
          </button>
        </header>

        <div className="min-h-0 flex-1 space-y-4 overflow-y-auto px-6 py-5">
          {/* Whose classes */}
          <section>
            <p className="mb-1.5 text-xs font-bold uppercase tracking-wide text-[#64748B]">Whose classes?</p>
            <div className="grid gap-2 sm:grid-cols-2">
              <PersonSlot
                label="Teacher"
                value={teacher?.displayName ?? ""}
                placeholder="Any teacher"
                onOpen={() => setPicker("teacher")}
                onClear={teacherId ? () => setTeacherId(null) : undefined}
              />
              <PersonSlot
                label="Student"
                value={student ? `${student.displayName}${student.studentCode ? ` (${student.studentCode})` : ""}` : ""}
                placeholder="Any student"
                onOpen={() => setPicker("student")}
                onClear={studentId ? () => setStudentId(null) : undefined}
              />
            </div>
            <p className="mt-1.5 text-xs text-[#64748B]">{scopeText}</p>
          </section>

          {/* Move by */}
          <section>
            <p className="mb-1.5 text-xs font-bold uppercase tracking-wide text-[#64748B]">Move by</p>
            <div className="flex flex-wrap items-center gap-2">
              <div className="inline-flex rounded-xl border border-[#E2E8F0] p-0.5">
                {([-1, 1] as const).map((d) => (
                  <button
                    key={d}
                    type="button"
                    onClick={() => setDirection(d)}
                    className={`rounded-lg px-3 py-1.5 text-sm font-semibold ${direction === d ? "bg-[#0386FF] text-white" : "text-[#334155]"}`}
                  >
                    {d < 0 ? "Earlier" : "Later"}
                  </button>
                ))}
              </div>
              <div className="inline-flex rounded-xl border border-[#E2E8F0] p-0.5">
                {AMOUNTS.map((a) => (
                  <button
                    key={a.minutes}
                    type="button"
                    onClick={() => setAmount(a.minutes)}
                    className={`rounded-lg px-2.5 py-1.5 text-sm font-semibold sm:px-3 ${amount === a.minutes ? "bg-[#0F172A] text-white" : "text-[#334155]"}`}
                  >
                    {a.label}
                  </button>
                ))}
              </div>
            </div>
          </section>

          {/* What moves */}
          {teacherId || studentId ? (
            <section className="rounded-xl border border-[#E2E8F0] px-3.5 py-3 text-xs text-[#64748B]">
              <p className="flex items-center gap-2 text-sm font-bold text-[#111827]">
                What moves {describeMinutes(minutes)}
                {scanning ? <Loader2 size={13} className="animate-spin text-[#94A3B8]" /> : null}
              </p>
              {!plan ? (
                scanning ? <p className="mt-1.5">Looking up the classes…</p> : null
              ) : plan.schedules.length === 0 && plan.singles.length === 0 ? (
                <p className="mt-1.5">No upcoming classes found.</p>
              ) : (
                <div className="mt-2 space-y-3">
                  {plan.schedules.length ? (
                    <div>
                      <p className="mb-1 font-bold uppercase tracking-wide text-[#94A3B8]">Weekly classes</p>
                      <div className="space-y-1">
                        {plan.schedules.map((s) => (
                          <label key={s.id} className="flex cursor-pointer items-start gap-2.5 rounded-lg px-1.5 py-1.5 hover:bg-[#F8FAFC]">
                            <input
                              type="checkbox"
                              className="mt-0.5"
                              checked={s.selected}
                              disabled={busy}
                              onChange={(e) => toggle("templateIds", s.id, e.target.checked)}
                            />
                            <span className="min-w-0 flex-1">
                              <span className="block truncate text-sm font-semibold text-[#111827]">
                                {s.studentNames.join(", ") || s.title}
                                <span className="font-normal text-[#64748B]"> · {s.teacherName}</span>
                              </span>
                              <span className="block text-[#334155]">
                                {s.before} <span className="text-[#94A3B8]">→</span>{" "}
                                <span className="font-semibold text-[#4F46E5]">{s.after}</span>{" "}
                                <span className="text-[#94A3B8]">{zoneLabel(s.zone)}</span>
                              </span>
                              {s.dayChanges ? <span className="block text-[#B45309]">Crosses midnight, so the day changes too.</span> : null}
                              {s.tooSoon ? (
                                <span className="block">
                                  {s.tooSoon} class{s.tooSoon === 1 ? "" : "es"} today keep{s.tooSoon === 1 ? "s" : ""} the old time (the new time has already passed).
                                </span>
                              ) : null}
                            </span>
                          </label>
                        ))}
                      </div>
                    </div>
                  ) : null}

                  {plan.singles.length ? (
                    <div>
                      <p className="mb-1 font-bold uppercase tracking-wide text-[#94A3B8]">Single classes</p>
                      <div className="space-y-1">
                        {plan.singles.map((s) => (
                          <label key={s.id} className={`flex items-start gap-2.5 rounded-lg px-1.5 py-1.5 ${s.tooSoon ? "opacity-60" : "cursor-pointer hover:bg-[#F8FAFC]"}`}>
                            <input
                              type="checkbox"
                              className="mt-0.5"
                              checked={s.selected}
                              disabled={busy || s.tooSoon}
                              onChange={(e) => toggle("shiftIds", s.id, e.target.checked)}
                            />
                            <span className="min-w-0 flex-1">
                              <span className="block truncate text-sm font-semibold text-[#111827]">
                                {s.studentNames.join(", ") || s.title}
                                <span className="font-normal text-[#64748B]"> · {s.teacherName}</span>
                              </span>
                              <span className="block text-[#334155]">
                                {s.before} <span className="text-[#94A3B8]">→</span> <span className="font-semibold text-[#4F46E5]">{s.after}</span>
                              </span>
                              {s.tooSoon ? <span className="block">The new time has already passed, so this class stays.</span> : null}
                            </span>
                          </label>
                        ))}
                      </div>
                    </div>
                  ) : null}

                  {plan.teacherConflicts.length ? (
                    <div className="rounded-lg border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-[#B91C1C]">
                      <p className="flex items-center gap-1.5 font-bold">
                        <AlertTriangle size={13} /> A teacher would have two classes at once
                      </p>
                      {plan.teacherConflicts.slice(0, 4).map((c, i) => (
                        <p key={i} className="mt-0.5">· {c.who}: {c.moved} overlaps {c.other}</p>
                      ))}
                      <p className="mt-1">Untick the class that collides, or move the other class too (pick only the teacher).</p>
                    </div>
                  ) : null}

                  {plan.studentOverlaps.length ? (
                    <div className="rounded-lg border border-[#FDE68A] bg-[#FFFBEB] px-3 py-2 text-[#92400E]">
                      <p className="font-bold">A student would have two classes at once</p>
                      {plan.studentOverlaps.slice(0, 4).map((c, i) => (
                        <p key={i} className="mt-0.5">· {c.who}: {c.moved} overlaps {c.other}</p>
                      ))}
                      <p className="mt-1">You can still move them; check with the family.</p>
                    </div>
                  ) : null}

                  <p>
                    Classes that started or finished are never changed. Teachers and students see the new time on their
                    schedule right away.
                  </p>
                </div>
              )}
            </section>
          ) : null}

          {/* Recent moves */}
          {moves && moves.length ? (
            <section>
              <p className="mb-1.5 text-xs font-bold uppercase tracking-wide text-[#64748B]">Recent moves</p>
              <div className="space-y-1.5">
                {moves.map((m) => (
                  <div key={m.id} className="flex items-center gap-3 rounded-xl border border-[#E2E8F0] px-3.5 py-2.5">
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm font-semibold text-[#111827]">
                        {m.label} · {describeMinutes(m.minutes)}
                      </span>
                      <span className="block text-xs text-[#64748B]">
                        {m.at ? new Date(m.at).toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }) : ""}
                        {m.byName ? ` · ${m.byName}` : ""} · {m.schedules} weekly · {m.singles} single
                        {m.undoneAt ? " · undone" : ""}
                      </span>
                    </span>
                    {m.undoneAt ? null : (
                      <ActionButton
                        variant="subtle"
                        className="shrink-0 px-3 py-1.5 text-xs"
                        icon={<Undo2 size={13} />}
                        label="Undo"
                        busyLabel="Undoing…"
                        disabled={busy}
                        onAction={() => undo(m)}
                      />
                    )}
                  </div>
                ))}
              </div>
            </section>
          ) : null}

          {error ? (
            <p className="rounded-xl border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#B91C1C]">{error}</p>
          ) : null}
          {toast ? <p className="text-xs font-semibold text-[#059669]">{toast}</p> : null}
        </div>

        <footer className="flex items-center gap-2 border-t border-[#E2E8F0] px-6 py-4">
          <button type="button" onClick={onClose} className="rounded-xl px-4 py-2.5 text-sm font-semibold text-[#64748B]">
            Close
          </button>
          <ActionButton
            variant="primary"
            className="ml-auto"
            label={
              nothing
                ? "Move classes"
                : `Move ${selectedSchedules.length + selectedSingles.length} class${
                    selectedSchedules.length + selectedSingles.length === 1 ? "" : "es"
                  } ${describeMinutes(minutes)}`
            }
            busyLabel="Moving…"
            disabled={busy || scanning || !plan || nothing || blocked}
            onAction={() => apply()}
          />
        </footer>
      </div>

      {picker ? (
        <PersonSelectDialog
          title={picker === "teacher" ? "Select Teacher" : "Select Student"}
          people={picker === "teacher" ? staffOptions : studentOptions}
          selectedIds={[]}
          onConfirm={(ids) => {
            if (picker === "teacher") setTeacherId(ids[0] ?? null);
            else setStudentId(ids[0] ?? null);
            setPicker(null);
          }}
          onClose={() => setPicker(null)}
        />
      ) : null}
    </div>
  );
}

function PersonSlot({
  label,
  value,
  placeholder,
  onOpen,
  onClear,
}: {
  label: string;
  value: string;
  placeholder: string;
  onOpen: () => void;
  onClear?: () => void;
}) {
  return (
    <div className="relative">
      <PersonPickerField label={label} value={value} placeholder={placeholder} onOpen={onOpen} />
      {onClear ? (
        <button
          type="button"
          onClick={onClear}
          className="absolute bottom-2 right-8 grid h-6 w-6 place-items-center rounded-full text-[#64748B] hover:bg-[#F1F5F9]"
          aria-label={`Clear ${label.toLowerCase()}`}
        >
          <X size={14} />
        </button>
      ) : null}
    </div>
  );
}
