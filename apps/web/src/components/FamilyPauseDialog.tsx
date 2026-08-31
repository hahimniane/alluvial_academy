"use client";

import { useEffect, useMemo, useState } from "react";
import { CalendarOff, Loader2, RotateCcw, Users, X } from "lucide-react";
import { ActionButton, type ProgressReporter } from "@/components/ActionButton";
import { PersonPickerField, PersonSelectDialog, type PersonOption } from "@/components/PersonSelect";
import type { StudentOption } from "@/lib/shifts";
import {
  type FamilyStudent,
  type PauseBatch,
  type PausePreview,
  type StudentFamily,
  applyFamilyPause,
  liftPauseBatch,
  loadPauseBatches,
  loadStudentFamily,
  previewFamilyPause,
} from "@/lib/familyPause";

/**
 * "This family is away" — pause every class for a student, or for all their
 * siblings at once, between two dates. Classes shared with a child who is
 * staying keep running and are listed so the admin can see why.
 */

export function FamilyPauseDialog({
  students,
  adminTimezone,
  adminName,
  onClose,
  onChanged,
}: {
  students: StudentOption[];
  adminTimezone: string;
  adminName: string;
  onClose: () => void;
  onChanged: () => void;
}) {
  const [pickerOpen, setPickerOpen] = useState(false);
  const [family, setFamily] = useState<StudentFamily | null>(null);
  const [loadingFamily, setLoadingFamily] = useState(false);
  const [picked, setPicked] = useState<Set<string>>(new Set());
  const [fromDay, setFromDay] = useState("");
  const [toDay, setToDay] = useState("");
  const [preview, setPreview] = useState<PausePreview | null>(null);
  const [scanning, setScanning] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");
  const [batches, setBatches] = useState<PauseBatch[] | null>(null);

  const refreshBatches = () => {
    loadPauseBatches()
      .then(setBatches)
      .catch(() => setBatches([]));
  };
  useEffect(refreshBatches, []);

  const studentOptions: PersonOption[] = useMemo(
    () => students.map((s) => ({ id: s.id, name: s.displayName, email: s.email, code: s.studentCode, isStudent: true })),
    [students],
  );

  const chooseStudent = async (studentId: string) => {
    setLoadingFamily(true);
    setError("");
    try {
      const found = await loadStudentFamily(studentId);
      setFamily(found);
      // Default to the whole family — that is the common case for a trip.
      setPicked(new Set(found.members.map((m) => m.id)));
    } catch {
      setError("Could not load that student's family.");
    } finally {
      setLoadingFamily(false);
    }
  };

  useEffect(() => {
    if (!family || picked.size === 0 || !fromDay) {
      setPreview(null);
      return;
    }
    let alive = true;
    setScanning(true);
    previewFamilyPause([...picked], fromDay, toDay, adminTimezone)
      .then((result) => alive && setPreview(result))
      .catch(() => alive && setPreview(null))
      .finally(() => alive && setScanning(false));
    return () => {
      alive = false;
    };
  }, [family, picked, fromDay, toDay, adminTimezone]);

  const selectedMembers: FamilyStudent[] = useMemo(
    () => (family ? family.members.filter((m) => picked.has(m.id)) : []),
    [family, picked],
  );

  const apply = async (report?: ProgressReporter) => {
    if (!preview) return;
    setBusy(true);
    setError("");
    try {
      await applyFamilyPause({
        students: selectedMembers,
        startDay: fromDay,
        endDay: toDay,
        zone: adminTimezone,
        preview,
        adminName,
        onProgress: report,
      });
      const total = preview.templates.length + preview.oneOffs.length;
      setToast(
        `Break saved — ${preview.templates.length} series paused and ${preview.oneOffs.length} class${
          preview.oneOffs.length === 1 ? "" : "es"
        } cancelled (${total} in total).`,
      );
      setFamily(null);
      setPicked(new Set());
      setFromDay("");
      setToDay("");
      setPreview(null);
      refreshBatches();
      onChanged();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save the break.");
    } finally {
      setBusy(false);
    }
  };

  const lift = async (batch: PauseBatch, report?: ProgressReporter) => {
    setBusy(true);
    setError("");
    try {
      await liftPauseBatch(batch.id, report);
      setToast("Break lifted — classes are back on the calendar.");
      refreshBatches();
      onChanged();
    } catch {
      setError("Could not lift that break.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[70] grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true">
      <div className="flex max-h-[90vh] w-full max-w-2xl flex-col overflow-hidden rounded-2xl bg-white shadow-2xl">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] px-6 py-4">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#FFF7ED] text-[#C2410C]">
            <CalendarOff size={18} />
          </span>
          <div className="min-w-0 flex-1">
            <h2 className="text-lg font-bold text-[#0F172A]">Pause classes for a break</h2>
            <p className="text-xs text-[#64748B]">One student, or every child in the family</p>
          </div>
          <button type="button" onClick={onClose} className="grid h-8 w-8 place-items-center rounded-full text-[#334155] hover:bg-[#F1F5F9]" aria-label="Close">
            <X size={18} />
          </button>
        </header>

        <div className="min-h-0 flex-1 space-y-4 overflow-y-auto px-6 py-5">
          {/* Step 1 — find the student */}
          <section>
            <p className="mb-1.5 text-xs font-bold uppercase tracking-wide text-[#64748B]">Who is away?</p>
            <PersonPickerField
              value=""
              placeholder="Search by student name or ID"
              onOpen={() => setPickerOpen(true)}
            />
            {loadingFamily ? (
              <p className="mt-2 flex items-center gap-1.5 text-xs text-[#64748B]">
                <Loader2 size={12} className="animate-spin" /> Finding the family…
              </p>
            ) : null}
          </section>

          {/* Step 2 — the family */}
          {family ? (
            <section className="rounded-xl border border-[#E2E8F0] px-3.5 py-3">
              <p className="flex items-center gap-1.5 text-sm font-bold text-[#111827]">
                <Users size={14} className="text-[#0386FF]" />
                {family.guardians.length
                  ? `Family of ${family.guardians.map((g) => g.name).join(" & ")}`
                  : "This student has no family on record"}
              </p>
              <p className="mt-0.5 text-xs text-[#64748B]">
                {family.members.length === 1
                  ? "No siblings found — only this student will be paused."
                  : `${family.members.length} children. Untick anyone who is staying.`}
              </p>
              <div className="mt-2 space-y-1">
                {family.members.map((member) => (
                  <label key={member.id} className="flex cursor-pointer items-center gap-2.5 rounded-lg px-1.5 py-1 text-sm hover:bg-[#F8FAFC]">
                    <input
                      type="checkbox"
                      checked={picked.has(member.id)}
                      onChange={(event) =>
                        setPicked((prev) => {
                          const next = new Set(prev);
                          if (event.target.checked) next.add(member.id);
                          else next.delete(member.id);
                          return next;
                        })
                      }
                    />
                    <span className="min-w-0 flex-1 truncate text-[#334155]">{member.name}</span>
                    <span className="shrink-0 text-xs font-semibold text-[#94A3B8]">ID: {member.code || "—"}</span>
                  </label>
                ))}
              </div>
            </section>
          ) : null}

          {/* Step 3 — dates */}
          {family && picked.size > 0 ? (
            <section className="grid grid-cols-2 gap-3">
              <label className="text-xs font-bold uppercase tracking-wide text-[#64748B]">
                First day off
                <input
                  type="date"
                  value={fromDay}
                  onChange={(event) => setFromDay(event.target.value)}
                  className="mt-1 w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm font-normal normal-case tracking-normal text-[#0F172A]"
                />
              </label>
              <label className="text-xs font-bold uppercase tracking-wide text-[#64748B]">
                Last day off
                <input
                  type="date"
                  value={toDay}
                  onChange={(event) => setToDay(event.target.value)}
                  className="mt-1 w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm font-normal normal-case tracking-normal text-[#0F172A]"
                />
              </label>
            </section>
          ) : null}

          {/* Step 4 — preview */}
          {family && picked.size > 0 && fromDay ? (
            <section className="rounded-xl border border-[#E2E8F0] px-3.5 py-3 text-xs text-[#64748B]">
              <p className="text-sm font-bold text-[#111827]">What this will do</p>
              {scanning ? (
                <p className="mt-1.5 flex items-center gap-1.5">
                  <Loader2 size={12} className="animate-spin" /> Checking every teacher…
                </p>
              ) : !preview ? (
                <p className="mt-1.5">Pick the dates to see the effect.</p>
              ) : (
                <div className="mt-1.5 space-y-2">
                  <p>
                    <span className="font-bold text-[#C2410C]">{preview.templates.length}</span> repeating classes paused
                    {preview.templates.length ? ":" : "."}
                  </p>
                  {preview.templates.slice(0, 4).map((t) => (
                    <p key={t.id} className="pl-3">· {t.teacherName} — {t.studentNames.join(", ")} ({t.time})</p>
                  ))}
                  {preview.templates.length > 4 ? <p className="pl-3">· + {preview.templates.length - 4} more</p> : null}

                  <p>
                    <span className="font-bold text-[#C2410C]">{preview.oneOffs.length}</span> individual class
                    {preview.oneOffs.length === 1 ? "" : "es"} cancelled in that window
                    {preview.oneOffs.length ? ":" : "."}
                  </p>
                  {preview.oneOffs.slice(0, 4).map((s) => (
                    <p key={s.id} className="pl-3">
                      · {s.start.toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" })} — {s.teacherName}
                    </p>
                  ))}
                  {preview.oneOffs.length > 4 ? <p className="pl-3">· + {preview.oneOffs.length - 4} more</p> : null}

                  {preview.shared.length ? (
                    <div className="rounded-lg border border-[#FDE68A] bg-[#FFFBEB] px-3 py-2 text-[#92400E]">
                      <p className="font-bold">
                        {preview.shared.length} class{preview.shared.length === 1 ? "" : "es"} left running
                      </p>
                      <p className="mt-0.5">
                        Shared with children who are staying, so cancelling would affect them too:
                      </p>
                      {preview.shared.slice(0, 3).map((s) => (
                        <p key={s.id} className="pl-2">
                          · {s.start.toLocaleString("en-US", { month: "short", day: "numeric" })} — {s.teacherName} (also {s.otherStudents.join(", ")})
                        </p>
                      ))}
                    </div>
                  ) : null}
                  <p>Completed and in-progress classes are never touched. Everything comes back when you lift the break.</p>
                </div>
              )}
            </section>
          ) : null}

          {/* Active breaks */}
          {batches && batches.length > 0 ? (
            <section>
              <p className="mb-1.5 text-xs font-bold uppercase tracking-wide text-[#64748B]">Breaks in force</p>
              <div className="space-y-1.5">
                {batches.map((batch) => (
                  <div key={batch.id} className="flex items-center gap-3 rounded-xl border border-[#E2E8F0] px-3.5 py-2.5">
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm font-semibold text-[#111827]">
                        {batch.studentNames.map((n, i) => `${n}${batch.studentCodes[i] ? ` (${batch.studentCodes[i]})` : ""}`).join(", ")}
                      </span>
                      <span className="block text-xs text-[#64748B]">
                        {batch.startDay}
                        {batch.endDay ? ` → ${batch.endDay}` : " → until lifted"} · {batch.templateIds.length} repeating ·{" "}
                        {batch.shiftIds.length} class{batch.shiftIds.length === 1 ? "" : "es"}
                      </span>
                    </span>
                    <ActionButton
                      variant="subtle"
                      className="shrink-0 px-3 py-1.5 text-xs text-[#059669]"
                      label="Lift"
                      busyLabel="Lifting…"
                      disabled={busy}
                      onAction={(report) => lift(batch, report)}
                    />
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
            label="Pause these classes"
            busyLabel="Pausing…"
            disabled={busy || !preview || !fromDay || picked.size === 0}
            onAction={(report) => apply(report)}
          />
        </footer>
      </div>

      {pickerOpen ? (
        <PersonSelectDialog
          title="Select Student"
          people={studentOptions}
          selectedIds={[]}
          onConfirm={(ids) => {
            setPickerOpen(false);
            if (ids[0]) void chooseStudent(ids[0]);
          }}
          onClose={() => setPickerOpen(false)}
        />
      ) : null}
    </div>
  );
}
