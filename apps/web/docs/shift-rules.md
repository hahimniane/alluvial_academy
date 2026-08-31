# Shift System Rules — the complete rulebook

Every rule governing shifts across the Flutter app, the Next.js admin, and the
Cloud Functions backend. "Server" rules hold no matter which client is used.

## 1. Creating a shift
- Only admins can create shifts.
- A teaching shift must have at least one student. Non-teaching shifts
  (Leader Duty / Meeting / Training) need a role/purpose instead.
- **End must be after start.** An end at/before the start that crosses
  midnight rolls to the next day (11:30 PM–12:30 AM is valid).
- **3-hour cap** for teaching classes with students (Zoom-routed). Longer must
  be split into separate classes.
- **12-hour sanity cap** on any window — catches wrong end dates.
- **No teacher overlap:** creation is refused if the teacher already has any
  non-cancelled shift overlapping the window. Overlap = `start < otherEnd AND
  end > otherStart`. Cancelled/deleted shifts don't block.
- **Zoom hub capacity** is pre-checked (validateZoomShiftCapacity) before a
  Zoom class is created.
- Hourly rate defaults from the subject's default wage; admin can override.
- Times are wall-clock in the chosen timezone, stored as UTC; the auto name is
  "Teacher - Subject - Students (≤3, else +N more)".
- Lifecycle tasks (reminders, auto clock-out) are scheduled on creation; if
  scheduling fails in Flutter the shift is rolled back.

## 2. Creating a recurring series
- A base shift is created first (all §1 rules apply), then a template is
  registered with `base_shift_id` = the base's doc id (template id = base id).
- For weekly recurrence, the base is snapped forward to the first selected
  weekday. Weekly needs selected weekdays; monthly needs month-days; yearly
  needs months.
- The server generates instances up to 70 days ahead (`tpl_{id}_{epoch}`),
  and the nightly generator keeps extending the window.
- **Generation skips any instance that would overlap** the teacher's existing
  schedule (skippedConflicts) — it never creates a conflict.
- Generation never overwrites occurrences that were teacher-modified,
  admin-modified, deleted, or in a terminal state.

## 3. Editing
- **Any edit that changes teacher or time re-runs the overlap check** against
  the target teacher's calendar (excluding the shift itself) plus the
  3h/12h window rules. Edits to students/subject/notes skip the conflict
  check so legacy overlapping data stays editable.
- Editing a recurring shift goes through **Edit Options**: this shift only /
  all in series / by student / by time range.
- **Edit all in series:** only `scheduled` occurrences move (completed,
  active, missed keep their recorded times). Every new window is validated
  (overlap vs the teacher's OTHER classes, 3h/12h caps) **before anything is
  written — all-or-nothing**; one collision aborts the whole edit. The
  template's start/end/duration update too, so future generated shifts
  inherit the new time.
- Moving/rescheduling one occurrence of a series **excludes that date from
  the template** so the nightly generator can't recreate the old slot.
- Admin edits stamp `admin_modified`; that protects the occurrence from being
  overwritten by regeneration.
- Bulk edits are capped at 100 shifts and conflict-checked first (Flutter).

## 4. Teacher reschedules (teacher-initiated, server-enforced)
- A reschedule **moves a class, never lengthens it** — the scheduled window is
  the pay window, so lengthening would be self-raised pay. Shortening is
  allowed. (Deployed server rule.)
- Absolute 12-hour cap with the "check that the end date matches the start
  date" error (kills the 25-hour end-date mistake).
- The new window is **conflict-checked against the teacher's own schedule**.
- Completed/cancelled/missed shifts cannot be rescheduled.
- Moving the start in the dialog drags the end with it (same duration).

## 5. Deleting
- **Nothing that already started is ever removed** — not by a delete, a stop, a
  pause, or a regeneration. Past classes (including missed and cancelled ones)
  and the class running right now are records: they carry attendance and pay.
  Enforced server-side in `_cleanupCandidateFilter` and client-side in
  `deleteShiftSeriesForward`.
- Delete always asks for confirmation; "This action cannot be undone."
- A repeating class offers **"Delete This Shift"** vs **"Stop repeating &
  delete N upcoming"** — the count shown is exactly what will be removed, and
  it stops the class repeating.
- Deleting a single generated occurrence **excludes its date from the
  template** first — otherwise the nightly generator resurrects it.
- **Completed/active shifts are not deleted** by series deletion.

## 6. Shift trading (publish → claim)
- A teacher publishes their own shift; only `is_published == true` AND
  `status == scheduled` shifts are claimable, and never your own.
- **Claiming is refused if the claimer already has any class overlapping the
  window** (server-side, inside the transaction — deployed and live-tested).
  Cancelled/deleted shifts don't block.
- A successful claim reassigns teacher_id/name, unpublishes, stamps
  `claimed_via_shift_trade`, and notifies the students.

## 7. Clock-in / clock-out & timesheets (the money rules)
- One open timesheet per teacher+shift: clock-in refuses if an open entry
  exists, and entries are written under a **deterministic id**
  (`ts_{uid}_{shift}_s{n}`) so a stalled-connection tap-stampede collapses
  into one document instead of 32.
- **Instant dedup on write:** the server trigger deletes stampede copies
  (open, same teacher+shift, clock-in within 60s of the kept entry) within
  seconds; slower overlaps are marked rejected for review.
- The end-of-shift sweepers pay **only one entry per teacher+shift time
  window**; overlapping copies are auto-rejected with $0. Rejected entries
  can never be paid, exported, or approved.
- **Pay is capped to the scheduled window**: early clock-ins and late
  clock-outs don't increase pay; auto clock-out caps at shift end.
- Clock-in opens 1 minute before shift start; auto clock-out runs at shift
  end ("System auto clock-out at shift end").
- A genuine re-clock-in (after a clock-out) is a new legitimate session —
  never treated as a duplicate.

## 8. Statuses & what blocks what
- Statuses: scheduled → active → completed / partiallyCompleted /
  fullyCompleted / missed; plus cancelled.
- `cancelled` and `deleted` shifts **never block** scheduling, claiming, or
  rescheduling (a cancelled class frees its slot).
- Everything else occupies the teacher's calendar for conflict purposes.
- Completion status is recomputed from timesheets/forms by the server
  (rejected timesheets excluded).

## 9. Picking people (UI guardrail)
- **Every** teacher or student selection — in any dialog, filter or flow —
  uses the one shared picker (`components/PersonSelect.tsx`), ported from the
  Flutter `EmployeeSelectionDialog`. Never hand-roll another list.
  Single-select (teachers) confirms on tap; multi-select (students) keeps a
  "N selected" toggle and a Done button.
- **A student is never shown by name alone.** Names repeat across families
  (one parent has two children both named "Soulaymane Barry"), so every
  student row, chip, tooltip, summary and dropdown carries their ID.
- Search matches name in either order, email, and any id/code.

## 10. Buttons that write (UI guardrail)
- **Every button that writes uses `components/ActionButton.tsx`.** It disables
  itself the instant it is clicked and stays disabled until the work finishes,
  so a second click cannot start a second save. Never hand-roll a save button.
- Work that loops over many classes reports progress — the button reads
  "Creating… 3 of 19" with a fill bar — so an admin can see it is running and
  never wonders whether it worked.
- Every finished action confirms with a green tick and states the outcome in
  plain numbers ("Created 7 one-time shifts").

## 11. Dialogs must fit the window (UI guardrail)
- **Never give a dialog a fixed pixel height.** Use `h-[min(Xpx,90vh)]` /
  `max-h-[90vh]` with the footer outside the scroll area. The admin screen runs
  inside the Flutter frame where the viewport can be ~450px tall; a fixed 600px
  panel put the picker's **Done** button below the fold, so students could be
  ticked but never confirmed — the form then said "pick a student".
- A multi-select picker **confirms on dismiss**; clicking away never discards
  what was ticked.

## 12. One editor per thing (UI guardrail)
- Editing a repeating class happens in ONE place: click the shift → Edit all in
  series. It covers time, **which weekdays it repeats on**, teacher, students,
  subject and notes.
- The Recurring series list never edits. It finds series (including paused and
  stopped ones, which have no shift to click) and hands off to that same editor,
  plus lifecycle: pause for a period / resume / stop / restart.
- Never add a second dialog that edits the same field.

## 13. Pausing for a break
- A series can be paused for a PERIOD; it resumes by itself the day after the
  window (the template stays active, the generator skips those days).
- A pause covers every class in the window, not only generated ones: one-off
  classes are cancelled (not deleted) and restored when the pause is lifted.
- A whole family can be paused at once — siblings are resolved through
  `guardian_ids`. A class shared with a child who is NOT away keeps running,
  and is listed in the preview so the admin can see why.
- Completed and in-progress classes are never touched.

## 14. Visibility & audit
- Every write stamps who/when (`created_by_*`, `admin_modified_at`,
  `teacher_modified_at`, `reassigned_by`, `shift_trade_claimed_at`).
- Grid shows past shifts tinted by status; future by subject; pay-relevant
  corrections keep `pre_dedup_*` / `pre_repair_*` audit fields.
