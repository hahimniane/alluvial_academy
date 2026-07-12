# Teacher Next.js Parity Matrix

Last updated: 2026-07-12. Coordination issue: #25.

This matrix tracks functional parity between the Flutter teacher role and
`apps/web`. Production is read-only during verification; mutations use
`alluwal-dev`.

| Area | Native route | Current functional checkpoint | Remaining acceptance work |
| --- | --- | --- | --- |
| Dashboard | `/teacher/` | Native shell, metrics, quick access, sidebar, mobile drawer | Full role-switch/logout and stale metric failure pass |
| My Shifts | `/teacher/shifts/` | Day/week/month, details, issue report, timezone, transactional clock actions, location denial, duplicate-tab protection, reload recovery | No known functional gap; retain in final regression |
| Time Clock | `/teacher/time-clock/` | Transactional clock actions and draft submission, location/offline errors, duplicate-tab protection, reload recovery, filters, draft edit, desktop/mobile detail views | No known functional gap; retain in final regression |
| Tasks | `/teacher/tasks/` | Native list and task actions | Lifecycle/status and stale-record pass |
| Job Board | `/teacher/job-board/` | Accept and withdraw/rebroadcast | Permission/failure and concurrent acceptance pass |
| Chat | `/teacher/chat/` | Conversation creation/repair and text send | Ordering, unread state, send failure, mobile back navigation |
| Classes | `/teacher/classes/` | Schedule, presence, details, guest link, provider-specific RealtimeKit join | Real Zoom hub join verification |
| Classroom | `/teacher/classroom/` | Live dev teacher/guest join, active roster, lock denial, participant removal, media-denial fallback, and reconnect verified | Real Zoom hub join and return verification |
| Recordings | `/teacher/recordings/` | Native listing and playback | Expired/missing URL and playback failure pass |
| Surah Podcasts | `/teacher/surah-podcasts/` | Native browse and assignment sharing | Failed write, empty assignment, responsive dialog pass |
| Curriculum Books | `/teacher/curriculum-books/` | Native content listing | Broken/missing asset and download/navigation pass |
| Submit Form | `/teacher/submit-form/` | Shift selection, saved detection, time/image/signature fields, linked writes | Inventory every live template field type and failure recovery |
| Form Submissions | `/teacher/form-submissions/` | Native history and hydrated labels | Missing template, legacy response, empty/error states |

## Completion rule

An area moves to complete only after its Flutter behavior is observed, its
desktop and mobile Next workflows pass, data writes are Flutter-compatible,
failure states are visible, focused browser coverage exists, and the full web
regression remains green. Cosmetic-only differences do not block completion
unless they would make the migration noticeable or impair use.
