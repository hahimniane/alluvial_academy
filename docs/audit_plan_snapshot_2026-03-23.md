# Audit Plan Snapshot (2026-03-23)

## Manifest
- Snapshot created before Admin Audit HTML redesign implementation.
- Source files:
  - `d:\alluvial_academy\docs\audit_todo.md`
  - `d:\alluvial_academy\docs\audit_redesign_spec.md` (not found at snapshot time)
  - `d:\alluvial_academy\CLAUDE.md`

---

## Copy: `docs/audit_todo.md`

```md
# Audit Redesign — Implementation Phases

Full specification: `docs/audit_redesign_spec.md`
Form field data: `forms_ai_export/forms_ai_context.json`

---

## PHASE 1: Critical Bug Fixes (do first, small scope)
- [x] Fix tier case mismatch: updateAuditFactors in teacher_audit_service.dart writes capitalized tiers ('Excellent'), teacher UI expects lowercase ('excellent') → unify to lowercase in updateAuditFactors
- [x] Fix unused AuditStatus enum values: remove coachReview/ceoReview/founderReview from enum and filters, or wire them into actual transitions
- [x] Fix teacher "My Report" status gate: show read-only summary for coachSubmitted+ states, not just completed
- [x] Fix month picker: use getAvailableYearMonths() instead of hardcoded 12 months
- [x] Fix score display: show both automaticScore and overallScore with labels so score drop after coach eval is explained
- [x] Fix performanceTier write in updateAuditFactors: use _calculateTier(overallScore) instead of the separate factor-sum tier system

## PHASE 2: Scoring Redesign (medium scope, model changes)
- [x] Migrate AuditFactor.rating from 1-9 to 0-5 scale (update model, service, UI, Excel export)
- [x] Remove +35 floor from automaticScore formula
- [x] Unify tier system: one set of thresholds, one casing, used everywhere
- [x] Wire the 12 hardcoded-zero fields to real data OR remove from model/display
- [x] Auto-populate factor scores from form_responses data (read Bi-Weekly Coachees form fields → map to quiz_goal, assignment_goal, etc.)
- [x] Update CoachEvaluationScreen for 0-5 scale with descriptive labels per level
- [x] Update Excel export for new scale

## PHASE 3: Audit UX Overhaul (large scope, new screens)
- [x] Build in-app audit editing with change log (replace Excel-as-editor workflow) — PR2
- [x] Build audit review mode (master-detail layout like AdminSubmissionsReviewScreen) — PR1
- [x] Add form response content display in teacher "My Report" Classes tab — PR1
- [x] Integrate facts/findings and penalty forms as structured incidents in audit
- [x] Add cross-navigation between AdminAllSubmissionsScreen and AdminAuditScreen — PR3a
- [x] Show form breakdown in audit: accepted / orphaned / rejected with reasons

## PHASE 4: System Integration (large scope, cross-feature)
- [x] Add firstOpenedAt tracking to tasks model + UI — PR4a
- [x] Leave request → shift reconciliation (auto-flag affected shifts on approval) — PR4b
- [x] Admin audit (lightweight parallel tracking for admin form submissions and task completion) — PR4c
- [x] Notification when audit status changes to a state the teacher should see — PR4d
- [ ] Form template cleanup: consolidate duplicates, remove person names from titles, standardize allowedRoles
- [ ] Fix Firestore field naming: clock_out_time vs clock_out_timestamp, shift_id vs shiftId
```

---

## Copy: `CLAUDE.md`

```md
# Alluvial Academy — Claude Code Project Instructions

## Project
Flutter web app for Islamic education management. Firestore backend, deployed on Hostinger.
Build: `./increment_version.sh && flutter build web --release`
Localization: `flutter gen-l10n` after editing any `lib/l10n/*.arb` file.

## Audit Redesign (active project)
- Full spec with architecture, bugs, and requirements: `docs/audit_redesign_spec.md`
- Phased implementation checklist: `docs/audit_todo.md`
- Complete form field export (80 forms, 1,320 fields): `forms_ai_export/forms_ai_context.json`
- Readable form digest: `forms_ai_export/forms_ai_context.md`
- Forms system investigation report: `forms_ai_export/progress.md`

## Key source files for audit work
- Model: `lib/core/models/teacher_audit_full.dart`
- Service: `lib/core/services/teacher_audit_service.dart`
- Admin audit screen: `lib/admin/screens/admin_audit_screen.dart`
- Coach eval screen: `lib/admin/screens/coach_evaluation_screen.dart`
- Teacher "My Report": `lib/features/audit/screens/teacher_audit_detail_screen.dart`
- Excel export: `lib/core/services/advanced_excel_export_service.dart`
- Admin submissions: `lib/features/forms/screens/admin_all_submissions_screen.dart`

## Gotchas
- NEVER run `flutter build web --release` without `./increment_version.sh` first
- After editing ARB files, run `flutter gen-l10n` or new keys won't resolve
- Firestore has inconsistent field naming: clock_out_time vs clock_out_timestamp, shift_id vs shiftId
- Two tier systems exist (lowercase from _calculateTier, capitalized from updateAuditFactors) — this is a known bug to fix
- 12 audit fields (quizzesGiven, assignmentsGiven, overdueTasks, etc.) are hardcoded to 0 — never computed
- Teacher "My Report" only shows audits with status=completed, which requires full 3-step review chain
```
