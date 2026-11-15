# Parent web area: Flutter → Next.js

Owner's rule (2026-11-13): the new screens must do what the old ones do. Nothing
broken. Every feature tested and matched before any parent is switched over.

## Source of truth

The three inventories in this folder list what the Flutter parent area does today
(506 checklist items):

- `inventory_A_dashboard.md` — entry/routing, shell, home dashboard, child detail, profile, settings, ParentService (A-001…A-118)
- `inventory_B_money_forms.md` — invoices, invoice detail + PDF, pay screen, payment history, suspension, money card, parent forms, adult-student pages (B-001…B-149)
- `inventory_C_classes_chat_cutover.md` — classes + join, recordings, books, Quran, chat, circles, notifications, Next.js counterparts, cut-over mechanics, production numbers (C-001…C-732)

Every slice below is built against these item IDs and tested item by item on
alluwal-dev with a seeded parent, side by side with the Flutter screen.

## Defaults taken where the inventory raised a question

"Same as today" unless today is plainly broken. Each can be overridden by the owner.

| Question | Default |
|---|---|
| One URL per screen (Back and refresh work; state not kept between screens) | Yes — same as the student and teacher pages |
| Two attendance numbers on the home page (class-status vs join-based) | Keep both exactly as they are |
| "All-time" figures only cover ~60 days of live classes | Same as today |
| Quran menu item (dead on web today) | Make it open the existing reader |
| Junk text ("Assigned By Assignedbyname", "Failed To Save Profile E", raw error codes) | Show a correct plain sentence |
| Money card shows $0.00 while loading / on error | Show a loading and an error state; numbers computed exactly as today |
| "Overdue" filter (only finds invoices the server marked overdue) | Same as today |
| Invoice PDF wording and print dialog | Same as today |
| Payment history lists every attempt | Same as today |
| Parent+student accounts | Follow the active role, as Flutter does; switcher works both ways |
| Sidebar search, favourites, folding, collapse, reset | Keep all |
| Chat actions that fail today (clear, block, leave group, forward to support) | Make them work rather than carry a failure |
| Recordings (none stored today) | Build the page; it shows the same empty state |
| After paying on the web a parent lands on the public home page | Land on a parent "payment received / cancelled" page — needs a small change to the payment function, done as its own reviewed step |
| Roll-out | Staged like teachers: `settings/parent_web_cutover` (off → allowlist → all), fails closed, one switch sends everyone back |

## Slices

0. **Foundation** — parent session + children resolver (same fields and fallbacks as ParentService), ParentShell with the same sections/labels/order, route guard, cut-over switch (off). No parent sees anything.
1. **Home + child detail** — A-030…A-085.
2. **Money** — invoices, detail, PDF, pay, payment history, suspension banner, money card (B-001…).
3. **Classes + join** — C-001…C-030 (no change to class or Zoom behaviour).
4. **Chat** — C-400…C-484.
5. **Forms, Profile, Settings, Books, Recordings, Quran** — B forms items, A-086…A-095, C-200…C-356.
6. **Cut-over** — dev sign-off of every item → allowlist of a few parents → everyone. Phones stay on Flutter.

A slice is done when its checklist items are each marked pass / differs-on-purpose
(with the default above) / could-not-test in `PARITY.md`, with the evidence.
