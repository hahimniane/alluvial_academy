"use client";

import { useEffect, useState } from "react";
import { ActionButton } from "@/components/ActionButton";
import {
  type ShiftDoc,
  countDeletableFutureOccurrences,
  deleteShiftGuarded,
  deleteShiftSeriesForward,
  isRecurringShift,
} from "@/lib/shifts";

/**
 * Delete confirmation, matching the Flutter dialog copy and options: a
 * single shift always deletable, and a recurring occurrence additionally
 * offering "this and all future" (which also stops the series template).
 */
export function ShiftDeleteDialog({
  shift,
  onDeleted,
  onClose,
}: {
  shift: ShiftDoc;
  onDeleted: (message: string, mode: "single" | "series") => void;
  onClose: () => void;
}) {
  const [busy, setBusy] = useState<"single" | "series" | null>(null);
  const [error, setError] = useState("");
  // Series base shifts carry a recurrence field but no template_id, so use
  // the shared detector — otherwise the base offers no "Delete This & Future".
  const recurring = isRecurringShift(shift);
  // Say exactly how many upcoming classes will go, so the count on the button
  // matches what actually happens.
  const [upcoming, setUpcoming] = useState<number | null>(null);
  useEffect(() => {
    if (!recurring) return;
    let alive = true;
    countDeletableFutureOccurrences(shift)
      .then((n) => alive && setUpcoming(n))
      .catch(() => alive && setUpcoming(null));
    return () => {
      alive = false;
    };
  }, [shift, recurring]);

  const run = async (mode: "single" | "series", report?: (d: number, t: number) => void) => {
    setBusy(mode);
    setError("");
    try {
      if (mode === "series") {
        const removed = await deleteShiftSeriesForward(shift, report);
        onDeleted(
          removed === 0
            ? "Stopped repeating. Nothing upcoming to remove — past classes were left untouched."
            : `Stopped repeating. ${removed} upcoming class${removed === 1 ? "" : "es"} removed. Past classes were left untouched.`,
          "series",
        );
      } else {
        await deleteShiftGuarded(shift);
        onDeleted("Shift deleted.", "single");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not delete the shift.");
      setBusy(null);
    }
  };

  return (
    <div className="fixed inset-0 z-[60] grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true">
      <div className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-2xl bg-white p-6 shadow-2xl">
        <h2 className="text-lg font-bold text-[#0F172A]">Delete Shift</h2>
        <p className="mt-2 text-sm text-[#334155]">
          Are you sure you want to delete &ldquo;{shift.title}&rdquo;? This action cannot be undone.
        </p>
        {recurring ? (
          <p className="mt-2 text-sm text-[#64748B]">
            This class repeats. You can delete just this one, or stop it repeating and remove the upcoming ones.
          </p>
        ) : null}
        <p className="mt-2 text-sm text-[#64748B]">
          Classes that already happened or are running now are never removed — including missed and cancelled ones. They
          stay as a record.
        </p>

        {error ? (
          <p className="mt-3 rounded-xl border border-[#FECACA] bg-[#FEF2F2] px-3.5 py-2.5 text-sm font-semibold text-[#B91C1C]">
            {error}
          </p>
        ) : null}

        <div className="mt-5 flex flex-wrap items-center justify-end gap-2">
          <button type="button" onClick={onClose} disabled={busy !== null} className="rounded-xl px-4 py-2.5 text-sm font-semibold text-[#64748B]">
            Cancel
          </button>
          <ActionButton
            variant="ghost"
            label="Delete This Shift"
            busyLabel="Deleting…"
            disabled={busy !== null}
            onAction={() => run("single")}
          />
          {recurring ? (
            <ActionButton
              variant="danger"
              label={upcoming === null ? "Stop repeating & delete upcoming" : `Stop repeating & delete ${upcoming} upcoming`}
              busyLabel="Deleting…"
              disabled={busy !== null}
              onAction={(report) => run("series", report)}
            />
          ) : null}
        </div>
      </div>
    </div>
  );
}
