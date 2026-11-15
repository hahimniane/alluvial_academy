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

## Slice 4 — chat

Tested on alluwal-dev with the dev parent, a teacher of the dev child, a 1:1 thread
(two unread messages, one with a reply quote), a group (parent, teacher, staff
admin; a system notice; an @All message with a reaction) and the Admin Support
thread with a staff reply. Flutter (switch off) and Next (switch on) showed the
same Recent list. Every action below was run live and the written documents were
checked with the Admin SDK.

Plan default applied: chat actions that fail today are made to work (Clear chat,
Leave Group, Forward to Admin Support); wrong-perspective and junk copy replaced.

| Item | What | Result | Evidence |
|---|---|---|---|
| C-400 / C-401 | Sidebar Chat, no badge | pass | now listed; no unread badge (as today). |
| C-402 | Phone tab | n/a | phones stay on Flutter. |
| C-403 | Tabs + search, no Create Group | pass | "Recent Chats" / "My Contacts", one search box. |
| C-404…C-407 | Recent rows | pass | same rows as Flutter: 2 / 1 / 1 unread, online dot, Teacher / Group Chat + "3 members" / Administrator chips, time chips; live; 1:1 rows dropped when the other user is gone (unit-tested). |
| C-408 | Unread rule | pass | not read, not mine, not hidden for me (unit-tested). |
| C-409 | Preview text | pass / fix | deleted variants unit-tested; "You deleted this message" after delete-for-everyone recomputed `last_message` (checked). Hiding the last message now also marks its stored copy for the parent, so the fallback really happens (Flutter never marks it, so the removed text stays as the preview). |
| C-410 | States | pass / differs | spinner, permission/other errors, empty, no hits. The empty text no longer says "browsing all users" (parents cannot). |
| C-411 | Search | pass | name, e-mail, id, phone ≥ 7 digits; support card kept for "admin support" substrings (unit-tested). |
| C-412 | Support card | pass | live: card first; opening creates/repairs the thread. |
| C-413 | Administrators | pass | admin, super_admin, ceo, founder + admin-teachers (9 on dev incl. a leader title "Operations Director"). |
| C-414 | Teachers | pass | children from `children_ids`, else guardian_ids; teachers with a non-cancelled class ending in the last 30 days or later; the users lookup is batched by 30 (Flutter's single query fails above 30 — B-3). |
| C-415 | Contacts states | pass | loading; errors leave only the support card (as today). |
| C-416 | canMessage | pass | live: own child (student) → red locked bar; teacher of the child → composer; inbound unlock unit-tested. |
| C-417 | Support thread | pass / differs | header "Administrator", banner "Admin Support"; staff replies on the LEFT with the staff name (Flutter right/teal — B-9). |
| C-418 | Header | pass | back, avatar, online chip / "Last sent …" / role, ⋮ menu; full page over the shell. |
| C-419 | Relationship banner | pass / differs | "Your child's teacher" (Flutter shows the teacher's wording "Parent of your student" — B-10). |
| C-420 / C-421 | Messages + bubbles | pass | newest 50 live; own right blue, others left white with avatar + name; system pills; "edited"; HH:mm / Yesterday / D/M (unit-tested). |
| C-422 | Read receipts | pass | live: opening marked the teacher's messages read and stamped `last_read_by`; ✓ / ✓✓. |
| C-423 | Mentions | pass | `@All` styled; links not linkified (as today). |
| C-424 | Send | pass / differs | same documents as Flutter (checked). Enter sends, Shift+Enter new line; a failed send restores the draft with a message (Flutter loses the text silently). |
| C-425 | Message menu | pass / differs | live: React, Reply, Copy, Forward, Edit, Delete (own text) / React, Reply, Copy, Forward, Delete (others'). Opens on press-and-hold as in Flutter, and also on right-click / Enter for mouse and keyboard users. |
| C-426…C-428 | Reply, reactions, copy | pass | reply quote; six quick emojis + "More" grid; toggle/replace; chips; copy toast. |
| C-429 | Forward | pass / fix | live: forwarded into the REAL Admin Support thread with `forwarded` + `original_sender`; no `chats/admin_support` doc (Flutter B-1). |
| C-430 | Edit | pass / fix | live: "edited"; the list preview is patched only when the edited message is the last one (Flutter B-5). |
| C-431 | Delete | pass | live: delete for me + Undo; delete for everyone (own, ≤ 2 days) → placeholder and `last_message` recomputed. |
| C-432…C-434 | Attachments | pass | menu Photo / Camera / Video / Document / Location; live: photo with caption preview → `chat_images/{uid}/…`, image bubble with caption. Camera = the browser's capture input. |
| C-435 / C-436 | Voice | differs (decision) | no microphone on the web (Flutter web shows one that always fails — B-8; whether WebM plays on phones is unverified). Received voice notes play with the browser's audio player. |
| C-437 | Documents | pass | live: `revision-plan.txt` → `chat_files/{uid}/…`, file card with size, opens in a new tab; same extension list. |
| C-438 | Location | pass (code) | browser location → "Send current location" sheet → pinned-location card linking to Google Maps. Not run live (needs a location permission); no reverse geocoding on the web (Flutter's own fallback: "Current location" + coordinates). |
| C-439 | Images | pass | viewer with click / ctrl-wheel zoom. |
| C-440 | Clear chat, Block | pass / fix | live: Block hides the composer with "You blocked …", Unblock restores it. Clear chat now removes every message from the PARENT's view only (6 → 0) and the row leaves Recent; Flutter tries to hard-delete both sides and normally fails (B-4). |
| C-441 | Absent features | pass | none added. |
| C-442 | Presence | pass | slice-0 heartbeat. |
| C-450 | Group conversation | pass | live: @ suggestions (All + members), group menu with the same six entries; "Edit Group" / "Add members" give the same refusal for non-admins. |
| C-451 / C-452 | Group info, members | pass | live: members with You / Creator / Admin tags. |
| C-453 | Leave Group | pass / fix | live: participants updated, "Zz Web Parent left" posted (written as the parent so the rules accept it), back to the list; Flutter fails half-way (B-7). |
| C-460 | Leader titles | pass | shared `leaderTitle`. |
| C-461…C-465 | Push | unchanged | the same message documents fire the same trigger; no web push (as today). |
| C-466…C-469 | Data | pass | same documents, Storage folders and limits. |

Test note: Flutter showed the dev 1:1 thread as empty because the seeded teacher id
contains `_`, which Flutter treats as a chat id (C-420); real uids have none.

## Slice 5a — forms, profile, settings

Tested on alluwal-dev with the dev parent and seeded copies of the three forms
parents see in production (read-only check on 2026-11-15: "Parents Feedback on
Teachers" monthly/feedback, "Bayana Attendance Form" and "Parent/Student Class
Complain Form" anytime/other — radio, multi-select, text, dropdown, long text),
plus a form with every other question type and a teacher-only form. Every write
was checked with the Admin SDK. The Flutter screens were compared from source
(teacher_forms_screen.dart parentOnly, parent_forms_screen.dart,
parent_form_access_policy.dart, form_screen.dart, my_submissions_screen.dart,
parent_profile_screen.dart, role_settings_screen.dart).

| Item | What | Result | Evidence |
|---|---|---|---|
| B-123 | Ways in | pass | sidebar Forms; Profile also in the account menu. |
| B-124 | Header | pass | indigo gradient, "Family Forms" / subtitle (EN/FR), history icon → My Form Submissions. |
| B-125 | Which forms | pass | live: parent-audience forms shown, teacher-only hidden, inactive hidden; built-in names/ids shown whatever the audience (unit-tested, including the accent quirk of the French name). |
| B-126 | Latest copy per name | pass | unit-tested: highest version, then latest update, before the parent filter (as the app). |
| B-127 | Built-in excuse form | pass | live: always present, EN/FR labels and options from the ARB. |
| B-128 | Built-in feedback form | pass | live: hidden while "Parents Feedback on Teachers" is active, shown once it is switched off. |
| B-129 | List cannot load | pass / differs | the two built-ins with no error (unit-tested); a "Try Again" link replaces pull-to-refresh. |
| B-130 | Grouping and cards | pass | live: TEACHING REPORTS / FEEDBACK & COMPLAINTS / STUDENT ASSESSMENT / ADMINISTRATIVE / OTHER FORMS (the app's real section names), A→Z by code unit, "<n> items" without locked auto-fill fields, frequency word, arrow when it opens. |
| B-131 | Weekly / monthly lock | pass / fix | live: the monthly feedback form is greyed out on Nov 15. The lock badge now shows on every locked card (the app shows it on Teaching cards only, so parents saw a grey card with no reason). When open, the parent's own form opens — the app swapped in the active TEACHER monthly template here. |
| B-132 | Search | pass | live: name, section title ("other forms"), no-match state, clear button. |
| B-133 | Loading / refresh | pass | spinner; each visit reads the server. |
| B-134 | Opening a form | pass / differs | its own page (/parent/forms/fill/?id=…) with back, purple form styling, title and description. Per-session forms open directly — the app's class picker is a teacher list and is empty for a parent (no parent form uses it). |
| B-135 | Question types and checks | pass / fix | live: text, long text, email (format check), phone, number, date, dropdown, multi-select, radio, yes/no, image upload, heading and section blocks; "show only if" (live: shown on "Other", hidden answer not sent). The app's messages ("Please enter …", "Please select a …", "Please select a date", "Please enter a valid email address"). A label that is itself an instruction ("Please explain the absence") gets "Please fill in this question" instead of "Please enter Please explain the absence". A video block shows its link (the app drew a text box whose answer it threw away). Labels and options use the app's French dictionary (generated from form_localization.dart). |
| B-136 | Stored answers | pass | live: date `3/11/2026` (d/M/yyyy), multi-select array, yes/no `true`/`false`, unanswered questions `""`, display blocks and hidden questions left out. |
| B-137 | Image upload | pass / differs | live: `form_images/{uid}/{millis}_{name}`, `{fileName, downloadURL, size, type: 'image', uploadedAt}` plus `url`, `storagePath`, `contentType`. No compression or "Submit Without Image" dialog: an upload failure stops the send with a message. |
| B-138 | Submission document | pass | live: formId, formName, formTitle, formType, templateId, frequency, the four owner fields = parent uid, userEmail, names from the user doc, status completed, yearMonth, reportingContext {appSessionId, platform: web, clientTimestamp, recentBreadcrumbs}; no role field. |
| B-139 | No side effects | pass | only the form_responses row is written. |
| B-140 | After submitting | pass / fix | the page closes back to the list with "Form submitted successfully!". A failure shows a plain sentence instead of the raw error; 30-second time-out kept. |
| B-141 | Admin decision | pass | live: "Rejected" set by Admin SDK shows on the submission. |
| B-142 | My Form Submissions | pass / fix | the teacher page's view, shared (month picker, all time, search, counts, read-only detail). The four owner queries are the app's. Answers of the built-in forms show their questions' labels in order — the app showed raw field ids. |
| A-086 | Profile loading | pass / fix | spinner; failure shows a plain sentence with Try again ("Failed To Load Profile E" in the app). |
| A-087 | Header card | pass | person icon, saved name (or "Parent"), e-mail. |
| A-088 | Fields | pass | live: first/last side by side ("First name is required"), e-mail read-only ("Email cannot be changed"), phone. |
| A-089 | Save | pass / fix | live: `users/{uid}` first_name, last_name, phone_number (trimmed) + updated_at; green "Profile Updated Successfully"; the top-bar name and greeting follow at once. A failure shows a plain sentence. |
| A-090 | Back arrow in the tab | differs (decision) | not reproduced, per inventory. |
| A-091 | Settings header | pass / fix | "Parent Settings"; the junk subtitle "Account Settings Build Info" is now "Language, password and app version". |
| A-092 | Language | pass | live: English / Français switches the whole area and writes `language_preference` (plus `language_updated_at`, as the student and teacher pages do). |
| A-093 | Change password | pass / fix | live: the app's checks ("Enter your current password", "Password must be at least 6 characters", "Passwords do not match"), show/hide eyes, wrong current password → "Current password is incorrect." (the app showed the generic message for Firebase's current error code). Success path run live on a throwaway dev parent: "Password changed successfully.", the dialog closes, the new password signs in, and the user document gains no field. An account without e-mail gets a message instead of nothing. |
| A-094 | Version line | differs (decision) | shown only when the deploy sets NEXT_PUBLIC_WEB_BUILD_VERSION, labelled "Version" (the app's label read "New Version"); hidden otherwise rather than "Not set". |
| A-095 | Nothing else | pass | no notification settings, photo, theme or delete account. |

Shared code: the teacher "My Form Submissions" page now renders the same view
from `components/forms/MySubmissionsView.tsx`. Checked live against main with a
temporary dev teacher: identical text, counts and decisions.

Phone width (375 px): no sideways scroll on all five pages.

Decisions: the Forms lock badge for every locked card; the parent's own form
opens in its window (not the teacher template); per-session forms open without
the teacher class picker; "Autre" for the excuse reason (the app's "Autres");
"Rechercher des formulaires" (the app's "Formulaires de recherche").
## Slice 5b — recordings, curriculum books, Quran

Tested on alluwal-dev with the dev parent (child A on `guardian_ids`, child B on
`guardianIds`, both in `children_ids`) against `next dev` on this branch. Flutter
was compared live with the dev web build (built 2026-11-15 from main; the three
screens have not changed since) signed in as a second throw-away parent with the
same two children in `children_ids` and **not** on the cut-over list, so the
switch was never touched for the comparison. Seed: 11 `class_recordings` docs
(two fragments of one class with a classmate from another family, a class shared
by both children, a `shift_start`-only recording, missing file, `starting`,
merge `pending`, merge `completed` with no merged file, plus failed / expired /
no-file / other-family ones that must stay hidden), a 25-second test video in the
dev bucket, and a teacher with e-mail and phone. All removed afterwards.

No shared component changed: `QuranReaderPage`, the student and teacher
Recordings / Books / Quran pages, `ParentArea` and `ParentUi` have an empty diff
against main, so the student and teacher pages are unchanged by construction.

| Item | What | Result | Evidence |
|---|---|---|---|
| C-200 | Sidebar Learning → Recordings | pass | now listed; page sits inside the shell (not pushed), item highlighted. |
| C-201 | Not reachable on phones | n/a | phones stay on Flutter. |
| C-202 | Loading | pass | centred blue spinner; payload captured live: `listClassRecordings {limit: 200, activeRole: "parent"}`. |
| C-203 | Server authorisation | pass (unchanged) | parent branch of the server: both children (guardian field + `children_ids`) listed; the other family's recording absent. |
| C-204 | Server filtering / sort / classmate ids | pass | failed, expired, no-file and other-family recordings never shown; the classmate on a shared class does not appear as a child card; same 100 cap, `hasMore` unused (as today). |
| C-205 | Names | pass | children and teacher looked up 10 ids per read, first+last → name/displayName → e-mail → id; teacher e-mail/phone kept for search (unit-tested aliases). |
| C-206 | List failed | pass | full-page card replaces the screen; live (forced responses): "Requested role is not available for this user", "internal: failed to load recordings", "Failed to load recordings"; Try Again reloads and recovers. |
| C-207 | No recordings | pass | live before seeding: "Students / 0 students", "No recordings yet / Class recordings will appear here after sessions are recorded.", no search bar — same as Flutter. |
| C-208 | Header | pass | back only when drilled in, refresh always; titles and subtitles identical to Flutter at every level, fragments level titled with the class name ("Zz Quran Hifz"). |
| C-209 | Child cards | pass | Flutter and Next both: Amadou "6 recordings · Latest: Nov 14, 2026", Binta "2 recordings · Latest: Nov 12, 2026"; shared class counted under both; sort unit-tested. |
| C-210 | Child search | pass | name, e-mail, id, phone (7+ digits) — `AppSearch` ported and unit-tested; live "child_b" → Binta only in both apps; empty → "No students found / Try a different search term." (seen in both). |
| C-211 | Dates | pass | Binta: "Thursday, Nov 12, 2026" and "Tuesday, Nov 10, 2026" in both apps — the second uses the `shiftStart` fallback the student page lacks; long and short date search unit-tested. |
| C-212 | Classes on a day | pass | Nov 14: Quran Hifz / Missing File / Still Recording / Merge Missing with the same subtitles and times in both apps; live search by teacher phone "555-010-0222" (all 4), teacher e-mail "zz.fatou" (all 4), class id, class name. |
| C-213 | Fragments | pass | summary card + "Fragment 1 / Fragment 2" with numbered squares, "Full Recording" for one; screenshots match Flutter. |
| C-214 | Status chip | pass | Ready green, Processing amber (starting and merge pending), raw/Unknown grey — live + unit-tested. |
| C-215 | Auto-delete chip | pass | "Auto-deletes in about 2 months · Jan 14, 2027" (teal), "…in 19 hours · Nov 16, 2026" (red), "…in 9 days · Nov 25, 2026" (amber) — identical to Flutter; minutes tier and colours unit-tested. |
| C-216 | Error line | pass | "Egress ended early: participant left" in red, 2 lines max, both apps. |
| C-217 | Play button | pass | full width; "Loading..." while fetching, "Play Recording", "Processing..." (disabled), "Not Ready Yet" (disabled) — live. |
| C-218 | Playback link | pass | `getClassRecordingPlaybackUrl {recordingId, activeRole: "parent"}` captured live; dev cannot sign URLs so the server returned its download-token fallback (inventory item 7, server behaviour). |
| C-219 | Link failed | pass | live: red floating message "Recording file is not available yet. Please try again shortly.", button back to Play Recording; the list is not reset (the student page put it in the page error card). |
| C-220 | Inline player | pass / could not test (full screen) | Flutter's player rebuilt: loading box, overlay back 10 s / play-pause / forward 10 s toggled by a click, seek bar, ±10 s, "00:02 / 00:25", full-screen button, "Failed to load video" + Retry, Close Player. Live: play, +10 s (2.5→12.7), −10 s, seek to 80 % (20.0 s), pause. No download: no native controls, `controlsList=nodownload`, right-click menu suppressed (owner Q5 default). The full-screen request is issued (checked) but the test browser pane does not grant full screen. |
| C-221 | Links remembered | pass | live: close and reopen made no second call. |
| C-222 | Refresh | pass | live from the fragments level: back to "Students", search cleared, players closed, links forgotten. No pull-to-refresh on the web (refresh button only). |
| C-223 | Back | pass | one level up, search cleared, player closed when leaving fragments. Differs (fix, inventory item 5): the search box is emptied too (Flutter keeps stale text in the box while the filter is cleared). |
| C-224 | No other actions | pass | none added. |
| C-225 | Dual-role | pass | the parent area only opens as parent, so `activeRole: "parent"` is always the active role. |
| C-226 | Language | pass | English as Flutter; "Try Again" → "Réessayer" in French (unit-tested; French not switched live to avoid changing the shared dev parent's language). |
| C-300 | Sidebar → Curriculum Books | pass | listed, inside the shell. |
| C-301 / C-303 / C-307 | Phone entry, phone notice, phone viewer | n/a | phones stay on Flutter. |
| C-302 | Header panel | pass | badge, heading, paragraph, three chips — same text, colours and sizes as Flutter (screenshots side by side). |
| C-304 | The four books | pass | same order, titles, subtitles, descriptions, files, colours (unit test pins them); 2 columns from 1100 px window width as Flutter (live 1280 px: 2 × 476 px; 375 px: 1 column, no sideways scroll). All 8 files answer 200 publicly (checked with HEAD requests). |
| C-305 | Book card | pass | slideshow icon, Arabic title in Cairo 800, coloured subtitle, description, filled Open / outlined Download. |
| C-306 | Open (web) | pass | `<pdf>#view=Fit` in a new tab, as Flutter web (owner Q7 default: new tab, not the student page's in-page reader); live: a blocked new tab shows "Unable to open this curriculum book right now." |
| C-308 | Download | pass | the `.pptx` in a new tab; same failure message. |
| C-309 | Absent features | pass | none added. |
| C-310 | Language | pass | English as Flutter; "Download" → "Télécharger" (unit-tested). |
| A-019 / C-330 | Quran item | differs (default) | Flutter web: clicking it does nothing (confirmed live in the dev build). Next: opens the reader at `/parent/quran/` (plan default). |
| C-331 | Phone entry | n/a | phones stay on Flutter. |
| C-332…C-342, C-344…C-347, C-350…C-352, C-355, C-356 | Reader | differs (default: the existing web reader) | the shared web reader students and teachers use, unchanged, so every difference the inventory lists between it and the Flutter reader applies as-is (picker grid, pause/resume, word highlight, transliteration, inline tick/mic, goal chip instead of panel, streak = days that met the target, completion message). Live as the parent: Surah 1 loads, Play plays `Alafasy/mp3/001001.mp3` with "Playing verse 1:1", ticking 2 ayahs → "Memorized 2/7", goal created → "Today's goal" with 3 ayahs, Stop plan → back to Surah 1 with ticks kept. |
| C-341 | Ticking writes | pass / known issue | writes `quran_memorization/{parent uid}` (`memorized.1 = [1, 2]`); no document for either child. Inventory item 20 confirmed live: the count is stored as a literal field `daily_log.2026-11-15`, so "Today 2/3" reads "Today 0/3" after a reload and never reaches the phone. Shared component, carried as-is (owner Q10 default); see decisions. |
| C-343 | No-goal panel | differs (default) | "Goal" chip (web reader). |
| C-348 | Stop plan | pass / differs | plan removed, ticks kept (checked in Firestore); the web reader does not reset `reminder` (no reminder on the web). |
| C-349 | Daily reminder | differs (default) | none on the web (owner Q8 default: no bell). |
| C-353 | Recitation callables | could not test | `transcribeRecitation` and `checkPronunciation` are not deployed on alluwal-dev; same callables and payloads as the student page (code), which accept any signed-in user. |
| C-354 | Whose data | pass | the parent's own uid, as on the parent's phone (owner Q2 default). |

Decisions (inventory owner questions, "same as today" unless broken):

1. Quran on parent web: included, opening the existing web reader (plan default), tracking the parent's own progress as on phones (Q1, Q2).
2. Recordings on phones: unchanged — not reachable (Q3).
3. List size: the server's 100 newest, no "load more" (Q4).
4. Playback: no download control, as the Flutter player (Q5).
5. Teacher e-mail/phone search: kept (Q6).
6. Books "Open": new tab, as Flutter web (Q7).
7. No reminder bell on the web (Q8).
8. Recitation recordings kept server-side for parents too — server unchanged (Q9).
9. Web daily-goal count (item 20): carried as-is, because fixing it changes the shared reader for students and teachers. Owner decision needed (Q10).
