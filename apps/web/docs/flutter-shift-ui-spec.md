# Flutter Admin Shift System — captured spec (source of truth for the Next.js port)

Captured from the live Flutter web app (alluwaleducationhub.org/app/) by walking
every screen and dialog. Font throughout: **Inter** (GoogleFonts.inter). Accent
blue `#0386FF`, ink `#1F2937`.

## 1. Page header (Shift Management)
- Breadcrumb "Operations / Shifts" (tiny, top-left of content)
- Row: clock icon + **"Shift Management"** (bold ~20px)  ·  right side:
  **"+ Create Shift"** (blue filled pill), gear icon, **"Select"** (multi-select
  mode toggle), "Search Teacher (39)" inline search, **"Delete Teacher Shifts"**
  (disabled unless selecting), refresh icon.
- Stat pills row, centered: **Total 9214** (blue), **Active 4** (green),
  **Today 24** (amber), **Upcoming 2172** (purple). Each: icon + label + count.
- Tabs: "All Shifts (9214) | Today (24) | Upcoming (2172) | Active (4)" — blue
  underline on active. Right: **Grid / List** toggle (blue filled = active).
- Full-width search: "Search Users Or Shifts" (magnifier) + filter funnel icon at far right.
- Week bar: **"📅 Previous Week ‹"**  ·  centered **"Mon 8/24 → Sun 8/30"**  ·  **"› Next Week"**.

## 2. Weekly grid
- Left column header: "Teachers (52)" with a small **‹ Mon 8/24 → ›** mini-nav inside it.
- Day headers: bold weekday, `M/D`, and a stats line **"⏱ 68.5  📋 33"** (hours, count).
  Today's column tinted light blue, weekday label blue.
- Section band: **"👜 TEACHERS (35)"** grey bar. (Leaders section below if present.)
- Row: avatar initials (blue circle) + name + stats line "⏱ 13.0  📋 13".
- **Cells are tall (~150px+) and the shift chip FILLS the cell background** with a
  translucent status/subject color (not a small card). Past shifts: red/green tint
  by status. Multiple shifts stack, each with an `i/N` badge top-right.
- Chip content: **"5:00-6:00"** (bold, top-left) + **"Quran Studies"** (subject,
  under it) + person-add icon top-right; `i/N` badge when >1.
- Empty future cell: hover → **blue "+"** appears.
- **Chip hover toolbar** (appears over the chip): **✏ pencil (Edit)** · **⋮ (details/menu)**
  · **🗑 red trash (Delete)** · **blue "+" (add here)**.

## 3. Shift Details dialog (opens from the ⋮ on a chip)
- Header: blue calendar icon + **"Shift Details"** / subtitle "Teacher - Subject - Student".
- **Status banner** (colored by status): e.g. purple check **"Fully Completed"** /
  "All scheduled time was worked".
- **"📅 Schedule Information"** card — label/value rows: Date (`Tuesday, August 25, 2026`),
  Time (`12:00 PM - 1:00 PM`), Duration (`1.0 hours`), Subject (`Quran Studies`),
  Hourly Rate (`$4.00/hr`).
- **"👥 Participants"** card — Teacher, Students.
- **"◉ Class recording"** — "Recording is disabled for this class" + toggle +
  "Only admins can allow recording for a specific class."
- **"🕐 Timesheet Records (N)"** card — Total Worked (`01:00:00`), Clock In, Clock Out,
  Duration, + full-width outlined **"✏ Edit Entry"** button.
- Footer: **"Close"**  ·  **"🎥 Class Ended"** (gray/disabled when past).

## 4. Edit Options router (opens from the ✏ pencil on a recurring chip)
Header: sliders icon + **"Edit Options"** / subtitle. Four tappable cards with chevrons:
1. **Edit This Shift Only** — "Quick Edit Or Full Editor For…"
2. **Edit all in series (12)** [amber "Updates Template" badge] — "Apply Changes To All Shifts And…"
3. **Edit All Shifts For A Student** — "Bulk Edit Every Class For The…"
4. **Edit By Time Range Student** — "Find Shifts For A Student Matching…"
Footer: **Cancel**. (For a NON-recurring shift, the pencil goes straight to Quick Edit.)

## 5. Quick Edit dialog ("Edit This Shift Only")
- Header: blue calendar-pencil + **"Quick Edit"** / subtitle + X.
- **Teacher: <name>** (person icon, read-only). **Subject: <name>** (cap icon, read-only).
- Date dropdown: "📅 Tue, Aug 25, 2026".
- **Timezone** (ⓘ) dropdown: "Reykjavik (Atlantic/Reykjavik) - GMT (UTC…".
- **Start Time: 4:00 PM** / GMT   —   **End Time: 5:00 PM** / GMT (two tappable time chips).
- **Notes** field.
- Footer: red outlined **"🗑 Delete"**  ·  **"More Options"** (text)  ·  blue **"Save"**.

## 6. Full editor ("More Options" / Create New Shift / Edit Shift)
- Header: blue clock icon + **"Edit Shift"** (or "Create New Shift") /
  **"Configure Islamic Education Teaching Schedule"** + X.
- **Schedule Type** segmented: **Teacher Class ✓ | Leader Duty | Meeting | Training** (each w/ icon).
- **Teacher \*** — green banner "✓ Selected: <name>" + "Change" link; "Change teacher (optional)"
  search + **radio** list (avatar, name, TEACHER badge, email).
- **Students** — green banner "N student selected" + removable chips; "Change students (optional)"
  search + **checkbox** list (STUDENT badge, name, email).
- **Subject** (+ "Manage Subjects" link) dropdown.
- **Hourly Rate Usd** number input ("$4.00").
- **Timezone** (ⓘ) dropdown + blue banner "🔁 Scheduling in <zone>".
- **Schedule** — Date picker (✏) + **Time (GMT)** Start "4:00 PM" To End "5:00 PM" +
  **Time Conversion Preview**: "Selected (GMT): …" and "Your time (EDT): …" (blue).
- **Recurrence Settings** — "Recurrence Type" dropdown: **No Recurrence / Daily / Weekly /
  Monthly / Yearly**.
- **☐ Use Custom Shift Name** checkbox.
- **Notes** textarea ("Add Any Additional Notes Or Instructions").
- **Video Provider** — "🎥 Zoom" card.
- Footer: **Cancel**  ·  blue **"Update Shift"** (or "Create Shift").

## 7. Delete confirmation dialog
- **"Delete Shift"** title.
- "Are you sure you want to delete "<name>"? This action cannot be undone."
- Recurring: "This shift is part of a recurring series. You can delete just this shift,
  or delete this shift and all future scheduled shifts (N)."
- "Completed/active shifts are not deleted."
- Footer: **Cancel**  ·  red text **"Delete This Shift"**  ·  red filled **"Delete This & Future (N)"**.

## Gaps in my current Next.js build to fix
- Chip must FILL the cell with status/subject tint (not a small card).
- Chip hover toolbar (pencil / details / trash / +) — currently only whole-chip click.
- Details dialog: my labels/sections are close but need Schedule Information / Participants /
  Class recording / Timesheet Records card styling + status banner copy.
- Pencil must open the **Edit Options** router for recurring shifts (I don't have this at all).
- **Quick Edit** dialog (teacher/subject read-only, date/tz/time/notes, Delete/More Options/Save)
  — I don't have this; I jump straight to the full editor.
- Full editor: add **Schedule Type icons**, green "Selected" banners, "Manage Subjects" link,
  "Scheduling in <zone>" banner, **Time Conversion Preview**, recurrence dropdown
  (Daily/Weekly/Monthly/Yearly, not just weekly checkboxes), **Use Custom Shift Name** checkbox,
  **Video Provider** card.
- Delete copy + button labels: "Delete This Shift" / "Delete This & Future (N)".
