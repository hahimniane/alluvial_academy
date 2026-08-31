# Admin Shifts (Next.js) — Flutter parity test checklist

Target: `/admin/shifts/` must behave like the Flutter `ShiftManagementScreen`
for the core scheduling workflows. Status legend: [x] verified, [ ] pending,
[~] partially verified / post-deploy only.

## A. Access & navigation
- [x] A1. Signed-out visitor sees "Admin sign-in required" (no data leak)
- [ ] A2. Non-admin account sees "Administrator access required"
- [x] A3. Every other /admin/* route forwards to the Flutter app (/app/)
- [~] A4. Flutter web sidebar "Shifts" hands off to /admin/shifts/ (code done;
        verifiable only after deploy since both apps must share an origin)
- [x] A5. Admin shell sidebar renders; other modules link back to Flutter

## B. Weekly grid parity
- [x] B1. Teachers/Leaders sections, rows sorted by name
- [x] B2. Week navigation loads that week's shifts (verified: 8/24 week 277
        shifts → 8/31 week 270 shifts, today counts reset correctly)
- [x] B3. Per-teacher weekly hours + shift counts in the left column
- [x] B4. Per-day totals (hours | count) in the day headers
- [x] B5. Chips match Flutter: bold time + i/N badge + person icon, subject
        line, gray neutral for unmapped subjects, past days tinted by status
- [x] B6. Search filters by teacher / student / subject (verified w/ "Abass")
- [x] B7. List view shows the same data as a table

## C. Create shift
- [x] C1. One-off teaching shift saved and appeared on the grid
- [x] C2. Firestore doc matched the Flutter field shape exactly
        (doc RiZ6J41tDuXFOjYfNzCg, since deleted in cleanup)
- [x] C3. Timezone exact: 9:00 AM America/New_York stored as 13:00Z (DST)
- [x] C4. Conflict guard refused the overlapping create with shift details
- [x] C5. Zoom cap refused a 4h class ("Zoom classes must be 3 hours or
        shorter (this one is 4h 0m)")
- [x] C6. Tutoring default wage ($5) prefilled the hourly rate untouched
- [ ] C7. Weekly recurring create via createShiftTemplate + instance check

## D. Edit / delete
- [x] D1. Moved 9-10 AM → 11-12: chip updated, 15:00Z stored, admin_modified
        stamped at 2026-08-25T23:01:44Z
- [ ] D2. Reassign teacher: conflict check against the new teacher
- [x] D3. Delete with confirm: removed from grid and Firestore
- [ ] D4. Template-generated occurrence: move/delete excludes the date

## E. Cleanup
- [x] E1. All test data removed (the single test shift was deleted in D3)

## G. From live Flutter walkthrough (owner-requested)
- [x] Grid chips FILL the cell with status/subject tint + student name
- [x] Chip hover toolbar: edit / details / trash / add-here
- [x] Delete confirmation copy: "Delete This Shift" / "Delete This & Future"
- [x] Filter funnel button + panel (Teacher/Student/Subject/From/To/Start/End
      + status chips + Clear All + N results), filters the grid live
- [x] All people lists searchable (filter dropdowns are type-to-search combos)
- [x] Student rows show their ID (student_code) in filter + editor pickers
- [x] Create dialog uses Recurrence Type dropdown (No Recurrence/Daily/Weekly/
      Monthly/Yearly), not invented weekday chips; weekday row only for Weekly
- [x] Edit Options router (This shift / All in series (N) [Updates Template] /
      All for student / By time range) — appears for recurring shifts, detects
      recurrence via templateId OR recurrence field (base shift included)
- [x] Recurring create: base shift + createShiftTemplate(base_shift_id) +
      weekday snapping; verified template + 10 Wed instances match Flutter
- [x] Edit all in series: moved all 10 occurrences 2PM→4PM AND updated the
      template start_time to 16:00 (future shifts inherit) — verified in Firestore
- [ ] Quick Edit compact dialog (teacher+subject read-only, Delete/More Options/Save)
- [ ] Full editor polish: green Selected banners, Manage Subjects link,
      Scheduling-in-zone banner, Time Conversion Preview, Use Custom Shift Name, Video Provider

## F. UI parity (per owner review against the live Flutter screen)
- [x] Header: icon + "Shift Management", blue "+ Create Shift", refresh
- [x] Centered stat pills: Total / Active / Today / Upcoming
- [x] Underline tabs with counts + Grid/List pills
- [x] Full-width "Search Users Or Shifts" row
- [x] Week bar: "Previous Week ‹ | Mon m/d → Sun m/d | › Next Week"
- [x] Day headers with hour|count stats, today column tinted blue
- [x] Dialog: "Create New Shift / Configure Islamic Education Teaching
        Schedule", segmented "Teacher Class | Leader Duty | Meeting | Training"
