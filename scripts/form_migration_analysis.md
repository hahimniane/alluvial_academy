# Form Collection Migration Analysis - COMPLETE

## Executive Summary

This document analyzes all forms in the `form` collection and details the complete reorganization into the optimized `form_templates` system with categories, frequencies, and role-based access.

---

## NEW FORM TEMPLATE SYSTEM

### Category 1: Teaching Forms (`teaching`)
**For: Teachers | Frequency: Time-based**

| Template ID | Name | Frequency | Description |
|------------|------|-----------|-------------|
| `daily_class_report` | Daily Class Report | `perSession` | Quick 5-question report after each class |
| `weekly_summary` | Weekly Summary | `weekly` (Sun-Tue only) | End of week teaching summary |
| `monthly_review` | Monthly Review | `monthly` (End/Start of month) | Monthly teaching review |

### Category 2: Feedback Forms (`feedback`)
**For: Teachers, Coaches, Admins | Frequency: On-demand**

| Template ID | Name | Allowed Roles | Description |
|------------|------|---------------|-------------|
| `teacher_feedback` | Teacher Feedback & Complaints | teacher, coach | Submit feedback, suggestions, complaints |
| `leadership_feedback` | Feedback for Leaders | teacher | Rate coach/supervisor performance |
| `admin_self_assessment` | Admin Self-Assessment | admin, coach | Monthly self-evaluation |
| `coach_performance_review` | Coach Performance Review | admin only | Admin evaluates coaches monthly |

### Category 3: Student Assessment Forms (`studentAssessment`)
**For: Teachers, Coaches, Admins, Parents | Frequency: On-demand**

| Template ID | Name | Allowed Roles | Description |
|------------|------|---------------|-------------|
| `student_assessment` | Student Assessment | teacher, coach, admin | Evaluate student progress (9 fields) |
| `parent_feedback` | Parent/Guardian Feedback | admin, parent | Parents rate teachers |

### Category 4: Administrative Forms (`administrative`)
**For: Teachers, Coaches | Frequency: On-demand**

| Template ID | Name | Allowed Roles | Description |
|------------|------|---------------|-------------|
| `leave_request` | Leave Request | teacher, coach | Request time off with shift tracking |
| `incident_report` | Incident Report | teacher, coach, admin | Report issues with follow-up tracking |

---

## FORMS REMOVED (No Migration)

| Original Form | Reason for Removal | Replacement |
|--------------|-------------------|-------------|
| PayCheck Update Form | Manual payout tracking | **Audit System** auto-calculates payments |
| Zoom Meeting Forms | Zoom no longer used | N/A |
| Class Readiness Form (old) | Already migrated | `daily_class_report` template |
| Fact Finding Form | Manual investigation | **Task System** with Investigation label |
| Duplicate/Test Forms | Cleanup | N/A |

---

## STAFF RANKING SYSTEM

### Teacher Leaderboard (`staff_leaderboards` collection)

**Ranking Categories:**
1. **Overall Performance** - Combined weighted score
2. **Attendance & Punctuality** - 60% completion + 40% on-time
3. **Form Compliance** - Daily/Weekly/Monthly submission rate
4. **Teaching Quality** - Coach evaluation scores
5. **Parent Satisfaction** - Parent feedback scores (new)

**Monthly Awards:**
- 🏆 **Teacher of the Month** - Best overall (≥75%)
- ⏰ **Most Reliable** - Best attendance (≥90%)
- 📋 **Most Diligent** - Best form compliance (≥95%)
- ⭐ **Top Rated** - Best coach evaluation (≥80%)
- 📈 **Most Improved** - Biggest score increase (+10 pts)

### Admin/Coach Leaderboard

**Metrics Tracked:**
- Tasks completed per month
- Audit completion timeliness
- Response time to issues
- Teacher satisfaction scores (from feedback)
- Team retention rate

**Monthly Awards:**
- 🎯 **Admin of the Month** - Best overall admin
- 👑 **Coach of the Month** - Best coach performance

---

## LEAVE REQUEST TRACKING

**Data Captured:**
- Leave type (Sick, Personal, Family, Religious, Pre-planned, Other)
- Duration (start/end date, affected shifts)
- Advance notice provided
- Coverage arranged status
- Approval status (pending/approved/rejected)

**Impact on Audit:**
- Leave requests counted in attendance metrics
- Approved leaves don't count as "missed" shifts
- Frequent leave requests flagged for review
- Advance notice tracked for compliance scoring

---

## WORKFLOW OPTIMIZATIONS

### 1. Leave Request Workflow
```
Teacher submits Leave Request form
    ↓
Admin receives notification
    ↓
Admin approves/rejects in form_responses
    ↓
Affected shifts automatically updated
    ↓
Tracked in monthly audit (approved vs rejected ratio)
```

### 2. Payout Workflow (via Audit)
```
Audit auto-calculates payout from:
  - Completed shifts
  - Hourly rates
  - Deductions (missed, late)
    ↓
CEO reviews in Audit screen
    ↓
CEO marks payment as "Paid"
    ↓
Teacher sees summary in their screen
    ↓
Teacher confirms receipt
```

### 3. Teacher Ranking Workflow
```
End of month:
  - All audits finalized
  - LeaderboardService.generateLeaderboard(yearMonth)
  - Rankings calculated by category
  - Awards determined automatically
  - Results saved to staff_leaderboards
  - Top performers displayed in dashboard
```

---

## FILES CREATED/MODIFIED

### New Files:
- `lib/core/models/staff_leaderboard.dart` - Leaderboard model with rankings
- `lib/core/services/leaderboard_service.dart` - Generate rankings from audits
- `scripts/migrate_forms_to_templates.js` - Migration script

### Modified Files:
- `lib/core/models/form_template.dart` - Added `onDemand` frequency, `category`, `allowedRoles`
- `lib/core/services/form_template_service.dart` - Added 7 new default templates
- `lib/features/forms/screens/teacher_forms_screen.dart` - Shows all categories by role

---

## NEW TEMPLATE SUMMARY

| # | Template Name | Category | Frequency | Roles |
|---|--------------|----------|-----------|-------|
| 1 | Daily Class Report | teaching | perSession | teacher |
| 2 | Weekly Summary | teaching | weekly | teacher |
| 3 | Monthly Review | teaching | monthly | teacher |
| 4 | Teacher Feedback | feedback | onDemand | teacher, coach |
| 5 | Leadership Feedback | feedback | onDemand | teacher |
| 6 | Admin Self-Assessment | feedback | monthly | admin, coach |
| 7 | Coach Performance Review | feedback | monthly | admin |
| 8 | Student Assessment | studentAssessment | onDemand | teacher, coach, admin |
| 9 | Parent Feedback | studentAssessment | onDemand | admin, parent |
| 10 | Leave Request | administrative | onDemand | teacher, coach |
| 11 | Incident Report | administrative | onDemand | all |

---

## IMPLEMENTATION CHECKLIST

- [x] Add `FormFrequency.onDemand` enum value
- [x] Add `FormCategory` enum with 5 categories
- [x] Add `category` field to `FormTemplate` model
- [x] Add `allowedRoles` field for role-based access
- [x] Create 7 new default templates
- [x] Create `LeaderboardEntry` model
- [x] Create `MonthlyLeaderboard` model
- [x] Create `LeaderboardService` for ranking calculations
- [x] Update `TeacherFormsScreen` to show all categories
- [x] Role-based form visibility in UI
- [ ] Integrate leaderboard into admin audit screen
- [ ] Add Leave Request approval workflow
- [ ] Create Parent Feedback submission portal
- [ ] Add leaderboard widget to dashboards

---

## FIRESTORE COLLECTIONS

| Collection | Purpose |
|-----------|---------|
| `form` | **DEPRECATED** - Old forms (keep for historical data) |
| `form_templates` | New template system |
| `form_responses` | Form submissions (both old and new) |
| `staff_leaderboards` | Monthly rankings by yearMonth |
| `teacher_audits` | Audit data (source for leaderboard) |

---

## NEXT STEPS

1. **Run migration script** to move useful forms to `form_templates`
2. **Deprecate** old forms (set `status: 'deprecated'`)
3. **Test** new forms in app
4. **Integrate** leaderboard into admin dashboard
5. **Configure** approval workflow for leave requests
6. **Deploy** and monitor
