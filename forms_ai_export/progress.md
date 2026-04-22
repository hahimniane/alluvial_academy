# Forms System - Full Investigation Report

**Date:** 2026-03-22
**Scope:** Complete audit of the Alluvial Academy forms system -- architecture, data, roles, loading, and organization.

---

## 1. High-Level Summary

| Metric | Value |
|--------|-------|
| Form Templates (new system) | 47 |
| Legacy Forms (old system) | 33 |
| **Total Form Definitions** | **80** |
| Total Questions/Fields | 1,320 |
| Distinct Field IDs | 599 |
| Form Response Documents (sampled) | 4,000+ |
| Firestore Project | alluwal-academy |
| Supported Languages | English, French, Arabic |

The forms system runs on a **dual architecture**: a legacy `form` collection and a modern `form_templates` collection. Both are actively used. The modern system adds versioning, role-based access (`allowedRoles`), auto-fill rules, frequency scheduling, and category-based organization.

---

## 2. Firestore Collections

| Collection | Purpose | Key Fields |
|------------|---------|------------|
| `form_templates` | Modern form definitions | fields, allowedRoles, frequency, category, version, isActive, autoFillRules |
| `form` | Legacy form definitions | title, fields, status, permissions, description |
| `form_responses` | All submitted form data | userId, formId, templateId, shiftId, formType, responses, yearMonth, submittedAt |
| `form_drafts` | Unsaved work-in-progress | title, description, fields, createdBy, lastModifiedAt |
| `settings/form_config` | Readiness form ID config | readinessFormId |
| `settings/pilot_flags` | Feature flags | (various) |
| `admin_preferences` | Admin UI state per user | favoriteTeacherIds, defaultViewMode, defaultShowAllMonths |
| `teaching_shifts` | Shift metadata for daily forms | student_names, subject_display_name, shift_start, shift_end |
| `timesheet_entries` | Shift completion / time clock | form_completed, form_response_id, clock_in, clock_out |
| `users` | User profiles | first_name, last_name, email, role |

### Firestore Indexes Used

- `form_responses: (formType, userId, submittedAt)` -- teacher daily/weekly/monthly lookups
- `form_responses: (yearMonth, submittedAt)` -- month-based admin filtering
- `form_responses: (shiftId, userId)` -- duplicate submission check

---

## 3. Architecture & Data Flow

```
Firestore (form_templates / form)
        |
        v
Service Layer
  - FormTemplateService      (loads templates, default definitions, deduplication)
  - FormConfigService        (readiness form config, 30-min cache)
  - FormLabelsCacheService   (in-memory label cache, request coalescing)
  - FormMigrationService     (version tracking, auto-cache-clear)
  - FormDraftService         (draft persistence, 30-day cleanup)
  - ShiftFormService         (shift-linked daily forms, pending detection)
        |
        v
Screens / UI
  - TeacherFormsScreen       (form catalog for teachers/coaches/admins)
  - AdminAllSubmissionsScreen (admin review of daily/weekly/monthly submissions)
  - FormScreen               (dynamic form renderer + submission)
  - MySubmissionsScreen       (teacher's own submission history)
  - FormSubmissionsScreen     (submissions for a specific form)
        |
        v
Widgets
  - FormDetailsModal         (view submitted form responses)
  - FilterPanel, ResponseList, ResponseDetailsPanel, UserSelectionDialog
```

### Submission Flow (Step by Step)

1. Teacher opens **TeacherFormsScreen** (screenIndex 22)
2. Templates loaded from `form_templates`, filtered by role + category
3. Teacher selects a form (e.g. Daily Class Report)
4. For daily forms: shift selection dialog shows recent shifts without `form_completed=true`
5. **FormScreen** renders fields dynamically, auto-fills shift context
6. Teacher fills editable fields, submits
7. Validation runs (required fields, type checks)
8. Images uploaded to Firebase Storage (with retry logic)
9. `form_responses` document created with full metadata
10. `timesheet_entries` updated (`form_completed=true`, `form_response_id` linked)
11. Audit system auto-ingests the response
12. Admin can review via **AdminAllSubmissionsScreen** (screenIndex 24)

---

## 4. Role System

### Roles in the System

| Role | Normalized From |
|------|----------------|
| `teacher` | tutor, tutors, teacher, teachers, instructor |
| `admin` | admins, administrator, administrators |
| `coach` | coaches |
| `student` | students |
| `parent` | parents |
| `leader` | (specific to some forms) |
| `ceo` | (specific to some forms) |
| `marketing` | (specific to some forms) |

### Role-Based Filtering Logic

**Admin / Coach:** See ALL forms (no filtering). Extra admin-only forms added dynamically.

**Teacher:** Filtered by:
1. If template has `allowedRoles` and `teacher` is NOT in list -> hidden
2. If template has `allowedRoles` and `teacher` IS in list -> shown
3. If no `allowedRoles`: shown if category is teaching/feedback/administrative/studentAssessment OR frequency is perSession/weekly/monthly

**Student / Parent:** Strict filtering -- only forms with their role explicitly in `allowedRoles`. No category-based defaults.

**Additional keyword filter:** Form titles containing admin-only keywords ("admin", "coach", "salary", "payroll", "audit", "leadership", "management") are hidden from teachers unless the title also contains teacher keywords.

---

## 5. Complete Form Catalog

### 5A. Default/Built-In Forms (11 forms hardcoded in FormTemplateService)

#### TEACHING FORMS (Teacher-facing)

| # | Form Name | Frequency | Category | Allowed Roles | Purpose |
|---|-----------|-----------|----------|---------------|---------|
| 1 | Daily Class Report | perSession | Teaching | teacher | Post-session report: lesson, students present, quality, issues |
| 2 | Weekly Summary | weekly (Sun-Tue) | Teaching | teacher | Weekly progress, achievements, challenges |
| 3 | Monthly Review | monthly (last/first 3 days) | Teaching | teacher | Performance evaluation |

#### FEEDBACK FORMS

| # | Form Name | Frequency | Category | Allowed Roles | Purpose |
|---|-----------|-----------|----------|---------------|---------|
| 4 | Teacher Feedback & Complaints | onDemand | Feedback | teacher, coach | Feedback type, subject, urgency, anonymous option |
| 5 | Feedback for Leaders | onDemand | Feedback | teacher | Teachers rate their leaders |
| 6 | Coach Performance Review | monthly | Feedback | **admin only** | Admin reviews coach performance |
| 7 | Admin Self-Assessment | monthly | Feedback | admin, coach | Self-assessment for admins/coaches |

#### STUDENT ASSESSMENT FORMS

| # | Form Name | Frequency | Category | Allowed Roles | Purpose |
|---|-----------|-----------|----------|---------------|---------|
| 8 | Student Assessment | onDemand | Student Assessment | teacher, coach, admin | Student skills, behavior, progress |
| 9 | Parent/Guardian Feedback | onDemand | Student Assessment | admin, parent | Parent satisfaction, communication quality |

#### ADMINISTRATIVE FORMS

| # | Form Name | Frequency | Category | Allowed Roles | Purpose |
|---|-----------|-----------|----------|---------------|---------|
| 10 | Leave Request | onDemand | Administrative | teacher, coach, admin | Leave type, dates, coverage |
| 11 | Incident Report | onDemand | Administrative | teacher, coach, admin | Incident documentation |

### 5B. Firestore Form Templates (47 templates -- key ones)

| # | Template ID | Title | Allowed Roles | Frequency | Category | Questions |
|---|-------------|-------|---------------|-----------|----------|-----------|
| 1 | 0Nsvp0FofwFKa67mNVBX | All Bi-Weekly Coachees Performance | admin, coach | onDemand | other | 34 |
| 2 | 0wxe4mCVTe3Y2ME67uEp | X Progress Summary Report | -- | -- | -- | 10 |
| 3 | 1jn3ilyI5P1QnoHSMe5E | Weekly Summary | (not null) | -- | -- | 3 |
| 4 | 3MB3jxkjcCdD11us9q4N | Marketing Weekly Progress Summary Report | admin, marketing | -- | other | 23 |
| 5 | 4G0oKBSTA8l0780cQ2Vx | Daily End of Shift Form - CEO | admin, ceo | -- | -- | 21 |
| 6 | 4RDaZtzNDgizrydeDCS5 | Daily Class Report | -- | -- | -- | 4 |
| 7 | 5aXUrmtZnRGC5lj0bx7a | Forms/Facts Finding & Complaints Report - Leaders/CEO | admin, leader | -- | -- | 13 |
| 8 | 6YBwJQoLQ5tNU3RjDp7f | Excuse Form for Teachers & Leaders | null (all) | -- | -- | 16 |
| 9 | FEjhCvAr2sG1d57QuqOb | Monthly Penalty/Repercussion Record | teacher | -- | -- | 10 |
| 10 | E4H9T7tYqZ2wP5x9K8vL | Summer Plans (Teachers & Admins) | -- | -- | -- | 5 |
| 11 | -- | Payment Request/Advance CEO | admin | -- | -- | -- |
| 12 | -- | Task Assignments (For Leaders) - CEO | -- | -- | -- | -- |
| 13 | -- | Students Break/Vacation Form - Kadijatu | -- | -- | -- | -- |
| 14 | -- | All Students Database - CEO | -- | -- | -- | -- |
| 15 | -- | Weekly Overdues Data By Mamoudou/CEO | -- | -- | -- | -- |
| 16 | -- | Students Assessment/Grade Form | -- | -- | -- | -- |
| 17 | -- | Teacher Complaints Form - Khadijatu/CEO | -- | -- | -- | -- |
| 18 | -- | Group BAYANA Attendance - Kadijatu | -- | -- | -- | -- |
| 19 | -- | Feedback for Leaders/Commentaires pour les dirigeants | -- | -- | -- | -- |
| 20 | -- | Finance Weekly Update Form - Salimatu/CEO | -- | -- | -- | -- |
| 21 | -- | PayCheck Update Form | -- | -- | -- | -- |
| 22 | -- | Students Status Form - CEO | -- | -- | -- | -- |
| 23 | -- | Mamoudou Week Progress Summary Report | -- | -- | -- | -- |
| 24 | -- | Pre Start and End of Semester Survey | -- | -- | -- | -- |
| 25 | -- | Teacher & Student Coordinator Weekly Progress Report | -- | -- | -- | -- |
| 26 | -- | Daily Zoom Hosting - CEO | -- | -- | -- | -- |
| 27 | -- | Monthly Review | -- | -- | -- | -- |
| 28 | -- | Award and Recognitions Tracker | -- | -- | -- | -- |
| 29 | -- | Student Follow Up - CEO | -- | -- | -- | -- |
| 30 | -- | Teachers Waitlist (Arabic, English, Aldam) | -- | -- | -- | -- |
| 31 | -- | Absences: Meetings, Classes and Events | -- | -- | -- | -- |
| 32 | -- | Idea Suggestion Form - CEO | -- | -- | -- | -- |
| 33 | -- | CEO Weekly Progress Form | -- | -- | -- | -- |
| 34 | -- | Readiness Form / Formulaire de preparation | -- | -- | -- | -- |
| 35 | -- | Test (development form) | -- | -- | -- | -- |

*(Plus 12 more templates and 33 legacy forms not individually listed above)*

### 5C. Legacy Forms (33 forms in `form` collection)

Top legacy forms by response volume:

| Form ID | Response Count |
|---------|---------------|
| Ur1oW7SmFsMyNniTf6jS | 2,253 |
| wxaLkeDOhZXyVqlT8UBI | 364 |
| XxgGuLqV5XaqVDUE7KbY | 242 |
| A6syiQXSIlRnftoFfud9 | 130 |
| (others with fewer responses) | ... |

---

## 6. Access Matrix (Who Sees What)

| Form | Teacher | Admin | Coach | Parent | Student |
|------|:-------:|:-----:|:-----:|:------:|:-------:|
| Daily Class Report | Y | Y* | Y* | - | - |
| Weekly Summary | Y | Y* | Y* | - | - |
| Monthly Review | Y | Y* | Y* | - | - |
| Teacher Feedback & Complaints | Y | Y* | Y | - | - |
| Feedback for Leaders | Y | Y* | - | - | - |
| Student Assessment | Y | Y | Y | - | - |
| Leave Request | Y | Y | Y | - | - |
| Incident Report | Y | Y | Y | - | - |
| **Coach Performance Review** | - | **Y** | - | - | - |
| Admin Self-Assessment | - | Y | Y | - | - |
| Parent/Guardian Feedback | - | Y | - | Y | - |
| Bi-Weekly Coachees Performance | - | Y | Y | - | - |
| Marketing Progress Report | - | Y | - | - | - |
| CEO Daily End of Shift | - | Y | - | - | - |
| Facts Finding & Complaints (Leaders) | - | Y | - | - | - |
| Excuse Form (Teachers & Leaders) | Y | Y | Y | Y | Y |
| Monthly Penalty Record | Y | - | - | - | - |
| Summer Plans | Y | Y | - | - | - |

*Y* = Admin/Coach can submit via TeacherFormsScreen but primarily reviews submissions via AdminAllSubmissionsScreen*

---

## 7. Screen Breakdown

### TeacherFormsScreen (screenIndex 22)
- **File:** `lib/features/forms/screens/teacher_forms_screen.dart` (2,027 lines)
- **Used by:** Teachers, Coaches, Admins (to submit forms)
- **Navigation:** Dashboard sidebar "Submit Form"
- **Behavior:** Loads all active templates, filters by user role, groups by category, shows availability indicators (daily now, weekly Sun-Tue, monthly end/start of month)

### AdminAllSubmissionsScreen (screenIndex 24)
- **File:** `lib/features/forms/screens/admin_all_submissions_screen.dart` (4,558 lines)
- **Used by:** Admins only
- **Navigation:** Dashboard sidebar "All Submissions"
- **Behavior:** Queries `form_responses` for daily/weekly/monthly types only (NOT onDemand). Shows grouped by teacher or by form. Filters by teacher, month, status, form type.
- **Pagination:** 500 items per batch, load-more on scroll
- **View modes:** by_teacher (default), by_form
- **Internal keys:** `__daily_class_report__`, `__weekly_report__`, `__monthly_report__`

### FormScreen (main renderer)
- **File:** `lib/form_screen.dart` (4,600+ lines)
- **Used by:** All roles when filling a form
- **Behavior:** Dynamic field rendering from any form/template. Auto-fill from shift data. Image upload. Validation. Submission with metadata linking to timesheet.

### MySubmissionsScreen
- **File:** `lib/features/forms/screens/my_submissions_screen.dart`
- **Used by:** Teachers viewing their own history
- **Behavior:** Month-based filtering, grouped by form type, read-only view via FormDetailsModal

---

## 8. Caching & Loading Strategy

### Current Caching Layers

| Layer | Service | Strategy | TTL |
|-------|---------|----------|-----|
| Field Labels | FormLabelsCacheService (singleton) | In-memory Map + request coalescing | Session lifetime |
| Readiness Form ID | FormConfigService | In-memory with timestamp check | 30 minutes |
| Template Version | FormMigrationService | SharedPreferences | Until version change |
| Admin Preferences | AdminAllSubmissionsScreen | Firestore doc per admin | Persistent |
| Shift Data | FormScreen | In-memory _formSubmissionShiftCache | Session lifetime |

### Loading Pattern

1. **Cache-first:** Admin screen shows cached data immediately, then fetches latest from Firestore
2. **Request coalescing:** FormLabelsCacheService prevents duplicate concurrent Firestore reads for the same form
3. **Pagination:** Admin submissions load 500 at a time with scroll-triggered load-more
4. **Three-query model:** Admin screen runs 3 parallel queries (daily, weekly, monthly) using `Future.wait()`

### Identified Performance Bottlenecks

1. **No label warm-up:** First access to any form's labels triggers a Firestore read. No batch prefetch exists.
2. **Full template load:** All templates loaded and then filtered client-side. No server-side role filtering.
3. **Large response sets:** Admin dashboard can load thousands of form_responses documents. Mitigated by pagination but initial load of 500 x 3 queries = up to 1,500 docs.
4. **Shift lookups per response:** Each daily form response may trigger a teaching_shifts read for context. Cached in memory but no warm-up.
5. **Template deduplication in memory:** All templates loaded, then filtered for duplicates by name/version. Could be expensive with many templates.
6. **Legacy + Modern dual queries:** System queries both `form` and `form_templates` collections, doubling reads in some paths.

---

## 9. Auto-Fill System

Forms support automatic field population via `autoFillRules`:

| Auto-Fill Field | Source | Editable |
|----------------|--------|----------|
| teacherName | User profile (first_name + last_name) | No |
| teacherEmail | Firebase Auth | No |
| sessionDate | shift.shift_start | No |
| sessionTime | Formatted shift start/end | No |
| className | shift.auto_generated_name | No |
| subject | shift.subject_display_name | No |
| shiftId | Shift document ID | No |
| weekEndingDate | Calculated | No |
| weekShiftsCount | Count of shifts in week | No |
| weekCompletedClasses | Count completed in week | No |
| monthDate | Current month date | No |
| monthTotalClasses | Month class count | No |
| monthCompletedClasses | Completed in month | No |

Auto-filled fields are hidden from the visible field count unless marked `editable: true`.

---

## 10. Field Types & Data Model

### Supported Field Types
- `text` -- Short text input
- `long_text` -- Multi-line text area
- `number` -- Numeric input
- `date` -- Date picker
- `time` -- Time picker
- `dropdown` -- Single-select dropdown
- `radio` -- Radio button group
- `checkbox` -- Checkbox group
- `multi_select` -- Multi-select chips

### Field ID Conventions
- **Numeric IDs:** Timestamp-based from form builder (e.g., `1754647635467`)
- **Semantic IDs:** Human-readable snake_case (e.g., `weekly_progress`, `achievements`, `challenges`)

### Form Response Document Structure

```json
{
  "formId": "string",
  "templateId": "string",
  "formName": "string",
  "formType": "daily | weekly | monthly | onDemand",
  "frequency": "perSession | weekly | monthly | onDemand",
  "userId": "string",
  "userEmail": "string",
  "firstName": "string",
  "lastName": "string",
  "responses": {
    "field_id_1": "value",
    "field_id_2": ["array", "values"]
  },
  "shiftId": "string (optional, daily forms)",
  "timesheetId": "string (optional)",
  "yearMonth": "2026-03",
  "submittedAt": "Timestamp",
  "status": "completed",
  "lastUpdated": "Timestamp"
}
```

---

## 11. Key Files Reference

| File | Lines | Purpose |
|------|-------|---------|
| `lib/form_screen.dart` | ~4,600 | Dynamic form renderer, auto-fill, submission |
| `lib/features/forms/screens/teacher_forms_screen.dart` | ~2,027 | Form catalog for teachers/coaches/admins |
| `lib/features/forms/screens/admin_all_submissions_screen.dart` | ~4,558 | Admin submission review dashboard |
| `lib/features/forms/screens/my_submissions_screen.dart` | -- | Teacher's own submission history |
| `lib/features/forms/screens/form_submissions_screen.dart` | -- | Submissions for a specific form |
| `lib/features/forms/widgets/form_details_modal.dart` | -- | Reusable form response viewer |
| `lib/features/forms/widgets/filter_panel.dart` | -- | Admin filtering UI |
| `lib/features/forms/widgets/response_details_panel.dart` | -- | Individual response view |
| `lib/features/forms/widgets/response_list.dart` | -- | Response list rendering |
| `lib/features/forms/widgets/user_selection_dialog.dart` | -- | Teacher selection for filtering |
| `lib/features/forms/utils/form_localization.dart` | -- | Multi-language support |
| `lib/core/services/form_template_service.dart` | -- | Template loading, defaults, versioning |
| `lib/core/services/form_config_service.dart` | -- | Readiness form config, 30-min cache |
| `lib/core/services/form_labels_cache_service.dart` | -- | Label cache, request coalescing |
| `lib/core/services/form_migration_service.dart` | -- | Version tracking, auto-cache-clear |
| `lib/core/services/form_draft_service.dart` | -- | Draft persistence, 30-day cleanup |
| `lib/core/services/shift_form_service.dart` | -- | Shift-linked daily forms |
| `lib/core/models/form_template.dart` | -- | FormTemplate, FormFrequency, FormCategory, FormFieldDefinition |
| `lib/core/models/form_draft.dart` | -- | FormDraft model |
| `lib/admin/form_builder.dart` | -- | Admin UI for creating/editing forms |
| `scripts/export_forms_ai_context.mjs` | 640 | Exports all form definitions from Firestore |
| `scripts/discover_form_fields.mjs` | 492 | Scans Firestore for field IDs and response keys |

---

## 12. Observations & Recommendations for Next Steps

### Organization Issues
1. **80 total forms is a lot.** Many appear to be person-specific (e.g., "Mamoudou Week Progress", "Salimatu/CEO", "Kadijatu"). Consider consolidating into generic templates with role/person parameters.
2. **Inconsistent allowedRoles:** Some templates have null allowedRoles (open to category defaults), others have explicit lists. Should standardize.
3. **Legacy + modern dual system:** 33 legacy forms still active alongside 47 templates. Migration path exists but is incomplete.
4. **Naming inconsistency:** Some forms have "CEO" in title, others use person names. Makes filtering and categorization harder.

### Loading Efficiency
1. **No server-side role filtering:** All templates loaded then filtered client-side. A Firestore query with `where('allowedRoles', arrayContains: userRole)` would reduce reads.
2. **No label warm-up:** Batch-prefetching labels for forms the user is likely to open would reduce perceived latency.
3. **Admin screen loads up to 1,500 docs on first load** (500 x 3 queries). Could add yearMonth filter by default to reduce initial load.
4. **Shift lookups are per-response:** Could batch-fetch shifts for all visible responses.

### Update Efficiency
1. **Form template versioning** is implemented but deduplication is client-side. Could move to Firestore query (`orderBy version desc, limit 1 per name`).
2. **FormMigrationService** auto-clears cache on version mismatch -- good, but version must be manually bumped.
3. **Draft auto-cleanup** (30+ days) is reactive. Could be a Cloud Function.

### Role Clarity
1. Some forms use `ceo`, `leader`, `marketing` as roles but these are not in the standard role normalization. These users likely have `admin` role and a separate title/position field.
2. The keyword-based admin filter (scanning titles for "admin", "salary", etc.) is fragile -- relies on naming conventions rather than data.

---

---

## 13. Implementation Log: AdminAllSubmissionsScreen Optimization

**Date:** 2026-03-22
**Target file:** `lib/features/forms/screens/admin_all_submissions_screen.dart`
**Before:** 4,558 lines | **After:** 4,130 lines (-428 lines, -9.4%)
**Flutter analyze:** 0 new warnings

### Problem Statement

The AdminAllSubmissionsScreen was the heaviest screen in the app (4,558 lines) and the primary admin view. It suffered from:
- Full widget rebuilds on every search keystroke (O(n) filter over 1500+ docs per character typed)
- Background pagination loop hammering the UI with rapid setState calls, no throttle
- Stats computed in a redundant second O(n) pass that was always invalidated
- ~428 lines of dead code (unused widgets, unreachable methods, dead variables)
- No month navigation arrows (admins had to open a picker to change month)
- Empty state gave no context about which filters were causing zero results

### Changes Applied

#### 1. Search Debounce (300ms)
- Added `Timer? _searchDebounce` field
- Search `onChanged` now cancels previous timer and schedules setState after 300ms pause
- Clear button still works instantly (no debounce on clear)
- Eliminates ~5-15 full O(n) filter passes per search interaction

#### 2. Inline Stats Computation
- `_filteredSubmissions` getter now accumulates `uniqueTeachers`, `completedCount`, `pendingCount` during the filter loop
- `_statsCache` is populated inline instead of being nullified and recomputed in `_quickStats`
- Eliminates a full second O(n) pass over filtered data on every build

#### 3. Background Loading Throttle + Progress Indicator
- Added 100ms `Future.delayed` between background pagination iterations
- Added `_isBackgroundLoading` boolean state
- Thin `LinearProgressIndicator` appears below toolbar during background loading
- UI stays responsive instead of being hammered by rapid setState calls

#### 4. Dead Code Removal (-428 lines)
Removed the following unused code:

| Item | Lines Removed | Reason |
|------|--------------|--------|
| `AnimatedPopupMenuButton` class | ~38 | Never instantiated anywhere |
| `_AdminFormSheet` + `_AdminFormSheetState` | ~338 | Only used by `_showAdminFormSubmissionsSheet` which was never called |
| `_FormRow` + `_FormRowState` | ~114 | Never instantiated in this file |
| `_showAdminFormSubmissionsSheet` method | ~19 | Never called |
| `_filteredByForm` getter | ~22 | Never called from rendering path |
| `_byFormCache` field + invalidations | ~3 | Only used by removed `_filteredByForm` |
| `_viewMode` variable | ~1 | Always set to `'by_teacher'`, never controlled any UI |
| `_defaultViewMode` variable + references | ~5 | Loaded from Firestore but never affected UI |

`_saveAdminPreferences` still writes `'defaultViewMode': 'by_teacher'` (hardcoded) to avoid breaking stored Firestore preferences.

#### 5. Month Navigation Arrows
- Added left/right `IconButton` arrows flanking the month display in `_buildMonthBanner()`
- `_availableMonths` is sorted descending (newest first): left arrow = older month, right arrow = newer month
- Arrows disabled at boundaries (oldest/newest available month)
- Tapping an arrow calls `_loadMonthSubmissions()` directly -- no picker needed

#### 6. Improved Empty State with Filter Summary
- When no submissions match, active filters now show as small chips below the "No submissions found" message
- Each chip shows: icon + filter label + "x" close button
- Chips cover: teacher filter (with count), month, status, form type
- Tapping "x" on a chip clears that specific filter immediately
- New `_filterChip()` helper widget added for consistent styling

### What's Left (Not Addressed in This Pass)

These items from the investigation remain as future work:

| Item | Screen | Priority |
|------|--------|----------|
| No server-side role filtering on template load | TeacherFormsScreen | Medium |
| No label warm-up / batch prefetch | FormLabelsCacheService | Medium (partially addressed: review mode now prefetches top 30) |
| Cryptic availability labels ("Sun-Tue", "End/Start") | TeacherFormsScreen | High (UX) |
| Completion badge tracks per-frequency not per-template | TeacherFormsScreen | Medium (UX) |
| Shift selection dialog lacks grouping by date | TeacherFormsScreen | Medium (UX) |
| Legacy forms (33) not migrated to templates | Systemic | Low |
| Person-specific form names need generalization | Firestore data | Low |
| `_cGreen` unused field (pre-existing warning) | admin_all_submissions_screen | Trivial |

---

---

## 14. Bug Fix Log: Form Label Resolution

**Date:** 2026-03-22
**Related bugs:** Bugs 1-4 from screenshot review

### Bug Status Summary

| Bug | Description | Status |
|-----|-------------|--------|
| Bug 1 | Form names not showing in admin popup list | **FIXED** |
| Bug 2 | (N/A - covered by other fixes) | **FIXED** |
| Bug 3 | Raw numeric field IDs shown instead of human-readable labels | **FIXED** |
| Bug 4 | Form names not showing in Review Mode left panel | **FIXED** |

### What Was Fixed

#### Bugs 1 & 4: Form Names in Admin Popup & Review Mode Left Panel
Form names now display correctly in both the admin popup list (FormDetailsModal) and the Review Mode left panel. Label resolution via `FormLabelsCacheService` works correctly for these views.

#### Bug 3: Raw Numeric IDs in Review Mode Detail Panel

**Symptoms:** Legacy/CEO forms ("Daily End of Shift form - CEO", "Daily Zoom Hosting-CEO", "Forms/Facts Finding & Complains Report - leaders/CEO") showed raw numeric field IDs (e.g., `1754647635467`) instead of human-readable question labels in the Review Mode inline detail panel.

**Root Cause:** ID mismatch between prefetch and lookup in `AdminSubmissionsReviewScreen`.

The review mode detail panel uses `FormSubmissionDetailsView` (from `form_details_modal.dart`), which calls `FormLabelsCacheService().getLabelsForFormResponse(widget.formId)`. This method expects a **form_response document ID** — it looks up the document in `form_responses` to find the `formId`/`templateId`, then fetches labels from the corresponding `form` or `form_templates` document.

The label prefetch (`_prefetchLabelsWarm`) correctly cached labels using `d.id` (the response document ID):
```dart
// Line 3727 — correct: uses response document ID
chunk.map((id) => svc.getLabelsForFormResponse(id))
```

But when building the detail panel, the code passed `data['formId']` (the **form template ID**, e.g., `daily_end_of_shift_ceo`) instead of the response document ID:
```dart
// Line 4158 — was broken:
final formId = (data['formId'] ?? _selectedSubmission!.id).toString();
```

This meant `getLabelsForFormResponse` tried to find a document in `form_responses` using a template ID as the key. That document doesn't exist, so `formId` and `templateId` both resolve to null, and no labels are returned. The widget then falls back to displaying raw field IDs.

**The Fix:** Changed line 4158 in `admin_all_submissions_screen.dart`:
```dart
// After fix:
final formId = _selectedSubmission!.id;
```

Now the review mode passes the actual form_response document ID, matching what the prefetch cached and what `getLabelsForFormResponse` expects.

**Why the eye-icon modal worked:** `FormDetailsModal.show` was always called with `doc.id` (the response document ID) from all call sites — e.g., line 3186: `formId: doc.id`. So label resolution worked there all along.

**File changed:** `lib/features/forms/screens/admin_all_submissions_screen.dart` (line 4158, 1 line)

### Dead Code Note

`ResponseDetailsPanel` was deleted in Phase 4.2 below — it was never imported or used anywhere in the app.

---

## 15. Performance, Reactivity & Builder Fixes

**Date:** 2026-03-22
**Flutter analyze:** 0 new warnings (123 pre-existing)

### Phase 1: High-Speed Loading

| # | Change | File | Impact |
|---|--------|------|--------|
| 1.1 | Added `formTitle` key to submission data | `lib/form_screen.dart` | Eliminates 2 enrichment queries per new submission in admin screen |
| 1.2 | Parallelized `_loadAllData()` and `_loadSubmissionStatus()` | `lib/features/forms/screens/teacher_forms_screen.dart` | ~50% faster teacher screen load (5 sequential queries -> 2 parallel batches) |
| 1.3 | Added cache-first display to admin month view | `lib/features/forms/screens/admin_all_submissions_screen.dart` | Near-instant display on repeat visits (uses existing `_queryAllFormsByMonthCacheOnly` which was never called) |
| 1.4 | Parallelized admin screen initialization | `lib/features/forms/screens/admin_all_submissions_screen.dart` | Preferences, teachers, and submissions load concurrently via `Future.wait()` |

**Key discovery (1.1):** Form submissions stored the name as `formName` but admin screen looked for `formTitle`/`form_title`/`title`. This mismatch caused every submission to trigger 2 Firestore queries (form_templates + form collection) just to resolve the title. Adding `formTitle` eliminates this for all new submissions.

### Phase 2: Reactivity / Stale Data

| # | Change | File | Impact |
|---|--------|------|--------|
| 2.1 | Added refresh-on-tab-switch for indexes 22 & 24 | `lib/dashboard.dart` | Teacher and admin screens reload fresh data when navigated to (matches existing pattern for index 9) |
| 2.2 | Added refresh-on-return from review screens | `lib/features/forms/screens/admin_all_submissions_screen.dart` | 3 Navigator.push calls now reload current month on pop-back |
| 2.3 | Added 15-min TTL + 200-entry cap to labels cache | `lib/core/services/form_labels_cache_service.dart` | Labels refresh after template updates; cache won't grow unbounded |
| 2.4 | Added 5-min TTL + 100-entry cap to shift cache | `lib/features/forms/widgets/form_details_modal.dart` | Shift data refreshes after updates; cache won't grow unbounded |

### Phase 3: Image Upload Performance

| # | Change | File | Impact |
|---|--------|------|--------|
| 3.1 | Removed per-upload connectivity test | `lib/form_screen.dart` | Saves 2-5 seconds per image upload (was uploading/deleting a 5-byte test file before every real upload) |
| 3.2 | Implemented actual image compression | `lib/form_screen.dart` + `pubspec.yaml` | Images > 2MB resized to 1920px@70%, > 1MB to 2560px@75%, others re-encoded at 80% quality. Uses `image` package. |

### Phase 4: Form Builder & Cleanup

| # | Change | File | Impact |
|---|--------|------|--------|
| 4.1 | Replaced timestamp field IDs with UUID v4 | `lib/admin/form_builder.dart` | Eliminates collision risk from rapid question creation |
| 4.2 | Deleted dead code `ResponseDetailsPanel` | `lib/features/forms/widgets/response_details_panel.dart` | File removed (was never imported or used) |
| 4.3 | Documented auto-fill rules gap | `lib/admin/form_builder.dart` | TODO comment added at `autoFillRules: []` |

### Files Modified

| File | Changes |
|------|---------|
| `lib/form_screen.dart` | +formTitle key, removed connectivity test, implemented image compression |
| `lib/features/forms/screens/teacher_forms_screen.dart` | Parallelized loading |
| `lib/features/forms/screens/admin_all_submissions_screen.dart` | Cache-first display, parallel init, refresh-on-return |
| `lib/dashboard.dart` | Refresh trigger for indexes 22 & 24 |
| `lib/core/services/form_labels_cache_service.dart` | TTL + max entries |
| `lib/features/forms/widgets/form_details_modal.dart` | Shift cache TTL + max entries |
| `lib/admin/form_builder.dart` | UUID field IDs, auto-fill TODO |
| `pubspec.yaml` | Added `image: ^4.3.0` |
| `lib/features/forms/widgets/response_details_panel.dart` | **Deleted** |

---

*This report was generated by investigating the codebase, Firestore export data, and all form-related services/screens. The forms_ai_context.json (1.6 MB) in this folder contains the full structured export of all 80 form definitions with field details.*
