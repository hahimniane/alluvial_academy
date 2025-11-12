# Shift Lifecycle Automation

## Overview

Shifts now move through their lifecycle automatically without relying on a teacher or admin having the app open. The workflow is:

1. Admin (or bulk import) creates/updates/cancels a shift.
2. `ShiftService` calls the callable Cloud Function `scheduleShiftLifecycle`.
3. The Cloud Function schedules Cloud Tasks for shift start and shift end.
4. Cloud Tasks invoke HTTP functions exactly at the configured time, even if nobody is online.
5. The end-of-window handler auto-closes open timesheets and classifies the shift as `fullyCompleted`, `partiallyCompleted`, or `missed`.
6. `ShiftMonitoringService.runPeriodicMonitoring()` keeps acting as a safety net by re-triggering lifecycle scheduling when it detects stuck shifts.

## Cloud Tasks Configuration

- **Queue name:** `shift-lifecycle-queue`
- **Location:** `us-central1` (override with `TASKS_LOCATION` if needed)
- **Service account:** defaults to `${PROJECT_ID}@appspot.gserviceaccount.com` — customise via `TASKS_SERVICE_ACCOUNT`
- **Environment variables:**  
  - `SHIFT_TASK_QUEUE` (optional)  
  - `TASKS_LOCATION` (optional)  
  - `TASKS_SERVICE_ACCOUNT` (optional)

Create the queue once:

```bash
gcloud tasks queues create shift-lifecycle-queue --location=us-central1
```

## Cloud Functions

| Function | Type | Purpose |
| --- | --- | --- |
| `scheduleShiftLifecycle` | Callable (`onCall`) | Creates/cancels Cloud Tasks for shift start/end |
| `handleShiftStartTask` | HTTPS (`onRequest`) | Marks a `scheduled` shift as `active` at the window opening |
| `handleShiftEndTask` | HTTPS (`onRequest`) | Auto clock-out, aggregates worked minutes, assigns final status |

Ensure the Functions emulator/deployment installs the new dependency:

```bash
cd functions
npm install
```

## Status Classification

- `scheduled` → default when shift is created.
- `active` → set at shift start (even if no clock-in yet).
- `partiallyCompleted` → some attendance logged but not entire window.
- `fullyCompleted` → worked minutes meet/exceed the scheduled duration.
- `missed` → no clock-in events within the allowed grace window.
- `cancelled` → manual admin action (we still call the scheduler with `cancel: true` to remove pending tasks).

Additional telemetry written by the end handler:

- `worked_minutes` — total minutes collected from timesheet entries.
- `completion_state` — `'none'`, `'partial'`, or `'full'`.
- `auto_clock_out` / `auto_clock_out_reason` — flags when the system closed the session.
- `missed_reason` — populated with `"Teacher did not clock in within allowed window"` when applicable.

## Fallback Monitoring

`ShiftMonitoringService.monitorShiftsAndHandleOverdues()` now reconciles instead of mutating state directly. If a shift is overdue or still marked `scheduled` after the grace window, the service re-invokes `scheduleShiftLifecycle` so the Cloud Tasks handlers reconcile everything.

## Developer Checklist

- [ ] Run `npm install` in `functions/` to pull in `@google-cloud/tasks`.
- [ ] Create the Cloud Tasks queue (see command above) in each environment.
- [ ] Deploy functions: `firebase deploy --only functions`.
- [ ] Ensure new Flutter UI changes recognise `partiallyCompleted` and `fullyCompleted`.
- [ ] Run targeted Flutter tests:  
  ```bash
  flutter test test/core/models/teaching_shift_test.dart
  flutter test test/core/services/shift_overlap_test.dart
  ```
- [ ] Document the queue location/service account in environment runbook.

