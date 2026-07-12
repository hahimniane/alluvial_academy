# Web Migration Handoff

Last updated: 2026-06-22

## Stop Point

Paused after the Teacher Submit Form upload/signature pass. The
user checked the migration and clarified that teacher pages must be functional,
not only visually similar, and that we should stay on teacher-facing work before
moving to admin. A controlled shift was seeded in `alluwal-dev` for
`codex.cms.staff@alluwal-dev.test / 111111`, Flutter dev My Shifts behavior was
captured, and Next My Shifts now has real Day/Week/Month switching, a
selected-day timeline, shift details, schedule issue settings, timezone dialog,
dev-verified schedule issue report writes, and service-compatible clock-in/
clock-out writes to `teaching_shifts` plus `timesheet_entries`. Next Teacher
Time Clock now also restores the Flutter-like current-shift clock status panel,
clock-in/clock-out action wiring, mobile timesheet cards, status/time filters,
and draft submit controls. Next Teacher Classes/Classroom now uses Flutter
matching `Join Class` copy, pre-checks the class join window from
`teaching_shifts`, shows the class name before token fetch, and surfaces a clear
RealtimeKit dev configuration error instead of the raw `internal` callable
failure when `alluwal-dev` RealtimeKit functions/secrets are unavailable. Next
Teacher Submit Form now has native form fill, Daily shift selection, submitted
shift detection, native Timesheet and Details sheets, and dev-verified linking
from `form_responses` back to `timesheet_entries` and `teaching_shifts`. Next
Teacher Classes was rechecked against the current Flutter desktop/mobile
baseline and now matches the Flutter `Your classes` intro card, `Today`
grouping, simpler class cards, active Join/copy actions, and filtering that
hides completed/past classes once their end time has passed. Next Teacher Time
Clock now also has working View details, draft Edit, and Submit-for-review
confirmation dialogs on desktop and mobile, with dev-verified Firestore edits
against a draft timesheet fixture. Next Teacher Submit Form now also preserves
Firestore form-template `time` fields, renders them as native browser time
inputs on desktop/mobile, and was dev-verified with a submitted response. Next
Teacher Classes now also shows Flutter-style class display names, live
participant presence strips on active/joinable class cards, and a native class
details dialog with teacher, students, current participants, class info, and
Join Class action, backed by `getRealtimeKitRoomPresence`. Next Teacher Submit
Form now also supports Firestore `image_upload`/`imageUpload` and `signature`
fields with browser image picking, preview/remove/change states, Firebase
Storage uploads to `form_images/{uid}/...`, and response metadata compatible
with Flutter's saved form responses. Upload/signature validation now stays
inside the form sheet with inline errors instead of browser alerts. Next
Teacher Classes now also copies a
site guest-join URL instead of the raw Cloud Function URL, and Next has a public
`/classroom/join/?guestShift=...` flow that mirrors Flutter's guest join screen
before embedding Cloudflare RealtimeKit. Next Teacher My Form Submissions and
the Submit Form `View Form` sheet now hydrate saved response field labels from
the matching `form_templates`/legacy `form` document, so teachers see the real
question text instead of raw field IDs like `Class Start Time`. Next Teacher
Job Board now also matches Flutter's accepted-job withdrawal behavior: the
accepting teacher can open the confirmation dialog, withdraw, and re-broadcast
the opportunity through the same dev Firestore shape/rules path Flutter uses.
Next Teacher Chat now also opens conversations, creates/repairs Admin Support
and direct chat documents, subscribes to `chats/{chatId}/messages`, and sends
text messages with the same `last_message`/message fields Flutter writes.
Next Teacher Dashboard Quick Access now routes the Flutter-matching `Trading`
action to the native Teacher Job Board instead of the Flutter bridge. Teacher
mobile header menu buttons now open a native mobile drawer with the teacher
dashboard sections and links instead of being inert.

Do not keep polishing the already accepted screens. The About route, Public Site
CMS module, native admin dashboard home, native Invoices module, native Submit
Form module, native Circles alias, native All Submissions module, native Form
Builder module, native Notifications module, native Curriculum Books module,
native Surah Podcasts module, native Recordings module, native Classes module,
native Chat module, native Audits module, native Tasks module, native Timesheets
module, native Shifts module, native Users module, native Student Applicants
module, native Teacher Applicants module, native Teacher Dashboard Home, native
Teacher My Shifts, native Teacher Time Clock, and native Teacher Tasks are
parity acceptable after the allowed focused passes. Native Teacher Job Board is
also parity acceptable. Native Teacher Chat is parity acceptable. Native Teacher
Classes is parity acceptable. Native Teacher Recordings is parity acceptable.
Native Teacher Surah Podcasts is parity acceptable. Native Teacher Curriculum
Books is parity acceptable. Native Teacher Submit Form is parity acceptable.
Native Teacher My Form Submissions is parity acceptable. Native Teacher Submit
Form now has a first-pass native form-fill sheet and daily shift picker instead
of immediately bridging for every form. Admin work is still paused by user
request. Remaining teacher functionality needs deeper passes around controls
inside a successfully joined Cloudflare RealtimeKit room where Cloudflare's UI
does not already provide the control, less common form-fill edge cases not yet
seen in dev templates, and any teacher flows that still bridge.

Production may be used only for read-only observation with the provided
production account. Do not create, edit, delete, upload, save, publish, or bulk
copy production data. Use `alluwal-dev` for write tests and seeded users.

## Branch

Checkpoint branch:

```bash
feature/web-next-migration-checkpoint
```

This branch contains the Next.js migration checkpoint and does not intentionally
include unrelated Flutter/mobile dirty files from the local workspace.

## Implemented In This Checkpoint

- Created `apps/web` with Next.js static export, TypeScript, Tailwind CSS,
  Firebase JS SDK, and Playwright.
- Added Hostinger packaging that places the Next.js site at the static root and
  the Flutter bridge under `/app`.
- Ported the public web routes:
  `/`, `/about/`, `/team/`, `/programs/`, `/contact/`,
  `/teacher-application/`, `/leadership-application/`, `/login/`, `/enroll/`.
- Added Firebase models/helpers for the public CMS bundle and fallback data.
- Added Firebase Auth login/logout/reset and `/app` bridge entry.
- Added public form submission flows for contact, teacher application,
  leadership application, and enrollment.
- Added a Firestore rule allowing anonymous create for
  `leadership_applications`.
- Fixed contact form browser writes by using the Firestore REST create endpoint
  for `contact_messages`.
- Added/expanded Playwright coverage for route smoke checks, forms, auth bridge,
  mobile navigation, and Team directory interactions.
- Corrected the temporary dashboard bridge handoff so Next login opens the
  Flutter auth/dashboard shell at `/app/#/login` instead of the public Flutter
  landing page at `/app/`.
- Corrected Hostinger packaging so the copied Flutter bridge `.htaccess`
  rewrites `/app/...` refreshes and deep links to `/app/index.html`.
- Added the first native Next.js Dashboard/CMS route at
  `/admin/public-site-cms/` with the Flutter CMS tab structure:
  Pricing, Team on website, Social links, Home hero.
- Wired the native CMS first pass to the existing public CMS bundle and
  Firestore save paths for pricing, social links, and landing hero data.
- Added native Team on website add/edit/delete/import controls, including the
  Flutter-side-sheet fields, required validation, duplicate linked-user guard,
  Firestore writes to `public_site_cms_team`, best-effort Storage cleanup, and
  team photo upload path matching the Flutter CMS.
- Added the native CMS admin access guard using the same Firestore role fields
  as Flutter (`user_type`, `secondary_roles`, `is_admin_teacher`) so signed-out
  and non-admin users do not see the editor.
- Added linked-user directory search/select in the native team profile editor,
  plus the missing `adminSearchDirectoryUsers` callable export with a client
  fallback to direct Firestore search.
- Added landing hero image upload controls in the native CMS, using the same
  `public_site_assets/cms/{uid}/landing/...` Storage path as Flutter.
- Exported `syncPublicSiteAdminClaim` and added `public_site_assets` Storage
  rules so CMS images are publicly readable and admin-only writable.
- Added a native `/admin/` dashboard entry page with a Website section and
  Public pricing & team card linking to `/admin/public-site-cms/`.
- Added guarded Playwright coverage for authenticated CMS team save/delete and
  landing image upload verification. These tests are skipped unless
  `ALLUWAL_RUN_ADMIN_CMS_E2E=1`, admin credentials, and for upload
  `ALLUWAL_RUN_ADMIN_CMS_UPLOAD_E2E=1` are provided.
- Updated `public_site_assets/cms/{uid}` Storage rules so admin-owned CMS image
  uploads can also be deleted for cleanup while create/update remains limited
  to image files under 10 MB.
- Expanded the native `/admin/` dashboard entry to mirror the Flutter admin
  sidebar sections: Overview, People, Operations, Communication, Forms,
  Finance, Website, Savings, and System. The migrated Website module opens
  natively and non-migrated modules continue to route through the Flutter
  dashboard bridge.
- Completed the visible native admin sidebar parity pass by adding the
  Flutter-source entries that were still missing in Next: Surah Podcasts,
  Curriculum Books, Savings/Circles, and Test Audit Génération.
- Completed a native admin sidebar search parity pass: the Next `/admin/`
  sidebar search now filters sections/items like Flutter's `CustomSidebar`,
  includes a clear action, and shows a no-results state.
- Completed a native admin sidebar collapse/reset parity pass: section headers
  now toggle open/closed like Flutter's `CustomSidebar`, search still reveals
  matching items while a section is collapsed, and the sidebar footer includes
  the Flutter-matching `Reset Layout` action.
- Completed a native admin sidebar favorites parity pass: sidebar items now have
  pin/unpin star controls, pinned items appear in a Favorites block like
  Flutter, and `Reset Layout` clears pinned items.
- Tightened the native Public Site CMS Home hero tab toward Flutter by adding
  the landing helper copy and a browser-native color-picker swatch beside the
  hero background hex field.
- Tightened native CMS image URL/upload fields toward Flutter by adding the
  upload-zone preview area, empty image hint, and failed-image fallback.
- Tightened the native CMS Pricing tab toward Flutter by adding the pricing
  help copy, collapsed/expandable plan cards, Flutter-matching rate labels,
  discount-threshold helper text, bullet hint/placeholder copy, and per-track
  save action placement inside each expanded card.
- Tightened the native CMS Social links tab toward Flutter by adding visible
  network glyphs and replacing plain checkboxes with switch-style controls
  beside each network title and `Show on website` subtitle.
- Tightened the native CMS Team profile editor photo field toward Flutter by
  replacing the plain image URL input and tiny preview row with a full
  upload-zone card: photo URL input, preview/empty/error states, and Upload
  photo action in the same section.
- Tightened the native CMS Team profile editor linked-user section toward
  Flutter by showing `Linked user (required)`, the missing-link hint, selected
  user summary with `Remove link`, and a `Search users...` action that reveals
  the existing search/results controls.
- Tightened native CMS Team profile save behavior toward Flutter: linked user
  is required for every save, the editor no longer exposes a separate
  `Active on website` checkbox, and saving a profile publishes it as active.
- Tightened native CMS Team tab empty/import copy toward Flutter: the empty
  state now explains that profiles replace the default public Team list, the
  import hint describes stable Firestore IDs and inactive imported rows, and
  the import action reads `Import profiles from website defaults`.
- Replaced the native CMS Team row browser-native delete confirmation with an
  in-app confirmation dialog matching Flutter's visible flow:
  `Delete this profile from the website?`, member name, `Cancel`, and `Delete`.
- Updated authenticated CMS Playwright coverage to match the current linked-user
  requirement and in-app delete dialog.
- Created/reused dev-only Firebase test users in `alluwal-dev` for authenticated
  CMS testing:
  `codex.cms.admin@alluwal-dev.test` and
  `codex.cms.staff@alluwal-dev.test` (`uZyvgk7VBeRrhsZfYAzGfOSRCJo2`).
- Deployed `storage.rules` to `alluwal-dev` so
  `public_site_assets/cms/{uid}/...` CMS image uploads are allowed by the live
  dev Storage rules.
- Verified authenticated native CMS team profile save/delete and landing hero
  image upload against real dev Firestore/Storage.
- Restored Flutter Firebase build-time environment selection in `lib/main.dart`
  so production remains the default, while dev baselines can be built with
  `--dart-define=FIREBASE_ENV=dev`.
- Rebuilt the Flutter web baseline against `alluwal-dev` using the approved web
  build command plus the dev `dart-define`, which bumped the web cache-busting
  version in `web/index.html` to `101`.
- Added the native `AdminDashboardShell` around `/admin/public-site-cms/` so the
  CMS editor sits inside the Flutter-style admin sidebar/topbar on desktop while
  preserving the mobile CMS tab flow.
- Updated the native CMS shell header to derive the signed-in user display name,
  initials, and role chips from Firebase Auth plus the matching `users` record
  instead of showing a hardcoded test identity.
- Captured authenticated Flutter mobile CMS pricing through the real dev login
  flow by enabling Flutter web semantics and using the dashboard `Open editor`
  action.
- Tightened native Next mobile CMS parity: added the Flutter-like mobile admin
  app bar and back row, hid the mobile-only duplicate refresh/intro copy, kept
  the CMS title on one row, and pinned the save action above the bottom tab bar
  like Flutter.
- Captured authenticated Flutter mobile Public Site CMS Team, Social links, and
  Home hero baselines through the real dev login flow with bottom-tab
  coordinate clicks.
- Tightened native Next mobile CMS Team, Social links, and Home hero tabs by
  restoring the same mobile helper copy Flutter shows on those tabs.
- Captured authenticated Flutter and Next desktop/mobile admin dashboard home
  baselines through the real dev login flow.
- Replaced the generic public `/admin/` module hub with an administrator-gated
  native admin home inside the shared dashboard shell. The new admin home mirrors
  Flutter's welcome banner and actionable cards: pending timesheets, overdue
  tasks, recent submissions, upcoming shifts, applicants to review, and Public
  pricing & team.
- Updated Playwright coverage so signed-out `/admin/` access is always checked,
  while authenticated admin dashboard/sidebar behavior runs behind the dev admin
  E2E credentials.
- Captured authenticated Flutter and Next desktop/mobile Student Applicants
  baselines through the real dev login flow.
- Added a guarded native `/admin/student-applicants/` route inside the shared
  admin dashboard shell, matching Flutter's visible Student Applicants header,
  Inbox/Ready/Live/Archived/Matched tabs, applicant cards, schedule chips,
  parent/adult markers, info/phone controls, and empty/loading states.
- Added first native Student Applicants status actions for the visible workflow:
  `Mark Contacted`, `Archive`, and `Unarchive`, writing the same `metadata`
  status fields and action history on `alluwal-dev`.
- Rewired the admin sidebar and `/admin/` applicants card from the Flutter
  bridge to the native `/admin/student-applicants/` route.
- Added Playwright coverage for the Student Applicants signed-out guard and
  authenticated admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Teacher Applicants
  baselines through the real dev login flow.
- Added a guarded native `/admin/teacher-applicants/` route inside the shared
  admin dashboard shell, matching Flutter's visible Teacher Applicants header,
  total count, All/Pending/Reviewed/Approved/Rejected chips, date-range control,
  export action, selectable data grid, status pills, row actions, and application
  details dialog.
- Added first native Teacher Applicants status updates for the visible workflow:
  `Mark As Reviewed`, `Approve`, `Reject`, and `Mark As Pending`, writing the
  same `status`, `reviewed_by`, and `reviewed_at` fields as Flutter.
- Rewired the admin sidebar Teacher Applicants item from the Flutter bridge to
  the native `/admin/teacher-applicants/` route.
- Added Playwright coverage for the Teacher Applicants signed-out guard and
  authenticated admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Users baselines through
  the real dev login flow.
- Added a guarded native `/admin/users/` route inside the shared admin dashboard
  shell, matching Flutter's visible User Management header, Filter/Search/Export
  toolbar, `Users Didn't Log In Yet`, `Filter By Parent`, `Add Users`,
  Users/Admins tabs, dense data grid, role chips, and row action icon strip.
- Added native Users search, role/status filter menu, Users/Admins tab split,
  never-logged-in filter, and CSV export against real `alluwal-dev` Firestore
  data. Create/edit/archive/delete parent-link subflows remain future deeper
  module work; the visible action icons are present while destructive writes are
  intentionally not performed by verification.
- Rewired the admin sidebar Users item from the Flutter bridge to the native
  `/admin/users/` route.
- Added Playwright coverage for the Users signed-out guard and authenticated
  admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Shifts baselines
  through the real dev login flow.
- Added a guarded native `/admin/shifts/` route inside the shared admin
  dashboard shell, matching Flutter's visible Shift Management header, create
  and settings controls, Select action, teacher search, Total/Active/Today/
  Upcoming stat chips, All/Today/Upcoming/Active tabs, Grid/List toggle, search
  field, week navigation, and weekly teacher/leader schedule grid.
- Added native Shifts reads against real `alluwal-dev` Firestore data from
  `teaching_shifts` and `users`, including client-side date filtering, search,
  tab counts, teacher/leader grouping, and shift blocks in the grid/list views.
  Create/edit/delete/bulk mutation flows remain future deeper module work or
  bridge paths; verification intentionally did not mutate shifts.
- Rewired the admin sidebar Shifts item from the Flutter bridge to the native
  `/admin/shifts/` route.
- Added Playwright coverage for the Shifts signed-out guard and authenticated
  admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Timesheets baselines
  through the real dev login flow.
- Added a guarded native `/admin/timesheets/` route inside the shared admin
  dashboard shell, matching Flutter's visible Timesheet Review header, Filters
  action, export action, All/Pending/Approved/Rejected/Draft chips, shown count,
  search, `Select all pending (visible)`, This Week/Last week/This Month/Date
  Range controls, table/detail layout, and empty state.
- Added native Timesheets reads against real `alluwal-dev` Firestore data from
  `timesheet_entries`, including status counts, search, teacher/date/edited/
  needs-attention filters, CSV export, row selection, and list/detail rendering.
  Row approve/reject controls are present for parity, but verification did not
  mutate timesheet records.
- Rewired the admin sidebar Timesheets item from the Flutter bridge to the
  native `/admin/timesheets/` route.
- Added Playwright coverage for the Timesheets signed-out guard and
  authenticated admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Tasks baselines through
  the real dev login flow.
- Added a guarded native `/admin/tasks/` route inside the shared admin
  dashboard shell, matching Flutter's visible Tasks header, search, All Tasks/My
  Tasks/Today/Drafts tabs, Show filters control, no-results state, task card
  grid for real data, and bottom-right Add Task action.
- Added native Tasks reads against real `alluwal-dev` Firestore data from
  `tasks`, including tab filtering, search, status/priority filters, summary
  cards when tasks exist, task cards, and a simple working Add Task dialog that
  writes the same core task fields used by Flutter. Verification opened/read the
  module and did not create task records.
- Rewired the admin sidebar Tasks item from the Flutter bridge to the native
  `/admin/tasks/` route.
- Added Playwright coverage for the Tasks signed-out guard and authenticated
  admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Audits baselines
  through the real dev login flow.
- Added a guarded native `/admin/audits/` route inside the shared admin
  dashboard shell, matching Flutter's visible Audit Management header,
  Teachers/Admins segmented switch, month selector, refresh action,
  search/department/filter/review/export toolbar, no-audits empty state, and
  bottom Generate Audits action bar.
- Added native Audits reads against real `alluwal-dev` Firestore data from
  `teacher_audits` and `admin_audits`, including month filtering, search,
  teacher/admin view switching, summary stats when teacher audits exist, and
  table rendering for real audit rows. Generation/export buttons are visible for
  parity, but verification intentionally did not generate or mutate audit
  records.
- Rewired the admin sidebar Audits item from the Flutter bridge to the native
  `/admin/audits/` route.
- Added Playwright coverage for the Audits signed-out guard and authenticated
  admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Chat baselines through
  the real dev login flow, including Recent Chats and My Contacts.
- Added a guarded native `/admin/chat/` route inside the shared admin dashboard
  shell, matching Flutter's visible Chat landing: Recent Chats/My Contacts tabs,
  search field, no-conversations empty state, grouped contact cards, role pills,
  and the Create Group floating action.
- Added native Chat reads against real `alluwal-dev` Firestore data from
  `chats` and `users`, including recent-chat filtering, admin-support inbox
  reads, contact grouping by role, and search across conversations/users. The
  Create Group dialog is visible for parity but verification intentionally did
  not create groups or send messages.
- Rewired the admin sidebar Chat item from the Flutter bridge to the native
  `/admin/chat/` route.
- Added Playwright coverage for the Chat signed-out guard and authenticated
  admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Classes baselines
  through the real dev login flow.
- Added a guarded native `/admin/classes/` route inside the shared admin
  dashboard shell, matching Flutter's visible Classes header, Class Recordings
  icon, search field, Filters control, result count, `Your classes` intro card,
  and no-active-classes empty state.
- Added native Classes reads against real `alluwal-dev` Firestore data from
  `teaching_shifts`, limited to teaching shifts and supporting active-now,
  joinable, upcoming, all, and search filtering. Verification intentionally did
  not join video calls or mutate class records.
- Rewired the admin sidebar Classes item from the Flutter bridge to the native
  `/admin/classes/` route.
- Added Playwright coverage for the Classes signed-out guard and authenticated
  admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Recordings baselines
  through the real dev login flow.
- Added a guarded native `/admin/recordings/` route inside the shared admin
  dashboard shell, matching Flutter's visible Recordings landing state:
  Teachers header, teacher count, refresh action, no-recordings empty card, and
  mobile admin app bar.
- Added native Recordings reads against the same `listClassRecordings` callable
  used by Flutter, including admin active-role request data, teacher-level
  grouping for non-empty data, and search across teacher/shift/subject values.
  Verification intentionally did not request playback URLs or mutate recording
  records.
- Rewired the admin sidebar Recordings item from the Flutter bridge to the
  native `/admin/recordings/` route.
- Rewired the Classes page `Class Recordings` header action to the native
  `/admin/recordings/` route.
- Added Playwright coverage for the Recordings signed-out guard and
  authenticated admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Surah Podcasts
  baselines through the real dev login flow.
- Added a guarded native `/admin/surah-podcasts/` route inside the shared admin
  dashboard shell, matching Flutter's visible Surah Library header, content
  count, refresh action, search field, no-content empty state, and bottom-right
  Add Content action.
- Added native Surah Podcasts reads against real `alluwal-dev` Firestore data
  from `surah_podcasts`, including active-content filtering, fallback to all
  content when no active records exist, surah grouping, and search across surah
  number/name/title/description values. The Add Content dialog is visible for
  parity, but verification intentionally did not upload, delete, or mutate
  podcast content.
- Rewired the admin sidebar Surah Podcasts item from the Flutter bridge to the
  native `/admin/surah-podcasts/` route.
- Added Playwright coverage for the Surah Podcasts signed-out guard and
  authenticated admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Curriculum Books
  baselines through the real dev login flow.
- Added a guarded native `/admin/curriculum-books/` route inside the shared
  admin dashboard shell, matching Flutter's visible Curriculum Books hero,
  shared-learning label, all-roles/PowerPoint/Arabic-curriculum chips, four
  static Arabic curriculum cards, and Open/Download actions.
- Added the same public curriculum PDF/PPTX URLs used by Flutter:
  alphabet and fatha, damma lessons, open letters practice, and kasra lessons.
  Verification intentionally did not upload, delete, or mutate curriculum
  assets.
- Rewired the admin sidebar Curriculum Books item from the Flutter bridge to the
  native `/admin/curriculum-books/` route.
- Added Playwright coverage for the Curriculum Books signed-out guard and
  authenticated admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Notifications baselines
  through the real dev login flow.
- Added a guarded native `/admin/notifications/` route inside the shared admin
  dashboard shell, matching Flutter's visible Send Notification title,
  Compose Notification form, Individual User/All Users In Role/Selected Users
  recipient modes, notification title/message fields, email checkbox, Select
  User panel, user search, role filter, and Send Notification action.
- Added native Notifications reads against real `alluwal-dev` Firestore users
  from `users` where `is_active == true`, with search, role filtering, single
  user selection, multi-user selection, and role recipient selection.
- Wired the native send action to the same `sendAdminNotification` callable
  Flutter uses. Verification intentionally opened/read the module and did not
  send notifications.
- Rewired the admin sidebar Notifications item from the Flutter bridge to the
  native `/admin/notifications/` route.
- Added Playwright coverage for the Notifications signed-out guard and
  authenticated admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Form Builder baselines
  through the real dev login flow.
- Added a guarded native `/admin/form-builder/` route inside the shared admin
  dashboard shell, matching Flutter's visible Form Templates header, Create
  Form actions, single Form Templates tab, search field, All Forms/Active/
  Inactive status filter, Newest/Oldest/Name sort filter, empty state, and
  no-results state.
- Added native Form Builder reads against real `alluwal-dev` Firestore data
  from `form_templates`, including client-side search/status filtering,
  normalized-name deduplication with Flutter's active/version/updated priority,
  newest/oldest/name sorting, and form-template cards when records exist.
  Create/edit/delete/duplicate/activate flows remain future deeper module work
  or bridge paths; verification intentionally did not mutate form templates.
- Rewired the admin sidebar Form Builder item from the Flutter bridge to the
  native `/admin/form-builder/` route.
- Added Playwright coverage for the Form Builder signed-out guard and
  authenticated admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile All Submissions
  baselines through the real dev login flow.
- Added a guarded native `/admin/all-submissions/` route inside the shared
  admin dashboard shell, matching Flutter's visible compact All Submissions
  header, total/teacher/done/pending stats, search field, Teachers/Month/Status/
  Forms chips, current-month banner, View All action, teacher-group rows, and
  no-submissions empty state.
- Added native All Submissions reads against real `alluwal-dev` Firestore data
  from `form_responses`, including current-month reads by `yearMonth`, client
  sorting by `submittedAt` to avoid requiring a new composite index, status
  filtering, teacher/form-title search, all-time reads, and teacher grouping
  with teacher names from `users`. Review/export/detail/preference flows remain
  future deeper module work or bridge paths; verification intentionally did not
  mutate submissions or admin preferences.
- Rewired the admin sidebar All Submissions item from the Flutter bridge to the
  native `/admin/all-submissions/` route.
- Added Playwright coverage for the All Submissions signed-out guard and
  authenticated admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Submit Form baselines
  through the real dev login flow.
- Added a guarded native `/admin/submit-form/` route inside the shared admin
  dashboard shell, matching Flutter's visible Forms Reports launcher: gradient
  header, back/history controls, Daily/Weekly/Monthly pills, search field,
  teaching reports, feedback, student assessment, administrative, and other
  form sections, card metadata, unavailable badges, completed badges, and
  mobile stacked layout.
- Added native Submit Form reads against real `alluwal-dev` Firestore data from
  `form_templates` and `form_responses`, including Flutter-style active/latest
  template deduplication, role access filtering, fallback default forms, and
  client-side daily/weekly/monthly submitted-state checks. The deeper form-fill
  and My Submissions flows remain future module work or bridge paths;
  verification intentionally did not create form responses.
- Rewired the admin sidebar Submit Form item from the Flutter bridge to the
  native `/admin/submit-form/` route.
- Added Playwright coverage for the Submit Form signed-out guard and
  authenticated admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Invoices baselines
  through the real dev login flow, including the Create Invoice tab and All
  Invoices tab.
- Added a guarded native `/admin/invoices/` route inside the shared admin
  dashboard shell, matching Flutter's visible invoice hub: Create Invoice/All
  Invoices tabs, parent/adult-student search, selected-user card, billing month
  selector, payment due date, access cutoff date, per-student amount cards,
  invoice list search, All/Pending/Paid/Overdue/Cancelled chips, invoice cards,
  and empty state.
- Added native Invoices reads against real `alluwal-dev` Firestore data from
  `users` and `invoices`, including parent plus adult-student eligibility,
  linked-child loading, invoice sorting, parent-name resolution, search/status
  filtering, and remaining-balance/overdue display. The native create action is
  wired to the same `createInvoice` callable Flutter uses; edit/delete dialogs
  write to the same invoice fields. Verification intentionally opened/read the
  module and did not create, edit, delete, print, or download invoices.
- Rewired the admin sidebar Invoices item from the Flutter bridge to the native
  `/admin/invoices/` route.
- Added Playwright coverage for the Invoices signed-out guard and authenticated
  admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Circles baselines
  through the real dev login flow. Flutter currently routes Savings > Circles to
  the Public Site CMS Pricing screen, so this pass intentionally treats Circles
  as a native alias for that visible screen.
- Added a guarded native `/admin/circles/` route inside the shared admin
  dashboard shell, rendering the existing `PublicSiteCmsAdmin` pricing screen
  with `Circles` selected in the sidebar and the Flutter-matching
  `Website / Pricing & public team` breadcrumb.
- Rewired the admin sidebar Circles item from the Flutter bridge to the native
  `/admin/circles/` alias.
- Added Playwright coverage for the Circles signed-out guard and authenticated
  admin navigation/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Teacher Dashboard Home
  baselines through the real dev teacher login flow.
- Added role-aware Next login routing so admins go to `/admin/`, teachers go to
  `/teacher/`, and unknown roles continue to the Flutter bridge at
  `/app/#/login`.
- Added a guarded native `/teacher/` dashboard home with Flutter-style teacher
  sidebar/topbar sections, signed-out and non-teacher access states, summary
  metrics, earnings strip, next-class card, full-schedule action, and
  quick-access cards.
- Added native Teacher Dashboard Home reads against real `alluwal-dev`
  Firestore data from `teaching_shifts`, `tasks`, and `timesheet_entries`,
  with empty/zero states when reads are unavailable or no records exist.
- Kept non-home teacher quick actions on the Flutter bridge until each
  teacher-facing module receives its own parity pass.
- Added Playwright coverage for the Teacher Dashboard signed-out guard and
  authenticated teacher login/open behavior.
- Captured authenticated Flutter and Next desktop/mobile Teacher My Shifts
  baselines through the real dev teacher login flow.
- Added a guarded native `/teacher/shifts/` route inside the shared teacher
  dashboard shell, matching Flutter's visible My Shifts/Schedule screen:
  breadcrumb/sidebar active state on desktop, mobile teacher top bar, Schedule
  header, Day/Week/Month controls, settings action, Weekly Calendar title/helper
  copy, Grid/List segmented toggle, week navigation, and empty weekly agenda
  card.
- Added native Teacher My Shifts reads against real `alluwal-dev` Firestore
  data from `teaching_shifts`, checking both `teacher_id` and `teacherId`,
  with list/grid rendering when shifts exist and Flutter-style `No events`
  empty states when the teacher has no shifts in the selected week.
- Rewired the teacher sidebar My Shifts item, dashboard `See All`, `View Full
  Schedule`, and Quick Access Schedule card from the Flutter bridge to the
  native `/teacher/shifts/` route.
- Expanded Playwright coverage for Teacher My Shifts signed-out guard and
  authenticated teacher dashboard-to-schedule navigation.
- Added native Teacher My Shifts clock-in/clock-out behavior for the Day
  timeline. The Next flow now requests browser geolocation, creates the same
  pending `timesheet_entries` shape as Flutter (`source: shift_clock_in`,
  scheduled timestamps, location fields, pay fields, web platform markers),
  updates `teaching_shifts.clock_in_time`/`clock_out_time`, caps paid time to
  the scheduled window, and refreshes the schedule after each action.
- Captured authenticated Flutter and Next desktop/mobile Teacher Time Clock
  baselines through the real dev teacher login flow.
- Added a guarded native `/teacher/time-clock/` route inside the shared teacher
  dashboard shell, matching Flutter's visible My Timesheet screen: breadcrumb/
  sidebar active state on desktop, mobile teacher top bar, `My Timesheet`
  header, `All Time` range filter, Export action, sortable table header row,
  and empty/loading table body.
- Added native Teacher Time Clock reads against real `alluwal-dev` Firestore
  data from `timesheet_entries`, filtering by `teacher_id`, normalizing common
  timestamp/location/hour field variants, supporting All Time/This Month/This
  Week client filters, and exporting the visible rows to CSV.
- Rewired the teacher sidebar Time Clock item from the Flutter bridge to the
  native `/teacher/time-clock/` route.
- Expanded Playwright coverage for Teacher Time Clock signed-out guard and
  authenticated teacher dashboard-to-timesheet navigation. Verification used the
  dev teacher account and did not clock in/out or mutate timesheet records.
- Captured authenticated Flutter and Next desktop/mobile Teacher Tasks baselines
  through the real dev teacher login flow.
- Added a guarded native `/teacher/tasks/` route inside the shared teacher
  dashboard shell, matching Flutter's visible Tasks screen: breadcrumb/sidebar
  active state on desktop, mobile teacher top bar, title/search row, All
  Tasks/My Tasks/Today tabs, Show filters action, empty no-tasks state, and
  task cards for non-empty data.
- Added native Teacher Tasks reads against real `alluwal-dev` Firestore data
  from `tasks`, checking assigned/created teacher fields in both camelCase and
  snake_case variants, with client-side tab/search/status/priority filtering.
  Verification used the dev teacher account and did not create, edit, complete,
  archive, or mutate task records.
- Rewired the teacher sidebar Tasks item and dashboard Assignments quick-access
  card from the Flutter bridge to the native `/teacher/tasks/` route.
- Expanded Playwright coverage for Teacher Tasks signed-out guard and
  authenticated teacher dashboard-to-tasks navigation. Chromium and mobile
  Chrome cover signed-out teacher module guards; WebKit signed-out teacher
  module guard navigations are skipped because WebKit intermittently hangs
  before committing these static routes late in the full suite.
- Captured authenticated Flutter and Next desktop/mobile Teacher Job Board
  baselines through the real dev teacher login flow.
- Added a guarded native `/teacher/job-board/` route inside the shared teacher
  dashboard shell, matching Flutter's visible Job Board screen: breadcrumb/
  sidebar active state on desktop, mobile teacher top bar, `New Student
  Opportunities` header, subtitle, centered no-opportunities state, open job
  cards, recently filled job section, and teacher response dialog.
- Added native Teacher Job Board reads against real `alluwal-dev` Firestore
  data from `job_board`, including open opportunities, recently accepted
  opportunities, per-teacher response summaries, admin notes, schedule details,
  and empty-state rendering when no opportunities exist.
- Added teacher availability response writes from the native Job Board using
  the same `job_board/{jobId}/responses/{teacherId}` shape and parent job
  counters/status fields used by Flutter.
- Added native Teacher Job Board withdraw/re-broadcast parity for the teacher
  who accepted a filled opportunity. The web implementation uses direct
  Firestore writes, matching Flutter's current `JobBoardService.withdrawFromJob`
  flow, because the deployed callable is blocked by browser preflight/IAM before
  handler code runs. The write sets cleared match fields to explicit `null`
  values to satisfy the existing Firestore rules.
- Updated and deployed `firestore.rules` to `alluwal-dev` so authenticated
  teachers can submit valid availability responses while admins retain full Job
  Board management access.
- Rewired the teacher sidebar Job Board item from the Flutter bridge to the
  native `/teacher/job-board/` route.
- Expanded Playwright coverage for Teacher Job Board signed-out guard and
  authenticated teacher dashboard-to-job-board navigation. Chromium and mobile
  Chrome cover signed-out teacher module guards; WebKit signed-out teacher
  module guard navigations are skipped because WebKit intermittently hangs
  before committing these static routes late in the full suite.
- Captured authenticated Flutter and Next desktop/mobile Teacher Chat baselines
  through the real dev teacher login flow, including Recent Chats and My
  Contacts states.
- Added a guarded native `/teacher/chat/` route inside the shared teacher
  dashboard shell, matching Flutter's visible Chat list screen: breadcrumb/
  sidebar active state on desktop, mobile teacher top bar, Recent Chats/My
  Contacts segmented control, search field, no-conversations empty state,
  Admin Support card for non-admin users, and administrator contact rows.
- Added native Teacher Chat reads against real `alluwal-dev` Firestore data
  from `chats`, `users`, and `teaching_shifts`, including recent chat filtering
  by participant, teacher relationship contacts, admin contacts, and search
  across conversations/users. Verification intentionally did not create chats or
  send messages during this list parity pass.
- Added native Teacher Chat conversation actions: Recent Chat rows, relationship
  contacts, and Admin Support now open a conversation panel; the panel listens
  to `chats/{chatId}/messages`, creates missing direct/admin-support chat docs
  with Flutter-compatible participants/chat type, sends text messages, updates
  `last_message`, and preserves the Cloud Function notification trigger shape.
- Rewired the teacher sidebar Chat item from the Flutter bridge to the native
  `/teacher/chat/` route.
- Expanded Playwright coverage for Teacher Chat signed-out guard and
  authenticated teacher dashboard-to-chat navigation. Chromium and mobile
  Chrome cover signed-out teacher module guards; WebKit signed-out teacher
  module guard navigations are skipped because WebKit intermittently hangs
  before committing these static routes late in the full suite.
- Captured authenticated Flutter and Next desktop/mobile Teacher Classes
  baselines through the real dev teacher login flow.
- Added a guarded native `/teacher/classes/` route inside the shared teacher
  dashboard shell, matching Flutter's visible Classes screen: breadcrumb/
  sidebar active state on desktop, mobile teacher top bar, centered Classes
  header, Class Recordings icon, no-classes empty state, and class cards for
  non-empty teacher-scoped data.
- Added native Teacher Classes reads against real `alluwal-dev`
  `teaching_shifts` using the signed-in teacher id (`teacher_id` and
  `teacherId` field variants), with joinability/status labels and no class
  mutations during verification.
- Rewired the teacher sidebar Classes item from the Flutter bridge to the
  native `/teacher/classes/` route.
- Expanded Playwright coverage for Teacher Classes signed-out guard and
  authenticated teacher dashboard-to-classes navigation. Authenticated
  teacher module navigation tests are scoped to desktop Chromium because they
  use the desktop sidebar; mobile keeps signed-out guard coverage and the
  parity screenshots cover the mobile rendering.
- Captured authenticated Flutter and Next desktop/mobile Teacher Recordings
  baselines through the real dev teacher login flow.
- Added a guarded native `/teacher/recordings/` route inside the shared teacher
  dashboard shell, matching Flutter's visible Recordings screen: breadcrumb/
  sidebar active state on desktop, mobile teacher top bar, `Students` header,
  student count, refresh action, no-recordings empty state, and the
  student/date/shift/fragment hierarchy for non-empty teacher-scoped data.
- Added native Teacher Recordings reads against real `alluwal-dev`
  `listClassRecordings` with `activeRole: "teacher"`, plus lazy playback URL
  loading through `getClassRecordingPlaybackUrl` only when a teacher presses the
  visible Play action. Verification did not request playback URLs or mutate
  recording records.
- Rewired the teacher sidebar Recordings item from the Flutter bridge to the
  native `/teacher/recordings/` route, and rewired the Teacher Classes header
  `Class Recordings` shortcut to the same native route.
- Expanded Playwright coverage for Teacher Recordings signed-out guard and
  authenticated teacher dashboard-to-recordings navigation. Authenticated
  teacher module navigation tests remain scoped to desktop Chromium because
  they use the desktop sidebar; mobile keeps signed-out guard coverage and the
  parity screenshots cover the mobile rendering.
- Captured authenticated Flutter and Next desktop/mobile Teacher Surah Podcasts
  baselines through the real dev teacher login flow.
- Added a guarded native `/teacher/surah-podcasts/` route inside the shared
  teacher dashboard shell, matching Flutter's visible teacher Surah Content
  screen: breadcrumb/sidebar active state on desktop, mobile teacher top bar,
  Surah Content header, refresh action, Library/Shared tabs, no-content empty
  state, folder cards for non-empty podcast data, detail view sections, and
  teacher share/unshare scaffolding.
- Added native Teacher Surah Podcasts reads against real `alluwal-dev`
  `surah_podcasts` and `podcast_assignments`, with active-content filtering,
  fallback to all rows when no active content exists, grouping by surah,
  teacher assignment listing, teacher student lookup from active/scheduled
  `teaching_shifts`, and the same `podcast_assignments` write shape Flutter
  uses for sharing content with students. The current dev teacher baseline has
  no uploaded Surah content, so verification covered the empty Library/Shared
  states and route access without uploading admin content.
- Rewired the teacher sidebar Surah Podcasts item from the Flutter bridge to
  the native `/teacher/surah-podcasts/` route.
- Expanded Playwright coverage for Teacher Surah Podcasts signed-out guard and
  authenticated teacher dashboard-to-surah-podcasts navigation. Authenticated
  teacher module navigation tests remain scoped to desktop Chromium because
  they use the desktop sidebar; mobile keeps signed-out guard coverage and the
  parity screenshots cover the mobile rendering.
- Captured authenticated Flutter and Next desktop/mobile Teacher Curriculum
  Books baselines through the real dev teacher login flow.
- Added a guarded native `/teacher/curriculum-books/` route inside the shared
  teacher dashboard shell, matching Flutter's visible Curriculum Books screen:
  breadcrumb/sidebar active state on desktop, mobile teacher top bar,
  Shared Learning Materials hero, Curriculum Books heading/copy, All roles/
  PowerPoint files/Arabic curriculum chips, four Arabic curriculum cards, and
  Open/Download links to the same public curriculum PDF/PPTX URLs Flutter uses.
- Rewired the teacher sidebar Curriculum Books item from the Flutter bridge to
  the native `/teacher/curriculum-books/` route.
- Expanded Playwright coverage for Teacher Curriculum Books signed-out guard
  and authenticated teacher dashboard-to-curriculum-books navigation.
  Authenticated teacher module navigation tests remain scoped to desktop
  Chromium because they use the desktop sidebar; mobile keeps signed-out guard
  coverage and the parity screenshots cover the mobile rendering.
- Captured authenticated Flutter and Next desktop/mobile Teacher Submit Form
  baselines through the real dev teacher login flow.
- Added a guarded native `/teacher/submit-form/` route inside the shared
  teacher dashboard shell, matching Flutter's visible Forms Reports launcher:
  breadcrumb/sidebar active state on desktop, mobile teacher top bar, purple
  header, back/history controls, Daily/Weekly/Monthly pills, search field,
  teaching reports, feedback, student assessment, and administrative form
  sections, card metadata, unavailable badges, completed badges, and mobile
  stacked layout.
- Added native Teacher Submit Form reads against real `alluwal-dev`
  `form_templates` and `form_responses`, including teacher role filtering,
  normalized-name deduplication with latest-template preference, fallback
  default forms, and client-side daily/weekly/monthly submitted-state checks.
  The deeper form-fill flow remains future module work or a bridge path;
  verification intentionally did not create form responses.
- Rewired the teacher sidebar Submit Form item from the Flutter bridge to the
  native `/teacher/submit-form/` route.
- Expanded Playwright coverage for Teacher Submit Form signed-out guard and
  authenticated teacher dashboard-to-submit-form navigation. Authenticated
  teacher module navigation tests remain scoped to desktop Chromium because
  they use the desktop sidebar; mobile keeps signed-out guard coverage and the
  parity screenshots cover the mobile rendering.
- Captured authenticated Flutter desktop and Next desktop/mobile Teacher My
  Form Submissions baselines through the real dev teacher login flow. Flutter
  mobile login did not submit reliably under coordinate automation in this
  pass, so the mobile comparison used the Flutter screen source plus Next
  mobile rendering.
- Added a guarded native `/teacher/form-submissions/` route matching Flutter's
  visible My Form Submissions screen: standalone white app bar, back action,
  month picker action, selected-month summary banner, View All action, search
  field, no-submissions empty state, grouped submission cards for non-empty
  data, group bottom sheet, and read-only response detail sheet.
- Added native Teacher My Form Submissions reads against real `alluwal-dev`
  `form_responses` using the same owner fields Flutter merges: `userId`,
  `submittedBy`, `teacher_id`, and `teacherId`. The native screen hydrates
  missing titles from `form_templates`/legacy `form`, groups by form id, filters
  by selected month or all time, and searches by form title/status.
- Rewired teacher Quick Access `Forms` to `/teacher/submit-form/`, Quick Access
  `My Form Submissions` to `/teacher/form-submissions/`, and the Submit Form
  history icon to `/teacher/form-submissions/`.
- Expanded Playwright coverage for Teacher My Form Submissions signed-out guard
  and authenticated teacher dashboard-to-submissions navigation. Authenticated
  teacher module navigation tests remain scoped to desktop Chromium; mobile
  keeps signed-out guard coverage and captured rendering.

## Parity Status

Parity acceptable:

- Enrollment/student application flow:
  role, student details, program, schedule, review/contact, success.
- Home page.
- Programs page.
- Contact page.
- Team page, including category filters and profile sheet.
- About page, including the CTA/footer refresh from the current Flutter landing
  About section.
- Teacher application visual parity pass.
- Leadership application visual parity pass.
- Login/auth bridge parity pass.
- Temporary `/app` Flutter bridge opens the Flutter auth shell at
  `/app/#/login` and keeps `/app/...` Hostinger refreshes inside the Flutter
  bridge.

Parity acceptable after focused passes:

- Native Public Site CMS module at `/admin/public-site-cms/`.
  Current pass covers the visible shell, tab switching, pricing editing,
  social link editing, landing hero editing, team list display, team
  add/edit/delete/import, signed-out/admin access guard, linked-user search, and
  landing hero image upload, with dashboard navigation from `/admin/`, plus a
  Flutter-style admin sidebar/topbar wrapper for the native CMS route, plus
  image URL/upload fields with preview/empty states and a Pricing tab structure
  that now matches Flutter's expandable cards more closely. The Social links
  tab also now follows Flutter's icon-plus-switch card pattern more closely,
  the Team editor photo section now follows Flutter's upload-zone layout, and
  the linked-user section now follows Flutter's required-link/search action
  structure more closely. Team profile saves now also follow Flutter's
  publish-on-save behavior. Team tab empty/import copy now matches Flutter's
  public website defaults wording more closely, and Team delete now uses an
  in-app confirmation dialog instead of browser-native confirmation UI.
  Authenticated native save/delete and Storage upload are verified against
  `alluwal-dev`. Desktop Flutter and Next CMS screenshots were captured for the
  pricing, team, social, and hero tabs. Mobile Flutter and Next screenshots were
  captured for pricing, team, social, and hero. The mobile Pricing, Team, Social
  links, and Home hero tabs are parity acceptable after the allowed focused
  passes.
- Native admin dashboard home at `/admin/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, desktop welcome banner, mobile greeting card, dashboard sidebar/topbar
  reuse, actionable admin home cards, and the Public pricing & team entry point.
  Desktop and mobile Flutter/Next screenshots were captured under
  `output/playwright/admin-home-parity/`. Remaining dashboard work should move
  to the individual modules behind the sidebar.
- Native Student Applicants module at `/admin/student-applicants/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style page header, Inbox/Ready/Live/Archived/Matched pipeline
  tabs with counts, applicant cards, program/student/parent/schedule fields,
  adult markers, and the visible `Mark Contacted`, archive, and unarchive
  actions. Desktop and mobile Flutter/Next screenshots were captured under
  `output/playwright/student-applicants-parity/`. Deeper matching, broadcast,
  and account-creation flows remain future module work if those screens are
  migrated natively.
- Native Teacher Applicants module at `/admin/teacher-applicants/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style page header, total count, status filters, date-range
  control, export action, selectable data grid, status pills, row status action
  menu, and application details dialog. Desktop and mobile Flutter/Next
  screenshots were captured under
  `output/playwright/teacher-applicants-parity/`. Bulk selection and individual
  status updates write to `alluwal-dev` using the same fields as Flutter; the
  verification tests open the route but intentionally do not mutate teacher
  application statuses.
- Native Users module at `/admin/users/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style User Management header, horizontal toolbar, search,
  filter menu, export, Users/Admins tabs, dense grid, role chips, and action
  icons. Desktop and mobile Flutter/Next screenshots were captured under
  `output/playwright/users-parity/`. The native screen reads real
  `alluwal-dev` users and supports search/filter/export; add/edit/archive/delete
  and parent-link workflows remain future deeper module work or bridge paths.
- Native Shifts module at `/admin/shifts/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style Shift Management header, create/settings/select controls,
  teacher search, stat chips, All/Today/Upcoming/Active tabs, search, Grid/List
  toggle, week navigation, and the weekly teacher/leader schedule grid. Desktop
  and mobile Flutter/Next screenshots were captured under
  `output/playwright/shifts-parity/`. The native screen reads real
  `alluwal-dev` shifts/users and supports search, tab counts, weekly grouping,
  and list/grid switching; create/edit/delete/bulk write workflows remain future
  deeper module work or bridge paths.
- Native Timesheets module at `/admin/timesheets/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style Timesheet Review header, status chips, shown count,
  search, select-pending action, date preset controls, filters/export controls,
  table/detail states, and the empty inbox state. Desktop and mobile
  Flutter/Next screenshots were captured under
  `output/playwright/timesheets-parity/`. The native screen reads real
  `alluwal-dev` timesheet entries and supports status/search/date/teacher/
  edited/needs-attention filtering plus CSV export; verification intentionally
  did not mutate timesheet records.
- Native Tasks module at `/admin/tasks/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style Tasks header, search, All Tasks/My Tasks/Today/Drafts
  tabs, Show filters control, empty task state, task cards for real data, and
  Add Task action. Desktop and mobile Flutter/Next screenshots were captured
  under `output/playwright/tasks-parity/`. The native screen reads real
  `alluwal-dev` tasks and supports search, tab filtering, status/priority
  filters, summary cards, card rendering, marking tasks done, and adding a basic
  task; verification intentionally did not create or update task records.
- Native Audits module at `/admin/audits/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style Audit Management header, Teachers/Admins segmented
  switch, month selector, search/department/filter/review/export toolbar,
  no-audits empty state, bottom Generate Audits bar, and table rendering when
  data exists. Desktop and mobile Flutter/Next screenshots were captured under
  `output/playwright/audits-parity/`. The native screen reads real
  `alluwal-dev` `teacher_audits` and `admin_audits`; verification intentionally
  did not generate or mutate audit records.
- Native Chat module at `/admin/chat/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style Recent Chats/My Contacts tabs, search field, empty recent
  state, grouped contacts, role pills, and Create Group action. Desktop and
  mobile Flutter/Next screenshots were captured under
  `output/playwright/chat-parity/`. The native screen reads real `alluwal-dev`
  `chats` and `users`; verification intentionally did not create groups or send
  messages.
- Native Classes module at `/admin/classes/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style Classes header, Class Recordings icon, search/filter row,
  result count, `Your classes` intro card, and no-active-classes empty state.
  Desktop and mobile Flutter/Next screenshots were captured under
  `output/playwright/classes-parity/`. The native screen reads real
  `alluwal-dev` `teaching_shifts`; verification intentionally did not join video
  calls or mutate class records.
- Native Recordings module at `/admin/recordings/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style Teachers header, teacher count, refresh action, and
  no-recordings empty state. Desktop and mobile Flutter/Next screenshots were
  captured under `output/playwright/recordings-parity/`. The native screen reads
  real `alluwal-dev` recordings through the same `listClassRecordings` callable
  Flutter uses; verification intentionally did not request playback URLs or
  mutate recording records.
- Native Surah Podcasts module at `/admin/surah-podcasts/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style Surah Library header, content count, refresh action,
  search field, no-content empty state, and Add Content action/dialog. Desktop
  and mobile Flutter/Next screenshots were captured under
  `output/playwright/surah-podcasts-parity/`. The native screen reads real
  `alluwal-dev` `surah_podcasts` content with active filtering, fallback to all
  rows when no active content exists, grouping by surah, and search;
  verification intentionally did not upload, delete, or mutate podcast content.
- Native Curriculum Books module at `/admin/curriculum-books/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style shared-learning hero, all-roles/PowerPoint/Arabic
  curriculum chips, four static Arabic curriculum book cards, and Open/Download
  actions using Flutter's public curriculum URLs. Desktop and mobile
  Flutter/Next screenshots were captured under
  `output/playwright/curriculum-books-parity/`. The native screen is static and
  verification intentionally did not upload, delete, or mutate curriculum
  assets.
- Native Notifications module at `/admin/notifications/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style Send Notification title, Compose Notification card,
  recipient mode selection, title/message fields, email checkbox, Select User
  card, active-user list, search, role filter, and Send Notification action.
  Desktop and mobile Flutter/Next screenshots were captured under
  `output/playwright/notifications-parity/`. The native screen reads real
  `alluwal-dev` active users and the send action is wired to
  `sendAdminNotification`; verification intentionally did not send
  notifications.
- Native Form Builder module at `/admin/form-builder/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style Form Templates header, Create Form controls, single
  Form Templates tab, search/status/sort controls, empty/no-results states, and
  template cards when data exists. Desktop and mobile Flutter/Next screenshots
  were captured under `output/playwright/form-builder-parity/`. The native
  screen reads real `alluwal-dev` `form_templates` and mirrors Flutter's
  filtering, deduplication, and sorting; verification intentionally did not
  create, edit, duplicate, activate, deactivate, or delete form templates.
- Native All Submissions module at `/admin/all-submissions/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style compact submissions toolbar, stats text, search field,
  Teachers/Month/Status/Forms chips, current-month banner, View All action,
  teacher grouping, and empty state. Desktop and mobile Flutter/Next
  screenshots were captured under `output/playwright/all-submissions-parity/`.
  The native screen reads real `alluwal-dev` `form_responses` and `users`,
  supports current-month and all-time reads, client-side search/status
  filtering, submitted-at sorting, and teacher grouping; verification
  intentionally did not mutate submissions or admin preferences.
- Native Submit Form module at `/admin/submit-form/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style Forms Reports gradient header, history action, frequency
  pills, search, category sections, form cards, field/frequency metadata,
  unavailable/completed badges, and mobile stacked cards. Desktop and mobile
  Flutter/Next screenshots were captured under
  `output/playwright/submit-form-parity/`. The native screen reads real
  `alluwal-dev` `form_templates` and `form_responses`, supports role-aware
  template visibility, latest active template selection, fallback defaults, and
  submitted-status indicators; verification intentionally did not create form
  responses.
- Native Invoices module at `/admin/invoices/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, Flutter-style Create Invoice/All Invoices tabs, parent/adult-student
  search, selected-user card, billing month, due date, access cutoff date,
  per-student amount entry cards, invoice search, status chips, invoice cards,
  edit/delete dialogs, and empty states. Desktop and mobile Flutter/Next
  screenshots were captured under `output/playwright/invoices-parity/`,
  including All Invoices tab states. The native screen reads real `alluwal-dev`
  users and invoices, uses the same `createInvoice` callable as Flutter, and
  writes edit/delete changes to the same invoice fields; verification
  intentionally did not mutate invoice records.
- Native Circles alias at `/admin/circles/`.
  Current pass covers signed-out admin access guard, signed-in administrator
  shell, sidebar routing, and the current Flutter-visible behavior where
  Savings > Circles opens the Public Site CMS Pricing screen with `Circles`
  selected in the sidebar and breadcrumb `Website / Pricing & public team`.
  Desktop and mobile Flutter/Next screenshots were captured under
  `output/playwright/circles-parity/`. The alias reuses the existing
  `PublicSiteCmsAdmin` real-data reads and verification did not create, edit,
  save, publish, upload, or delete CMS records.
- Native Teacher Dashboard Home at `/teacher/`.
  Current pass covers signed-out teacher access guard, role-aware login routing,
  signed-in teacher shell, Flutter-style teacher sidebar/topbar, desktop and
  mobile metric grids, earnings strip, next-class empty state, full-schedule
  action, and teacher quick-access cards. Desktop and mobile Flutter/Next
  screenshots were captured under
  `output/playwright/teacher-home-parity/`. The native screen reads real
  `alluwal-dev` teacher shifts, assigned tasks, and timesheet entries where
  allowed; verification used the dev teacher account and did not mutate teacher
  dashboard data.
- Native Teacher My Shifts at `/teacher/shifts/`.
  Current pass covers signed-out teacher access guard, signed-in teacher shell,
  Flutter-style Schedule header, Day/Week/Month controls, Grid/List toggle,
  week navigation, empty weekly agenda state, and desktop/mobile responsive
  layout. Desktop and mobile Flutter/Next screenshots were captured under
  `output/playwright/teacher-shifts-parity/`. The native screen reads real
  `alluwal-dev` teacher shifts where allowed; verification used the dev teacher
  account and did not create, edit, delete, clock in, or mutate shift records.
- Native Teacher Time Clock at `/teacher/time-clock/`.
  Current pass covers signed-out teacher access guard, signed-in teacher shell,
  Flutter-style My Timesheet card, range filter, Export action, sortable
  timesheet table headers, empty/loading states, and desktop/mobile responsive
  layout. Desktop and mobile Flutter/Next screenshots were captured under
  `output/playwright/teacher-time-clock-parity/`. The native screen reads real
  `alluwal-dev` `timesheet_entries` by teacher and supports client-side range
  filtering plus CSV export; verification used the dev teacher account and did
  not clock in/out or mutate timesheet records.
- Native Teacher Tasks at `/teacher/tasks/`.
  Current pass covers signed-out teacher access guard, signed-in teacher shell,
  Flutter-style Tasks title/search row, All Tasks/My Tasks/Today tabs, Show
  filters action, no-tasks empty state, task cards for non-empty data, and
  desktop/mobile responsive layout. Desktop and mobile Flutter/Next screenshots
  were captured under `output/playwright/teacher-tasks-parity/`. The native
  screen reads real `alluwal-dev` `tasks` records assigned to or created by the
  teacher and supports client-side search/tab/status/priority filtering;
  verification used the dev teacher account and did not mutate task records.
- Native Teacher Job Board at `/teacher/job-board/`.
  Current pass covers signed-out teacher access guard, signed-in teacher shell,
  Flutter-style `New Student Opportunities` header/subtitle, no-opportunities
  empty state, job cards for non-empty data, recently filled opportunities,
  teacher availability response dialog, and desktop/mobile responsive layout.
  Desktop and mobile Flutter/Next screenshots were captured under
  `output/playwright/teacher-job-board-parity/`. The native screen reads real
  `alluwal-dev` `job_board` records and writes teacher responses to
  `job_board/{jobId}/responses/{teacherId}`; verification used a temporary dev
  job and cleaned it up after confirming the response write.
- Native Teacher Chat at `/teacher/chat/`.
  Current pass covers signed-out teacher access guard, signed-in teacher shell,
  Flutter-style Recent Chats/My Contacts segmented control, search field,
  no-conversations empty state, Admin Support contact card, administrator
  contact group, and desktop/mobile responsive layout. Desktop and mobile
  Flutter/Next screenshots were captured under
  `output/playwright/teacher-chat-parity/`. The native screen reads real
  `alluwal-dev` chats, users, and teaching-shift relationships; verification
  used the dev teacher account and did not create chats or send messages.
- Native Teacher Classes at `/teacher/classes/`.
  Current pass covers signed-out teacher access guard, signed-in teacher shell,
  Flutter-style Classes header, Class Recordings icon, `Your classes` intro
  card, Today/date grouping, centered no-classes empty state, teacher-scoped
  class cards for non-empty data, copy guest-link action, RealtimeKit Join
  action, and desktop/mobile responsive layout. The latest pass also corrected
  visible filtering to match Flutter by hiding classes after their end time
  instead of keeping completed/past classes on the list for 30 days. The
  presence/details pass restored the Flutter-visible class display name as the
  card title, live participant strip for active/joinable classes, and native
  details dialog that refreshes `getRealtimeKitRoomPresence` before showing
  teacher, student, participant, class info, and Join Class sections. Earlier
  desktop/mobile screenshots are under `output/playwright/teacher-classes-parity/`;
  the latest Flutter/Next desktop/mobile Classes and Classroom screenshots are
  under `output/playwright/teacher-classroom-session-controls/`; the
  presence/details screenshots are under
  `output/playwright/teacher-classes-presence/`. The native
  screen reads real `alluwal-dev` `teaching_shifts` for the signed-in teacher;
  verification used the dev teacher account, seeded/updated a dev-only current
  class, joined RealtimeKit for screenshots, and did not touch production. The
  latest dev-only fixture is
  `teaching_shifts/codex_teacher_classroom_presence_current`.
- Native Teacher Recordings at `/teacher/recordings/`.
  Current pass covers signed-out teacher access guard, signed-in teacher shell,
  Flutter-style Students header/count, refresh action, no-recordings empty
  state, student/date/shift/fragment hierarchy for non-empty recording data,
  lazy playback URL loading behind the Play action, and desktop/mobile
  responsive layout. Desktop and mobile Flutter/Next screenshots were captured
  under `output/playwright/teacher-recordings-parity/`. The native screen reads
  real `alluwal-dev` recordings through the same `listClassRecordings` callable
  Flutter uses; verification used the dev teacher account and did not request
  playback URLs or mutate recording records.
- Native Teacher Surah Podcasts at `/teacher/surah-podcasts/`.
  Current pass covers signed-out teacher access guard, signed-in teacher shell,
  Flutter-style Surah Content header, refresh action, Library/Shared tabs,
  no-content empty state, folder cards and detail sections for non-empty Surah
  content, and teacher share/unshare scaffolding. Desktop and mobile Flutter/
  Next screenshots were captured under
  `output/playwright/teacher-surah-podcasts-parity/`. The native screen reads
  real `alluwal-dev` `surah_podcasts`, `podcast_assignments`, and teacher
  `teaching_shifts`; verification used the dev teacher account and the current
  empty dev Surah content baseline, so it did not upload admin content.
- Native Teacher Curriculum Books at `/teacher/curriculum-books/`.
  Current pass covers signed-out teacher access guard, signed-in teacher shell,
  Flutter-style shared-learning hero, all-roles/PowerPoint/Arabic curriculum
  chips, four static Arabic curriculum book cards, and Open/Download actions
  using Flutter's public curriculum URLs. Desktop and mobile Flutter/Next
  screenshots were captured under
  `output/playwright/teacher-curriculum-books-parity/`. The native screen is
  static and verification used the dev teacher account without mutating data.
- Native Teacher Submit Form at `/teacher/submit-form/`.
  Current pass covers signed-out teacher access guard, signed-in teacher shell,
  Flutter-style Forms Reports launcher, Daily/Weekly/Monthly availability
  pills, search, grouped form-template cards, disabled monthly review state,
  desktop/mobile responsive layout, native form-fill sheet, Daily shift picker,
  submitted shift detection, and Flutter-style shift card actions for `Form`,
  `Timesheet`, and `Details`. Desktop and mobile Flutter/Next screenshots were
  captured under `output/playwright/teacher-submit-form-parity/`; the deeper
  functional screenshots are under
  `output/playwright/teacher-submit-form-functionality/`; the time-field
  verification screenshots are under
  `output/playwright/teacher-submit-form-time-field/`. The native screen
  reads real `alluwal-dev` form templates, including `time` fields, teacher form-response status,
  `teaching_shifts`, and `timesheet_entries`, tolerating both snake_case and
  camelCase shift/timesheet fields found in dev data. Verification submitted a
  real Daily Class Report against `alluwal-dev` and confirmed the response was
  linked back to the shift and timesheet. The time-field pass submitted dev-only
  template `form_templates/codex_teacher_time_field_qa` and confirmed
  `form_responses/BBzYlHQFWtd9VQkoA7zH` saved `class_start_time: "16:30"`.
- Native Teacher My Form Submissions at `/teacher/form-submissions/`.
  Current pass covers signed-out teacher access guard, signed-in standalone
  history screen, Flutter-style month summary, month picker action, search,
  no-submissions empty state, grouped submission cards/details for non-empty
  data, and desktop/mobile responsive layout. Desktop Flutter and Next
  desktop/mobile screenshots were captured under
  `output/playwright/teacher-form-submissions-parity/`. The native screen reads
  real `alluwal-dev` form responses for the signed-in teacher and did not
  create or edit form responses during verification.

Not started after this pause:

- Continue teacher-facing deeper passes before admin. Priority candidates are
  Cloudflare classroom in-room controls, teacher session actions, and remaining
  rich media/signature/image Submit Form field types.

## Verification Already Run

From `apps/web`:

```bash
npm run typecheck
NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build
PLAYWRIGHT_BASE_URL=http://127.0.0.1:3021 npm run test:e2e
PLAYWRIGHT_BASE_URL=http://127.0.0.1:3021 ALLUWAL_RUN_TEACHER_E2E=1 ALLUWAL_TEACHER_E2E_EMAIL=... ALLUWAL_TEACHER_E2E_PASSWORD=... npm run test:e2e -- tests/teacher-dashboard.spec.ts --project=chromium
ALLUWAL_RUN_WRITE_E2E=1 PLAYWRIGHT_BASE_URL=http://127.0.0.1:3021 npx playwright test tests/forms.spec.ts --project=chromium --grep "contact form writes"
npm run package:hostinger
firebase deploy --only storage --dry-run --project alluwal-dev
firebase deploy --only storage --project alluwal-dev
ALLUWAL_RUN_ADMIN_CMS_E2E=1 ALLUWAL_RUN_ADMIN_CMS_UPLOAD_E2E=1 ALLUWAL_E2E_EMAIL=... ALLUWAL_E2E_PASSWORD=... ALLUWAL_E2E_LINKED_USER_UID=... PLAYWRIGHT_BASE_URL=http://127.0.0.1:3021 npx playwright test tests/cms-admin.spec.ts --project=chromium
./increment_version.sh && flutter build web --release --pwa-strategy=none --dart-define=FIREBASE_ENV=dev
```

Previous full suite result before the native CMS first pass:

```text
48 passed, 36 skipped
```

Most recent full suite result after adding the native Dashboard/CMS navigation
entry pass:

```text
54 passed, 36 skipped
```

Most recent full suite result after the About page parity refresh:

```text
54 passed, 36 skipped
```

Most recent full suite result after adding the authenticated CMS verification
harness:

```text
54 passed, 42 skipped
```

Most recent full suite result after the native admin dashboard sidebar parity
pass:

```text
54 passed, 42 skipped
```

Most recent full suite result after the native Public Site CMS landing-tab
polish pass:

```text
54 passed, 42 skipped
```

Most recent full suite result after the native Public Site CMS image-preview
polish pass:

```text
54 passed, 42 skipped
```

Most recent full suite result after the native Public Site CMS pricing-tab
polish pass:

```text
54 passed, 42 skipped
```

Most recent full suite result after the native Public Site CMS social-links
polish pass:

```text
54 passed, 42 skipped
```

Most recent full suite result after the native Public Site CMS team-photo
polish pass:

```text
54 passed, 42 skipped
```

Most recent full suite result after the native Public Site CMS linked-user
polish pass:

```text
54 passed, 42 skipped
```

Most recent full suite result after the native Public Site CMS team-publish
polish pass:

```text
54 passed, 42 skipped
```

Most recent full suite result after the native Public Site CMS team-import-copy
polish pass:

```text
54 passed, 42 skipped
```

Most recent full suite result after the native Public Site CMS team-delete-dialog
polish pass:

```text
54 passed, 42 skipped
```

Most recent full suite result after the native admin dashboard sidebar parity
completion pass:

```text
54 passed, 42 skipped
```

Most recent full suite result after the native admin dashboard sidebar search
parity pass:

```text
57 passed, 42 skipped
```

Most recent full suite result after the native admin dashboard sidebar
collapse/reset parity pass:

```text
60 passed, 42 skipped
```

Most recent full suite result after the native admin dashboard sidebar
favorites parity pass:

```text
63 passed, 42 skipped
```

Most recent full suite result after authenticated CMS verification:

```text
63 passed, 42 skipped
```

Most recent full suite result after adding the native CMS dashboard shell:

```text
63 passed, 42 skipped
```

Most recent full suite result after the native CMS mobile shell parity pass:

```text
63 passed, 42 skipped
```

Most recent full suite result after the native CMS mobile tabs parity pass:

```text
63 passed, 42 skipped
```

Most recent full suite result after the native admin dashboard home parity pass:

```text
54 passed, 54 skipped
```

Most recent full suite result after the native Student Applicants parity pass:

```text
57 passed, 57 skipped
```

Most recent full suite result after the native Teacher Applicants parity pass:

```text
60 passed, 60 skipped
```

Most recent full suite result after the native Users parity pass:

```text
63 passed, 63 skipped
```

Most recent full suite result after the native Shifts parity pass:

```text
66 passed, 66 skipped
```

Most recent full suite result after the native Timesheets parity pass:

```text
69 passed, 69 skipped
```

Most recent full suite result after the native Tasks parity pass:

```text
72 passed, 72 skipped
```

Most recent full suite result after the native Audits parity pass:

```text
75 passed, 75 skipped
```

Most recent full suite result after the native Chat parity pass:

```text
78 passed, 78 skipped
```

Most recent full suite result after the native Classes parity pass:

```text
81 passed, 81 skipped
```

Most recent full suite result after the native Recordings parity pass:

```text
84 passed, 84 skipped
```

Most recent full suite result after the native Surah Podcasts parity pass:

```text
87 passed, 87 skipped
```

Most recent full suite result after the native Curriculum Books parity pass:

```text
90 passed, 90 skipped
```

Most recent full suite result after the native Notifications parity pass:

```text
93 passed, 93 skipped
```

Most recent full suite result after the native Form Builder parity pass:

```text
96 passed, 96 skipped
```

Most recent full suite result after the native All Submissions parity pass:

```text
99 passed, 99 skipped
```

Most recent full suite result after the native Submit Form parity pass:

```text
102 passed, 102 skipped
```

Most recent full suite result after the native Invoices parity pass:

```text
105 passed, 105 skipped
```

Most recent full suite result after the native Circles alias parity pass:

```text
108 passed, 108 skipped
```

Most recent full suite result after the native Teacher Dashboard Home parity
pass:

```text
111 passed, 111 skipped
```

Most recent full suite result after the native Teacher My Shifts parity pass:

```text
114 passed, 114 skipped
```

Most recent full suite result after the native Teacher Time Clock parity pass:

```text
117 passed, 117 skipped
```

Most recent full suite result after the native Teacher Tasks parity pass:

```text
117 passed, 123 skipped
```

Most recent full suite result after the native Teacher Job Board parity pass:

```text
119 passed, 127 skipped
```

Most recent full suite result after the native Teacher Chat parity pass:

```text
121 passed, 131 skipped
```

Most recent full suite result after the native Teacher Classes parity pass:

```text
131 passed, 127 skipped
```

Most recent full suite result after the native Teacher Recordings parity pass:

```text
134 passed, 130 skipped
```

Most recent full suite result after the native Teacher Surah Podcasts parity
pass:

```text
137 passed, 133 skipped
```

Most recent full suite result after the native Teacher Curriculum Books parity
pass:

```text
140 passed, 136 skipped
```

Most recent full suite result after the native Teacher Submit Form parity pass:

```text
143 passed, 139 skipped
```

Most recent full suite result after the native Teacher My Form Submissions
parity pass:

```text
146 passed, 142 skipped
```

Most recent targeted authenticated native admin dashboard/CMS verification
against `alluwal-dev`:

```text
8 passed
```

Most recent targeted authenticated native Teacher Dashboard Home verification
against `alluwal-dev`:

```text
2 passed
```

Most recent targeted authenticated native Teacher Dashboard/My Shifts
verification against `alluwal-dev`:

```text
4 passed
```

Most recent targeted authenticated native Teacher Dashboard/My Shifts/Time
Clock verification against `alluwal-dev`:

```text
6 passed
```

Most recent targeted authenticated native Teacher Dashboard/My Shifts/Time
Clock/Tasks verification against `alluwal-dev` on Chromium:

```text
8 passed
```

Most recent targeted authenticated native Teacher Dashboard/My Shifts/Time
Clock/Tasks/Job Board verification against `alluwal-dev` on Chromium:

```text
10 passed
```

Most recent targeted authenticated native Teacher Dashboard/My Shifts/Time
Clock/Tasks/Job Board/Chat verification against `alluwal-dev` on Chromium:

```text
12 passed
```

Most recent targeted authenticated native Teacher Dashboard/My Shifts/Time
Clock/Tasks/Job Board/Chat/Classes verification against `alluwal-dev` on
Chromium:

```text
14 passed
```

Most recent targeted authenticated native Teacher Dashboard/My Shifts/Time
Clock/Tasks/Job Board/Chat/Classes/Recordings verification against
`alluwal-dev` on Chromium:

```text
16 passed
```

Most recent targeted authenticated native Teacher Dashboard/My Shifts/Time
Clock/Tasks/Job Board/Chat/Classes/Recordings/Surah Podcasts verification
against `alluwal-dev` on Chromium:

```text
18 passed
```

Most recent targeted authenticated native Teacher Dashboard/My Shifts/Time
Clock/Tasks/Job Board/Chat/Classes/Recordings/Surah Podcasts/Curriculum Books
verification against `alluwal-dev` on Chromium:

```text
20 passed
```

Most recent targeted authenticated teacher-facing verification after native My
Shifts clock-in/clock-out implementation against `alluwal-dev` on Chromium:

```text
24 passed
```

Most recent manual native My Shifts clock-in/clock-out browser write
verification against `alluwal-dev`:

```text
Shift: teaching_shifts/4TpVsguSUkUHg3jLPbt0
Timesheet: timesheet_entries/FLY3fsO9eig0rdGk2jfo
Verified: pending shift_clock_in entry, web clock-in/out platforms,
scheduled_start/scheduled_end, payment fields, and shift clock_in_time plus
clock_out_time.
Screenshots: output/playwright/teacher-shifts-functionality/
next-clock-ready-before.png, next-clock-after-in.png, next-clock-after-out.png
```

Most recent real dev enrollment smoke test after the native Teacher My Shifts
parity pass:

```text
Codex Teacher Shifts Student 20260622021427
codex.teacher.shifts.parent.20260622021427@alluwal-dev.test
```

Most recent real dev enrollment smoke test after the native Teacher Time Clock
parity pass:

```text
Codex Teacher Time Clock Student 20260622023343
codex.teacher.timeclock.parent.20260622023343@alluwal-dev.test
```

Most recent real dev enrollment smoke test after the native Teacher Tasks
parity pass:

```text
Codex Teacher Tasks Student 20260622025938
codex.teacher.tasks.parent.20260622025938@alluwal-dev.test
```

Most recent real dev Job Board response smoke test after the native Teacher Job
Board parity pass:

```text
Temporary dev job: codex_teacher_job_board_20260622031316
Teacher response: partial, comment "Codex dev test: available Mondays only."
Cleanup confirmed: jobExists=false, responseExists=false
```

Most recent real dev Job Board withdraw smoke test after the Teacher Job Board
withdraw parity pass:

```text
Stable modal fixture: job_board/codex_teacher_job_board_withdraw_qa
Temporary smoke job: job_board/codex_teacher_job_board_withdraw_smoke_1782155045766
Result after confirming withdraw: status=open, acceptedByTeacherId=null
```

Most recent real dev enrollment smoke test after the native Teacher Chat parity
pass:

```text
Codex Teacher Chat Student 20260622033046
codex.teacher.chat.parent.20260622033046@alluwal-dev.test
```

Most recent real dev enrollment smoke test after the native Teacher Classes
parity pass:

```text
Codex Teacher Classes Student 20260622035709
codex.teacher.classes.parent.20260622035709@alluwal-dev.test
```

Most recent real dev enrollment smoke test after the native Teacher Recordings
parity pass:

```text
Codex Teacher Recordings Student 20260622040840
codex.teacher.recordings.parent.20260622040840@alluwal-dev.test
```

Most recent real dev enrollment smoke test after the native Teacher Surah
Podcasts parity pass:

```text
Codex Teacher Surah Podcasts Student 20260622042415
codex.teacher.surah.parent.20260622042415@alluwal-dev.test
```

Most recent real dev enrollment smoke test after the native Teacher Curriculum
Books parity pass:

```text
Codex Teacher Curriculum Books Student 20260622043333
codex.teacher.curriculum.parent.20260622043333@alluwal-dev.test
```

Most recent real dev enrollment smoke test after the native Teacher Submit Form
parity pass:

```text
Codex Teacher Submit Form Student 20260622044727
codex.teacher.submit.parent.20260622044727@alluwal-dev.test
```

Most recent real dev enrollment smoke test after the native Teacher My Form
Submissions parity pass:

```text
Codex Teacher Form Submissions Student 20260622050628
codex.teacher.submissions.parent.20260622050628@alluwal-dev.test
```

Previous real dev enrollment smoke test after the native Teacher Dashboard Home
parity pass:

```text
Codex Teacher Home Student 20260622015628
codex.teacher.home.parent.20260622015628@alluwal-dev.test
```

Teacher-facing dev test login:

```text
codex.cms.staff@alluwal-dev.test / 111111
```

Package sanity after this pass:

```text
build/hostinger-web: 117M
build/hostinger-web/app: 97M
apps/web/out: 21M
apps/web/out/_next: 4.4M
No flutter_service_worker.js, _next*, or .DS_Store found under build/hostinger-web/app.
git diff --check passed.
```

Most recent targeted authenticated native admin dashboard/CMS/Student Applicants
verification against `alluwal-dev`:

```text
10 passed
```

Most recent targeted authenticated native admin dashboard/CMS/Student
Applicants/Teacher Applicants verification against `alluwal-dev`:

```text
12 passed
```

Most recent targeted authenticated native admin dashboard/CMS/Users/Student
Applicants/Teacher Applicants verification against `alluwal-dev`:

```text
14 passed
```

Most recent targeted authenticated native admin dashboard/CMS/Shifts/Users/
Student Applicants/Teacher Applicants verification against `alluwal-dev`:

```text
15 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/Timesheets/Shifts/
Users/Student Applicants/Teacher Applicants verification against `alluwal-dev`:

```text
17 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/Tasks/Timesheets/
Shifts/Users/Student Applicants/Teacher Applicants verification against
`alluwal-dev`:

```text
19 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/Audits/Tasks/
Timesheets/Shifts/Users/Student Applicants/Teacher Applicants verification
against `alluwal-dev` on Chromium:

```text
21 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/Chat/Audits/Tasks/
Timesheets/Shifts/Users/Student Applicants/Teacher Applicants verification
against `alluwal-dev` on Chromium:

```text
23 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/Classes/Chat/
Audits/Tasks/Timesheets/Shifts/Users/Student Applicants/Teacher Applicants
verification against `alluwal-dev` on Chromium:

```text
25 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/Recordings/
Classes/Chat/Audits/Tasks/Timesheets/Shifts/Users/Student Applicants/Teacher
Applicants verification against `alluwal-dev` on Chromium:

```text
27 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/Surah Podcasts/
Recordings/Classes/Chat/Audits/Tasks/Timesheets/Shifts/Users/Student
Applicants/Teacher Applicants verification against `alluwal-dev` on Chromium:

```text
29 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/Curriculum Books/
Surah Podcasts/Recordings/Classes/Chat/Audits/Tasks/Timesheets/Shifts/Users/
Student Applicants/Teacher Applicants verification against `alluwal-dev` on
Chromium:

```text
31 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/Notifications/
Curriculum Books/Surah Podcasts/Recordings/Classes/Chat/Audits/Tasks/
Timesheets/Shifts/Users/Student Applicants/Teacher Applicants verification
against `alluwal-dev` on Chromium:

```text
33 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/Form Builder/
Notifications/Curriculum Books/Surah Podcasts/Recordings/Classes/Chat/Audits/
Tasks/Timesheets/Shifts/Users/Student Applicants/Teacher Applicants
verification against `alluwal-dev` on Chromium:

```text
35 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/All Submissions/
Form Builder/Notifications/Curriculum Books/Surah Podcasts/Recordings/Classes/
Chat/Audits/Tasks/Timesheets/Shifts/Users/Student Applicants/Teacher
Applicants verification against `alluwal-dev` on Chromium:

```text
37 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/Submit Form/All
Submissions/Form Builder/Notifications/Curriculum Books/Surah Podcasts/
Recordings/Classes/Chat/Audits/Tasks/Timesheets/Shifts/Users/Student
Applicants/Teacher Applicants verification against `alluwal-dev` on Chromium:

```text
39 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/Invoices/Submit
Form/All Submissions/Form Builder/Notifications/Curriculum Books/Surah
Podcasts/Recordings/Classes/Chat/Audits/Tasks/Timesheets/Shifts/Users/Student
Applicants/Teacher Applicants verification against `alluwal-dev` on Chromium:

```text
41 passed, 1 skipped
```

Most recent targeted authenticated native admin dashboard/CMS/Circles/Invoices/
Submit Form/All Submissions/Form Builder/Notifications/Curriculum Books/Surah
Podcasts/Recordings/Classes/Chat/Audits/Tasks/Timesheets/Shifts/Users/Student
Applicants/Teacher Applicants verification against `alluwal-dev` on Chromium:

```text
43 passed, 1 skipped
```

Most recent targeted authenticated native CMS verification against
`alluwal-dev`:

```text
7 passed
```

Most recent targeted non-writing native CMS verification:

```text
5 passed, 2 skipped
```

The real login bridge test remains skipped unless `ALLUWAL_E2E_EMAIL` and
`ALLUWAL_E2E_PASSWORD` are provided.

Most recent meaningful flow verification also submitted a dev Firebase student
application through `/enroll/`:

```text
Codex Login Parity Student 2026-06-21T16-26-25-284Z
```

Most recent real dev Firebase enrollment submitted after the native CMS first
pass:

```text
Codex CMS Pass Student 2026-06-21T16-51-20-204Z
```

Most recent real dev Firebase enrollment submitted after the native CMS
team-management pass:

```text
Codex CMS Team Pass Student 2026-06-21T17-00-45-060Z
```

Most recent real dev Firebase enrollment submitted after the native CMS access
guard pass:

```text
Codex CMS Guard Pass Student 2026-06-21T17-09-20-811Z
```

Most recent real dev Firebase enrollment submitted after the native CMS landing
upload pass:

```text
Codex CMS Upload Pass Student 2026-06-21T17-14-54-265Z
```

Most recent real dev Firebase enrollment submitted after the native
Dashboard/CMS navigation entry pass:

```text
Codex CMS Nav Pass Student 2026-06-21T17-20-44-538Z
```

Most recent real dev Firebase enrollment submitted after the authenticated CMS
verification harness pass:

```text
Codex CMS Auth Harness Student 2026-06-21T17-37-02-214Z
```

Most recent real dev Firebase enrollment submitted after the native admin
dashboard sidebar parity pass:

```text
Codex Admin Sidebar Student 2026-06-21T17-42-59-637Z
```

Most recent real dev Firebase enrollment submitted after the native Public Site
CMS landing-tab polish pass:

```text
Codex CMS Landing Polish Student 2026-06-21T17-47-44-904Z
```

Most recent real dev Firebase enrollment submitted after the native Public Site
CMS image-preview polish pass:

```text
Codex CMS Image Preview Student 2026-06-21T17-53-54-290Z
```

Most recent real dev Firebase enrollment submitted after the native Public Site
CMS pricing-tab polish pass:

```text
Codex CMS Pricing Polish Student 2026-06-21T17-58-51-195Z
```

Most recent real dev Firebase enrollment submitted after the native Public Site
CMS social-links polish pass:

```text
Codex CMS Social Polish Student 2026-06-21T18-02-33-016Z
```

Most recent real dev Firebase enrollment submitted after the native Public Site
CMS team-photo polish pass:

```text
Codex CMS Team Photo Student 2026-06-21T18-06-48-310Z
```

Most recent real dev Firebase enrollment submitted after the native Public Site
CMS linked-user polish pass:

```text
Codex CMS Linked User Student 2026-06-21T18-11-11-262Z
```

Most recent real dev Firebase enrollment submitted after the native Public Site
CMS team-publish polish pass:

```text
Codex CMS Team Publish Student 2026-06-21T18-15-18-232Z
```

Most recent real dev Firebase enrollment submitted after the native Public Site
CMS team-import-copy polish pass:

```text
Codex CMS Team Import Copy Student 2026-06-21T18-19-09-180Z
```

Most recent real dev Firebase enrollment submitted after the native Public Site
CMS team-delete-dialog polish pass:

```text
Codex CMS Delete Dialog Student 2026-06-21T18-23-23-208Z
```

Most recent real dev Firebase enrollment submitted after the native admin
dashboard sidebar parity completion pass:

```text
Codex Admin Sidebar Parity Student 2026-06-21T18-28-24-420Z
```

Most recent real dev Firebase enrollment submitted after the native admin
dashboard sidebar search parity pass:

```text
Codex Admin Sidebar Search Student 2026-06-21T18-34-58-297Z
```

Most recent real dev Firebase enrollment submitted after the native admin
dashboard sidebar collapse/reset parity pass:

```text
Codex Admin Sidebar Collapse Student 2026-06-21T18-39-23-112Z
```

Most recent real dev Firebase enrollment submitted after the native CMS
dashboard-shell pass:

```text
Codex CMS Shell Student 2026-06-21T19-23-32-150Z
```

Most recent real dev Firebase enrollment submitted after the native CMS mobile
parity pass:

```text
Codex CMS Mobile Parity Student 2026-06-21T19-56-35-118Z
```

Most recent real dev Firebase enrollment submitted after the native CMS mobile
tabs parity pass:

```text
Codex CMS Mobile Tabs Student 2026-06-21T20-08-56-209Z
```

Most recent real dev Firebase enrollment submitted after the native admin
dashboard home parity pass:

```text
Codex Admin Home Student 2026-06-21T20-27-06-391Z
```

Most recent real dev Firebase enrollment submitted after the native Student
Applicants parity pass:

```text
Codex Student Applicants Student 2026-06-21T20-40-42-411Z
```

Most recent real dev Firebase enrollment submitted after the native Teacher
Applicants parity pass:

```text
Codex Teacher Applicants Student 2026-06-21T20-56-23-951Z
```

Most recent real dev Firebase enrollment submitted after the native Users parity
pass:

```text
Codex Users Student 2026-06-21T21-08-58-762Z
```

Most recent real dev Firebase enrollment submitted after the native Shifts
parity pass:

```text
Codex Shifts Student 2026-06-21T21-22-02-052Z
```

Most recent real dev Firebase enrollment submitted after the native Timesheets
parity pass:

```text
Codex Timesheets Student 2026-06-21T21-32-44-492Z
```

Most recent real dev Firebase enrollment submitted after the native Tasks parity
pass:

```text
Codex Tasks Student 2026-06-21T21-41-59-656Z
```

Most recent real dev Firebase enrollment submitted after the native Audits
parity pass:

```text
Codex Audits Student 2026-06-21T22-00-23-369Z
```

Most recent real dev Firebase enrollment submitted after the native Chat parity
pass:

```text
Codex Chat Student 2026-06-21T22-15-09-131Z
```

Most recent real dev Firebase enrollment submitted after the native Classes
parity pass:

```text
Codex Classes Student 2026-06-21T22-30-55-709Z
```

Most recent real dev Firebase enrollment submitted after the native Recordings
parity pass:

```text
Codex Recordings Student 2026-06-21T22-49-30-365Z
```

Most recent real dev Firebase enrollment submitted after the native Surah
Podcasts parity pass:

```text
Codex Surah Podcasts Student 2026-06-21T23-04-17-738Z
```

Most recent real dev Firebase enrollment submitted after the native Curriculum
Books parity pass:

```text
Codex Curriculum Books Student 2026-06-21T23-25-26-457Z
```

Most recent real dev Firebase enrollment submitted after the native
Notifications parity pass:

```text
Codex Notifications Student 2026-06-21T23-37-30-199Z
```

Most recent real dev Firebase enrollment submitted after the native Form Builder
parity pass:

```text
Codex Form Builder Student 2026-06-21T23-57-08-817Z
```

Most recent real dev Firebase enrollment submitted after the native All
Submissions parity pass:

```text
Codex All Submissions Student 2026-06-22T00-09-49-403Z
```

Most recent real dev Firebase enrollment submitted after the native Submit Form
parity pass:

```text
Codex Submit Form Student 2026-06-22T00-54-28-762Z
```

Most recent real dev Firebase enrollment submitted after the native Invoices
parity pass:

```text
Codex Invoices Student 2026-06-22T01-17-56-118Z
```

Most recent real dev Firebase enrollment submitted after the native Circles
alias parity pass:

```text
Codex Circles Student 2026-06-22T01-33-57-265Z
```

Most recent explicit dev Firebase public application write verification:

```text
Firebase project: alluwal-dev
Adult/student enrollment: Codex Dev Adult Student 2026-06-21T18-51-00-921Z
Parent enrollment child: Codex Dev Parent Child 2026-06-21T18-51-00-921Z
Teacher application: CodexDevTeacher 2026-06-21T18-51-00-921Z
Leadership application: CodexDevLeadership 2026-06-21T18-51-00-921Z
```

Package sanity checks already passed:

```bash
find build/hostinger-web/app \( -name 'flutter_service_worker.js' -o -name '_next*' -o -name '.DS_Store' \) -print
du -sh build/hostinger-web build/hostinger-web/app apps/web/out apps/web/out/_next
git diff --check
```

Expected package size at the checkpoint:

```text
117M build/hostinger-web
 97M build/hostinger-web/app
 20M apps/web/out
4.3M apps/web/out/_next
```

Dashboard bridge screenshots from this pass are in:

```text
output/playwright/dashboard-bridge/
```

Native Dashboard/CMS navigation entry screenshots from this pass were added
under:

```text
output/playwright/dashboard-bridge/
```

Public Site CMS first-pass screenshots are in:

```text
output/playwright/public-site-cms/
```

Public Site CMS team editor desktop/mobile viewport screenshots from the
team-management pass were also added under:

```text
output/playwright/public-site-cms/
```

Public Site CMS signed-out admin guard screenshots from the access-guard pass
were also added under:

```text
output/playwright/public-site-cms/
```

Public Site CMS signed-out guard screenshots were refreshed after the landing
upload pass under:

```text
output/playwright/public-site-cms/
```

About parity baseline and after screenshots from the refresh are in:

```text
output/playwright/about-parity/
```

Public Site CMS signed-out guard screenshots and the latest real enrollment
success screenshot from the verification-harness pass are in:

```text
output/playwright/cms-verification/
```

Native admin dashboard desktop/mobile screenshots and the latest real enrollment
success screenshot from the sidebar parity pass are in:

```text
output/playwright/admin-dashboard/
```

Public Site CMS/admin accessible desktop/mobile screenshots and the latest real
enrollment success screenshot from the landing-tab polish pass are in:

```text
output/playwright/cms-landing-polish/
```

Public Site CMS/admin accessible desktop/mobile screenshots and the latest real
enrollment success screenshot from the image-preview polish pass are in:

```text
output/playwright/cms-image-preview-polish/
```

Public Site CMS/admin accessible desktop/mobile screenshots and the latest real
enrollment success screenshot from the pricing-tab polish pass are in:

```text
output/playwright/cms-pricing-polish/
```

Public Site CMS/admin accessible desktop/mobile screenshots and the latest real
enrollment success screenshot from the social-links polish pass are in:

```text
output/playwright/cms-social-polish/
```

Public Site CMS/admin accessible desktop/mobile screenshots and the latest real
enrollment success screenshot from the team-photo polish pass are in:

```text
output/playwright/cms-team-photo-polish/
```

Public Site CMS/admin accessible desktop/mobile screenshots and the latest real
enrollment success screenshot from the linked-user polish pass are in:

```text
output/playwright/cms-linked-user-polish/
```

Public Site CMS/admin accessible desktop/mobile screenshots and the latest real
enrollment success screenshot from the team-publish polish pass are in:

```text
output/playwright/cms-team-publish-polish/
```

Public Site CMS/admin accessible desktop/mobile screenshots and the latest real
enrollment success screenshot from the team-import-copy polish pass are in:

```text
output/playwright/cms-team-import-copy-polish/
```

Public Site CMS/admin accessible desktop/mobile screenshots and the latest real
enrollment success screenshot from the team-delete-dialog polish pass are in:

```text
output/playwright/cms-team-delete-dialog-polish/
```

Native admin dashboard desktop/mobile/full-page screenshots and the latest real
enrollment success screenshot from the sidebar parity completion pass are in:

```text
output/playwright/admin-sidebar-parity/
```

Native admin dashboard default/search-filtered desktop and mobile screenshots,
plus the latest real enrollment success screenshot from the sidebar search
parity pass, are in:

```text
output/playwright/admin-sidebar-search/
```

Native admin dashboard expanded/collapsed/search desktop and mobile screenshots,
plus the latest real enrollment success screenshot from the sidebar
collapse/reset parity pass, are in:

```text
output/playwright/admin-sidebar-collapse/
```

Native admin dashboard favorites desktop/mobile screenshots are in:

```text
output/playwright/admin-sidebar-favorites/
```

Explicit dev Firebase public application write screenshots are in:

```text
output/playwright/dev-firebase-writes/
```

Authenticated Flutter and Next Public Site CMS desktop screenshots from the
dashboard-shell parity pass, plus the latest real dev enrollment success
screenshot, are in:

```text
output/playwright/cms-auth-parity/
```

Authenticated Flutter mobile pricing/team/social/hero, Next mobile
pricing/team/social/hero, and the latest real dev enrollment success
screenshots from the mobile CMS parity passes are in:

```text
output/playwright/cms-mobile-parity/
```

Authenticated Flutter and Next admin dashboard home desktop/mobile screenshots,
signed-out Next guard screenshots, and the latest real dev enrollment success
screenshot from the admin home parity pass are in:

```text
output/playwright/admin-home-parity/
```

Authenticated Flutter and Next Student Applicants desktop/mobile screenshots,
signed-out Next guard screenshots, console captures, and the latest real dev
enrollment success screenshot from the Student Applicants parity pass are in:

```text
output/playwright/student-applicants-parity/
```

Authenticated Flutter and Next Teacher Applicants desktop/mobile screenshots,
details dialog screenshots, and the latest real dev enrollment success
screenshot from the Teacher Applicants parity pass are in:

```text
output/playwright/teacher-applicants-parity/
```

Authenticated Flutter and Next Users desktop/mobile screenshots, Admins tab
screenshots, and the latest real dev enrollment success screenshot from the
Users parity pass are in:

```text
output/playwright/users-parity/
```

Authenticated Flutter and Next Shifts desktop/mobile screenshots from the
Shifts parity pass are in:

```text
output/playwright/shifts-parity/
```

Authenticated Flutter and Next Timesheets desktop/mobile screenshots from the
Timesheets parity pass are in:

```text
output/playwright/timesheets-parity/
```

Authenticated Flutter and Next Tasks desktop/mobile screenshots from the Tasks
parity pass are in:

```text
output/playwright/tasks-parity/
```

Authenticated Flutter and Next Audits desktop/mobile screenshots from the Audits
parity pass are in:

```text
output/playwright/audits-parity/
```

Authenticated Flutter and Next Chat desktop/mobile screenshots from the Chat
parity pass are in:

```text
output/playwright/chat-parity/
```

Authenticated Flutter and Next Classes desktop/mobile screenshots from the
Classes parity pass are in:

```text
output/playwright/classes-parity/
```

Authenticated Flutter and Next Recordings desktop/mobile screenshots from the
Recordings parity pass are in:

```text
output/playwright/recordings-parity/
```

Authenticated Flutter and Next Surah Podcasts desktop/mobile screenshots from
the Surah Podcasts parity pass are in:

```text
output/playwright/surah-podcasts-parity/
```

Authenticated Flutter and Next Curriculum Books desktop/mobile screenshots from
the Curriculum Books parity pass are in:

```text
output/playwright/curriculum-books-parity/
```

Authenticated Flutter and Next Notifications desktop/mobile screenshots from
the Notifications parity pass are in:

```text
output/playwright/notifications-parity/
```

Authenticated Flutter and Next Form Builder desktop/mobile screenshots from the
Form Builder parity pass are in:

```text
output/playwright/form-builder-parity/
```

Authenticated Flutter and Next All Submissions desktop/mobile screenshots from
the All Submissions parity pass are in:

```text
output/playwright/all-submissions-parity/
```

Authenticated Flutter and Next Submit Form desktop/mobile screenshots from the
Submit Form parity pass are in:

```text
output/playwright/submit-form-parity/
```

Authenticated Flutter and Next Invoices desktop/mobile screenshots from the
Invoices parity pass are in:

```text
output/playwright/invoices-parity/
```

Authenticated Flutter and Next Circles desktop/mobile screenshots from the
Circles alias parity pass are in:

```text
output/playwright/circles-parity/
```

Authenticated Flutter and Next Teacher Dashboard Home desktop/mobile screenshots
from the teacher home parity pass are in:

```text
output/playwright/teacher-home-parity/
```

Authenticated Flutter and Next Teacher My Shifts desktop/mobile screenshots
from the teacher shifts parity pass are in:

```text
output/playwright/teacher-shifts-parity/
```

Authenticated Flutter and Next Teacher Time Clock desktop/mobile screenshots
from the teacher time clock parity pass are in:

```text
output/playwright/teacher-time-clock-parity/
```

Authenticated Flutter and Next Teacher Tasks desktop/mobile screenshots from
the teacher tasks parity pass are in:

```text
output/playwright/teacher-tasks-parity/
```

Authenticated Flutter and Next Teacher Job Board desktop/mobile screenshots from
the teacher job board parity pass are in:

```text
output/playwright/teacher-job-board-parity/
```

Authenticated Flutter and Next Teacher Chat desktop/mobile screenshots from the
teacher chat parity pass are in:

```text
output/playwright/teacher-chat-parity/
```

Authenticated Flutter and Next Teacher Classes desktop/mobile screenshots from
the teacher classes parity pass are in:

```text
output/playwright/teacher-classes-parity/
```

Authenticated Flutter and Next Teacher Recordings desktop/mobile screenshots
from the teacher recordings parity pass are in:

```text
output/playwright/teacher-recordings-parity/
```

Authenticated Flutter and Next Teacher Surah Podcasts desktop/mobile
screenshots from the teacher surah podcasts parity pass are in:

```text
output/playwright/teacher-surah-podcasts-parity/
```

Authenticated Flutter and Next Teacher Curriculum Books desktop/mobile
screenshots from the teacher curriculum books parity pass are in:

```text
output/playwright/teacher-curriculum-books-parity/
```

Authenticated Flutter and Next Teacher Submit Form desktop/mobile screenshots
from the teacher submit form parity pass are in:

```text
output/playwright/teacher-submit-form-parity/
```

Authenticated Flutter desktop and Next desktop/mobile Teacher My Form
Submissions screenshots from the teacher submissions parity pass are in:

```text
output/playwright/teacher-form-submissions-parity/
```

Authenticated native CMS save/delete and upload verification has now run against
`alluwal-dev`. Current dev test users:

```text
codex.cms.admin@alluwal-dev.test / 111111
codex.cms.staff@alluwal-dev.test / 111111
```

Authenticated Flutter Public Site CMS desktop screenshots were captured in the
previous pass. Authenticated Flutter mobile Pricing/Team/Social/Hero were
captured in the current mobile parity passes. The local Flutter dev baseline
still logs CORS noise for `getPublicSiteMarketingBundleHttp` and
`syncPublicSiteAdminClaim` from `127.0.0.1:3032`, but the authenticated screens
render and the native Next authenticated CMS write/upload tests pass against
`alluwal-dev`.

## How To Continue

1. Install/build the web app if needed:

   ```bash
   cd apps/web
   npm install
   NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build
   ```

2. Serve the Next static export:

   ```bash
   cd apps/web/out
   python3 -m http.server 3021 --bind 127.0.0.1
   ```

3. Serve or rebuild the Flutter web baseline:

   ```bash
   cd build/web
   python3 -m http.server 3032 --bind 127.0.0.1
   ```

   If `build/web` is stale or missing, use the repo-approved Flutter web build:

   ```bash
   ./increment_version.sh && flutter build web --release --pwa-strategy=none
   ```

   For a dev Firebase Flutter baseline, use:

   ```bash
   ./increment_version.sh && flutter build web --release --pwa-strategy=none --dart-define=FIREBASE_ENV=dev
   ```

4. Continue teacher-facing modules, not admin modules, until the teacher areas
   are handled. The user explicitly asked to stop treating teacher pages as
   design-only parity and to verify Flutter dev behavior, seed dev data when
   useful, then implement the same teacher-facing actions in Next.

   Current teacher functional checkpoint:
   - `alluwal-dev` has a seeded dev teacher shift for
     `codex.cms.staff@alluwal-dev.test / 111111`:
     `teaching_shifts/GWOc5d3j6pOM4c2QLna1`.
   - `alluwal-dev` also has a dev-only active clock test shift that was used
     to verify native Next clock-in/clock-out writes:
     `teaching_shifts/4TpVsguSUkUHg3jLPbt0`. The Next browser flow created
     `timesheet_entries/FLY3fsO9eig0rdGk2jfo`, set `source:
     shift_clock_in`, `status: pending`, `clock_in_platform: web`,
     `clock_out_platform: web`, scheduled start/end fields, pay fields, and
     updated the shift with both `clock_in_time` and `clock_out_time`.
   - Flutter dev My Shifts behavior was captured with that shift in
     `output/playwright/teacher-shifts-functionality/`.
   - Next My Shifts now has a functional first pass: Day/Week/Month modes,
     selected-day date strip, timeline-style day cards, shift details modal,
     settings/report-schedule-issue modal, timezone dialog, and successful
     teacher schedule issue report creation against `alluwal-dev`.
   - Native Next My Shifts clock actions are now functional for current Day
     timeline shifts: clock-in requests browser geolocation, creates a
     Flutter-compatible pending timesheet entry, marks the shift active, and
     clock-out fills `end_time`, capped `total_hours`, payment fields, location
     fields, and `clock_out_time`.
   - My Shifts clock-in UI was corrected after user review: Next now shows a
     Flutter-style active/upcoming gradient session card when a shift is
     clocked in or inside the 1-minute clock-in window, and the shift details
     modal exposes Clock In/Clock Out actions instead of being view-only.
   - `firestore.rules` now defines `teacherIdFromData(...)`; this was deployed
     to `alluwal-dev` only so teacher schedule issue reports can be created.
   - Native Teacher Submit Form no longer bridges immediately when opening a
     normal form; it has a native first-pass form sheet and daily shift picker.
   - Native Teacher Submit Form daily/per-session flow now checks existing
     `form_responses` for each shift using the same tolerant shift/user fields
     as Flutter, marks submitted shifts in the picker, opens an existing
     response in a read-only sheet, and links new submissions back to
     `timesheet_entries` plus `teaching_shifts` with `form_response_id`,
     `formResponseId`, `form_completed`, `formCompleted`, and completed-at
     best-effort updates. The daily picker now also exposes native `Timesheet`
     and `Details` sheets like Flutter, instead of routing those actions through
     the Flutter bridge.
   - Latest dev Submit Form write verification used shift
     `teaching_shifts/4TpVsguSUkUHg3jLPbt0`, created
     `form_responses/QnljDd4wQIIYdLWsKEDm`, and confirmed both the shift and
     `timesheet_entries/DKTQZJeXPe54zQJpSteh` were linked with completed form
     metadata.
   - Important video correction: Flutter dev/prod use the same source code and
     select Firebase by `FIREBASE_ENV`; the current Flutter class-video path is
     Cloudflare RealtimeKit, not LiveKit. Next teacher classroom now calls
     `getRealtimeKitJoinToken` and hosts `/realtimekit_meeting.html` in a
     full-page iframe, matching Flutter web's RealtimeKit host page. Guest copy
     links use `getRealtimeKitGuestJoin`.
   - Native Teacher Classes/Classroom deeper pass now matches Flutter visible
     join semantics more closely: class cards say `Join Class`, future classes
     use `Join (Xm)` style waiting copy, classroom route fetches the
     `teaching_shifts` record first to show the real class name and block
     too-early/ended joins before requesting a token, and dev RealtimeKit
     failures show a clear configuration message instead of raw `internal`.
   - Dev video QA blocker resolved: `alluwal-dev` now has the required
     RealtimeKit Secret Manager entries and the current RealtimeKit function
     exports deployed. Real teacher and guest token issuance was verified
     against `alluwal-dev`, and a two-party fake-media RealtimeKit UI smoke test
     rendered successfully. Do not fall back to LiveKit for the migration.
   - 2026-06-22 production/dev credential check for video: both projects have
     the required Secret Manager entries `CLOUDFLARE_ACCOUNT_ID`,
     `CLOUDFLARE_REALTIME_API_TOKEN`, and `REALTIMEKIT_APP_ID`; a redacted
     equality check confirmed the dev values currently match production values.
     The active RealtimeKit functions bind those secrets in both projects. Do
     not print or paste the secret payloads. Dev function hashes differ from
     prod because dev has the newer migration build; do not deploy prod unless
     explicitly instructed.
   - Remaining teacher functionality still needs deeper passes around
     Cloudflare classroom session controls, teacher session actions, and any
     form-fill edge cases beyond the first native sheet.

   - Teacher Dashboard Home desktop/mobile parity screenshots are under
     `output/playwright/teacher-home-parity/`.
   - Teacher Dashboard Trading quick-action screenshots are under
     `apps/web/output/playwright/teacher-dashboard-trading-link/`, including
     desktop/mobile dashboard and native Job Board results.
   - Teacher mobile menu screenshots are under
     `apps/web/output/playwright/teacher-mobile-menu/`, including mobile
     dashboard before, mobile drawer open, mobile Time Clock after drawer
     navigation, desktop sidebar sanity, and dev enrollment success.
   - Teacher My Shifts visual parity screenshots are under
     `output/playwright/teacher-shifts-parity/`; functional Flutter/Next
     screenshots are under `output/playwright/teacher-shifts-functionality/`.
  - Teacher Time Clock desktop/mobile parity screenshots are under
    `output/playwright/teacher-time-clock-parity/`.
    The latest Time Clock pass includes `next-desktop-after.png`,
    `next-mobile-after.png`, Flutter public/bridge probes, and
     `dev-enrollment-success.png`. The packaged Flutter root currently boots
     the public landing page and the packaged `/app` bridge page, so the Time
     Clock baseline for this pass was cross-checked against the Flutter source:
    `lib/features/time_clock/screens/time_clock_screen.dart`,
    `lib/features/time_clock/widgets/timesheet_table.dart`, and
    `lib/features/time_clock/widgets/mobile_timesheet_view.dart`.
  - Teacher Time Clock action/detail screenshots are under
    `output/playwright/teacher-time-clock-actions/`. This includes Next
    before/after desktop/mobile screenshots, View details, Edit, Submit
    confirmation dialogs, and the dev enrollment success artifact. The pass
    used dev-only timesheet fixtures
    `timesheet_entries/codex_teacher_timeclock_edit_draft` and
    `timesheet_entries/codex_teacher_timeclock_view_pending` for
    `codex.cms.staff@alluwal-dev.test / 111111`; the draft fixture was edited
    through the Next UI and remained `draft`.
   - Teacher Tasks desktop/mobile parity screenshots are under
     `output/playwright/teacher-tasks-parity/`.
   - Teacher Job Board desktop/mobile parity screenshots are under
     `output/playwright/teacher-job-board-parity/`.
   - Teacher Chat desktop/mobile parity screenshots are under
     `output/playwright/teacher-chat-parity/`.
   - Teacher Chat send/action screenshots are under
     `apps/web/output/playwright/teacher-chat-send/`, including desktop/mobile
     Admin Support conversation panels and the dev enrollment success artifact.
   - Teacher Classes desktop/mobile parity screenshots are under
     `output/playwright/teacher-classes-parity/`.
   - Teacher Classes/Classroom functionality screenshots are under
     `output/playwright/teacher-classroom-functionality/`, including current
     desktop/mobile class cards, classroom join-attempt error screens, and the
     dev enrollment success artifact.
   - Teacher Classes current-baseline correction screenshots are under
     `output/playwright/teacher-classroom-session-controls/`. This includes
     Flutter desktop/mobile Classes baselines, Next before/after Classes
     screenshots, Next Classroom RealtimeKit screenshots, and the dev enrollment
     success artifact. The pass used the dev-only current class
     `teaching_shifts/codex_teacher_classroom_session_current` for
     `codex.cms.staff@alluwal-dev.test / 111111`; it was extended for manual
     testing until 2026-06-22 20:11 UTC / 4:11 PM Eastern.
   - Teacher Classes presence/details screenshots are under
     `output/playwright/teacher-classes-presence/`. This includes Next
     desktop/mobile class-card presence screenshots, desktop/mobile details
     dialog screenshots, Flutter route probes from the currently served 3032
     baseline, a RealtimeKit classroom join-smoke screenshot, and dev enrollment
     success. The pass used dev-only class
     `teaching_shifts/codex_teacher_classroom_presence_current` for
     `codex.cms.staff@alluwal-dev.test / 111111`; the class card now exposes
     Flutter-style `Live participants`, participant count/list, and a native
     details dialog that refreshes presence on open.
   - Teacher guest class-link screenshots are under
     `apps/web/output/playwright/teacher-guest-join-link/`. This includes the
     Next teacher copy-link evidence, desktop/mobile public guest join screens,
     and a dev enrollment confirmation. The pass used
     `teaching_shifts/codex_teacher_classroom_presence_current`, verified the
     copied teacher link was
     `/classroom/join/?guestShift=codex_teacher_classroom_presence_current`,
     verified root `/?guestShift=...` links redirect to the public join route,
     and verified real dev guest joining reached `Connected` with RealtimeKit.
   - Teacher Recordings desktop/mobile parity screenshots are under
     `output/playwright/teacher-recordings-parity/`.
   - Teacher Surah Podcasts desktop/mobile parity screenshots are under
     `output/playwright/teacher-surah-podcasts-parity/`.
   - Teacher Curriculum Books desktop/mobile parity screenshots are under
     `output/playwright/teacher-curriculum-books-parity/`.
   - Teacher Submit Form desktop/mobile parity screenshots are under
     `output/playwright/teacher-submit-form-parity/`.
   - Teacher Submit Form deeper functionality screenshots from the native page,
     shift picker, and dev enrollment success are under
     `output/playwright/teacher-submit-form-functionality/`.
   - Teacher Submit Form time-field screenshots are under
     `output/playwright/teacher-submit-form-time-field/`. This includes Next
     before/after desktop/mobile screenshots, Flutter root/app probes, filled
     form and success screenshots, and dev enrollment success. The pass used
     dev-only form template `form_templates/codex_teacher_time_field_qa` and
     created `form_responses/BBzYlHQFWtd9VQkoA7zH` with
     `class_start_time: "16:30"`.
   - Teacher Submit Form upload/signature screenshots are under
     `apps/web/output/playwright/teacher-submit-form-upload-field/`. This
     includes desktop empty/selected/success screenshots, mobile empty
     screenshot, and a real dev enrollment confirmation screenshot. The pass
     used dev-only form template `form_templates/codex_teacher_upload_field_qa`
     with required `image_upload` and `signature` fields, and created
     `form_responses/TNciBrTJaORGr5iPghEk` for
     `codex.cms.staff@alluwal-dev.test / 111111`; the response contains
     `session_photo` and `teacher_signature` metadata with download URLs and
     `form_images/uZyvgk7VBeRrhsZfYAzGfOSRCJo2/...` storage paths.
   - Teacher Submit Form upload validation screenshots are under
     `apps/web/output/playwright/teacher-submit-form-upload-validation/`. This
     includes desktop/mobile invalid image-file evidence and a real dev
     enrollment confirmation screenshot.
   - Teacher My Form Submissions parity screenshots are under
     `output/playwright/teacher-form-submissions-parity/`.
   - Teacher My Form Submissions response-label screenshots are under
     `apps/web/output/playwright/teacher-form-label-hydration/`. This pass used
     dev-only response
     `form_responses/codex_teacher_label_hydration_1782150126117` for
     `form_templates/codex_teacher_time_field_qa`, proving the detail sheet
     renders `What time should the makeup class start?` instead of the raw
     `class_start_time`/`Class Start Time` fallback.
   - Use `codex.cms.staff@alluwal-dev.test / 111111` for authenticated teacher
     baselines and Next verification.
   - For each teacher-facing module, capture Flutter desktop/mobile from
     `http://127.0.0.1:3032/` through the teacher login, capture Next
     desktop/mobile from the native route, patch only user-visible differences,
     and keep non-migrated actions bridged to `/app/#/login`.
   - Re-run the guarded authenticated teacher verification when teacher routing
     or dashboard behavior changes:
     `ALLUWAL_RUN_TEACHER_E2E=1 ALLUWAL_TEACHER_E2E_EMAIL=...
     ALLUWAL_TEACHER_E2E_PASSWORD=... npx playwright test
     tests/teacher-dashboard.spec.ts --project=chromium`
   - This pass added one login retry in the teacher E2E helper for transient
     Firebase Auth "Network connection failed" responses, and added a
     non-mutating My Shifts assertion that a Day timeline clock action button
     is visible.
   - 2026-06-22 verification after the RealtimeKit/My Shifts correction:
     `npm run typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`,
     `cd functions && npm test`, focused teacher E2E with
     `codex.cms.staff@alluwal-dev.test / 111111` (24 passed), full web E2E
     (133 passed, 155 skipped), `npm run package:hostinger`, and
     `git diff --check`.
   - 2026-06-22 verification after the deeper Teacher Submit Form pass:
     `npm run typecheck`, focused teacher E2E with
     `codex.cms.staff@alluwal-dev.test / 111111` (24 passed),
     `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`, `npm run
     package:hostinger`, full web E2E (133 passed, 155 skipped), and
     `git diff --check`. Real dev enrollment submitted through `/enroll/`:
     `Codex Teacher Submit Deep Student 20260622145609`
     (`codex.teacher.submit.deep.20260622145609@example.com`).
   - 2026-06-22 verification after the Teacher Time Clock correction:
     `npm run typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`,
     focused teacher E2E with `codex.cms.staff@alluwal-dev.test / 111111`
     (24 passed), `npm run package:hostinger`, full web E2E (133 passed,
     155 skipped), and `git diff --check`. Real dev enrollment submitted
     through `/enroll/`: `Codex Time Clock Student 20260622151241`
     (`codex.time.clock.20260622151241@example.com`).
   - 2026-06-22 verification after the Teacher Classes/Classroom correction:
     `npm run typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`,
     focused teacher E2E with `codex.cms.staff@alluwal-dev.test / 111111`
     (24 passed), `npm run package:hostinger`, full web E2E (133 passed,
     155 skipped), and `git diff --check`. Real dev enrollment submitted
     through `/enroll/`: `Codex Classroom Student 20260622152133`
     (`codex.classroom.20260622152133@example.com`). Initial real dev class join
     could not complete until RealtimeKit functions/secrets were configured in
     `alluwal-dev`; the UI reports that blocker clearly when a project is
     missing the backend setup.
   - 2026-06-22 RealtimeKit dev backend reconciliation: copied the three
     required Secret Manager entries by name into `alluwal-dev` without
     printing secret payloads, deployed the current RealtimeKit function exports
     to dev (`getRealtimeKitJoinToken`, `getRealtimeKitGuestJoin`,
     `getRealtimeKitRoomPresence`, `setRealtimeKitRecordingEnabled`,
     `bulkSetRealtimeKitRecordingEnabled`, `kickRealtimeKitParticipant`,
     `setRealtimeKitRoomLock`), and verified real dev teacher/guest token
     issuance against temporary shift `rb66TBQsjSyGIKDQLsqT` (extended for
     manual testing until 2026-06-22 21:36 UTC / 5:36 PM Eastern). Screenshots
     of the connected teacher classroom shell are under
     `output/playwright/teacher-classroom-functionality/` as
     `next-desktop-classroom-realtimekit-ready.png` and
     `next-mobile-classroom-realtimekit-ready.png`. A two-party fake-media
     RealtimeKit UI smoke test also rendered teacher/guest tiles in
     `realtimekit-two-party-teacher.png` and `realtimekit-two-party-guest.png`.
     Focused teacher E2E with `codex.cms.staff@alluwal-dev.test / 111111`
     passed again (24 passed).
   - 2026-06-22 verification after the Teacher Submit Form native Timesheet/
     Details correction: `npm run typecheck`,
     `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`, focused teacher E2E with
     `codex.cms.staff@alluwal-dev.test / 111111` (24 passed), full web E2E
     (146 passed, 142 skipped), `npm run package:hostinger`, and
     `git diff --check`. Real dev enrollment submitted through `/enroll/`:
     `Codex Submit Native Student 20260622155222`
     (`codex.submit.native.20260622155222@example.com`).
   - 2026-06-22 verification after the Teacher Classes current-baseline
     correction: `npm run typecheck`,
     `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`, focused teacher E2E with
     `codex.cms.staff@alluwal-dev.test / 111111` (24 passed), full web E2E
     (146 passed, 142 skipped), `npm run package:hostinger`, and
     `git diff --check`. Real dev enrollment submitted through `/enroll/`:
     `Codex Classes Student 20260622161007`
     (`codex.classes.parent.20260622161007@alluwal-dev.test`).
   - 2026-06-22 verification after the Teacher Time Clock action/detail pass:
     `npm run typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`,
     focused teacher E2E with `codex.cms.staff@alluwal-dev.test / 111111`
     (24 passed), full web E2E (146 passed, 142 skipped), `npm run
     package:hostinger`, and `git diff --check`. Real dev enrollment submitted
     through `/enroll/` and confirmed in `alluwal-dev` as
     `enrollments/ZmZMhi3lNJyTeB7mq55r`
     (`codex.teacher.timeclock.actions.parent.20260622162954@alluwal-dev.test`).
   - 2026-06-22 verification after the Teacher Submit Form time-field pass:
     `npm run typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`,
     focused teacher E2E with `codex.cms.staff@alluwal-dev.test / 111111`
     (24 passed), full web E2E (146 passed, 142 skipped), `npm run
     package:hostinger`, and `git diff --check`. Real dev form response
     submitted through `/teacher/submit-form/` and confirmed in `alluwal-dev` as
     `form_responses/BBzYlHQFWtd9VQkoA7zH` with
     `class_start_time: "16:30"`. Real dev enrollment submitted through
     `/enroll/` and confirmed in `alluwal-dev` as
     `enrollments/wS5o09e28Q8j4xMhznfc`
     (`codex.teacher.timefield.parent.20260622164535@alluwal-dev.test`).
   - 2026-06-22 verification after the Teacher Classes presence/details pass:
     `npm run typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`,
     focused teacher E2E with `codex.cms.staff@alluwal-dev.test / 111111`
     (24 passed), full web E2E (146 passed, 142 skipped), RealtimeKit classroom
     join smoke against `teaching_shifts/codex_teacher_classroom_presence_current`
     (`classroom connected`), `npm run package:hostinger`, and `git diff
     --check`. Real dev enrollment submitted through `/enroll/` and confirmed
     in `alluwal-dev` as `enrollments/lBtfCnvI32VHb804MpVg`
     (`codex.teacher.classes.presence.parent.20260622170715@alluwal-dev.test`).
   - 2026-06-22 verification after the Teacher Submit Form upload/signature
     pass: `npm run typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`,
     real browser upload smoke against `form_templates/codex_teacher_upload_field_qa`
     with Firestore/Storage confirmation, focused teacher E2E with
     `codex.cms.staff@alluwal-dev.test / 111111` (24 passed), full web E2E
     (133 passed, 155 skipped; authenticated tests skipped by default env),
     `npm run package:hostinger`, and `git diff --check`. Real dev form
     response submitted through `/teacher/submit-form/` and confirmed in
     `alluwal-dev` as `form_responses/TNciBrTJaORGr5iPghEk`. Real dev
     enrollment submitted through `/enroll/` and confirmed as
     `enrollments/YqTrLcD7X9AcKmWGxEjR`
     (`codex.teacher.upload.parent.20260622171950@alluwal-dev.test`).
   - 2026-06-22 verification after the Teacher guest class-link pass:
     `npm run typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`,
     direct browser smoke for teacher copy link, root guest redirect, and
     public guest RealtimeKit join against
     `teaching_shifts/codex_teacher_classroom_presence_current`, focused public
     route E2E (12 passed, 1 skipped), focused teacher E2E with
     `codex.cms.staff@alluwal-dev.test / 111111` (24 passed), full web E2E
     (136 passed, 155 skipped), `npm run package:hostinger`, and
     `git diff --check`. Real dev enrollment submitted through `/enroll/` and
     confirmed as `enrollments/VW0ixQNfG6rFHIN6dLEr`
     (`codex.guest.join.parent.20260622173040@alluwal-dev.test`).
   - 2026-06-22 verification after the Teacher My Form Submissions response
     label pass: `npm run typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run
     build`, focused teacher E2E with
     `codex.cms.staff@alluwal-dev.test / 111111` (24 passed), focused public
     route E2E (12 passed, 1 skipped), full web E2E (149 passed, 142 skipped),
     and `npm run package:hostinger`. Real dev enrollment submitted through
     `/enroll/` and confirmed as `enrollments/orIG3ToJVYPiM4g2Y7k7`
     (`codex.teacher.labels.parent.20260622174704@alluwal-dev.test`).
   - 2026-06-22 verification after the Teacher Job Board withdraw/re-broadcast
     pass: `npm run typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`,
     real browser withdraw smoke against
     `job_board/codex_teacher_job_board_withdraw_smoke_1782155045766` with
     Firestore confirmation (`status: open`, `acceptedByTeacherId: null`),
     focused teacher E2E with `codex.cms.staff@alluwal-dev.test / 111111`
     (25 passed), and `npm run package:hostinger`. Screenshots are under
     `apps/web/output/playwright/teacher-job-board-withdraw/`: desktop fixture,
     mobile fixture, withdraw dialog, withdraw success, and dev enrollment
     success. Real dev enrollment submitted through `/enroll/` and confirmed as
     `enrollments/oOClVUbMnC0dcx8mJ9kV`
     (`codex.teacher.jobboard.parent.20260622192101@alluwal-dev.test`).
   - 2026-06-22 verification after the Teacher Chat conversation/send pass:
     `npm run typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`,
     focused teacher E2E with `codex.cms.staff@alluwal-dev.test / 111111`
     (26 passed), full web E2E (136 passed, 161 skipped), and
     `npm run package:hostinger`. Real browser chat smoke sent
     `Codex chat smoke 1782156854254` through Admin Support and dev Firestore
     confirmed `chats/admin_support_uZyvgk7VBeRrhsZfYAzGfOSRCJo2` has
     participants `[uZyvgk7VBeRrhsZfYAzGfOSRCJo2, admin_support]`,
     `chat_type: admin_support`, matching `last_message.content`, and latest
     `messages` subdocument `message_type: text`. Real dev enrollment submitted
     through `/enroll/` and confirmed as `enrollments/dhmbjDq74EkKamyGoM6r`
     (`codex.teacher.chat.parent.20260622193733@alluwal-dev.test`).
   - 2026-06-22 verification after the Teacher Dashboard Trading quick-action
     bridge removal: `npm run typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm
     run build`, focused teacher E2E with
     `codex.cms.staff@alluwal-dev.test / 111111` (27 passed), full web E2E
     (136 passed, 164 skipped), `npm run package:hostinger`, and
     `git diff --check`. Search confirmed no remaining teacher `/app` bridge
     links except the non-bridge guest-link origin builder. Real dev enrollment
     submitted through `/enroll/` and confirmed as
     `enrollments/6tfz8s9LDHSsjdu7ig0i`
     (`codex.teacher.trading.parent.20260622194526@alluwal-dev.test`).
   - 2026-06-22 verification after the Teacher Submit Form upload-validation
     pass: `npm run typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`,
     no remaining `window.alert`/`alert()` calls in teacher Next routes/
     components, focused teacher E2E with
     `codex.cms.staff@alluwal-dev.test / 111111` (27 passed), full web E2E
     (136 passed, 164 skipped), `npm run package:hostinger`, and
     `git diff --check`. Desktop/mobile screenshots confirm selecting a
     non-image for `Session photo` shows `Please choose an image file.` inline
     with no browser alert. Real dev enrollment submitted through `/enroll/`
     and confirmed as `enrollments/NHPEkZLrQZDdjVud6NUe`
     (`codex.teacher.upload.validation.parent.20260622195254@alluwal-dev.test`).
   - 2026-06-22 verification after the Teacher mobile menu pass: `npm run
     typecheck`, `NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build`, focused
     teacher E2E with `codex.cms.staff@alluwal-dev.test / 111111` on Chromium
     and mobile Chrome (41 passed, 15 skipped), full web E2E (136 passed,
     167 skipped), `npm run package:hostinger`, and `git diff --check`.
     Screenshots confirm the mobile dashboard menu opens native teacher
     navigation and can route to Time Clock. Real dev enrollment submitted
     through `/enroll/` and confirmed as `enrollments/ftuumw96Wh4brwQy00Pq`
     (`codex.teacher.mobile.menu.parent.20260622200405@alluwal-dev.test`).
   - Match the currently running Flutter baseline, not old assumptions.

5. After each teacher-facing module patch:

   ```bash
   cd apps/web
   npm run typecheck
   NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build
   PLAYWRIGHT_BASE_URL=http://127.0.0.1:3021 npm run test:e2e
   npm run package:hostinger
   git diff --check
   ```

## Teacher parity continuation (2026-07-11)

- Opened coordination issue #25 and created
  `docs/teacher-next-parity-matrix.md` as the finite acceptance tracker.
- Corrected native Teacher Classroom provider selection. Zoom-backed shifts now
  call `getZoomJoinInfo` and open the same `zoom_meeting.html` host and routing
  payload used by Flutter; non-Zoom shifts continue through RealtimeKit.
- Added a Next-owned RealtimeKit teacher session layer with live roster,
  lock/unlock, participant removal, and token-based reconnect controls.
- Updated Next asset preparation to package the canonical Zoom classroom host.
- Verification completed: Next typecheck, production-style static build, and
  focused Chromium/WebKit/mobile public classroom-host tests, RealtimeKit
  Functions Jest (32 passed), Hostinger packaging, and the authenticated teacher
  Chromium suite (25 passed, 2 intentionally skipped, 2 stale-fixture failures
  corrected and re-run successfully). No Firebase or production deploy was
  performed. Authenticated two-party dev verification remains before this
  classroom slice is ready to merge.

## Teacher transactional parity continuation (2026-07-11)

- Kept Flutter/Dart and the production `alluwal-academy` Firebase project
  untouched. Flutter source was read only as the behavioral/data reference.
- Added assigned-teacher task status actions in Next for To Do, In Progress,
  and Done. A narrowly validated `updateAssignedTaskStatus` callable enforces
  assignment ownership and writes Flutter-compatible status/completion fields.
  The callable and disposable fixture were deployed only to `alluwal-dev`.
- Added the task details/status sheet on desktop and responsive mobile. A real
  dev browser write moved the disposable task to In Progress; Firestore
  verification confirmed the status/updater fields, then removed the fixture.
- Completed the clock metadata compatibility pass in both native My Shifts and
  Time Clock: category/leader role, pay-rate source, subject billability,
  clock-in/out status, deviation minutes, and clock-out-note requirement flags
  now match Flutter fields. A real dev browser clock-in/out passed and the
  resulting timesheet fields were verified before cleanup.
- Corrected Job Board withdrawal resets to satisfy the deployed ownership rules
  while clearing auxiliary accepted/match fields like Flutter. A real dev
  accepted-job withdrawal passed, the re-broadcast job/enrollment shapes were
  verified, and all disposable records/notifications were removed.
- Verification: Next typecheck and production-style build passed; task callable
  Jest passed (3 tests); guarded task, clock, and Job Board write E2E passed.
  No production function, rule, data, Hosting, Flutter, or VPS change occurred.

## Teacher forms and chat parity continuation (2026-07-11)

- Kept Flutter/Dart and production Firebase untouched; Flutter form/chat source
  was used read-only to enumerate supported behavior and field/message shapes.
- Submit Form now applies Flutter-equivalent email and phone validation and
  exposes accessible labels for text, select, radio, checkbox, boolean, and
  multi-select controls. A disposable dev template verified both validation
  messages through the browser and was removed afterward.
- My Form Submissions now renders uploaded image/signature responses as previews
  and accessible file links instead of raw JSON. A disposable response/template
  verified the detail flow and was removed afterward.
- Chat now computes unread counts from unread incoming message documents, marks
  them read when opening a conversation, and records `last_read_by`. A dev
  fixture verified both fields in Firestore before cleanup.
- Chat now supports browser image, video, file, audio, and recorded voice
  messages using the same Storage folders and message metadata as Flutter.
  Non-text messages render native image/video/audio/file controls. A real dev
  image upload/send/render flow passed; its message and Storage object were
  verified and removed, and the prior chat preview was restored.
- Verification: Next typecheck and repeated production-style static builds
  passed; guarded form validation, unread receipt, image attachment, and saved
  upload rendering E2E passed. No function/rule deployment or production change
  occurred in this slice.

### Teacher content and shell cutover (2026-07-11)

- Recordings now reports a retryable in-app error when the browser cannot play
  a selected recording instead of leaving a silent failed player.
- The teacher shell now persists sidebar favorites and collapsed state, offers
  Reset Layout, exposes an authenticated account menu, supports the existing
  Admin role switch when the user record allows it, and signs out to `/login/`
  from desktop and mobile controls.
- The Surah share workflow was exercised end-to-end in `alluwal-dev` with
  disposable podcast, teaching-shift, student, and assignment data. Share,
  persisted Shared-tab visibility, and removal passed; the assignment and both
  source fixtures were deleted after verification.
- All eight production curriculum PDF/PPTX targets were checked read-only and
  returned HTTP 200. Production Firestore, Functions, rules, and Hosting were
  not changed. No Flutter source was changed.
- Focused Chromium checks passed for account-menu role/logout controls, actual
  logout, sidebar persistence/reset, and Surah share/remove. The full teacher
  matrix passed on desktop Chromium, mobile Chrome, and WebKit (44 passed, 52
  intentionally skipped); the fixture-dependent write smoke passed separately.
  Typecheck, the production-style Next build, Hostinger packaging, and
  `git diff --check` passed.

### Teacher final integration gate (2026-07-12)

- Combined the classroom, transactional, forms/chat, and content/shell slices
  on `feature/teacher-final-cutover` without changing Flutter source or any
  production Firebase resource.
- Integrated teacher coverage passed across Chromium, mobile Chrome, and
  WebKit (47 passed, 73 intentionally skipped). RealtimeKit configuration,
  classroom access, and task status tests passed (39 tests).
- A repository-wide run exposed a mobile enrollment test whose Continue button
  was covered by the dismissible Quran player and one isolated WebKit
  navigation hang. The test now dismisses the player through its public control;
  both failed cases passed when rerun in isolation. The clean rerun completed
  144 tests with 203 intentional skips; its sole failure was a different WebKit
  static-page navigation hang on `/team/`, which passed immediately in
  isolation after switching the test to committed-document navigation. A final
  sequential WebKit-only run reached 40 passes before the same non-deterministic
  navigation hang moved to `/teacher/`; both routes pass in focused runs.
- Next typecheck, production-style build, Hostinger packaging, and
  `git diff --check` passed. No site, rule, Function, or Firebase deployment was
  performed from the integration branch.

### Teacher live classroom controls acceptance (2026-07-12)

- A disposable `alluwal-dev` RealtimeKit shift was used for a real headed,
  two-tab teacher/guest session. Both participants joined the same room; the
  Next roster showed both active peers, locking blocked a new guest with the
  expected message, removal disconnected the existing guest, unlocking worked,
  and the teacher reconnected successfully. The shift fixture was deleted.
- The live run found and fixed two defects. The Next RealtimeKit host now falls
  back to an audio/video-off initialization when normal media initialization
  stalls, so a missing/denied device does not leave the class on an infinite
  connecting screen. The parent message listener is installed before the iframe
  can report readiness.
- The participant-removal callable now uses Cloudflare participant UUIDs for
  meetings configured with `idType: userId`. Presence now reads the active
  session roster instead of all provisioned meeting participants, so removed or
  departed users no longer remain in the connected count.
- `kickRealtimeKitParticipant` and `getRealtimeKitRoomPresence` were deployed
  only to `alluwal-dev`. No production Firebase, Hostinger, VPS, Zoom routing,
  meeting lifetime, or Flutter change was made.

### Teacher clock resilience acceptance (2026-07-12)

- Flutter clock behavior was inspected read-only and confirmed to require a
  location for clock-in and clock-out. Native My Shifts and Time Clock now show
  an actionable location-access error for either action instead of writing a
  zero-coordinate clock-out.
- Clock-in and clock-out writes now use Firestore transactions against the
  shift and timesheet entry. Concurrent browser tabs cannot create duplicate
  entries or close the same entry twice, and refreshed pages recover the active
  clock state from Firestore.
- Guarded Chromium resilience tests passed for both native routes with two
  authenticated tabs and reloads. The My Shifts run produced exactly one
  Flutter-compatible `timesheet_entries` document containing scheduled times,
  clock timestamps, status/deviation, web platform, pay, and real clock-in/out
  coordinates. The disposable entry and shift were deleted afterward.
- Next typecheck and the production-style build passed for this implementation
  checkpoint. Flutter/Dart and production Firebase remained untouched.
- Single and bulk draft submission now verify `status: draft` inside a
  transaction before changing an entry to pending. The confirmation action is
  disabled while submitting, and offline/network and permission failures show
  actionable in-app messages while keeping the draft available to retry.
- A second guarded two-tab dev run confirmed that an offline draft remained a
  draft without `submitted_at`, while concurrent submission of another draft
  produced one pending transition and one visible already-submitted result.
  Both disposable drafts were deleted after Firestore verification.

### Teacher task lifecycle acceptance (2026-07-12)

- Flutter task loading was inspected read-only and confirmed that non-admin
  teachers load tasks assigned to them. Next no longer mixes creator-owned
  tasks into the teacher list, because those records are not teacher-actionable
  under the assigned-task callable contract.
- A failed task query now renders a retryable error instead of the misleading
  `No Tasks Found` state. Stale task and revoked-assignment callable failures
  remain inside the details dialog with actionable wording.
- A disposable assigned task completed the real dev `todo` → `inProgress` →
  `done` lifecycle through the browser. Firestore verification confirmed
  `TaskStatus.done`, the teacher `updatedBy`, `completedAt`, and
  `overdueDaysAtCompletion`. Guarded mocked-callable browser checks covered
  not-found and permission-denied responses. The task was deleted afterward.
- No Flutter source, production Firebase resource, rule, or Function was
  changed or deployed.

### Teacher Job Board resilience acceptance (2026-07-12)

- Flutter Job Board source was inspected read-only. Next now applies the same
  `targetTeacherIds` visibility rule, so teachers do not see broadcasts aimed
  only at other teachers.
- Availability response and withdrawal actions now fail immediately with a
  retryable offline message and translate Firestore permission failures into an
  actionable in-app error rather than exposing the raw SDK response.
- A guarded two-tab dev test submitted full availability concurrently against
  one disposable open job. Transaction retries produced one response document,
  one `available` count, and the expected `closed` /
  `teacher_fully_available` parent state; the losing tab showed an explicit
  failure. A second targeted job was confirmed hidden. Both jobs and the
  response were deleted after verification.
- Previously verified withdraw/rebroadcast behavior remains covered by its
  guarded mutation test. No Flutter or production Firebase change occurred.

### Teacher Chat live-state acceptance (2026-07-12)

- Recent conversations now stay subscribed to parent chat changes and re-sort
  by the latest message while the page remains open. Revision guards prevent a
  slower unread-count refresh from replacing newer list data.
- Opening a conversation pushes an in-page history entry. The visible Back
  control and mobile browser Back now return to the Chat list at
  `/teacher/chat/` instead of navigating away from the module.
- Offline text sends fail immediately, keep the unsent draft in the composer,
  and show a retryable error. Existing unread-message clearing,
  `last_read_by`, conversation repair, and media attachment coverage remain in
  place.
- Focused Chromium checks passed for offline draft recovery and live preview
  promotion; mobile Chrome passed browser-back conversation navigation. The
  preview server at `http://localhost:3021/teacher/` was rebuilt with this
  checkpoint for owner testing. Flutter and production Firebase were untouched.

### Teacher Recordings failure-state acceptance (2026-07-12)

- Callable-backed fixture tests exercised the complete student → date → shift
  → fragment navigation without creating or changing Firebase data.
- A successful playback response with no URL now has explicit coverage for the
  `Playback URL not available` state. A returned URL whose media request fails
  has focused coverage for the retryable in-app playback error.
- Both guarded Chromium scenarios passed. Existing loading, empty, search,
  refresh, unavailable-fragment, and responsive hierarchy behavior remains in
  the teacher regression suite. No Flutter or Firebase resource changed.

### Teacher Surah sharing resilience acceptance (2026-07-12)

- Share and remove now reject offline actions immediately and preserve the
  selected students or existing shared assignment for retry. Firestore
  permission errors are translated into an actionable message.
- The share action remains disabled for an empty selection. The mobile dialog
  now presents as a viewport-contained bottom sheet while retaining the
  centered desktop dialog.
- Guarded Chromium and mobile Chrome tests passed against disposable podcast,
  shift/student, and active-assignment fixtures. Offline remove, empty
  selection, offline share, retained selection, and viewport bounds all passed;
  all three fixtures were deleted afterward.

### Teacher Curriculum Books target acceptance (2026-07-12)

- All four PDF and four PPTX targets were checked read-only with HEAD requests;
  every file returned success with a non-zero content length.
- Focused Chromium coverage verifies the complete eight-link set, PDF `Open`
  destination/fit fragment, PPTX `Download` destination, and new-tab behavior.
  PDF viewer rendering is browser-owned, so acceptance uses the authoritative
  target response rather than waiting for a browser PDF DOM event.
- No application code, Flutter source, Storage object, or production resource
  was changed for this pass.

### Teacher shell separation and form resilience (2026-07-12)

- Following owner review, the desktop teacher shell now has two structurally
  separate viewport columns: a fixed-height sidebar with its own navigation
  scroll, and an independently scrolling header/content column. A focused
  browser test confirms non-overlap, stationary sidebar position, and zero
  window-level scroll while page content moves. The live preview on port 3021
  was rebuilt for review.
- The current `alluwal-dev` form inventory contains `time`, `long_text`,
  `email`, `phone`, `image_upload`, and `signature`; all six types have native
  rendering/validation or upload coverage. No speculative field type was added.
- Per-session submissions now use a deterministic response ID and create-only
  Firestore behavior. A real two-tab dev run produced exactly one compatible
  completed response, linked the shift to that ID, and showed the losing tab an
  already-submitted message. The response, shift, and template were deleted.
- Failed submissions preserve entered values. Uploaded form files are deleted
  if a later upload or Firestore response write fails, preventing orphaned
  Storage objects. A focused offline browser test confirmed values remain ready
  to retry.
- `My Form Submissions` is now a first-class Forms sidebar item and the route is
  wrapped in the same separated TeacherShell instead of rendering as a
  standalone page. Read failures display a retry action without misclassifying
  the signed-in teacher as role-denied.
- Disposable responses verified a deleted/missing template falls back to
  readable field labels and values, while a legacy response with no response
  fields shows `No responses recorded`. Both fixtures were removed afterward.

### Teacher dashboard partial-data resilience (2026-07-12)

- Dashboard shift, task, and timesheet reads now settle independently. A failed
  section can no longer silently masquerade as a real zero; successful sections
  still render and a warning names each incomplete metric source with Retry.
- Metric-read failures are handled after teacher authorization, so they no
  longer turn an authenticated teacher into a misleading role-denied screen.
- Existing authenticated coverage verifies account-menu logout, conditional
  Admin role destination when present, sidebar persistence/reset, the separated
  scroll columns, mobile drawer navigation, quick actions, and metric rendering.
- Flutter's pending-readiness workflow is now native on the Next dashboard.
  Completed and missed shifts without a compatible `form_responses` shift link
  produce the warning banner and responsive class picker. `Fill Form` carries
  the shift into `/teacher/submit-form/`, which opens the active per-session
  template and selected class directly; successful submission removes it from
  the pending list after reload.
- Real desktop and mobile Chrome runs completed and removed a disposable shift
  plus one response each. During the audit the former 100-shift single-field
  dashboard limit was also corrected to merge both Flutter teacher-id field
  variants with a 500-row ceiling, preventing older valid sessions from being
  silently omitted. Active-session parity is the next dashboard checkpoint.
- The active/imminent dashboard card now follows Flutter's one-minute join
  window, distinguishes Ready from In Progress, displays elapsed time, opens the
  exact shift detail, and performs GPS-required clock-in/out directly from the
  dashboard. Its transaction fields match the native Time Clock workflow,
  including duplicate protection, scheduled bounds, deviation metadata,
  platform/GPS fields, completion method, hours, and pay.
- A disposable live-window dev shift verified location denial followed by a
  successful clock-in/out lifecycle. Readback confirmed both shift timestamps,
  one `shift_clock_in` timesheet, web/GPS metadata, and manual completion; the
  shift and timesheet were deleted. The Dashboard row now has no known gap.
- Flutter's home-only Islamic Resources card was absent from the earlier matrix.
  Next now includes the native Surah Podcasts destination plus the exact
  Quran.com, Sunnah.com, Islamic Finder, IslamQA, Bayyinah, and SeekersGuidance
  external resources. External destinations are labelled links that open in a
  separate tab with safe opener isolation. Desktop and mobile Chrome verified
  every href and target.
- Flutter also renders up to three recent assigned tasks between Schedule and
  Quick Access. Next now uses the already-loaded task records for the same
  section, including status color, due/overdue state, See All, and exact-task
  deep links. The Tasks route consumes `?task=` and opens the requested detail
  dialog after authorization/load. A disposable dev task verified the complete
  dashboard-to-detail path and was deleted.
- The Next Class card itself now carries the shift ID into My Shifts and opens
  the exact detail dialog, matching Flutter's tappable upcoming-class card
  rather than presenting a dead informational surface.
- The My Shifts detail dialog now restores Flutter's contextual actions: a
  10-minute-before/after-window Join Class link into the existing Classroom
  provider flow, Fill Class Report for completed/missed shifts without a linked
  response, View Class Report for linked responses, and the existing Report
  Issue flow. Disposable live and completed shifts verified join/report hrefs
  and were deleted.
- The formerly inert desktop bell is now a labelled link to My Report and shows
  the real unread `audit_notifications` count. Opening My Report attempts the
  same teacher-owned read acknowledgement as Flutter. A disposable notification
  verified count and navigation; deployed dev rules rejected the read update
  despite the checked-in rule allowing it, so the badge correctly remained
  unread. No rules were deployed and production was not touched; reconcile the
  dev rules deployment before requiring read-clear acceptance.
- A teacher-control audit found that the Shuffle icon was decorative in ten
  mobile headers and the Submit Form back arrow had no action. Every Shuffle
  control now opens the existing teacher account/navigation drawer (including
  conditional role switching), and the form back control returns to the teacher
  dashboard. One mobile Chrome test visits all ten routes, opens/closes each
  account control, and verifies back navigation.

### Teacher Assignments route recovery (2026-07-12)

- Flutter Quick Access opens `TeacherAssignmentsScreen`; Next previously sent
  the identically labelled shortcut to Tasks, which is a different collection
  and lifecycle. The shortcut now opens native `/teacher/assignments/`.
- The route reads teacher-owned `assignments`, preserves Flutter's `title`,
  `description`, `due_date`, student-name `assigned_to`, teacher identity,
  attachment objects, active/type flags, and timestamp fields. It supports
  search, empty/error/retry states, create/edit/details/delete, required student
  validation, due dates, 50 MB attachment uploads under
  `assignment_files/{assignmentId}/`, invalid legacy file warnings, and file
  cleanup attempts when a new upload is removed/cancelled, an existing file is
  removed during edit, or an assignment is deleted.
- A real dev lifecycle created an assignment, selected a student, uploaded a
  text attachment, edited and reopened its details, then deleted the document
  and attempted file cleanup. Firestore readback found no leftover lifecycle document. Guard and
  mobile route/account-control coverage also pass; no Flutter or Functions code
  changed.
- Storage readback found that client deletes are rejected: the current rule
  requires `request.resource.size` for all writes, but `request.resource` is
  absent on delete. Five disposable upload leftovers were removed with dev
  admin access. The UI now reports partial cleanup instead of silently claiming
  success. No Storage rule was changed or deployed; attachment cleanup remains
  an explicit environment blocker for full Assignments acceptance.
- Follow-up: `storage.rules` now treats `request.resource == null` as a delete
  while retaining the existing authenticated-user requirement and 50 MB limit
  for create/update. The Storage rule alone was compiled and deployed to
  `alluwal-dev` on 2026-07-12; no Functions, Firestore rules, website, Flutter,
  or production project was deployed. The full browser lifecycle was repeated,
  and bucket readback found zero lifecycle or cancelled-upload leftovers.
  Assignments attachment cleanup is no longer blocked in dev; production still
  requires explicit deployment authorization.

### Teacher Zoom provider routing check (2026-07-12)

- A disposable dev shift with `video_provider: zoom` exercised the Next
  classroom provider branch. The callable response was mocked at the network
  boundary to avoid invoking production-critical hub allocation or creating a
  real Zoom meeting.
- The browser routed into the existing `/zoom_meeting.html` host with Meeting
  SDK credentials, customer identity, breakout room name/key, auto-join flag,
  class-end timestamp, and `/teacher/classes/` return URL intact. Returning to
  Classes rendered the native schedule again. The shift was deleted afterward.
- This proves Next payload and return routing without modifying the Zoom hub,
  bot lanes, meeting lifetimes, Flutter, Functions, or production Firebase. A
  real dev Zoom meeting/hub session is still not available for destructive live
  acceptance; production remains read-only.

### Teacher final regression gate (2026-07-12)

- The full Next.js Playwright run completed with 171 passing tests, 237
  intentionally skipped tests, and no failures across Chromium, mobile Chrome,
  and WebKit projects. The enabled teacher coverage includes authenticated
  navigation, workflow reads and mutations, error recovery, and the independent
  desktop sidebar/content scroll regions.
- `npm run typecheck`, the production-style `npm run build`, Hostinger packaging,
  and `git diff --check` all pass. The local review server remains available at
  `http://localhost:3021/teacher/` against `alluwal-dev`.
- No Flutter files, Firebase Functions, production Firebase data, Zoom routing,
  or deployment targets were changed as part of this gate. Real two-party Zoom
  hub acceptance remains the only external live-session verification item.
- After the Assignments/dashboard/shift-detail additions, the three-project
  teacher run completed 63 enabled tests with 154 fixture-gated skips. Its only
  two failures were selector collisions caused by the restored Islamic resource
  link and the now-labelled notification bell; both tests were scoped to their
  owning navigation/content regions and their focused Chromium reruns pass.

### Teacher My Report parity recovery (2026-07-12)

- A fresh Flutter sidebar audit found that the earlier matrix omitted the
  teacher-only Reports section and `My Report` workflow. Next.js now exposes a
  stable `/teacher/report/` route in the shared desktop and mobile navigation.
- The native report reads the same `teacher_audits` documents and legacy
  `oderId`/current `userId` ownership fields as Flutter. It supports month
  selection, overview score/rates/stats/issues, Classes, Clock-ins, and Forms
  detail tabs, visible retry/error and no-data states, and CSV download.
- A disposable `alluwal-dev` audit verified the populated 88.5% overview, all
  three detail collections, issue rendering, and downloaded CSV filename. The
  fixture was deleted immediately afterward. Desktop populated/guard tests and
  mobile sidebar discovery pass; no Flutter, Functions, or production data was
  changed.
- The focused parity-refinement pass added Flutter's gross/penalty/bonus/final
  payment summary and changed the download from headline metrics to the same
  session-oriented columns: date, shift, status, scheduled hours, worked hours,
  pay, and form presence. A second disposable fixture verified a 1.5-hour,
  $75.00 session and the exact downloaded CSV contents, then was deleted.
- Re-checking Flutter's actual sidebar route showed it opens the newer
  `TeacherAuditDetailScreen`. Next now also implements that screen's teacher
  actions: report acknowledgement, general discussion navigation, correction
  validation, compatible nested `reviewChain.teacherDispute` submission,
  top-level `disputed` status, and existing request/admin-response display.
  Real dev writes confirmed both the allowed acknowledgement field set and the
  dispute document shape; the transactional audit fixture was then deleted.
- When an audit contains `coachEvaluation.coachId`, Open discussion now carries
  that contact into Chat and opens/repairs the direct conversation after the
  contact list loads. Audits without a coach retain Flutter's general Chat
  fallback.

## Post-parity additions (2026-07-09)

These are deliberate improvements beyond Flutter parity, requested by the
owner. Do not "fix" them back to Flutter parity:

- **Public-site motion pass.** `src/components/Reveal.tsx` +
  `reveal`/`hero-enter`/`hero-blob`/`hover-lift`/`menu-pop` utilities in
  `globals.css` drive staggered hero entrances, scroll reveals, and hover
  lifts on the marketing home and header menus. All animation respects
  `prefers-reduced-motion`.
- **Visitor analytics.** `src/lib/analytics.ts` (Firebase Analytics / GA4,
  uses the `measurementId` already present in the Firebase web config) plus
  `src/components/AnalyticsTracker.tsx` mounted in `app/layout.tsx` logs
  `page_view` on every route change. The enroll form logs
  `enrollment_form_viewed`, `enrollment_step_completed`,
  `enrollment_submitted`, and `enrollment_submit_failed` funnel events.
  View the data in Firebase console → Analytics (or GA4 property
  G-F6605YZC8B for prod, G-9T98VV4GPR for dev).
- **Enrollment draft capture.** The enroll form asks for an optional
  email/WhatsApp on the student-details step and auto-saves progress
  (debounced) to the `enrollment_drafts` Firestore collection via
  `src/lib/enrollmentDrafts.ts` (draft ID kept in `localStorage`, marked
  `completed` on submit). `firestore.rules` gained a matching block
  (public create/update, admin read/delete) — **rules must be deployed to
  dev and prod before drafts work**. Admins follow up from the new
  "Incomplete" tab in `StudentApplicantsAdmin` (mailto / wa.me / tel
  follow-up actions, dismiss button).

## Parity Rule

For each screen, use at most two focused visual polish passes. Fix
user-noticeable gaps: missing content, wrong layout structure, wrong copy,
broken mobile behavior, broken forms, console errors. Do not loop on tiny font
rendering, pixel spacing, or differences a normal user would not notice.
# 2026-07-12 — Teacher profile and settings navigation parity

- Audited Flutter's teacher mobile profile sheet and confirmed that Next.js
  omitted its working View Profile and Settings destinations.
- Added guarded native routes at `/teacher/profile/` and `/teacher/settings/`
  and exposed them from both the desktop account menu and mobile drawer.
- Profile reads/writes the same `users/{uid}` and `teacher_profiles/{uid}`
  documents and uses the same owner-scoped `profile_pictures/{uid}/...`
  Storage layout as Flutter. Editing, required-name validation, upload size/type
  errors, offline/permission errors, and responsive dialogs are implemented.
- Settings now includes password reauthentication/update, persisted English or
  French preference, a visible persisted light/dark theme, help/privacy links,
  profile navigation, and sign-out. Notification preference data parity remains
  in the matrix rather than being claimed complete.
- Verification: `npm run typecheck`, production `npm run build`, Hostinger
  packaging, three focused desktop guard/navigation browser tests, one mobile
  drawer test, and a live dev profile save plus password mismatch validation.
  The preview remains available at `http://localhost:3021/teacher/` against
  `alluwal-dev`. No Flutter or Firebase Functions files were changed.

## Notification preference follow-up

- Added the Flutter teacher preference set to the native Settings route:
  shift reminders (10/15/20/30 minutes), task reminders (1/2/3/5/7 days),
  chat messages, and device-local prayer reminders.
- The first dev browser write showed that the deployed notification callable
  rejects the authenticated web client. Next now uses the existing owner-only
  Firestore update permission to write the identical nested
  `notificationPreferences` fields. No Function source or deployment changed.
- A reversible dev test toggled chat notification delivery and restored the
  original value. Focused Chromium write coverage and mobile Chrome viewport
  coverage pass; errors remain actionable and draft choices remain visible.

## Profile photo cleanup follow-up

- Added the Flutter profile-photo removal action to the native teacher profile.
- A disposable one-pixel PNG was uploaded through the browser to the dev
  teacher's owner-scoped Storage folder, rendered from the persisted download
  URL, then removed through the UI. The `users/{uid}.profile_picture_url` field
  and test object were cleaned up, leaving the fixture in its original state.

# 2026-07-12 — Teacher AI Tutor native foundation

- Audited Flutter's conditional AI Tutor FAB, stored interaction/voice/background
  preferences, `getAITutorToken` payload, LiveKit data topics, microphone and
  disconnect behavior, transcript handling, whiteboard, and teacher-action path.
- Added the guarded `/teacher/tutor/` route and conditional AI Tutor action when
  `users/{uid}.ai_tutor_enabled` is true. Disabled users see Flutter's explicit
  administrator-contact state rather than an inert control.
- Added `livekit-client@2.20.1`; this dependency is necessary because the
  deployed callable returns a LiveKit room/token and the browser needs the
  official SDK for signaling, WebRTC media, data messages, and cleanup.
- Implemented mode selection, Blake/Jacqueline/Robyn voices, all five background
  choices, local preference persistence, token payload parity, microphone
  permission and toggle behavior, tutor agent presence, text data publishing,
  transcript rendering, failed-draft preservation, preference restart, room
  disconnect, backend session ending, and failed-connect session cleanup.
- Temporarily enabled AI Tutor only for the disposable dev teacher and restored
  its original false value after testing. Token generation succeeded, but the
  returned `wss://live.alluwaleducationhub.org/rtc/v1` signaling request receives
  HTTP 404 and its HTTPS validation fallback lacks CORS headers. The same
  endpoint is used by Flutter, so real room/agent acceptance is externally
  blocked until that dev LiveKit proxy is corrected. The disposable session was
  closed. No Function source or deployment changed.
- Guard and enablement/preference browser tests pass. A gated live-session test
  records the unresolved signaling acceptance failure. Whiteboard and
  AI-requested teacher clock-in/reschedule actions remain explicitly open.

## AI Tutor whiteboard and teacher-action follow-up

- Added both Flutter-compatible whiteboard topics (`ai_tutor_whiteboard` and
  legacy `alluwal_whiteboard`) using the same `{type, payload}` envelope and
  version-2 project shape. Normalized pen strokes, undo/redo/clear, agent
  project replay, inbound project display, and inbound drawing permission are
  implemented on desktop and mobile.
- Added `ai_tutor_teacher_actions` handling and reliable
  `ai_tutor_teacher_action_results` responses. Supported actions match Flutter:
  GPS-backed transactional `clock_in`, `reschedule_shift`, and
  `reschedule_shift_future`. Rescheduling requires explicit confirmation and a
  valid single/future scope before calling the existing deployed contracts.
- Added focused protocol tests for exact Flutter whiteboard normalization and
  rejection of unsupported or unconfirmed mutations. These pass alongside
  typecheck and production static export. End-to-end agent delivery remains
  gated by the previously recorded LiveKit proxy 404/CORS failure.

# 2026-07-12 — Native teacher Savings Circles

- Audited Flutter's conditional `tontine_enabled` teacher tab and the `circles`,
  `circle_members`, `circle_invites`, `circle_cycles`, and
  `circle_contributions` contracts plus `circle_receipts` Storage paths.
- Added guarded `/teacher/circles/` with conditional desktop/mobile navigation.
  Disabled teachers see an explicit access state, matching Flutter's feature
  flag rather than receiving an inert navigation item.
- Implemented pending invite acceptance, open teacher-circle joining, created
  and joined circle lists, creator/member detail dashboards, payout order,
  circle creation, existing-user email invitation, activation gating, cycle
  status, receipt submission, contribution confirmation/rejection, and payout
  completion. Responsive dialogs preserve values and show permission/network
  failures.
- Temporarily enabled the dev teacher, created a disposable one-member circle
  through the browser, verified its detail route, removed its member and circle
  using dev administrative cleanup, verified zero leftovers, and restored the
  original disabled feature flag. Production and Functions were untouched.
- Signed-out and feature-flag browser tests pass. Multi-member invitation and
  backend-generated cycle acceptance remain listed in the parity matrix.
