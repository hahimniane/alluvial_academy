# Parent web area — parity record

Each checklist item from the inventories is marked **pass**, **differs (default)**
(a difference the plan's defaults chose, see `PLAN.md`), **later slice** (the item
belongs to a screen not built yet) or **could not test**, with the evidence.
Tests ran on alluwal-dev with a throw-away parent (`zz.parent.web@…`, user_type
parent, children on `guardian_ids` and on `guardianIds`) placed alone on
`settings/parent_web_cutover` (allowlist), against `next dev` on this branch.

## Slice 0 — foundation (entry, session, shell, switch)

| Item | What | Result | Evidence |
|---|---|---|---|
| A-001 | Loading while the account resolves | differs (by design) | Flutter has already found the account before it redirects; a direct visit resolves once and shows the Flutter loading text ("Loading user profile...") instead of polling for 30 s. |
| A-002 | Account not set up | pass | `ParentGatePrompt` notSetUp: title, sentence, Retry (re-resolves), Sign Out (→ `/`). |
| A-003 | Profile error | pass | error state with a plain sentence (default: no raw errors), Retry, Sign Out. |
| A-004 | Unknown role | pass | non-parents are handed to `/app/`, where Flutter shows its own screen. |
| A-005 | Active role | pass | `activeRoleOf` = saved `flutter.active_user_role` if still held, else `user_type`; unit-tested; live: Student saved → `/parent/` hands over to `/app/`, Parent saved → admitted. |
| A-006 | Parent on the web gets the parent shell | pass | allowlisted parent opening as parent: Flutter `/app/` → `/parent/` shell (C-722). |
| A-007 | Phones keep bottom tabs | pass | `redirectToParentWebApp` is a no-op off the web (stub) and `ParentWebCutover` returns false when `!kIsWeb`. |
| A-008 | Parent who is also a teacher | pass (logic) | active role parent → `/parent/`; active role teacher → Flutter's teacher routing, unchanged. No such account in production. |
| A-009 | Parent who is also a student | pass | live: chips Parent + Student; Student chip saves `"student"` and opens `/app/`; `/student/login/` link is `/student/` with active Student and `/parent/` with active Parent; with the switch off it stays `/student/` as today. |
| A-010 | Adult students | pass | untouched (student pages). |
| A-011 | Presence heartbeat | pass | live: `is_online: true`, `last_seen` 14 s old after opening `/parent/`; same 60 s interval and 20 s floor (unit-tested); offline on hide/close is subject to the same floor as Flutter. |
| A-012 | Role switch reloads | pass | full navigation to `/app/`, which opens the chosen role. |
| A-013 | Two layouts at 900 px | pass | live at 1024 px (sidebar) and 375 px (hamburger + drawer, no sideways scroll). |
| A-014 | Brand | pass | logo + "Alluwal Education Hub" ("Académie Alluwal" in French); click → `/parent/`. |
| A-015 | Screen map | later slice | Dashboard only; each slice adds its screen to `PARENT_WEB_SCREENS` when its parity passes, so a parent is never sent to a page that does not exist. |
| A-016 | Tabs kept alive, no URLs | differs (default) | one URL per screen (approved default); the shell sits in `app/parent/layout.tsx`, so the sidebar keeps its state between pages. |
| A-017 | Sidebar sections, items, order, colours | pass | unit test pins every section, label, order and colour to `_getParentStructure`; French from `app_fr.arb`, untranslated labels stay English. |
| A-018 | Circles hidden | pass | not in the list. |
| A-019 | Quran item dead | later slice | default: open the reader (slice 5). |
| A-020 | Wrong menu flash | pass | not reproduced: the shell renders only after the session is known. |
| A-021 | Icon rail | pass | live: collapses to 72 px, hover widens to 200 px with labels, survives reload; stored in `flutter.parent_sidebar_collapsed` (the Flutter key); chevron does nothing in the drawer, as in Flutter. |
| A-022 | Search, favourites, folding, reorder, reset | pass / could not test (reorder, live) | live: pin shows the Favorites box; folding survives reload and is not re-opened on load (Flutter re-folds only on a change of page); Reset Layout clears everything. Stored in `flutter.admin_sidebar_preferences` in Flutter's double-encoded format, so layouts carry across both apps. Search and reorder rules are unit-tested; dragging can be tried live once more than one section is listed. |
| A-023 | Role chips | pass / differs | live: one chip per role, active filled in its role colour, single-role parent sees one orange Parent chip. The "Switched to … mode" snackbar is not shown because the page leaves at once for the app. |
| A-024 | Role watcher | pass | live: removing the student role shrank the chips to Parent within 30 s. Message is a plain sentence (default) instead of "Admin Privileges Have Been Revoked". |
| A-025 | Account menu | pass / later slice | person icon, name on wide layouts, Sign Out in red; Profile appears when the Profile page ships (slice 5). |
| A-026 | Sign out with confirmation | pass | live: dialog "Sign Out / Are you sure you want to sign out?" with Cancel and red Sign Out; live confirm: signed out (no auth record left) and landed on `/`. |
| A-027 | No unread badge | pass | no bell, no badge. |
| A-028 | Text selectable | pass | native browser behaviour. |
| A-029 | Access-suspended screen (dead) | pass | not ported. |
| A-030 / A-031 | Whose dashboard, greeting | pass | "Welcome, Zz" (22 px, extra-bold); "Parent Dashboard" without a first name (unit-tested); English in both languages, as in Flutter. |
| A-096 | Children resolver | pass | unit-tested mapping, fallback and Dart sort; live as the dev parent through the client SDK: `guardian_ids` query → child A, `guardianIds` query → child B, both allowed by the rules; the resolver keeps A only, as Flutter does. |
| A-097 | `isParentOfStudents` (dead) | pass | not ported. |
| C-720 / C-721 | Switch document, Flutter fails closed | pass | `ParentWebCutover.allows` unit-tested (missing, off, unknown, allowlist, all, empty uid). |
| C-722 | Flutter applies it on the web | pass | live with a dev Flutter web build served at `/app/` on the same origin: switch naming the parent → Flutter replaced `/app/` with `/parent/`, signed in, no second login; switch off → the Flutter parent dashboard as today. Native apps: stub no-op. |
| C-723 | Next side | differs (on purpose) | fails **closed** (the teacher console fails open): until the switch names a parent, `/parent/` hands them to `/app/`. A failed read shows Retry instead of redirecting, so no one bounces between the apps. Live: switch off → `/parent/` went to `/app/`. |
| C-725 | `dashboardPathForUser` | pass | parent branch first, only when opening as parent and the switch names them; otherwise unchanged (live, both ways). |
| C-728 | `/parent/*` guard | pass | `app/parent/layout.tsx` → `ParentArea`. |
| C-730 | Shared session | pass | only `auth`/`db` from `lib/firebase.ts`. |
| C-731 | COEP | pass | not embedded (full redirect), nothing needed. |

## Slice 1 — home and child page

Tested on alluwal-dev with the dev parent, two children on `guardian_ids` (one
suspended) and one on `guardianIds` only, 16 classes in every state (live,
scheduled-but-past, completed/partially/fully, missed, cancelled, a leader shift,
one 45 days old), 3 tasks, 4 invoices and 5 payments. Flutter (dev web build on
the same origin, switch off) and Next (switch on) were compared on the same data;
every figure below was also worked out by hand from the Dart formula.
`getClassContacts` was missing on alluwal-dev and was deployed there to test A-052.

Plan defaults applied throughout: junk ARB text replaced by plain sentences
(EN + FR), wrong French fixed ("Excédent" → "En retard", "Outstanding" → "Solde
dû", "Participants vivants" → "Participants en direct", "Vivre" → "En direct"),
raw errors replaced by "Failed to load …. Please refresh to try again.", English-
only strings stay English, dates and money stay US English.

| Item | What | Result | Evidence |
|---|---|---|---|
| A-030 | Parent account | pass | session from slice 0; the dashboard uses the signed-in uid. |
| A-031 | Greeting | pass | "Welcome, Zz" both apps. |
| A-032 | Refresh | differs (by design) | a Refresh button (mouse users had none); live: re-runs children, progress, money and suspension listeners, and sends `forceRefresh: true` for the current period (payloads captured). |
| A-033 | Section order | pass | same order, 16 px padding, single column. |
| A-034 | Suspension banner | pass | "2 students have been suspended" + names + "View & pay invoices" in both apps; same query (no `user_type`, no `guardianIds`). Link goes to the invoices page (slice 2). |
| A-035 | Money summary | pass | $140.00 outstanding / $80.00 overdue in both apps (= 120 − max(40 completed, 20) + 60); unit-tested incl. cancelled, settled and invoice-less payments. |
| A-036 | Pay Now | pass / later slice | shown only when outstanding > 0; opens the pending invoices page (slice 2). |
| A-037 | Loading / error | differs (default) | spinners in the two figures while loading and a plain error line, instead of $0.00. |
| A-038 / A-039 | Quick actions | pass / later slice | same tiles; targets are the slice-2 pages. Titles wrap instead of truncating at phone width, as Flutter's text does. |
| A-040 | Family Progress states | pass | loading card, plain error, empty card. |
| A-041 | Header + ring | pass / differs | 50% avg in both. Flutter draws the ring at 36 px (its text overflows); Next draws the intended 86 px ring. |
| A-042 | Four tiles | pass | 2 / 9 / 5.5 / 1 in both; side by side at ≥ 680 px card width (container query), stacked below. |
| A-043 | Weekly Activity | pass | bars 0,1,1,1,1,2,3 in both. "1 classes" fixed to "1 class". |
| A-044 | Top Subjects | pass | "Quran (2) · Arabic (2) · quranStudies (1)" in both (the enum name is Flutter's documented behaviour here). |
| A-045 | Child cards | pass | Coumba Needs Support 33% / 3 classes / 1.0h / +3; Amadou Watch 67% / 6 classes / 4.5h / +4 — identical. |
| A-046 | Analytics states | pass | loading, plain error, empty; a failed report reads as zeros. |
| A-047 | Weekly / Monthly | pass | live: switching re-requests every child with `forceRefresh: false`. |
| A-048 | Five tiles | pass | same values both apps; row at ≥ 680 px. |
| A-049 | By Child cards | pass | same order (lowest attendance, then more scheduled) and figures; join-offset wording unit-tested. |
| A-050 | Children list | pass | names, "ID: ZZPA1", chevron; opens `/parent/child/?id=`. |
| A-051 | No children | pass | plain sentence. |
| A-052 | Teachers' numbers | pass | parent variant of the shared card: each child with "No phone number on file" in both; one child per row as in Flutter. |
| A-053 / A-054 | Recent invoices | pass | same 4 cards: badges, period, amount, due chip, "3 days overdue", "Access cut off in 3 days", "Access suspended 2 days ago", Pay Now; card/Pay Now open slice-2 pages. |
| A-055 | Recent payments | pass / differs | same 5 rows, dots and "PROCESSING • Nov 15, 2026"; an error shows a message instead of an endless spinner. |
| A-056 | Payment → invoice | pass | found → invoice page URL; refused (rules deny a missing invoice) → nothing, same as Flutter. |
| A-057 | Raw errors | differs (default) | plain sentences. |
| A-058 | Child page frame | pass | full page over the shell (no sidebar), back arrow, centred name, four tabs with label-width underline; Refresh button added (pull-to-refresh). |
| A-059 | Ownership | pass (stricter) | an id that is not one of the parent's children shows "This child is not linked to your account." (live with the `guardianIds`-only child). |
| A-060 | Quick stats | pass | 9 / 67% / 1/3 in both. |
| A-061 | Today's Classes | pass | Missed 6:15 AM, In Progress 8:25 AM (+ later today); leader shift excluded. Subject shows "Quran Studies" instead of "IslamicSubject.quranStudies". |
| A-062 | Upcoming preview | pass | next 5 within 7 days, earliest first, live class excluded. |
| A-063 | Recent Activity | pass | last class = status `completed` only (Flutter's string test kept), last task with "Nov 13, 2026". |
| A-064 | Status badge | pass | scheduled-but-past = Missed; unit-tested all statuses. |
| A-065 | Card body | pass | time, subject, "Teacher: …", "Sunday, Nov 15, 2026". |
| A-066 | Live participants | pass | panel, "0 in class", "No one has joined yet." (plain), polls every 15 s. |
| A-067 | Join button | pass | "Join Now" live / "Join Class" in the ±10-min window; unit-tested window edges. |
| A-068 | What Join does | later slice | opens `/parent/classroom/?shiftId=` (built in slice 3, classes + join). |
| A-069 | Details sheet | pass / differs | press and hold opens it (live: the hold did not also join); 60 % high, drag 40–90 %; Status shows "In progress" rather than "ACTIVE"-style raw names. A keyboard "Class details" button is added. |
| A-070 | Spinner bug | differs (fix) | polling starts whenever a card turns live. |
| A-071 | Upcoming / History | pass | segmented control, heading changes, calendar stays. |
| A-072 | Calendar | pass | November 2026, Monday first, tints 3/5/10/12/14/15/16/18/24 as in Flutter's priority rule, today outlined. |
| A-073 | Upcoming list | pass | live, includes the class in progress, no limit (5 rows incl. +9 days). |
| A-074 | Class History | pass | every started class newest first incl. live and the leader shift (no category filter), 45-day-old class included. |
| A-075 / A-076 | Task counters / filter | pass | 3 / 1 / 1 / 1; filters share the counters' definitions (unit-tested). |
| A-077 | Task cards | pass / differs | badges, due date, overdue pill, paperclip count. A task with no due date is skipped instead of failing the whole list. |
| A-078 | Assigned by | differs (fix) | "Assigned by Zz Web Parent" (Flutter prints "Assigned By Assignedbyname"); hidden when the user doc is missing. |
| A-079 | Read-only | pass | cards do not open. |
| A-080 | Progress states | pass | loading card, plain error. |
| A-081 / A-082 | Hero + tiles | pass | 60% / 5 / 3.5 / 3 / Watch — hand-checked against the Dart formula; row at ≥ 620 px. |
| A-083 | Weekly bars + trend | pass | 0,1,0,1,0,1,2 and "+3 class activity vs previous week". |
| A-084 | Breakdown | pass | 60% · 3 / 1 / 1 / 5. |
| A-085 | Subject Performance | pass | Quran 3/1/1.0h, Arabic 3/2/2.5h, Tajweed, quranStudies — in Flutter's tie order. |

Also fixed in the shell: `globals.css` gives buttons `font: inherit` outside any
cascade layer, which overrode every Tailwind size/weight class on buttons (the
role chip and Reset Layout rendered at 16 px). `app/parent/parent.css` restores
the layered cascade inside `.parent-area` only.

## Slice 2 — money (invoices, details, PDF, pay, payment history)

Tested on alluwal-dev with the dev parent and 5 invoices (pending, late pending,
stored-overdue in EUR with a cut-off and a range period, paid, cancelled; one with
three lines incl. a discount and a credit, created by a staff user) and 7 payment
records. Flutter (dev web build, switch off) and Next (switch on) were compared on
the same data: the list, pay screen, payment history and invoice details matched.
alluwal-dev has no Stripe configuration, so the pay button was exercised against the
dev fallback (a mock checkout address) and Stripe's return + the webhook's writes
were simulated on dev records.

| Item | What | Result | Evidence |
|---|---|---|---|
| B-001 / B-092 | Ways in | pass | sidebar Finance → Invoices / Payments (now listed), dashboard tiles, See all, Pay Now and the suspension banner (`?status=pending`). Both pages sit inside the shell; Flutter pushes them over it from the dashboard. |
| B-002 / B-003…B-005 | List and queries | pass | parent_id (status in the query, due date desc, 100) + student_id (error = empty), merged, 100 cap (unit-tested); same 5 cards in the same order as Flutter. |
| B-006 / B-007 | Chips | pass | stored-status filter kept (plan default): the late INV-ZZ-0001 under Pending, only the stored-overdue invoice under Overdue — same as Flutter. Row centred as in Flutter. |
| B-008 | Search | differs (default) | number only, as today; the hint now says so ("Search by invoice number") instead of promising parent/email/phone. |
| B-009…B-011 | States | pass / differs | spinner; plain error instead of an endless spinner; "No invoices found." |
| B-012 | Child name | pass | first + last, raw id when missing (unit-tested); same names as Flutter. |
| B-013 | Card opens details | differs (fix) | Flutter web: clicking a card does nothing (its text-selection layer takes the click — reproduced live); Next opens the details. |
| B-014…B-028 | Card | pass | shared card from slice 1 (badges, period incl. ranges, amount in the invoice currency incl. €, due chip, cut-off strip, Pay Now) — identical to Flutter on all 5. |
| B-029 / B-030 | Details load | differs (fix) | live instead of one read, so totals follow a payment; missing/refused → "This invoice could not be found." |
| B-031…B-033 | Buttons + pill | pass | Pay Invoice / Paid / disabled for cancelled; Download PDF; OVERDUE pill — same as Flutter. |
| B-034…B-041 | Invoice sheet | pass | header, FROM / BILLED TO (15 s name cap, placeholders), meta row, 4-column table (2 columns under 560 px, live at 375 px), negative lines, Subtotal / Paid Toward Balance / Amount Due colours, footer — same as Flutter on INV-ZZ-0001 and the EUR invoice. |
| B-042 | Decision history | pass | fallback row "Created invoice · By Zz Finance Admin · admin · date" (date in the app language, as Flutter); tooltip with email · role · uid. Same as today (owner question B-P3 still open). |
| B-043 / B-044 | Payments for the invoice | pass | invoice_id + parent_id, live, newest first, same row; plain empty/error. |
| B-045…B-056 | PDF | pass / differs | same content and wording (A4, "Payment Date" = issue date, "From:", "Received by: Muhammed Barry", rows only when present — unit-tested); opens the browser print dialog with `Invoice_<n>.pdf` as on Flutter web. Differs: built from the live invoice; accented letters kept; a long invoice continues on a second page instead of overflowing. |
| B-057 | Emailed PDF | unchanged | server renderer untouched. Note: its fixed layout overlaps the footer on long invoices (seen while porting) — not changed here. |
| B-058…B-061 | Pay page | pass | live invoice box (PAID / OVERDUE / PENDING, never CANCELLED — unit-tested), Total / Paid / Remaining, one button; same as Flutter. |
| B-062 / B-063 | Start checkout | pass | `createPaymentSession {invoiceId, returnTo:'parent'}`; answer must carry a payment id and an absolute address; same-tab redirect — live against the dev fallback ($60.00, full balance). |
| B-064 | Return from Stripe | differs (default, needs PR #185) | `/parent/pay/return/`: "Payment submitted" → live flip to "Payment received" when the webhook marks it paid (simulated live); "Payment cancelled — nothing was charged" with Pay again. Payment polled every 2 s × 15 + Check Payment Status, as Flutter's phone flow. Requires the `createPaymentSession` change in its own PR; until it is deployed, Stripe still returns to the home page. |
| B-065…B-067, B-071, B-073 | Phone sheet | n/a | phones stay on Flutter. |
| B-068 / B-069 | Status box, success banner | pass | on the return page and the pay page. |
| B-070 | Error messages | pass | same mapping from the server's code (unit-tested), fixed French for the screen title. |
| B-072 | Double click | pass | button disabled while starting. |
| B-074…B-091 | Server, pay links | unchanged | apart from the opt-in return address (PR #185). |
| B-093…B-097 | Payment History | pass / differs | 100 newest, live, attempts included, tinted icons with processing in blue — identical to Flutter; row opens the invoice; plain error instead of an endless spinner. |
| B-098 | Adult-student gap | same as today | parent_id only (adult students use the student pages). |
| B-099…B-102 | Emails | unchanged | "parent dashboard → Invoices / Payments" stays true. |
| B-103…B-112 | Suspension | pass | banner (slice 1) and cut-off strips; nothing blocks the parent. |
| B-113…B-122 | Dashboard money | pass | slice 1. |

## Slice 3 — classes and joining

Tested on alluwal-dev with the dev parent and two children: 26 classes including a
live one, one opening in 25 minutes, a cancelled one, a leader shift, ended ones,
and one class shared by both children (same Zoom meeting and room). Flutter (dev
web build, switch off) and Next (switch on) showed the same Upcoming list, in the
same order, with the shared class as one card naming both children.

`getZoomJoinInfo` creates or ensures a real Zoom meeting for a class the parent
may enter, so the final hand-off was not run live (no Zoom changes); every path
before it was, and the meeting-page address is pinned by unit tests against
`ZoomMeetingScreen` (web).

| Item | What | Result | Evidence |
|---|---|---|---|
| C-001 | Sidebar Learning → Classes | pass | now listed; page in the shell with "Classes" and a refresh icon. |
| C-002 | Phone tab | n/a | phones stay on Flutter. |
| C-003 | Whose classes | pass | the slice-0 children resolver (guardian_ids, then guardianIds). |
| C-004 / C-005 | Spinner, no children | pass / differs | "No children linked to your account" with the school icon; a failed lookup now says so instead of looking like "no children". |
| C-006 | Refresh | pass | re-reads the children quietly; listeners rebuilt only when the set changes. |
| C-007 | Live classes per child | pass | one listener per child, teaching only, no date bound (leader shift hidden; 45-day-old class in History). |
| C-008 | Siblings share a card | pass | live: "Family Quran circle — Zz Child Amadou, Zz Child Coumba" in both apps; grouping key and "joinable copy wins" unit-tested. |
| C-009…C-013 | Upcoming / History | pass | live first, then joinable, then start (cancelled kept); History newest first — same order as Flutter on the seeded data. Empty rows as Flutter. |
| C-014…C-016 | Card | pass | the slice-1 card plus the children line; same status words, Teacher, date; readable subject instead of `IslamicSubject.*`. |
| C-017 / C-018 | Live panel, details sheet | pass | slice 1 (polls every 15 s; hold opens the sheet). |
| C-019 | Join button | pass | same window; card and button open `/parent/classroom/?shiftId=`. |
| C-020 | Checks before the server | pass / differs | live: "Class opens in 14 minutes", "This class has ended", "This class link is no longer available." — shown on the join page with Back to Classes instead of a snackbar on the list. |
| C-021 | Server + role | pass | `getZoomJoinInfo {shiftId, activeRole: 'parent'}` as Flutter (no clientPlatform on the web); live: the server's refusal for a class that is not the parent's is shown as written. |
| C-022 / C-023 | Attendance, suspension | pass | unchanged server behaviour; no presence parameters are sent. |
| C-024 | Zoom meeting page | pass (by design) | the SAME cross-origin-isolated page Flutter web opens, `/app/zoom_meeting.html?join=…#…`, with the same parameters and texts (unit-tested). Leaving returns to `/parent/classes/` (Flutter: the parent home). The Next root copy is not used, so nothing about Zoom changes. |
| C-025 | Reconnecting waiting room | pass (shared) | the existing `ClassroomReconnecting` + `readClassroomReconnect` (same 15 s retry as Flutter). |
| C-026 | Join errors | pass | server sentence kept; bare codes → slow-connection / failed sentences (unit-tested); Try again + Back to Classes. |
| C-027 | RealtimeKit classes | pass (code) | `getRealtimeKitJoinToken {shiftId, activeRole: 'parent'}` and Flutter's `/app/realtimekit_meeting.html` in a frame; unused in production (all classes are Zoom). |
| C-028 | `?joinShift=` links | pass (code) | Flutter now carries a pending class link through the parent redirect to `/parent/classroom/?shiftId=`. No screen generates these links today. |
| C-029 / C-030 | Guest links, selectable text | pass | no guest-link control; ordinary web text. |

Before cut-over: one real join as a parent in production (a parent account in a
live class), to confirm the Zoom hand-off end to end.
