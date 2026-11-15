# Inventory B — Parent money screens, access suspension, parent forms

## Summary (read this first)

1. Scope: Flutter parent Invoices, Invoice detail, PDF, Pay screen, Payment history, the dashboard financial card, unpaid-family suspension, parent Forms, plus what the Next.js adult-student Invoices/Payments pages already do. Repo `~/alluwal-work/base` at `0a49330` (main), read 2026-11-13. Nothing was changed.
2. There is NO Next.js parent area today (`apps/web/src/app` has no `parent/`). The closest reusable code is `StudentInvoicesPage.tsx`, `StudentPaymentsPage.tsx`, `StudentFormsPage.tsx` + `components/forms/FormFields.tsx`.
3. Paying is always "the whole remaining balance of one invoice". There is no partial payment, no pay-all, no amount field, no saved-card screen. Partial balances only come from payments an admin records by hand.
4. Web pays by Stripe Checkout redirect (`createPaymentSession`); phones pay by the in-app Stripe sheet (`createPaymentIntent`). Only the server marks anything paid (Stripe webhook, or an admin recording a payment by hand).
5. SURPRISE: in production both Stripe return addresses (success AND cancel) are the bare public home page `https://alluwaleducationhub.org`. After paying on the web a parent is dropped on the marketing site with no "paid" message; the Flutter polling / "Check Payment Status" code never runs on web.
6. SURPRISE: the "Overdue" filter chip asks the database for stored status `overdue`, which the server only writes after a part-payment on a late invoice. Ordinary late invoices sit under "Pending" with a red OVERDUE badge.
7. Suspension never blocks the parent. The server sets `users/{child}.access_suspended`; only the child's class-join is refused. The parent sees a red banner and per-invoice lock badges. `AccessSuspendedScreen` is dead code (never shown).
8. The dashboard card shows exactly two numbers, Outstanding and Overdue. The all-time "paid" total is still computed but is not displayed (confirmed).
9. Parent forms = audience-filtered templates + two built-in forms (absence excuse, parent feedback). Submitting the excuse form only writes a `form_responses` document: no class is excused, nobody is notified.
10. 149 checklist items (B-001 … B-149), then lists of broken/dead things, every place two screens can show different money, and owner questions.

Conventions used below
- "Sees/does" is what the parent experiences. English strings are from `lib/l10n/app_en.arb`; French and Arabic exist for every `l10n` key. Strings written as plain literals in the Dart code are English-only today and are marked (hard-coded).
- Money in Flutter is `NumberFormat.simpleCurrency(name: invoice.currency)`; the app never sets `Intl.defaultLocale`, so the output is always US style (`$1,234.50`) whatever the app language. Dates are likewise always English (`Nov 13, 2026`).
- "Next:" = Next.js counterpart. "none" means it has to be built.
- Paths are relative to `~/alluwal-work/base` unless they start with `apps/web`.

---

## A. Invoices list — `lib/features/parent/screens/parent_invoices_screen.dart`

**B-001 — Ways into the Invoices list**
- Sees/does: Parent opens Invoices from (a) sidebar Finance → Invoices; (b) dashboard tile "Invoices / View And Pay"; (c) dashboard "Recent Invoices → See all" (hard-coded "See all"); (d) dashboard card "Pay Now" and (e) red suspension banner button "View & pay invoices" — (d) and (e) open the list already filtered to Pending.
- Source: `parent_dashboard_layout.dart:93`; `dashboard/config/sidebar_config.dart:546-551`; `parent_dashboard_screen.dart:209-216, 255-264, 270-286, 399-409`.
- Data: none (navigation). `parentId` = signed-in uid.
- Next: none. A Next parent area needs the same five entry points; the two "pre-filtered to Pending" entries need a `?status=pending` style deep link.
- Platform: web/desktop has the sidebar; the phone app has no Invoices tab for parents (tabs are Home, Classes, Chat, Forms, Tasks, Library — `mobile_dashboard_screen.dart:586-596`), so phones reach it only through the dashboard.

**B-002 — Page chrome**
- Sees/does: White app bar titled "Invoices" (l10n `invoices`), page background `#F8FAFC`. All text on the page can be selected/copied (`SelectionArea`).
- Source: `parent_invoices_screen.dart:63-75`.
- Next: none.

**B-003 — Main query: invoices billed to this parent**
- Sees/does: Lists the parent's invoices, newest due date first.
- Source: `invoice_service.dart:15-25, 56-62`.
- Data: `invoices` where `parent_id == uid` [and `status == <chip>` when a chip is selected] `orderBy due_date desc` `limit 100`, live (`snapshots()`). Uses composite indexes `(parent_id, due_date desc)` and `(parent_id, status, due_date desc)` — both exist in `firestore.indexes.json`.
- Rules: `firestore.rules:1035-1039` read if `parent_id == uid || student_id == uid || payer_id == uid || isAdmin()`.
- Next: `apps/web/src/components/StudentInvoicesPage.tsx:101-112` runs `parent_id == uid` with NO status filter, NO orderBy, NO limit (sorts in the browser).

**B-004 — Second query: invoices raised against the signed-in person as student**
- Sees/does: An adult student (or any account that is the `student_id` of an invoice) also sees invoices whose `parent_id` is someone else/empty.
- Source: `invoice_service.dart:27-34, 64-78`. Only runs when the screen's `parentId` equals the signed-in uid (so not when an admin views a parent).
- Data: `invoices` where `student_id == uid`, no order, no limit, live. If this stream errors it is treated as an empty list (the page still loads).
- Rules: same rule, `student_id == uid` branch.
- Next: same second query at `StudentInvoicesPage.tsx:114-125`.

**B-005 — Merge, sort and cap**
- Sees/does: The two result sets are merged by document id, filtered again by the selected status, sorted by `due_date` descending, and cut to the first 100. Nothing is shown until BOTH queries have answered once.
- Source: `invoice_service.dart:42-54`.
- Next: merges the same way, no 100 cap, sort by due date desc with missing dates last (`StudentInvoicesPage.tsx:91-99`).
- Note: a parent with more than 100 invoices silently loses the oldest ones; there is no "load more".

**B-006 — Status filter chips**
- Sees/does: Horizontal row of pill chips: "All", "Pending", "Paid", "Overdue", "Cancelled" (l10n `timesheetAll`, `timesheetPending`, `parentInvoicesPaid`, `overdue`, `shiftCancelled`). Selected chip = blue `#0386FF` with white text; others white with grey border. One chip at a time; "All" clears the filter. The list can be opened with a chip pre-selected (`initialStatus`).
- Source: `parent_invoices_screen.dart:27-35, 177-233`.
- Data: the chip changes the Firestore query (`status == 'pending' | 'paid' | 'overdue' | 'cancelled'`), i.e. it filters on the STORED status string.
- Next: `StudentInvoicesPage.tsx:17-23, 157-164` has the same five chips but filters in the browser on a DERIVED status (see B-007). Chips are centred and wrap instead of scrolling.

**B-007 — "Overdue" and "Pending" chips do not mean what the badges say (existing inconsistency)**
- Sees/does: A late unpaid invoice shows a red OVERDUE badge but is listed under "Pending", not under "Overdue". "Overdue" lists only invoices whose stored status is `overdue`.
- Source: filter `invoice_service.dart:21-23`; badge `invoice_card.dart:37-49`; the only writers of `status: 'overdue'` are `functions/handlers/payments.js:1396-1401` (card payment that does not clear a late invoice) and `:1674-1679` (manual part-payment on a late invoice). No scheduled job flips pending → overdue.
- Next: `effectiveStatus()` (`StudentInvoicesPage.tsx:354-360`) derives overdue from due date + balance, so its "Overdue" chip lists every late invoice and its "Pending" chip excludes them. This is a deliberate behaviour difference — decide which one is "the" behaviour before matching.

**B-008 — Search box**
- Sees/does: Text box with a magnifier and the hint "Search invoice, parent, student, email, phone, or ID" (l10n `searchInvoiceNumber`). Typing filters the loaded cards instantly.
- Source: `parent_invoices_screen.dart:82-100, 122-127`.
- Data: client-side only; matches when `invoice_number` contains the text, case-insensitive. It does NOT search parent, student, email, phone or ID despite the hint.
- Next: `StudentInvoicesPage.tsx:157-164, 197` — same hint, matches invoice number OR student name (and only a `student_name` stored on the invoice, which invoices do not carry, so in practice number only).

**B-009 — Loading state**
- Sees/does: Centred spinner until both queries answer.
- Source: `parent_invoices_screen.dart:114-116`.
- Next: "Loading your invoices…" with a spinner (`StudentInvoicesPage.tsx:223-229`).

**B-010 — Error state (effectively unreachable; spinner forever instead)**
- Sees/does: The code has an error message "Failed To Load Invoices NMessage" (l10n `failedToLoadInvoicesNMessage`, a broken auto-generated string). In practice the service swallows stream errors (`handleError` without rethrow), so a failed query leaves the spinner turning forever.
- Source: `parent_invoices_screen.dart:117-119, 247-258`; `invoice_service.dart:61, 85-88`.
- Next: on a query error the Next page treats that query as empty and shows "No invoices to show." (`StudentInvoicesPage.tsx:108-111`) — a different failure face; neither tells the parent something went wrong.

**B-011 — Empty state**
- Sees/does: Centred grey text "No Invoices Found" (l10n `noInvoicesFound`) when there are no invoices, or none match the chip/search.
- Source: `parent_invoices_screen.dart:129-131, 235-245`.
- Next: dashed box "No invoices to show."

**B-012 — Student name on each card**
- Sees/does: Each card shows the name of the invoice's first student once it has loaded (blank until then).
- Source: `parent_invoices_screen.dart:43-59, 137-143`.
- Data: `users/{invoice.student_id}` one-time read, cached per screen; name = `first_name + ' ' + last_name`; falls back to the raw student id if the user has no name or the read fails.
- Rules: `firestore.rules:279` any signed-in user may read any user doc.
- Next: `StudentInvoicesPage.tsx:133-155` same lookup; shows nothing (not the id) when the name is missing.
- Note: a family invoice covering several children (`student_ids`) shows only the first child here.

**B-013 — Tap a card**
- Sees/does: Opens Invoice Details for that invoice.
- Source: `parent_invoices_screen.dart:144-150`.
- Next: MISSING — the Next card is not clickable; there is no invoice detail page at all.

**B-014 — "Pay Now" on a card**
- Sees/does: Opens the Pay Invoice screen for that invoice. Button is absent when the invoice is fully paid or cancelled.
- Source: `parent_invoices_screen.dart:151-159`.
- Next: `StudentInvoicesPage.tsx:241-249` shows a confirm dialog ("Continue to payment — You are about to pay $X for <invoice>. You will be taken to Stripe to complete the payment." / "Continue") and then goes straight to Stripe; there is no separate pay screen.

**B-015 — Live updates**
- Sees/does: Cards change by themselves when an invoice is paid, cancelled or edited (no refresh needed).
- Source: `invoice_service.dart:91-104` (`snapshots()`).
- Next: also live (`onSnapshot`).

**B-016 — Admin viewing another person's list**
- Sees/does: When `parentId` is not the signed-in user (admin use), only the `parent_id` query runs.
- Source: `invoice_service.dart:27-34`.
- Next: n/a for parents; keep in mind if the component is shared.

**B-017 — Empty `parentId` edge**
- Sees/does: If the uid cannot be resolved the layout passes `''`; the query for `parent_id == ''` is refused by rules and the page spins forever.
- Source: `parent_dashboard_layout.dart:86-95`.
- Next: guard explicitly.

---

## B. Invoice card — `lib/features/parent/widgets/invoice_card.dart` (used by the list and by the dashboard "Recent Invoices")

**B-018 — Card frame and left colour bar**
- Sees/does: White rounded card, grey border, soft shadow, 4px colour bar on the left: red `#DC2626` if late and unpaid; green `#059669` if status paid; grey `#6B7280` if cancelled; amber `#D97706` otherwise (pending, or stored overdue that is not actually late).
- Source: `invoice_card.dart:24-35, 68-93`.
- Next: `StudentInvoicesPage.tsx:265, 271` bar is 6px; colours green `#16A34A`, red `#DC2626`, grey `#94A3B8`, amber `#F59E0B`.

**B-019 — Invoice number**
- Sees/does: Bold invoice number; the word "Invoice" (hard-coded) if the invoice has no number.
- Source: `invoice_card.dart:54-56, 106-113`. Field `invoice_number` (or `invoiceNumber`).
- Next: shows the document id when there is no number (`:365`).

**B-020 — Status badge**
- Sees/does: Pill, upper-case, hard-coded English: "OVERDUE" (when late and unpaid, whatever the stored status), else "PAID", "OVERDUE", "CANCELLED", "PENDING" from stored status. Same colour as the left bar. Any unknown stored status (e.g. `partial`, `sent`, `unpaid`) is treated as PENDING.
- Source: `invoice_card.dart:37-49, 256-281`; status parsing `models/invoice.dart:281-288`.
- "Late and unpaid" = not fully paid AND now is after `due_date` (exact timestamp, device clock) AND status is not cancelled — `models/invoice.dart:253-256`.
- Next: `:338-360` translated badge text (`t(status)`); PAID/CANCELLED decided by stored status only; unknown statuses are printed as-is (not mapped to pending).

**B-021 — Student line**
- Sees/does: Small person icon + student name, only when a name is available.
- Source: `invoice_card.dart:121-140`.
- Next: same.

**B-022 — Billing period line**
- Sees/does: Small calendar icon + period in blue, e.g. "Aug 2026" or "Aug 2026 - Oct 2026"; hidden when there is no period.
- Source: `invoice_card.dart:142-160`; rule in `models/invoice.dart:259-279, 311-322`.
- Data: uses `period_start` + `period_end` (first `yyyy-MM` found in each; same month → one label, else "start - end", `MMM y`); else `period` (also `billing_period` / `billingPeriod`): `a..b` → range, a single `yyyy-MM` → FULL month name ("August 2026"), anything else → the raw text.
- Next: `:372, 380-386` uses `period` only and only when it is exactly `yyyy-MM` → "Aug 2026"; ignores `period_start/period_end`, so multi-month invoices show a single month or raw text. DIFFERENT.

**B-023 — "Amount due"**
- Sees/does: Small grey label "Amount due" (hard-coded) and the amount in large type: `max(0, total_amount − paid_amount)` in the invoice currency, e.g. `$68.00`. Green when fully paid, near-black otherwise.
- Source: `invoice_card.dart:167-195`; `models/invoice.dart:245-251`.
- Next: `:263, 294-297` prints `$` + `toFixed(2)` — always a dollar sign whatever `currency` says, no thousands separator (`$1234.50` vs Flutter `$1,234.50`), and the amount is coloured by status (red when overdue, amber when pending) rather than black.

**B-024 — Due-date chip**
- Sees/does: Not late: grey chip with calendar icon and the due date as `MMM d` (e.g. "Nov 30", no year). Late: red chip with warning icon and "N day(s) overdue" (hard-coded; "1 day overdue" singular).
- Source: `invoice_card.dart:283-333`. Days = whole days between today's midnight and the due timestamp, so an invoice that became late earlier today reads "0 days overdue".
- Next: `:264, 299-309` shows "N days overdue" only when N ≥ 1 (N = whole 24h periods since the due timestamp), otherwise the date chip; so on the first late day Next shows the date while the badge already says overdue.

**B-025 — Access cut-off warning strip**
- Sees/does: Only on unpaid, non-cancelled invoices, a full-width strip (hard-coded English): cut-off passed → red lock "Access suspended N day(s) ago"; less than 24h either side → red "Access suspended today"; 1–3 days ahead → red text on orange "Access cut off tomorrow" / "Access cut off in N days"; 4–14 days ahead → amber "Access cut off in N days"; more than 14 days ahead → nothing.
- Source: `invoice_card.dart:205-212, 335-405`.
- Data: cut-off = `access_cutoff_date`, or `due_date + 1 day` when the invoice has none (`models/invoice.dart:234-236`), the same fall-back the server uses.
- Note: "today" is also shown during the last 24h BEFORE the cut-off, i.e. while access is still on.
- Next: `:312-319` shows only "Access suspended N day(s) ago", only when the invoice has an explicit `access_cutoff_date` in the past and money is owed. No advance warning, no due+1 fall-back, and it is not hidden for cancelled invoices. DIFFERENT.

**B-026 — "Pay Now" button**
- Sees/does: Full-width blue `#1A56DB` button "Pay Now" (l10n `payNow`) with card icon; shown only when not fully paid, not cancelled, and the screen supplied a pay action.
- Source: `invoice_card.dart:58-60, 214-240`.
- Next: `:266, 321-331` shown when stored status is not paid/cancelled AND balance > 0; label turns into "Starting checkout…" with a spinner.

**B-027 — What counts as "fully paid"**
- Sees/does: An invoice is treated as settled when `total_amount <= 0` (scholarship / fully covered by credit) or `paid_amount >= total_amount`, regardless of the stored status.
- Source: `models/invoice.dart:242-245`.
- Next: Pay button uses balance > 0 (same effect) but the PAID badge follows stored status only. So an invoice with stored `paid` and a remaining balance shows "PAID + Pay Now + amount due" in Flutter and "PAID, no button" in Next; an invoice fully paid by amount but still stored `pending` shows PENDING in both.

**B-028 — Missing-field defaults that affect money display**
- Sees/does: An invoice with no `due_date` is shown as due 30 days from the moment it is read (so never overdue, cut-off always ~31 days away); no `issued_date` → "today"; no `currency` → USD; amounts read from `total_amount`/`totalAmount`, `paid_amount`/`paidAmount`, strings parsed as numbers.
- Source: `models/invoice.dart:145-199`.
- Next: missing due date → no chip and sorted last; no overdue.

---

## C. Invoice details — `lib/features/parent/screens/invoice_detail_screen.dart` + `widgets/beautiful_invoice_widget.dart`

**B-029 — Loading the invoice (one-time, not live)**
- Sees/does: Title "Invoice Details". Spinner, then the page. The invoice is read ONCE; if it is paid while the page is open the header, totals and buttons do not change until the page is reopened (the payments list at the bottom IS live).
- Source: `invoice_detail_screen.dart:40-52`; `invoice_service.dart:106-112`.
- Data: `invoices/{id}` get.
- Rules: invoices read rule (B-003).
- Next: none — no detail page exists.

**B-030 — Load failure / not found**
- Sees/does: Centred grey text "Failed To Load Invoice NMessage" (broken l10n string) for any error, including a missing invoice or one that belongs to someone else.
- Source: `invoice_detail_screen.dart:46-52, 318-330`.
- Next: none.

**B-031 — "Pay Invoice" button**
- Sees/does: Left button, blue `#0386FF`, card icon. Label "Pay Invoice" (l10n `payInvoice`) → opens the Pay screen. When fully paid: label "Paid", greyed out. When cancelled: label still "Pay Invoice", greyed out.
- Source: `invoice_detail_screen.dart:70-106`.
- Next: none.

**B-032 — "Download Pdf" button**
- Sees/does: Right button, outlined, PDF icon, label "Download Pdf" (l10n `downloadPdf`). Always enabled (paid, unpaid, cancelled).
- Source: `invoice_detail_screen.dart:108-129`. Behaviour in section D.
- Next: none.

**B-033 — Status pill under the buttons**
- Sees/does: Pill with "OVERDUE" (late and unpaid) or the stored status upper-cased ("PENDING", "PAID", "OVERDUE", "CANCELLED"). Colours: red `#DC2626` late; green `#16A34A` paid; grey `#6B7280` cancelled; amber `#F59E0B` otherwise.
- Source: `invoice_detail_screen.dart:54-57, 134-154, 398-409`.
- Next: none.

**B-034 — Invoice sheet: header**
- Sees/does: White "paper" card with a blue gradient strip on top. Logo (`assets/Alluwal_Education_Hub_Logo.png`, school icon if it fails), "Alluwal Education Hub", "billing@alluwaleducationhub.org"; on the right the word "INVOICE" in blue and a status badge (same wording rule as the cards; red when late, otherwise green paid / red stored-overdue / grey cancelled / amber pending).
- Source: `beautiful_invoice_widget.dart:117-142, 229-331`; company details hard-coded in `lib/features/settings/services/mock_company_service.dart:5-15`.
- Next: none.

**B-035 — "FROM" block**
- Sees/does: "FROM", "Alluwal Education Hub", "11 McKeever Pl, Brooklyn, NY 11225, United States", phone "+1646-338-1286", email "billing@alluwaleducationhub.org". All hard-coded in the app, not read from settings.
- Source: `beautiful_invoice_widget.dart:357-387`; `mock_company_service.dart`.
- Next: none (server PDF has the same constants in `functions/utils/invoice_pdf.js:7-16`).

**B-036 — "BILLED TO" block**
- Sees/does: "BILLED TO", the parent's full name (or "Parent / Guardian" if not found), then the first student's name with a person icon (omitted if not found), then the billing period in blue with a calendar icon (omitted if none). Two grey placeholder bars while the names load (15-second cap, then fall-backs).
- Source: `beautiful_invoice_widget.dart:34-52, 389-446`; `invoice_data_service.dart:11-50`.
- Data: `users/{parent_id}` and `users/{student_id}` (first_name, last_name).
- Next: none.

**B-037 — Three facts row**
- Sees/does: "Invoice #" (number, or document id if none), "Issue Date" and "Due Date" both as `MMM d, y` (e.g. "Nov 1, 2026"); the due date turns red when the invoice is late. Side by side on wide screens, stacked rows below 560px.
- Source: `beautiful_invoice_widget.dart:450-550`. Fields `issued_date`, `due_date`.
- Next: none.

**B-038 — Line items table**
- Sees/does: Blue header row. Wide (≥560px): "Description", "Qty", "Price", "Total". Narrow: "Description" and "Total" only (quantity and unit price are not shown on phones/narrow windows). One row per `items[]` entry in stored order, zebra-striped; totals bold, right-aligned. No items → grey box "No Items On This Invoice".
- Source: `beautiful_invoice_widget.dart:555-644`.
- Data: `items[].description`, `.quantity` (default 1), `.unit_price`/`unitPrice`, `.total`.
- Next: none.

**B-039 — Discounts and family credits appear as negative lines**
- Sees/does: Monthly family invoices carry discount lines and "Family credit applied (reason)" lines as ordinary rows with negative amounts (shown as `-$10.00`). There is no separate discount/credit summary.
- Source: server writes them — `functions/utils/finance_billing_math.js:241-290`, `functions/utils/finance_invoice_math.js:243-272`; the widget just prints `items`.
- Data: invoice also stores `subtotal`, `discount_total`, `credit_applied`, `credit_lines` — the Flutter parent screens ignore all four.
- Next: none.

**B-040 — Summary box**
- Sees/does: Right-aligned box: "Subtotal" = `total_amount` (the already-discounted invoice total, NOT the stored `subtotal` field); "Paid Toward Balance" = "− $X" in green, shown only when `paid_amount > 0`; highlighted "Amount Due" = `max(0, total − paid)`, coloured green when settled, red when late, blue otherwise.
- Source: `beautiful_invoice_widget.dart:649-716`.
- Next: none.

**B-041 — Sheet footer**
- Sees/does: Small logo, "Alluwal Education Hub", and on the right the word "Signature" above an empty line (no name).
- Source: `beautiful_invoice_widget.dart:721-782`.
- Next: none.

**B-042 — "Decision history" box (shows staff identity to parents)**
- Sees/does: When the invoice records who created it, a box titled "Decision history" with one row: "Created invoice", "By <staff member's name>", their role in small print, the creation date/time, and a hover tooltip containing the staff member's email, role and user id. System-created invoices read "By <system automation label>".
- Source: `invoice_detail_screen.dart:159-177`; `lib/core/widgets/decision_history_card.dart`; `lib/core/services/decision_audit_service.dart:18-92`.
- Data: tries `decision_audits/invoice_{id}/events` (order `recorded_at desc`, limit 20) — refused for parents, so they only get the fall-back row built from invoice fields `created_by`, `created_by_name`, `created_by_email`, `created_at`, plus `users/{created_by}` for the role.
- Rules: `firestore.rules:1086-1094` decision audits are admin-only.
- Next: none. OWNER DECISION: should parents see which staff member created an invoice at all?

**B-043 — "Payments" list for this invoice**
- Sees/does: Heading "Payments". One row per payment attempt for this invoice, newest first: coloured dot, amount in the invoice currency, and "STATUS • Nov 13, 2026" (status = PENDING/PROCESSING/COMPLETED/FAILED hard-coded upper-case; date = created date). Dot colours: completed green `#16A34A`, failed red `#DC2626`, processing blue `#2563EB`, pending amber `#F59E0B`. Rows are not clickable.
- Source: `invoice_detail_screen.dart:179-262, 376-396`; `payment_service.dart:50-65`.
- Data: live `payments` where `invoice_id == id` AND `parent_id == uid` (admins: `invoice_id` only).
- Rules: `firestore.rules:1063-1068`.
- Next: none.
- Note: because the query pins `parent_id == uid`, an adult student whose payment rows carry a different/empty `parent_id` sees none here.

**B-044 — Payments list states**
- Sees/does: Spinner while loading; "No payments for this invoice yet." in a white info box (hard-coded); red box "Failed to load payments: <raw error>" on failure.
- Source: `invoice_detail_screen.dart:198-226, 332-374`.
- Next: none.

---

## D. Invoice PDF — `services/invoice_pdf_service.dart`, `utils/invoice_printing.dart`

**B-045 — Producing the PDF**
- Sees/does: Tapping "Download Pdf" shows a blocking spinner, builds the PDF inside the app (no server call, nothing stored), then closes the spinner. Gives up after 45 seconds. Any failure shows a red snack bar "Failed To Generate Pdf E" (broken l10n string).
- Source: `invoice_detail_screen.dart:274-316`; `invoice_pdf_service.dart:13-84`.
- Data: re-reads `users/{parent_id}` and `users/{student_id}` for names. Uses the invoice as loaded when the page opened (stale if paid since).
- Next: none. A Node twin of this exact layout already exists server-side: `functions/utils/invoice_pdf.js` (used for email attachments).

**B-046 — Web: opens the browser print dialog, it does not download a file**
- Sees/does: On the web the PDF opens in the browser's print/preview dialog (`Printing.layoutPdf`); the parent chooses "Save as PDF" or a printer there. No file name is passed, so the browser's default document name is used.
- Source: `utils/invoice_printing.dart:9-20`.
- Platform: web-only branch (`kIsWeb`).
- Next: none. Decide: keep "print dialog" or give a real download.

**B-047 — Phone: share sheet with a named file**
- Sees/does: On iOS/Android the system share sheet opens with the file `Invoice_<number>.pdf`.
- Source: `utils/invoice_printing.dart:17-19`; name built at `invoice_detail_screen.dart:297-304`.
- File name: `Invoice_` + invoice number (or document id if no number) with every run of characters other than letters, digits, `_`, `-` replaced by `_`, + `.pdf` (e.g. `Invoice_INV-2026-0142.pdf`).
- Platform: mobile-only.

**B-048 — Page set-up**
- Sees/does: One A4 page, 40pt margins, built-in PDF font, English only. It is a single `pw.Page`: a very long item list is not continued on a second page.
- Source: `invoice_pdf_service.dart:34-82`.

**B-049 — PDF header**
- Sees/does: Blue vertical bar, a light-blue square with the letters "AEH" (no logo image), "Alluwal Education Hub" (22pt bold), "11 McKeever Pl, Brooklyn, NY 11225, United States", "Contact: +1646-338-1286", "Email: billing@alluwaleducationhub.org".
- Source: `invoice_pdf_service.dart:86-160`.

**B-050 — PDF title band**
- Sees/does: Light-blue band: "INVOICE", "Tuition & fees", then the invoice number (or document id).
- Source: `invoice_pdf_service.dart:49-51, 162-219`.

**B-051 — PDF facts box**
- Sees/does: Grey box, label/value rows: "Invoice Number"; "Payment Date" = the ISSUE date (mislabelled) as "November 1, 2026"; "Due Date" same format; "Access cutoff" only when the invoice has an explicit `access_cutoff_date`; "Billing period" only when one exists.
- Source: `invoice_pdf_service.dart:221-248`.

**B-052 — PDF payer box**
- Sees/does: Grey box "From: <parent name>  |  Student: <student name>" and "Billing period: <period, or the issue month e.g. 'November 2026'>". Falls back to the word "Parent" and to the raw student id. The whole box is omitted if neither name could be read. (On screen the same person is under "BILLED TO"; the PDF calls them "From".)
- Source: `invoice_pdf_service.dart:28-31, 58-65, 279-309`.

**B-053 — PDF items table**
- Sees/does: Blue header "Description | Qty | Price | Total", one row per item, totals bold; or a grey box "No items on this invoice". Always four columns (unlike the narrow on-screen table).
- Source: `invoice_pdf_service.dart:311-384`.

**B-054 — PDF totals**
- Sees/does: "Subtotal" = `total_amount`; "Paid" = `paid_amount` (always printed, even $0.00); divider; "Remaining Balance" in blue = `max(0, total − paid)`.
- Source: `invoice_pdf_service.dart:386-428`.
- Note: screen says "Paid Toward Balance"/"Amount Due"; PDF says "Paid"/"Remaining Balance". Same numbers, different words.

**B-055 — PDF footer**
- Sees/does: "Received by: Muhammed Barry" (hard-coded name) and "Signature" with a blank line.
- Source: `invoice_pdf_service.dart:430-475`; `mock_company_service.dart:18-23`.

**B-056 — What the PDF does not contain**
- Sees/does: No PAID/OVERDUE/CANCELLED status, no list of payments, no logo image, no second/third child's name, no translation. A cancelled invoice prints exactly like a live one.
- Source: whole file.

**B-057 — The emailed PDF is a separate renderer with the same layout**
- Sees/does: Invoice and receipt emails attach `<invoice number>.pdf` (non `[a-zA-Z0-9._-]` → `_`) drawn by server code that mirrors B-049…B-055 line for line, including "Payment Date", "Received by: Muhammed Barry".
- Source: `functions/utils/invoice_pdf.js`; attachment `functions/handlers/payments.js:319-342`.
- Next: this is the natural thing to reuse if the web download should match the emailed file exactly.

---

## E. Pay Invoice screen — `lib/features/parent/screens/payment_screen.dart`

**B-058 — Screen and live invoice**
- Sees/does: Title "Pay Invoice". The invoice box on this screen is LIVE: it changes the moment the server records the payment.
- Source: `payment_screen.dart:246-290`; `invoice_service.dart:115-126`.
- Data: `invoices/{id}` `snapshots()`.
- Rules: invoices read rule.
- Next: none as a screen. `StudentInvoicesPage.tsx` pays straight from the card after a confirm dialog.

**B-059 — Loading / failure / missing**
- Sees/does: Spinner while first loading; "This invoice could not be loaded. Please try again." on a stream error; "This invoice could not be found." when the document does not exist or cannot be parsed.
- Source: `payment_screen.dart:266-278` (l10n `paymentErrorInvoiceLoad`, `paymentErrorInvoiceNotFound`).
- Next: none.

**B-060 — Invoice summary box**
- Sees/does: Invoice number (or document id); badge "PAID" (green, when fully paid by amount), else "OVERDUE" (red, when late), else "PENDING" (amber) — a cancelled invoice shows PENDING or OVERDUE here, never CANCELLED; rows "Total" = `total_amount`, "Paid" = `paid_amount` (green when > 0), divider, "Remaining" = `max(0, total − paid)` (green when 0). Labels hard-coded English. Box border turns green when paid.
- Source: `payment_screen.dart:408-536`.
- Next: none (the confirm dialog only states the amount and invoice number).

**B-061 — The one pay button**
- Sees/does: Full-width button "Continue to Secure Checkout" (l10n `continueToSecureCheckout`) with a card icon; spinner while a payment is starting; label becomes "Invoice already paid" with a tick when paid. Disabled (grey) when paid, when the invoice is cancelled, or while starting.
- Source: `payment_screen.dart:313-355`.
- Next: card button "Pay Now" → confirm dialog → "Starting checkout…".

**B-062 — The amount is not chosen by the parent**
- Sees/does: There is no amount field. Every online payment is for the whole remaining balance of that one invoice, computed on the server at the moment of the click. No part-payment, no "pay all invoices", no tips/fees.
- Source: client sends only `{invoiceId}` (`payment_screen.dart:74, 160`); server amount `payments.js:1957-1959, 2141-2143`.
- Next: same (`StudentInvoicesPage.tsx:175`).

**B-063 — WEB: start Stripe Checkout**
- Sees/does: The browser tab leaves the app and shows Stripe's hosted checkout page.
- Source: `payment_screen.dart:67-70, 157-184`.
- Data: callable `createPaymentSession` with `{invoiceId}`; expects `{success: true, paymentId, checkoutUrl, provider}`; rejects the answer unless `paymentId` is non-empty and `checkoutUrl` is an absolute URL with a host; then `launchUrl(uri, webOnlyWindowName: '_self')` (same tab).
- Platform: `kIsWeb` only.
- Next: `StudentInvoicesPage.tsx:168-185` same callable and payload; checks `success === true` and that `checkoutUrl` starts with http(s); `window.location.assign`. Does not require `paymentId`.

**B-064 — WEB: coming back from Stripe (no return handling exists)**
- Sees/does: After paying — or after pressing Stripe's back arrow — the browser is sent to `https://alluwaleducationhub.org`, the public home page. No "payment received" page, no return to the invoice, nothing distinguishes success from cancel. The parent must open the app again to see the invoice marked paid.
- Source: return addresses come from server settings `STRIPE_CHECKOUT_SUCCESS_URL` / `STRIPE_CHECKOUT_CANCEL_URL` (`functions/services/stripe/checkout.js:104-107`, used at `payments.js:1986-1994`). Values read from the live `createpaymentsession` service on 2026-11-13: both are `https://alluwaleducationhub.org`. No Flutter or Next code looks for a Stripe return (`session_id`, `payment=success`, etc. appear nowhere).
- Platform: web only.
- Next: identical today for adult students (same callable, same two addresses). NOTE: the two addresses are global — one pair for every caller — so a new parent return page needs either new settings or per-call return addresses in the callable.

**B-065 — PHONE: start the in-app Stripe sheet**
- Sees/does: Stripe's native payment sheet slides up inside the app, titled for "Alluwal Education Hub", light/dark following the phone.
- Source: `payment_screen.dart:72-110`.
- Data: callable `createPaymentIntent` with `{invoiceId}`; expects `{success, paymentId, paymentIntent (client secret), ephemeralKey, customer, publishableKey}`; any missing value → generic error. Sets `Stripe.publishableKey` from the answer.
- Platform: iOS/Android only.
- Next: not applicable to web.

**B-066 — PHONE: after the sheet closes successfully**
- Sees/does: Immediately a green "Payment COMPLETED" box with "Completed: <now>" appears (an optimistic guess, before the server confirms), the pay button becomes "Invoice already paid", and the app re-reads the payment record every 2 seconds for up to 30 seconds (15 tries) until it says completed or failed.
- Source: `payment_screen.dart:33-58, 112-128`.
- Data: `payments/{paymentId}` get (`payment_service.dart:39-45`).
- Rules: payments read rule (`firestore.rules:1063-1068`).
- Platform: mobile only (on web the page has already navigated away).

**B-067 — "Check Payment Status" button**
- Sees/does: Outlined button "Check Payment Status" appears once a payment was started and has not yet reached completed/failed; re-reads the payment record. On failure: "The payment status could not be checked. Please try again in a moment."
- Source: `payment_screen.dart:186-198, 357-380`.
- Platform: in practice mobile only.

**B-068 — Payment status box**
- Sees/does: Coloured dot + "Payment PENDING / PROCESSING / COMPLETED / FAILED" (hard-coded), "Amount" (when > 0), "Created" and "Completed" as "Nov 13, 2026 4:05 PM". Green tint when completed.
- Source: `payment_screen.dart:539-629`.

**B-069 — Success banner**
- Sees/does: Green banner "Payment received — invoice is now fully paid." (hard-coded) when the invoice is fully paid and no payment box is showing — i.e. when the screen is opened for an already-paid invoice, or the live invoice flips to paid.
- Source: `payment_screen.dart:307-311, 632-659`.

**B-070 — Error messages shown to the parent**
- Sees/does: A red box above the button. Mapping from the server's error code:
  - `unauthenticated` → "Please sign in again to pay this invoice."
  - `permission-denied` → "This invoice belongs to another account."
  - `not-found` → "This invoice could not be found."
  - `failed-precondition` + message contains "cancel" → "This invoice was cancelled."
  - `failed-precondition` + message contains "already paid" → "This invoice is already paid."
  - anything else (including the server's `internal` errors such as the $0.50 minimum, Stripe key problems, missing return addresses) → "The payment could not be started. Please try again, or contact the school if this keeps happening."
  - browser refused to open the checkout address → "The payment page could not be opened. Please try again."
  - Stripe sheet error on phone → Stripe's own localized message, or "The payment did not go through. Please try again."
- Source: `payment_screen.dart:129-151, 200-244` (l10n `paymentError*`).
- Next: `StudentInvoicesPage.tsx:181-184, 219-221` prints the raw server message (English, technical, e.g. "Cannot pay another user's invoice") or "Could not start checkout." DIFFERENT — needs the same mapping.

**B-071 — Cancelling the phone sheet**
- Sees/does: Closing the Stripe sheet without paying shows no message at all; the button is usable again.
- Source: `payment_screen.dart:129-139` (`FailureCode.Canceled` ignored).
- Data: the `payments` row created for that attempt stays `processing` for ever (nothing expires a PaymentIntent here) and shows in Payment History.

**B-072 — Double-click protection and attempts**
- Sees/does: The button is disabled while a payment is starting. Each press that reaches the server creates a NEW `payments` row (first `pending`, then `processing`).
- Source: `payment_screen.dart:60-64, 318-322`; `payments.js:1996-2005, 2191-2201`.
- Next: card button disabled while "Starting checkout…".

**B-073 — Saved cards**
- Sees/does: There is no saved-cards screen. Web: Stripe Checkout is created without a Stripe customer, so no card is remembered. Phone: a Stripe customer is created per signed-in user and passed to the sheet (Stripe's sheet may then offer/reuse saved cards — Stripe's own behaviour, not app code).
- Source: `functions/services/stripe/checkout.js:128-172` (no `customer`), `:178-239`; `payments.js:2173-2188`.
- Data: phone flow writes `users/{uid}.stripe_customer_id`.
- Dead leftovers: model `lib/features/parent/models/payment_method.dart`, rule `users/{uid}/payment_methods` (`firestore.rules:1102-1104`) and the parent-may-update-`payment_method_id` invoice rule (`:1043-1047`) are used by no screen.

---

## F. Server side of paying — `functions/handlers/payments.js`, `functions/services/stripe/checkout.js`

**B-074 — `createPaymentSession` (callable, web)**
- Does: Checks in this order: signed in (`unauthenticated`); `invoiceId` present (`invalid-argument`); invoice exists (`not-found`); invoice not cancelled (`failed-precondition` "This invoice was cancelled."); remaining > 0 (`failed-precondition` "Invoice is already paid"); caller may pay (`permission-denied`); return addresses configured (`failed-precondition`).
- Source: `payments.js:1927-2105`.
- Writes: new `payments/{auto}` = `{invoice_id, parent_id: invoice.parent_id || invoice.student_id || caller uid, student_id (or null), payer_id: caller uid, amount: remaining, status: 'pending', payment_method: 'stripe', created_at}`; then merges `{stripe_checkout_session_id, status: 'processing', checkout_url}`; on Stripe failure merges `{status: 'failed', error_message, updated_at}` and throws `internal`.
- Returns: `{success: true, paymentId, checkoutUrl, provider: 'stripe'}`.
- Note: the cancelled / already-paid answers are given before the ownership check, so any signed-in user who knows an invoice id can learn those two facts.

**B-075 — Who is allowed to pay an invoice**
- Does: admin, or the caller's uid equals the invoice's `parent_id`, `student_id` or `payer_id`.
- Source: `payments.js:63-76`.
- Note: a second guardian who is not the invoice's `parent_id` cannot see or pay it.

**B-076 — The Stripe Checkout session**
- Does: `mode: 'payment'`; one line "Invoice <number>" (or "Invoice payment"), description "Alluwal Education Hub — tuition / fees", quantity 1, amount = remaining × 100 (whole units for zero-decimal currencies); `customer_email` = the caller's sign-in email when there is one; `client_reference_id` = payment id; `metadata {payment_id, invoice_id}`; success/cancel addresses from settings; no explicit payment-method list (Stripe account defaults); no expiry set (Stripe default 24h).
- Source: `functions/services/stripe/checkout.js:109-172`.
- Limit: USD below $0.50 is refused ("Amount must be at least $0.50 USD for card payments") → the parent sees the generic error.

**B-077 — Payoneer fall-back**
- Does: If no Stripe secret key is configured the same callable creates a Payoneer session instead (`payment_method: 'payoneer'`, `payoneer_session_id`), answered by `handlePayoneerWebhook`. Production runs Stripe; this path is legacy/mock.
- Source: `payments.js:2052-2104, 2251-2317`.

**B-078 — `createPaymentIntent` (callable, phone)**
- Does: Same checks as B-074 plus "Stripe is not configured". Creates/reuses the caller's Stripe customer, writes the same `payments` row, creates a card-only PaymentIntent (`payment_method_types: ['card']`, `metadata {payment_id, invoice_id}`) and an ephemeral key (API version `2024-06-20`), then merges `{stripe_payment_intent_id, status: 'processing', updated_at}`.
- Returns: `{success, paymentId, paymentIntent: client_secret, ephemeralKey, customer, publishableKey}`.
- Source: `payments.js:2112-2249`; `checkout.js:178-239`.

**B-079 — Stripe key safety check**
- Does: In project `alluwal-academy` both keys must be live keys, and secret/publishable must be the same mode; otherwise `failed-precondition` (parent sees the generic error).
- Source: `checkout.js:27-102`; `payments.js:78-87`.

**B-080 — Stripe webhook: which events do anything**
- Does: `handleStripeWebhook` (HTTP, signature-checked with `STRIPE_WEBHOOK_SECRET`): `checkout.session.completed` with `payment_status == 'paid'` or `checkout.session.async_payment_succeeded` → completed; `checkout.session.expired` → failed (unless already completed); `payment_intent.succeeded` → completed (phone sheet); `payment_intent.payment_failed` → failed. The payment is found by `metadata.payment_id`; events without it are ignored. Everything else is acknowledged and ignored.
- Source: `payments.js:2324-2487`.
- Gaps: refunds/disputes (`charge.refunded` etc.) and `checkout.session.async_payment_failed` are not handled — a refund made in Stripe changes nothing in the app.

**B-081 — What "completed" writes (the only place an online payment marks an invoice paid)**
- Does, in one transaction: applied = min(payment amount, remaining balance, never below 0). `payments/{id}` ← `{status: 'completed', applied_amount, [overpaid_amount], stripe ids, [paid_by_email], completed_at, updated_at}`. `invoices/{id}` ← `{paid_amount: old + applied (2 dp), status: 'paid' if paid ≥ total else 'overdue' if due date passed else 'pending', last_payment_at, last_payment_by_uid, [overpaid_amount += excess], pay_link_pending: deleted, updated_at}`. A second "completed" for the same payment is a no-op.
- Source: `payments.js:1316-1470`.

**B-082 — Payment that lands on a cancelled invoice**
- Does: Payment is stored `completed` with `applied_amount: 0, needs_refund: true`; the invoice stays cancelled and gets `needs_refund: true, refund_due_amount += amount`. No automatic refund. The parent still gets the receipt email.
- Source: `payments.js:1344-1381`.

**B-083 — Paying twice (two tabs, or link + app)**
- Does: The second payment is clamped: only what is still owed is applied, the excess is recorded as `overpaid_amount` on both documents and logged for a manual Stripe refund.
- Source: `payments.js:1383-1437`.
- Parent sees: two COMPLETED rows in history, each for the full amount.

**B-084 — What "failed" writes**
- Does: `payments/{id}` ← `{status: 'failed', completed_at, updated_at}`; the invoice is not touched.
- Source: `payments.js:1486-1498`.

**B-085 — Receipt after a completed payment**
- Does: Email "Payment received: <invoice number>" from `billing@alluwaleducationhub.org` to the first existing user among invoice `parent_id`, `student_id` (their `e-mail`/`email`), showing amount CHARGED, date, method, with the invoice PDF attached (post-payment, so it doubles as the receipt) and the sentence "You can review this payment any time in your parent dashboard under Payments at https://alluwaleducationhub.org". Adds a `notification_history` row titled "Payment received". If the email fails the payment gets `receipt_email_status: 'failed'` (+ error, address, time). No push notification.
- Source: `payments.js:390-536, 1514-1539`; `functions/services/email/senders.js:94-150`.
- Next: the email text names "parent dashboard → Payments"; keep that path true after the move.

**B-086 — Payments recorded by an admin (cash, transfer, bank match)**
- Does: `recordManualPayment` (admin only) / bank matcher write `payments` = `{invoice_id, parent_id: invoice.parent_id, amount, applied_amount, status: 'completed', payment_method: <cash/transfer/…>, payment_source, reference_number, notes, received_at, completed_at, created_at, recorded_by_*}` and raise `paid_amount`; amount may be less than the balance (this is the only way an invoice becomes part-paid) but never more. Same receipt email unless switched off.
- Source: `payments.js:1541-1744`.
- Parent sees: a COMPLETED row in history and "Paid Toward Balance" on the invoice. Note these rows have no `student_id`/`payer_id`, so an account that is only the invoice's `student_id` cannot read them.

**B-087 — Callables that exist but no screen uses**
- Does: `getParentInvoices` and `getPaymentHistory` (callables returning the same lists) are exported but called by neither Flutter nor Next; both apps read Firestore directly.
- Source: `payments.js:1246-1307, 1893-1925`; `functions/index.js:200, 205`.

---

## G. Pay-by-link page (outside the app, but it is how most invoice emails get paid)

**B-088 — Where the link comes from**
- Sees/does: Every invoice email and reminder email carries a button "Pay $X" pointing at `https://pay.alluwaleducationhub.org/<token>` (setting `PAY_LINK_BASE_URL`, read from production). No sign-in needed.
- Source: `functions/services/payment_links.js:30-58`; `payments.js:690-707`; `finance_billing.js:1136-1150`.
- Data: token = `invoices.pay_link_token` (random, minted by the server; clients are forbidden to write it — `firestore.rules:985-1010`), `pay_link_status` `active`/`cancelled`.
- Next: nothing to port; it is a Cloud Function page. Listed because the new parent pages must stay consistent with it.

**B-089 — Link page states**
- Sees/does: Payable → big balance, "Balance due" (or "Balance due (remaining)"), rows Invoice / Student(s) (first names of ALL billed children, up to 6) / Due date / Already paid, button "Pay $X", note that the full balance is charged and partial amounts cannot be paid. Other states: "Invoice … is fully paid."; "below the minimum we can charge online" (< $0.50); "Invoice … has been cancelled. No payment is due."; "This payment link is no longer active."; "This payment link is not valid."
- Source: `functions/handlers/payment_links.js:245-378`; state logic `functions/services/payment_links.js:100-160`.

**B-090 — Link checkout and return**
- Sees/does: Pressing Pay (a POST) creates a `payments` row `{…, payer_id: null, payment_source: 'payment_link', pay_link_token}` with `parent_id` copied from the invoice, stores `invoices.pay_link_pending {payment_id, amount, checkout_url, created_at}`, and redirects to Stripe. A still-open session for the same balance is reused for 23 hours. Stripe returns to `/<token>/done` ("Thank you — your payment was submitted… A receipt … is on its way by email") or, on cancel, back to the link page.
- Source: `functions/handlers/payment_links.js:380-520`.
- Parent sees in the app: these attempts/payments appear in Payment History and under the invoice like any other.

**B-091 — A link never expires on a timer**
- Does: It stops working only when the invoice is fully paid, the invoice is cancelled, or an admin cancels the link. (Same owner rule as the Laawol payment-link note in memory; verified in code comments and logic.)
- Source: `functions/services/payment_links.js:1-14, 126-159`.

---

## H. Payment History — `lib/features/parent/screens/payment_history_screen.dart`

**B-092 — Ways in**
- Sees/does: Sidebar Finance → Payments; dashboard tile "Payments / History"; dashboard "Recent Payments → See all".
- Source: `parent_dashboard_layout.dart:95`; `sidebar_config.dart:553-558`; `parent_dashboard_screen.dart:288-303, 464-479`.
- Next: none for parents. Adult students: `/student/payments/`.

**B-093 — Query**
- Sees/does: Title "Payment History". Lists up to 100 payment records, newest first, live.
- Source: `payment_history_screen.dart:24-29`; `payment_service.dart:14-37`.
- Data: `payments` where `parent_id == uid` `orderBy created_at desc` `limit 100` (index `(parent_id, created_at desc)` exists).
- Rules: `firestore.rules:1063-1068`.
- Next: `StudentPaymentsPage.tsx:63-100` runs TWO queries (`parent_id == uid` and `student_id == uid`), no order, no limit, merges and sorts by date in the browser.

**B-094 — It is a list of ATTEMPTS, not only of money received**
- Sees/does: Every press of the pay button (app, web or link) leaves a row: abandoned web checkouts read PROCESSING for 24h and then FAILED; an abandoned phone sheet reads PROCESSING for ever; successful ones read COMPLETED. A parent who tried three times and paid once sees four rows.
- Source: writers in B-074, B-078, B-090; expiry B-080.
- Next: same data, same effect.

**B-095 — Row content**
- Sees/does: White card: tinted square with a payments icon; title = amount; subtitle "STATUS • Nov 13, 2026" (status upper-case English: PENDING, PROCESSING, COMPLETED, FAILED; date = created date, omitted if missing); chevron. Colours: completed green `#16A34A`, processing blue `#2563EB`, failed red `#DC2626`, pending amber `#F59E0B`. The invoice number, the method (card / cash) and the child are NOT shown.
- Source: `payment_history_screen.dart:44-81, 123-134`.
- Money format: `NumberFormat.simpleCurrency()` with no currency → always "$" — the payment record has no currency field, so a non-USD invoice's payment is shown in dollars.
- Next: `StudentPaymentsPage.tsx:130-160` title "Invoice <number>" when the payment row has `invoice_number` — payment rows never have it, so it always reads "Payment"; subtitle "Nov 13, 2026 · stripe" (raw method string); amount `$` + `toFixed(2)` on the right; status in colour underneath. Only three colours (done green / failed red / everything else amber) — processing is amber, not blue. Icons tick / cross / clock.

**B-096 — Tap a row**
- Sees/does: Opens Invoice Details for that payment's invoice. If the invoice no longer exists: snack bar "Invoice Not Found For This Payment". If the read is refused (invoice belongs to someone else) nothing happens (unhandled error).
- Source: `payment_history_screen.dart:82-96`.
- Data: `invoices/{payment.invoice_id}` get.
- Next: MISSING — rows are not clickable.

**B-097 — States**
- Sees/does: Spinner; "No payments yet." (hard-coded); "Failed to load payments: <error>" exists in code but the service swallows stream errors, so a failed query spins for ever.
- Source: `payment_history_screen.dart:31-40`; `payment_service.dart:33-36`.
- Next: "Loading your payments…"; "No payments yet."; query errors count as empty.

**B-098 — Adult student gap in Flutter**
- Sees/does: An adult student whose payment rows carry a `parent_id` other than their own uid sees "No payments yet." in Flutter although payments exist.
- Source: `payment_service.dart:18-21` (parent_id only).
- Next: fixed on Next by the extra `student_id` query (comment at `StudentPaymentsPage.tsx:53-62`).

---

## I. Emails and notifications that send parents to these screens

**B-099 — New-invoice email**
- Sees/does: "New invoice from Alluwal Education Hub: <number>" from `billing@…` with amount due, due date, access cut-off date and warning, the "Pay $X" link button, the invoice PDF, and written directions: "Through the website: Go to https://alluwaleducationhub.org, sign in, open your parent dashboard, choose Invoices, select <invoice> …".
- Source: `payments.js:628-796`; `functions/services/email/senders.js:11-92`. Sent to the first existing user among `parent_id`/`payer_id`, `student_id`.
- Next: the written directions must still be true after the move (wording lives in the function, not the app).

**B-100 — New-invoice push + in-app notification**
- Sees/does: Phone push "New invoice available — <number> is ready. Amount due: $X." (data `type: invoice_created, invoiceId, invoiceNumber`), and a `notification_history` row with the same text. Tapping the push does not deep-link to the invoice (no handler in the app).
- Source: `payments.js:550-626, 766-790`.
- Platform: push is mobile only.

**B-101 — Due-date reminders**
- Sees/does: Daily at 09:00 New York, only while the finance "parent messages" switch is on: one reminder N days before the due date and one on the due date, each sent once — email "Invoice <n> is due in N days / is due today" with a "Pay $X" link button, plus a push (`type: invoice_reminder`). Skipped for paid/cancelled/zero-balance invoices.
- Source: `functions/handlers/finance_billing.js:1110-1255` (`reminders_sent.before/.due` on the invoice).

**B-102 — Receipt** — see B-085.

---

## J. Access suspension for unpaid families

**B-103 — What makes an invoice "blocking"**
- Does: stored status is neither `paid` nor `cancelled`, AND `total_amount > 0`, AND `paid_amount < total_amount`, AND the cut-off moment has passed. Cut-off = `access_cutoff_date`, or `due_date + 24h` when the invoice has none.
- Source: `functions/handlers/invoice_access.js:26-34, 93-103`.
- Note: a part-payment does not lift it. Setting status to `paid` lifts it even if the amounts say otherwise.

**B-104 — Who gets suspended (children, never the parent account)**
- Does: For the invoice's `parent_id`, the server gathers every child (users with `guardian_ids` containing the parent, the parent's `children_ids`, and every student named on the parent's invoices) and writes `users/{child}.access_suspended = true/false` + `access_suspension_updated_at`. A blocking invoice that names its children (`student_ids` or per-line `student_id`) suspends only those children; a blocking invoice with no child list (older invoices) suspends the whole family. The parent's own user document is not flagged — unless the payer is also the student (adult student), who then suspends themselves.
- Source: `invoice_access.js:105-212`.

**B-105 — When the flag is recalculated**
- Does: (a) immediately whenever an invoice is created, deleted, or its status / paid amount / total / cut-off date changes (`onInvoiceWrite`); (b) every 60 minutes (`checkAccessCutoffs`) for families whose cut-off has passed and for families of currently suspended children.
- Source: `invoice_access.js:218-345`.
- Consequence: suspension starts up to an hour after the cut-off moment; it ends within seconds of the payment being recorded.

**B-106 — How paying lifts it**
- Does: Stripe webhook (or admin manual payment) raises `paid_amount`/sets `paid` → invoice write → trigger recomputes → `access_suspended: false` if no other blocking invoice remains for that child. Admin alternative: `extendStudentAccessCutoff` (admin-only callable) pushes `access_cutoff_date` into the future for one student's or one parent's blocking invoices.
- Source: `payments.js:1420-1437`; `invoice_access.js:218-262, 347-487`.

**B-107 — What the parent sees: red dashboard banner**
- Sees/does: At the top of the parent dashboard, live: lock icon, heading "Platform access suspended" (one child) or "N students have been suspended", text "<names> has/have lost platform access due to an unpaid invoice. Pay now to restore access immediately.", red button "View & pay invoices" → Invoices list filtered to Pending. All hard-coded English. Hidden when no child is suspended.
- Source: `parent_dashboard_screen.dart:107-121, 163-242`.
- Data: live `users` where `guardian_ids array-contains uid` AND `access_suspended == true`; names from first_name/last_name (doc id if blank).
- Rules: users read (any signed-in user).
- Next: none.
- Note: only children linked by `guardian_ids` appear; a child linked only through the parent's `children_ids` can be suspended without the banner showing.

**B-108 — What the parent sees: per-invoice lock strip** — see B-025 (computed in the app from dates, independent of the server flag, so it can say "suspended today" up to 24h early or up to an hour before the server acts).

**B-109 — What the parent is NOT blocked from**
- Sees/does: The parent can sign in, see everything, pay, submit forms. Nothing in the parent screens reads `access_suspended` for the parent. A parent joining a class in the parent role is not refused (the server refuses only when the resolved role is student).
- Source: no reference in `lib/features/parent` other than the banner; server checks `functions/handlers/zoom.js:288-338`, `livekit.js:142-150, 1956-1962`, `realtimekit.js:255-360`.

**B-110 — What the suspended child sees (Flutter student app)**
- Sees/does: A banner on the classes screen: "Your account has an outstanding invoice. Class access is suspended until payment is received. Please contact your administrator." Pressing Join shows a dialog "Class Access Suspended" / "Your account has an outstanding unpaid invoice. Class access is suspended until payment is received. Please contact your administrator to resolve this." / OK. The child can still see the timetable and everything else.
- Source: `lib/features/student/screens/student_classes_screen.dart:122-129, 232-235, 960-1010`.
- Data: own `users` doc `access_suspended`, read when the screen loads through a 5-minute cache — a child may need to reopen the screen after the parent pays.
- Server backstop: join calls answer `permission-denied` "Class access is suspended because of an outstanding unpaid invoice."
- Next: already built for students — `apps/web/src/components/StudentClassesPage.tsx:60, 88-90, 156, 302`.

**B-111 — `AccessSuspendedScreen` is dead code**
- Sees/does: A full-page "Access Suspended … Sign Out" screen exists but nothing navigates to it.
- Source: `lib/features/parent/screens/access_suspended_screen.dart` (no other reference in `lib/`).
- Next: do not port.

**B-112 — There is no `accessSuspendedAt` field**
- Does: The data has `access_cutoff_date` (invoice) and `access_suspended` + `access_suspension_updated_at` (user). `accessSuspendedAt` is only a variable name inside `StudentInvoicesPage.tsx:34, 373-375` holding the cut-off date.

---

## K. Dashboard money widgets — `widgets/financial_summary_card.dart`, `services/parent_service.dart`, `screens/parent_dashboard_screen.dart`

**B-113 — The card shows exactly two numbers**
- Sees/does: Dark gradient card, wallet icon, title "Financial Summary". Two tiles: "Outstanding" (light blue `#38BDF8` when > 0, white when 0) and "Overdue" (light red `#FCA5A5` when > 0, white when 0). No "paid" / "total paid" / lifetime figure. The file's own comment: "It deliberately shows no running total of everything ever paid".
- Source: `financial_summary_card.dart:6-20, 80-99`; used at `parent_dashboard_screen.dart:243-268`.
- CONFIRMED: the all-time paid total is gone from the screen. The service still computes a `paid` number (`parent_service.dart:219, 231, 248-257`) that nothing displays — do not resurrect it.
- Next: none.

**B-114 — "Pay Now" on the card**
- Sees/does: Blue "Pay Now" button in the card header only when Outstanding > 0; opens the Invoices list filtered to Pending.
- Source: `financial_summary_card.dart:63-77`; `parent_dashboard_screen.dart:254-266`.
- Next: none.

**B-115 — Data behind the card**
- Sees/does: Live; recalculates whenever an invoice or payment changes. Shows $0.00 / $0.00 until both queries answer (no spinner).
- Source: `parent_service.dart:105-158`.
- Data: `invoices` where `parent_id == uid` `orderBy issued_date desc` `limit 200` (index exists) + `payments` where `parent_id == uid` `limit 500` (no order).
- Rules: invoices / payments read rules.
- Note: unlike the Invoices list there is NO `student_id` query here, and the cap is 200 newest-issued invoices (list: 100 by due date).

**B-116 — How "Outstanding" is computed**
- Does: For each invoice: `effectivePaid = max(invoice.paid_amount, sum of amount of this parent's COMPLETED payments for that invoice)`; `remaining = total_amount − effectivePaid`; skip if status is `cancelled` or remaining ≤ 0; Outstanding = sum of the remaining amounts.
- Source: `parent_service.dart:191-241`.
- Differs from the invoice cards, which use `total − paid_amount` only. The two disagree whenever completed payment rows add up to more than `paid_amount` (e.g. a payment clamped as an overpayment, B-083) — the card then shows less owed than the invoice list.
- Stored status `paid` is NOT skipped: an invoice marked paid by status with amounts unpaid still counts as outstanding here.

**B-117 — How "Overdue" is computed**
- Does: Same remaining amounts, counted only where `due_date` is before now (exact timestamp, device clock).
- Source: `parent_service.dart:239-241`.
- Note: independent of the stored `overdue` status and of the access cut-off.

**B-118 — Currency on the card**
- Does: Always formatted as USD (`currency` defaults to 'USD' and the dashboard never passes another). Invoices in different currencies would be added together as if dollars.
- Source: `financial_summary_card.dart:18, 24`; `parent_dashboard_screen.dart:251-254`.

**B-119 — Dashboard tiles "Invoices" and "Payments"**
- Sees/does: Two tiles under the card: "Invoices / View And Pay" and "Payments / History".
- Source: `parent_dashboard_screen.dart:270-303`.

**B-120 — Dashboard "Recent Invoices"**
- Sees/does: Heading "Recent Invoices" + "See all". The 5 invoices with the latest due dates, as the same invoice cards (B-018…B-026) but WITHOUT the student name line; tap → details; "Pay Now" → pay screen. Empty: receipt icon, "No Invoices Yet", "When Invoices Are Created They Will" (truncated l10n string). Error text "Failed to load invoices: …" (unreachable, see B-010).
- Source: `parent_dashboard_screen.dart:399-463`.
- Data: `InvoiceService.getParentInvoices(parentId, limit: 5)` — same two queries as B-003/B-004 with limit 5.

**B-121 — Dashboard "Recent Payments"**
- Sees/does: Heading "Recent Payments" + "See all". The 5 newest payment records in one white box: dot, amount (`$` default format), "STATUS • date"; tap → invoice details (same rules as B-096). Empty: "No Payments Yet" + sub-line.
- Source: `parent_dashboard_screen.dart:464-508, 2154-2215`.
- Data: `PaymentService.getPaymentHistory(parentId, limit: 5)`.

**B-122 — Pull to refresh**
- Sees/does: Pulling down on the dashboard re-subscribes the summary and the suspension banner (lists are live anyway).
- Source: `parent_dashboard_screen.dart:86-104`.

---

## L. Parent forms — `lib/features/forms/screens/parent_forms_screen.dart`, `teacher_forms_screen.dart` (parentOnly), `form_screen.dart`, `my_submissions_screen.dart`

**B-123 — Ways in**
- Sees/does: Web/desktop sidebar → Forms (parent layout index 3); phone bottom tab "Forms".
- Source: `parent_dashboard_layout.dart:97`; `mobile_dashboard_screen.dart:594`.
- Next: none for parents. Closest: `apps/web/src/components/StudentFormsPage.tsx` (students, live since 2026-11-13).

**B-124 — Header**
- Sees/does: Indigo `#6366F1` collapsing header, title "Family Forms" (l10n `parentFormsTitle`), sub-line "Submit an excuse request or share feedback with school leaders." (`parentFormsSubtitle`), a history icon top-right (tooltip "My Form Submissions"). None of the teacher "Daily / Weekly / Monthly" pills.
- Source: `teacher_forms_screen.dart:545-606`.

**B-125 — Which forms from the database a parent sees**
- Sees/does: Every ACTIVE form whose "Who can see this" audience includes parents, plus any active form whose name contains "parent guardian feedback", "student absence excuse request", "demande d excuse d absence de l eleve", "feedback for leaders" or "commentaires pour les dirigeants" (punctuation ignored) or whose id is `parent_feedback` / `parent_student_excuse`, whatever its audience. A form with no audience is hidden.
- Source: `utils/parent_form_access_policy.dart:14-39`; audience parsing `utils/form_audience.dart` (reads `allowedRoles`, `audience`, `targetRoles`, `roles`, legacy `permissions.role(s)`; lists, maps, comma strings; "parents", "guardian(s)", "parent/guardian" all mean parent).
- Data: `form_templates` whole collection, `orderBy updatedAt desc` (falls back to `createdAt`), server read on pull-to-refresh (`services/form_template_service.dart:1015-1070`).
- Rules: `firestore.rules:373-376` any signed-in user reads; admins write.
- Next: `apps/web/src/lib/formAudience.ts` has the same parser but only `studentCanSeeForm`; a `parentCanSeeForm` with the five built-in name matches does not exist yet.

**B-126 — One card per form name (latest version wins)**
- Sees/does: If several active templates share a name (case/spacing ignored) only the one with the highest `version` is shown, ties broken by latest `updatedAt`.
- Source: `teacher_forms_screen.dart:175-197`.
- Next: `apps/web/src/lib/studentForms.ts:17` `latestStudentForms` does the equivalent for students.

**B-127 — Built-in form 1: absence excuse (always present)**
- Sees/does: Card "Student Absence / Excuse Request" — "Let the school know why your child will miss or has missed a class." under ADMINISTRATIVE. It is defined in the app, not in the database, and is added for every parent every time. Title, description, labels and options are in the parent's app language.
- Source: `parent_forms_screen.dart:15-84`; added at `teacher_forms_screen.dart:296-302`.
- Fields (id · label EN · type · required): `student_name` · "Child's full name" · text · yes; `class_or_teacher` · "Class or teacher (optional)" · text · no; `absence_date` · "Date of the missed class" · date · yes; `reason` · "Reason for the absence" · dropdown [Illness, Appointment, Family emergency, Technical issue, Other] · yes; `details` · "Please explain the absence" · long text · yes; `preferred_contact` · "Preferred follow-up method (optional)" · dropdown [In-app chat, Email, Phone] · no.
- Next: none.

**B-128 — Built-in form 2: parent feedback (only when no feedback form is visible)**
- Sees/does: Card "Parent/Guardian Feedback" — "Collect feedback from parents about their child's teacher", under STUDENT ASSESSMENT — added only if no visible form has "feedback" in its name and none has id `parent_feedback`. English only (hard-coded).
- Source: `teacher_forms_screen.dart:303-312`; `services/form_template_service.dart:905-1004`.
- Fields: `teacher_name` "Teacher Name" text req; `child_name` "Child's Name" text req; `overall_satisfaction` "Overall Satisfaction with Teacher" radio [Very Satisfied, Satisfied, Neutral, Dissatisfied, Very Dissatisfied] req; `communication_quality` "Quality of Communication" radio [Excellent, Good, Average, Poor] req; `child_progress` "Is your child making progress?" radio [Significant progress, Some progress, Little progress, No progress] req; `punctuality` "Teacher Punctuality" radio [Always on time, Usually on time, Sometimes late, Often late] req; `recommendation` "Would you recommend this teacher?" radio [Definitely yes, Probably yes, Not sure, Probably no, Definitely no] req; `comments` "Additional Comments" long text optional, placeholder "Any other feedback or suggestions...".
- Note: a published "Feedback for Leaders" form counts as "a feedback form" and removes this built-in one.

**B-129 — If the form list cannot be loaded**
- Sees/does: The parent still gets the two built-in forms and no error message.
- Source: `teacher_forms_screen.dart:398-408`.

**B-130 — Grouping, order and card content**
- Sees/does: Sections in fixed order TEACHING, FEEDBACK, STUDENT ASSESSMENT, ADMINISTRATIVE, OTHER (only those with forms; section names English, upper-case); inside a section forms sort A→Z by name. Each card: icon, form name, description (2 lines max), "<n> items", and "Anytime" / "Daily" / "Weekly" / "Monthly"; arrow when it can be opened. A form saved as category "other" with a weekly/monthly/per-class frequency is shown under TEACHING.
- Source: `teacher_forms_screen.dart:806-1040, 211-221`.

**B-131 — Weekly / monthly forms are locked on some days, for parents too**
- Sees/does: A parent-audience form with frequency weekly can be opened only Sunday–Tuesday; monthly only in the last 3 / first 3 days of the month; otherwise the card is greyed and not tappable (the orange "Sun-Tue" / "End/Start" lock badge shows only for the teaching category). Per-class ("Daily") forms open a class picker built for teachers.
- Source: `teacher_forms_screen.dart:932-940, 1141-1147`; `models/form_template.dart:61-79`.
- OWNER QUESTION: are any parent forms meant to be weekly/monthly?

**B-132 — Search**
- Sees/does: Search box "Search Forms" with a clear button; matches form name, description, section name and frequency word; no match → "No active forms match your search." / "Try adjusting your search".
- Source: `teacher_forms_screen.dart:131-147, 750-806`.

**B-133 — Pull to refresh / loading**
- Sees/does: Indigo spinner while loading; pull down re-reads the forms from the server.
- Source: `teacher_forms_screen.dart:519-524, 700-706`.

**B-134 — Opening a form**
- Sees/does: Tapping a card opens the shared form page (Google-Forms style, purple `#673AB7`) with the form's title, description and questions, and a "Submit Form" button.
- Source: `teacher_forms_screen.dart:1635-1680`; `form_screen.dart:86-124`.
- Note: for weekly/monthly cards the app swaps in the currently active weekly/monthly TEACHER template at this point (`getActiveWeeklyTemplate`/`getActiveMonthlyTemplate`) — another reason parent forms should be "Anytime".

**B-135 — Question types the form page supports**
- Sees/does: text, long text (`long_text`/`multiline`/`description`), number, email (format checked), phone, date (calendar picker 1900–2100), dropdown (`select`/`dropdown`), multi-select, radio, yes/no (`boolean`/`yes_no`/`yesNo`), image upload, signature, and display-only blocks (heading, section, image, video). Questions can be shown/hidden by "show only if" rules. Required questions refuse submit with "Please enter <label>", "Please select a <label>", "Please select a date", "Please select an option for <label>", "Please select at least one option for <label>", "Please enter a valid email address", "Please enter a valid number" (hard-coded English).
- Source: `form_screen.dart:2104-2260, 2319-2331, 2405-2444, 2660-2730, 2823-2931`.
- Next: `apps/web/src/components/forms/FormFields.tsx` covers the same types for students (date uses the browser date input).

**B-136 — How answers are stored per type**
- Does: text/long text/number/email/phone/dropdown/radio → the typed or chosen string; date → the string `d/M/yyyy` with no leading zeros (e.g. `13/11/2026`); multi-select → array of strings; image/signature → `{fileName, downloadURL, size, type: 'image', uploadedAt}`; hidden (rule-failed) questions and display blocks are left out.
- Source: `form_screen.dart:2724, 4640-4812`.
- Next: the student page stores a date as the browser gives it (`yyyy-MM-dd`) — DIFFERENT format from Flutter's `d/M/yyyy`; pick one before admins compare answers.
- Note: for the excuse form the stored `reason` / `preferred_contact` text is in the parent's language ("Illness" vs "Maladie").

**B-137 — Image upload**
- Sees/does: Shows "Uploading <file> (<n>MB)…"; images over 500 KB are compressed first. If the upload fails a dialog "Image Upload Failed" offers "Try Again" (stops the submit) or "Submit Without Image" (stores `{fileName, uploadFailed: true, size, type: 'image', failureReason}`).
- Source: `form_screen.dart:4683-4770, 4195-4260`.
- Data: Storage `form_images/{uid}/{millis}_{fileName}` with metadata `uploadedBy, originalFileName, attempt`.
- Rules: `storage.rules:49-53` any signed-in user may read; write < 10 MB.

**B-138 — What a parent's submission writes (exact document)**
- Does: `form_responses/{auto}` =
  `formId` (template id, e.g. `parent_student_excuse`), `formName`, `formTitle` (both the form's display name), `formType` ('onDemand' for Anytime forms; 'weekly'/'monthly'/'daily' otherwise), `templateId`, `frequency` ('onDemand'), `userId`, `submittedBy`, `teacherId`, `teacher_id` (all four = the parent's uid), `userEmail`, `firstName`, `lastName`, `userFirstName`, `userLastName` (from the parent's user doc), `responses` {fieldId: answer}, `submittedAt` and `lastUpdated` (server time), `status: 'completed'`, `yearMonth` (current `yyyy-MM`), `reportingContext` {appSessionId, platform, clientTimestamp, recentBreadcrumbs}.
- Source: `form_screen.dart:4825-4960`; context `lib/core/services/error_reporting_service.dart:155-167`.
- Rules: `firestore.rules:345-357` create allowed when the owner field (`userId`, else `submittedBy`, …) equals the caller; only admins update/delete.
- Next: `apps/web/src/lib/studentForms.ts:43-82` writes the same keys plus `userRole: 'student'` and an empty `reportingContext`. A parent version needs the parent role and, to match exactly, no `userRole` (Flutter does not write one).
- Note: there is no role field on a Flutter submission; admins tell parents from teachers only by looking the user up. The parent uid sitting in `teacherId`/`teacher_id` is deliberate legacy compatibility — keep all four owner fields or the parent's own "My Submissions" and the admin review screens lose the row.

**B-139 — The excuse form has no special effect**
- Does: Submitting it only creates the `form_responses` row above. No class or attendance record is marked excused, no teacher or admin is notified, no email or push is sent, no leave/absence document is written. The server trigger on form responses only acts on rows that carry a class id, which these never do.
- Source: client `form_screen.dart:4612-5060` (no branch on form id); server `functions/handlers/shifts.js:638-660`; `functions/handlers/forms.js` (only a scheduled teacher-readiness check).
- OWNER QUESTION: is "an admin eventually notices it in All Submissions" the intended handling of an absence excuse?

**B-140 — After submitting**
- Sees/does: Green snack bar "Form submitted successfully!" and the form closes straight away (so it cannot be sent twice). On failure red "Error submitting form: <raw error>". Firestore write times out after 30 seconds. There are no drafts — leaving the page loses what was typed.
- Source: `form_screen.dart:4966-5062`.
- A parent may submit the same form any number of times.

**B-141 — Admin decision comes back to the parent**
- Sees/does: When an admin accepts or rejects a submission the submitter gets a push notification (`type: form_decision`) and the decision shows as a badge on the submission.
- Source: `lib/features/forms/services/form_review_service.dart:58-110` (callable `sendAdminNotification`); fields `reviewStatus`, `reviewNotifiedAt`.
- Platform: push reaches phones only.

**B-142 — "My Form Submissions" (history icon)**
- Sees/does: Opens a list of everything this account has submitted, grouped by form, defaulting to the CURRENT month with a month picker and an "all time" option; search by form name or status; per form: counts of Accepted / Rejected / Not reviewed and "Last submitted <MMM d, yyyy>"; opening a submission shows "Submitted on <Month d, yyyy at h:mm a>", "Decision:" badge (Not reviewed / Seen / In review / Accepted / Rejected) and each answer. Read-only.
- Source: `teacher_forms_screen.dart:553-565`; `my_submissions_screen.dart` (load `:66-160`, title `:340-397`); `utils/form_response_owner_queries.dart`.
- Data: four queries on `form_responses` — `userId`, `submittedBy`, `teacher_id`, `teacherId` == uid, each `orderBy submittedAt desc`, merged by id (indexes exist).
- Rules: `firestore.rules:345-350`.
- Next: `StudentFormsPage.tsx:83-98` lists the student's sent forms from ONE query (`userId == uid`, limit 200) with a review badge; no month picker, no answer viewer. `TeacherFormSubmissionsPage.tsx` is the fuller teacher equivalent.
- Verify when porting: for the two built-in forms (not in the database) answer labels may fall back to field ids.

---

## M. Adult students — what the Next.js site already does, and every difference from the Flutter parent screens

Who is an adult student: `users.is_adult_student == true` (`apps/web/src/lib/userRoles.ts:31-33`). On the web they are sent to Next (`/student/…`); in the phone app they still use the Flutter screens above (`ParentInvoicesScreen` as a bottom tab, `PaymentHistoryScreen`, `mobile_dashboard_screen.dart:558-572`; desktop Flutter indexes 29/33).

**B-143 — Menu**
- Sees/does: Sidebar section "Finance" with "Invoices" (`/student/invoices/`) and "Payments" (`/student/payments/`), shown only to adult students.
- Source: `apps/web/src/components/StudentDashboardHome.tsx:72-91`.

**B-144 — Access guard**
- Sees/does: Page requires a signed-in student; otherwise the standard student access prompt. It does NOT check `is_adult_student` — a minor who types `/student/invoices/` gets the page (rules still limit them to invoices naming them).
- Source: `StudentInvoicesPage.tsx:55-74, 166`; `StudentPaymentsPage.tsx:32-51, 102`.

**B-145 — Invoices page: queries** — see B-003/B-004 (two live queries `parent_id == uid`, `student_id == uid`; no limit; merged; sorted by due date).

**B-146 — Invoices page: card** — see B-018…B-027 for the element-by-element differences.

**B-147 — Invoices page: pay** — see B-014, B-063, B-064, B-070 (confirm dialog → `createPaymentSession({invoiceId})` → browser goes to Stripe → returns to the public home page).

**B-148 — Payments page** — see B-093…B-098.

**B-149 — Translation**
- Sees/does: Next pages are English/French through `useT()`; dates follow the chosen language. Flutter has English/French/Arabic for l10n keys but always-English dates, money and the many hard-coded strings.
- Source: `StudentInvoicesPage.tsx:10, 39`.

### Difference table (Flutter parent screen → Next adult-student page)

| # | Topic | Flutter today | Next today |
|---|---|---|---|
| D1 | Invoice detail page | Yes (sheet, items, totals, payments, PDF) | None; card not clickable |
| D2 | PDF | Print dialog (web) / share sheet (phone) | None |
| D3 | Pay screen | Separate screen with Total / Paid / Remaining | Confirm dialog only |
| D4 | Pay errors | Mapped to 8 plain translated messages | Raw server message |
| D5 | Status filter | Database filter on stored status | Browser filter on derived status |
| D6 | "Overdue" chip | Only stored `overdue` (part-paid late) | Every late unpaid invoice |
| D7 | "Pending" chip | Includes late invoices | Excludes late invoices |
| D8 | Result cap | 100 (by due date) | Unlimited |
| D9 | Search | Invoice number | Invoice number (+ unused stored student name) |
| D10 | Money format | Invoice currency, `$1,234.50` | Always `$`, `1234.50` |
| D11 | Amount colour | Black / green when settled | Status colour (red, amber, green, grey) |
| D12 | PAID decided by | Amounts (`total ≤ 0` or `paid ≥ total`) for buttons; stored status for badge | Stored status for badge; balance > 0 for button |
| D13 | Unknown status | Shown as PENDING | Shown as the raw word |
| D14 | Billing period | `period_start`–`period_end` ranges, `a..b`, fall-backs | Single `yyyy-MM` `period` only |
| D15 | Due chip on first late day | "0 days overdue" | Date chip |
| D16 | Cut-off strip | Warnings from 14 days before, "today", "N days ago"; due+1 fall-back; hidden when cancelled | Only "suspended N days ago", explicit cut-off only, not hidden when cancelled |
| D17 | No invoice number | "Invoice" | Document id |
| D18 | Missing student name | Shows student id | Shows nothing |
| D19 | Load error | Spinner for ever | Looks empty |
| D20 | Payment row title | Amount | "Payment" |
| D21 | Payment row detail | STATUS • date | date · method; status under amount |
| D22 | Payment colours | 4 (processing blue) | 3 (processing amber) |
| D23 | Payment row tap | Opens invoice | Nothing |
| D24 | Payment query | `parent_id` only, limit 100 | `parent_id` + `student_id`, unlimited |
| D25 | Dashboard card / banner / recent lists | Yes (parent dashboard) | None on the student dashboard |
| D26 | Languages | EN/FR/AR keys, many English literals | EN/FR |

Reusable as-is: the two-query merge, `createPaymentSession` call, student-name lookup, live updates, payments merge. Everything in D1–D4 and D14/D16 has to be built or changed to match.

---

## N. Broken, dead or inconsistent today

1. Web payment returns to the public home page for both success and cancel; no confirmation (B-064).
2. "Overdue" chip is almost always empty; late invoices sit under "Pending" (B-007).
3. Search hint promises parent/student/email/phone/ID; only the invoice number is searched (B-008).
4. Failed invoice/payment queries spin for ever; the written error states can never appear (B-010, B-097).
5. Auto-generated placeholder texts shown to parents: "Failed To Load Invoices NMessage", "Failed To Load Invoice NMessage", "Failed To Generate Pdf E", "Download Pdf", "When Invoices Are Created They Will", "Invoice Not Found For This Payment", "Unable To Load Parent Account Please".
6. "Download Pdf" does not download on the web; it opens the print dialog, and the file name is only used on phones (B-046, B-047).
7. PDF labels the issue date "Payment Date", calls the payer "From", prints "Received by: Muhammed Barry" on every invoice including unpaid ones, shows no status (B-051…B-056).
8. Company address/phone/email and the "received by" name are hard-coded in two places (`mock_company_service.dart`, `functions/utils/invoice_pdf.js`).
9. Invoice detail is not live; totals and the PDF can be stale after a payment (B-029, B-045).
10. Pay screen never shows CANCELLED (B-060); invoice detail shows a disabled "Pay Invoice" for cancelled invoices (B-031).
11. Multi-child invoices show one child in the app, all children on the pay-link page (B-012, B-089).
12. Payment History lists abandoned attempts; phone-sheet cancellations stay PROCESSING for ever (B-071, B-094).
13. Payment History ignores currency and omits invoice number, method and child (B-095).
14. Parents see which staff member created an invoice, with email/uid in a tooltip (B-042).
15. Dashboard card ignores `student_id` invoices, caps at 200, treats everything as USD, and uses a different "paid" basis from the invoice cards (B-115…B-118).
16. Suspension banner finds children by `guardian_ids` only; the server also suspends children linked by `children_ids` (B-107).
17. Lock strip can say "Access suspended today" up to 24h before the cut-off (B-025).
18. "0 days overdue" on the first late day (B-024).
19. Dead code: `AccessSuspendedScreen`; `InvoiceService.downloadInvoicePDF` (throws); `PaymentMethod` model + `payment_methods` rule + `payment_method_id` rule; callables `getParentInvoices` / `getPaymentHistory`; Payoneer path and model fields; the unused `paid` total.
20. Refunds made in Stripe are invisible to the app; payments on cancelled invoices and overpayments are only flagged (`needs_refund`, `overpaid_amount`) for a manual refund (B-080, B-082, B-083).
21. Manual payments carry only `parent_id`, so an adult student billed by `student_id` alone cannot see them (B-086).
22. Excuse form answers are stored in the parent's language; the built-in parent feedback form is English only; the built-in feedback form disappears when any form with "feedback" in its name is visible (B-127, B-128, B-136).
23. Parent forms with weekly/monthly frequency are locked on most days and swap to the teacher template when opened (B-131, B-134).
24. `createPaymentSession` tells any signed-in user whether an invoice id is cancelled or paid before checking ownership (B-074).
25. Memory note check — archive blind spot: none of the parent money screens read `teaching_shifts`, so the 60-day archive does not affect them (invoices carry their own amounts). Invoice duplication: the parent screens simply list whatever invoices exist; a duplicate shows as a second payable invoice, and cancelled duplicates remain visible under "Cancelled".

---

## O. Every place two screens can show a different money number for the same family

| Where | Number | Basis | Can differ from |
|---|---|---|---|
| Invoice card / detail "Amount Due" / pay screen "Remaining" / PDF "Remaining Balance" | per invoice | `max(0, total_amount − paid_amount)` | Dashboard card (below); Stripe charge if balance changed between page load and click (server recomputes) |
| Dashboard "Outstanding" | all invoices | `total − max(paid_amount, sum of completed payment amounts)`, newest 200 by issue date, `parent_id` only, cancelled skipped, stored `paid` NOT skipped | Sum of the cards (uses `paid_amount` only, 100 by due date, includes `student_id` invoices, hides Pay on amount-settled) |
| Dashboard "Overdue" | subset | same, where due date < now | "Overdue" chip (stored status), OVERDUE badges (same rule but per card), lock strip (cut-off date, not due date) |
| Invoice detail (not live) vs pay screen (live) | paid / remaining | snapshot at open vs live | each other, right after a payment |
| PDF from the app vs PDF in the email | all totals | app: invoice as loaded on the page; email: invoice at send time | each other |
| Invoice "Subtotal" | label | prints `total_amount` (after discounts and credits) | stored `subtotal` field (before discounts), which the finance screens use |
| Payment row amount | per payment | `payments.amount` = what was charged | `applied_amount` actually credited (overpayment, cancelled invoice) → history total can exceed what invoices show as paid |
| Payment History currency | symbol | always `$` | invoice currency |
| Next adult-student card | amount | `$` + 2 decimals, no currency, no thousands separator | Flutter format |
| Pay-link page "Balance due" | per invoice | `total − paid`, 2 dp, live on each visit | app invoice detail (stale) |
| Receipt email "amount paid" | per payment | amount charged | amount applied |
| Reminder email amount | per invoice | `$` + balance at send time | later balance |
| Stored status vs amounts | paid/pending | status string | amounts — badge follows status, buttons follow amounts (B-027); server suspension follows status first, then amounts (B-103) |

---

## P. Questions only the owner can answer

1. After paying on the web, where should a parent land? Today: the public home page with no message. (Needs a decision before any Next pay flow is called "matched".)
2. "Overdue" filter: keep today's behaviour (almost empty) or make it list every late invoice as the adult-student page already does? Same question for whether "Pending" should include late invoices.
3. Should parents see which staff member created an invoice (the "Decision history" box)?
4. PDF: keep the wording exactly ("Payment Date" for the issue date, "From:" for the payer, "Received by: Muhammed Barry" on unpaid invoices), or fix while moving? And on the web: keep "opens print dialog" or make it a real download?
5. Should Payment History keep showing abandoned/failed attempts, or only money actually received?
6. Absence excuse form: is "saved for an admin to read, nobody notified, nothing marked excused" the intended behaviour?
7. Are any parent forms meant to be weekly or monthly (they are locked most days)?
8. Second guardian: only the invoice's `parent_id` can see and pay. Intended?
9. Family invoices: show all children's names on the card and PDF, or keep first child only?
10. Is anything billed in a currency other than USD? (Several screens assume dollars.)
11. Should the dashboard card count invoices raised against the person as a student (adult students) and why does it deliberately take the larger of `paid_amount` and completed payments?
12. Stripe refunds: should a refund in Stripe reduce "paid" in the app, or stay manual?
