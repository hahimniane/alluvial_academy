"use client";

import { useEffect, useState } from "react";
import { ActionButton } from "@/components/ActionButton";
import { auth } from "@/lib/firebase";
import {
  type ShiftDoc,
  canDeleteShift,
  cancelPastShift,
  countDeletableFutureOccurrences,
  deleteShiftGuarded,
  deleteShiftSeriesForward,
  isRecurringShift,
  shiftHasClockIn,
} from "@/lib/shifts";

/**
 * Delete confirmation, matching the Flutter dialog copy and options. A class
 * that has not started can be deleted; one that has started is a record, so
 * it can only be cancelled (when nobody clocked in). A recurring class also
 * offers "stop repeating", which removes upcoming classes only.
 */
export function ShiftDeleteDialog({
  shift,
  onDeleted,
  onClose,
}: {
  shift: ShiftDoc;
  onDeleted: (message: string, mode: "single" | "series" | "cancelled") => void;
  onClose: () => void;
}) {
  const [busy, setBusy] = useState<"single" | "series" | "cancel" | null>(null);
  const [error, setError] = useState("");
  // Series base shifts carry a recurrence field but no template_id, so use
  // the shared detector — otherwise the base offers no "Delete This & Future".
  const recurring = isRecurringShift(shift);
  const deletable = canDeleteShift(shift);
  const alreadyCancelled = shift.status.toLowerCase() === "cancelled";
  // A started class can be cancelled only when nobody clocked in to it.
  const [taught, setTaught] = useState<boolean | null>(deletable ? false : null);
  useEffect(() => {
    if (deletable) return;
    let alive = true;
    shiftHasClockIn(shift.id)
      .then((has) => alive && setTaught(has))
      .catch(() => alive && setTaught(true));
    return () => {
      alive = false;
    };
  }, [shift.id, deletable]);
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

  const run = async (mode: "single" | "series" | "cancel", report?: (d: number, t: number) => void) => {
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
      } else if (mode === "cancel") {
        await cancelPastShift(shift, auth.currentUser);
        onDeleted("Class cancelled. It stays on the schedule as a record.", "cancelled");
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
        <h2 className="text-lg font-bold text-[#0F172A]">{deletable ? "Delete Shift" : "This class already started"}</h2>
        {deletable ? (
          <p className="mt-2 text-sm text-[#334155]">
            Are you sure you want to delete &ldquo;{shift.title}&rdquo;? This action cannot be undone.
          </p>
        ) : (
          <p className="mt-2 text-sm text-[#334155]">
            &ldquo;{shift.title}&rdquo; has already started, so it can&apos;t be deleted. It stays as a record of
            attendance and pay.{" "}
            {alreadyCancelled
              ? "It is already cancelled."
              : taught === null
                ? ""
                : taught
                  ? "Someone clocked in to it, so it was taught and stays as it is."
                  : "Nobody clocked in to it. If it should never have been on the schedule, cancel it so it doesn't count as missed."}
          </p>
        )}
        {recurring ? (
          <p className="mt-2 text-sm text-[#64748B]">
            This class repeats. You can delete just this one, or stop it repeating and remove the upcoming ones.
          </p>
        ) : null}
        {deletable ? (
          <p className="mt-2 text-sm text-[#64748B]">
            Classes that already happened or are running now are never removed — including missed and cancelled ones.
            They stay as a record.
          </p>
        ) : null}

        {error ? (
          <p className="mt-3 rounded-xl border border-[#FECACA] bg-[#FEF2F2] px-3.5 py-2.5 text-sm font-semibold text-[#B91C1C]">
            {error}
          </p>
        ) : null}

        <div className="mt-5 flex flex-wrap items-center justify-end gap-2">
          <button type="button" onClick={onClose} disabled={busy !== null} className="rounded-xl px-4 py-2.5 text-sm font-semibold text-[#64748B]">
            {deletable ? "Cancel" : "Close"}
          </button>
          {deletable ? (
            <ActionButton
              variant="ghost"
              label="Delete This Shift"
              busyLabel="Deleting…"
              disabled={busy !== null}
              onAction={() => run("single")}
            />
          ) : taught === false && !alreadyCancelled ? (
            <ActionButton
              variant="ghost"
              label="Cancel This Class"
              busyLabel="Cancelling…"
              disabled={busy !== null}
              onAction={() => run("cancel")}
            />
          ) : null}
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
