# Teacher Next.js Parity Matrix

Last updated: 2026-07-12. Coordination issue: #25.

This matrix tracks functional parity between the Flutter teacher role and
`apps/web`. Production is read-only during verification; mutations use
`alluwal-dev`.

| Area | Native route | Current functional checkpoint | Remaining acceptance work |
| --- | --- | --- | --- |
| Dashboard | `/teacher/` | Separated shell, resilient metrics, pending forms, active/imminent GPS clock lifecycle, exact details, correct Assignments shortcut, Flutter Islamic resources, persisted sidebar, role switch/logout | No known functional gap; retain in final regression |
| My Shifts | `/teacher/shifts/` | Day/week/month, exact deep links, details with join/class-report/issue actions, timezone, transactional clock actions, location denial, duplicate protection, reload recovery | No known functional gap; retain in final regression |
| Time Clock | `/teacher/time-clock/` | Transactional clock actions and draft submission, location/offline errors, duplicate-tab protection, reload recovery, filters, draft edit, desktop/mobile detail views | No known functional gap; retain in final regression |
| Tasks | `/teacher/tasks/` | Assignee-only list, filters, todo/in-progress/done lifecycle, completion metadata, stale/revoked errors, retryable load failure | No known functional gap; retain in final regression |
| Assignments | `/teacher/assignments/` | Flutter-compatible teacher-owned CRUD, student-name targeting, due dates, details/search, Storage attachments, file opening/cleanup, validation, mobile and guard states | No known functional gap; retain in final regression |
| Job Board | `/teacher/job-board/` | Targeted visibility, availability responses, concurrent-response protection, offline/permission errors, withdraw/rebroadcast | No known functional gap; retain in final regression |
| Chat | `/teacher/chat/` | Conversation creation/repair, live latest ordering, unread/read receipts, text/attachment/voice send, failed-send draft recovery, mobile browser-back navigation | No known functional gap; retain in final regression |
| Classes | `/teacher/classes/` | Schedule, presence, details, guest link, provider-specific RealtimeKit join | Real Zoom hub join verification |
| Classroom | `/teacher/classroom/` | Live dev teacher/guest join, active roster, lock denial, participant removal, media-denial fallback, and reconnect verified | Real Zoom hub join and return verification |
| Recordings | `/teacher/recordings/` | Native hierarchy, search, refresh, playback, missing-link and browser playback failure handling | No known functional gap; retain in final regression |
| Surah Podcasts | `/teacher/surah-podcasts/` | Native browse, shared assignments, empty selection, offline write preservation, responsive mobile share dialog | No known functional gap; retain in final regression |
| Curriculum Books | `/teacher/curriculum-books/` | Native content cards; all PDF/PPTX targets resolve with non-empty files and correct open/download destinations | No known functional gap; retain in final regression |
| Submit Form | `/teacher/submit-form/` | Current dev field inventory covered, shift selection/linking, deterministic duplicate protection, validation, image/signature uploads with orphan cleanup, offline value preservation | No known functional gap; retain in final regression |
| Form Submissions | `/teacher/form-submissions/` | Native history in TeacherShell, sidebar navigation, hydrated/fallback labels, uploaded files, missing-template legacy and empty-response states, retryable read failure | No known functional gap; retain in final regression |
| My Report | `/teacher/report/` | Current Flutter detail-screen parity: month selection, KPIs/payment/issues, classes/clock-ins/forms details, acknowledgement, discussion link, correction request/status, refresh, failure states, and shift/session CSV export | No known functional gap; retain in final regression |
| Profile | `/teacher/profile/` | Native guarded profile view/editor using Flutter-compatible `users`, `teacher_profiles`, and owner-scoped profile-picture contracts; responsive view, validation, write/upload errors, and verified photo upload/removal cleanup | No known functional gap; retain in final regression |
| Settings | `/teacher/settings/` | Native guarded account settings, password reauthentication/update, Flutter-compatible shift/task/chat/prayer notification preferences, persisted language/theme preferences, support/privacy destinations, and sign-out from desktop/mobile account navigation | Final language refinement |

## Completion rule

An area moves to complete only after its Flutter behavior is observed, its
desktop and mobile Next workflows pass, data writes are Flutter-compatible,
failure states are visible, focused browser coverage exists, and the full web
regression remains green. Cosmetic-only differences do not block completion
unless they would make the migration noticeable or impair use.
