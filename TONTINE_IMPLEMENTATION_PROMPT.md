# Tontine (Savings Circle) Feature — Implementation Prompt

## READ THIS FIRST

You have full access to the Alluvial Academy codebase. **Read the code before writing anything.** The original feature spec was written by someone without full codebase access, so some assumptions are wrong. This prompt corrects those and tells you what to actually build, reusing existing patterns.

**Use your best judgement.** When something in this prompt conflicts with what you see in the code, trust the code. When two parts of this prompt conflict, prefer the simpler approach. The goal is a working feature that doesn't break anything, not perfection on day one.

---

## CODEBASE RULES (MANDATORY)

Read `CLAUDE.md` in the project root. It defines the feature-first architecture. Key rules:

- All tontine code goes in `lib/features/tontine/` with subfolders: `screens/`, `widgets/`, `services/`, `models/`, `config/`
- Cloud Functions go in `functions/handlers/circles.js`, exported from `functions/index.js`
- Do NOT add anything to `lib/core/` unless it's used by 3+ features
- State management: Provider (ChangeNotifier). No new packages.
- All user-facing strings use `AppLocalizations` (ARB files in `lib/l10n/`)
- Add translations to `app_en.arb`, `app_fr.arb`, `app_ar.arb`

---

## WHAT YOU'RE BUILDING

A rotating savings circle (tontine):
- Members each contribute a fixed amount every cycle (monthly)
- Each cycle, one member receives the entire pooled amount
- Rotates until every member has received exactly once
- No interest. No fees. Ever.

**Three circle types:**
1. **Open Circle** — Any user creates. Members can be anyone (inside or outside Alluwal). Creator is the tontine head.
2. **Teacher Circle** — Admin creates. Only platform teachers. Contributions deducted from teacher payouts manually by admin.
3. **Parent Circle** — Admin creates. Only platform parents. Manual contributions with receipt upload, same as Open Circles.

---

## HOW THE CODEBASE WORKS (KEY CONTEXT)

### Navigation Architecture

**Web (desktop):** `DashboardPage` in `lib/features/dashboard/screens/dashboard.dart` uses an index-based `_buildScreenForIndex()` switch statement. Currently 28 screens (indices 0-27). `_screenCount = 28`. Sidebar items are defined in `lib/features/dashboard/config/sidebar_config.dart` per role.

**Mobile (iOS/Android):** `MobileDashboardScreen` in `lib/features/dashboard/screens/mobile_dashboard_screen.dart` has its own bottom-nav per role. This is the primary target.

**Parent role:** Has its own layout: `ParentDashboardLayout` in `lib/features/parent/screens/parent_dashboard_layout.dart` with separate index (0-7).

**Role routing:** `RoleBasedDashboard` in `lib/features/dashboard/screens/role_based_dashboard.dart` routes by `userRole` — on mobile always returns `MobileDashboardScreen`, on web returns role-specific dashboard. Currently handles: `admin`, `super_admin`, `teacher`, `student`, `parent`.

### Roles System

- `users` collection stores `user_type` (primary role) and `secondary_roles: List<String>`
- `UserRoleService` in `lib/core/services/user_role_service.dart` handles role detection, caching, switching
- Existing roles: `admin`, `super_admin`, `teacher`, `student`, `parent`
- The `is_admin_teacher` bool is a legacy dual-role flag still in use

### Authentication

- Current auth: email/password only via `flutter_login` package
- Login screens: `lib/features/auth/screens/login.dart` (web) and `mobile_login_screen.dart` (mobile)
- No phone auth currently. No deep linking currently.

### Notifications

- `NotificationService` in `lib/core/services/notification_service.dart` — FCM-based push notifications
- Cloud Function `sendAdminNotification` in `functions/handlers/notifications.js` handles sending
- Pattern: callable Cloud Functions that look up FCM tokens and send via `admin.messaging()`

### Firestore Rules

- `firestore.rules` in project root — has helper functions `isSignedIn()`, `isOwner()`, `isAdminRole()`
- Currently fairly permissive for authenticated users. You'll add rules for the new collections.

### Existing Payment Patterns

- `lib/features/parent/services/payment_service.dart` — reads from `payments` collection
- `functions/handlers/payments.js` — payment-related Cloud Functions
- Parent invoicing exists in `lib/features/parent/screens/` — good reference for receipt/payment UI patterns

---

## WHAT TO BUILD — PHASED APPROACH

### Phase 1: Core Data Layer + Open Circles (Build This First)

**1a. Firestore Collections**

Create these new collections:

```
circles/
  {circleId}
    type: "open" | "teacher" | "parent"
    title: string
    status: "forming" | "active" | "completed" | "cancelled"
    contributionAmount: number
    currency: "USD"
    frequency: "monthly"
    totalMembers: number
    currentCycleIndex: number
    createdBy: string (userId)
    createdAt: timestamp
    startDate: timestamp
    rules: {
      gracePeriodDays: number,
      missedPaymentAction: "move_to_back" | "suspend"
    }
    paymentInstructions: string

circle_members/
  {memberId}
    circleId: string
    userId: string
    displayName: string
    photoUrl: string?
    contactInfo: string (phone or email used to invite)
    isTontineHead: bool
    payoutPosition: number
    status: "invited" | "active" | "suspended" | "completed" | "removed"
    joinedAt: timestamp?
    totalContributed: number
    totalReceived: number
    hasReceivedPayout: bool

circle_cycles/
  {cycleId}
    circleId: string
    cycleNumber: number
    dueDate: timestamp
    payoutRecipientUserId: string
    payoutAmount: number
    status: "pending" | "in_progress" | "completed"
    totalExpected: number
    totalCollected: number
    payoutSentAt: timestamp?
    payoutConfirmedBy: string?

circle_contributions/
  {contributionId}
    circleId: string
    cycleId: string
    userId: string
    displayName: string
    expectedAmount: number
    submittedAmount: number?
    amountIsCorrect: bool?
    status: "pending" | "submitted" | "confirmed" | "rejected" | "missed"
    paymentMethod: "manual" | "payroll_deduction"
    receiptImageUrl: string?
    submittedAt: timestamp?
    paymentDate: timestamp?
    confirmedAt: timestamp?
    confirmedBy: string?
    rejectionReason: string?

circle_invites/
  {inviteId}
    circleId: string
    inviteCode: string (8 chars)
    inviteMethod: "phone" | "email"
    contactInfo: string
    createdBy: string
    createdAt: timestamp
    expiresAt: timestamp
    status: "pending" | "accepted" | "expired"
    existingUserId: string? (if contact matched existing user at invite time)
    acceptedBy: string?
    acceptedAt: timestamp?
```

**1b. Flutter Models** — `lib/features/tontine/models/`

Create Dart model classes for each collection above. Follow the same pattern as existing models (e.g., `Payment.fromFirestore(doc)` in `lib/features/parent/models/payment.dart`). Each model should have:
- Named constructor from fields
- `fromFirestore(DocumentSnapshot doc)` factory
- `toMap()` for writing to Firestore

**1c. Tontine Service** — `lib/features/tontine/services/tontine_service.dart`

Core service class. Follow the pattern of `ShiftService` or `PaymentService` — static methods, direct Firestore access. Key methods:
- `createCircle(...)` → creates circle doc + creator as first member (isTontineHead: true)
- `getMyCircles(userId)` → stream of circles where user is a member
- `getCircleMembers(circleId)` → stream of members
- `getCurrentCycle(circleId)` → current cycle doc
- `getContributionsForCycle(cycleId)` → stream of contributions
- `submitContribution(...)` → creates/updates contribution doc
- `confirmContribution(contributionId)` / `rejectContribution(contributionId, reason)`
- `markPayoutSent(cycleId)` → marks cycle complete
- `inviteMember(circleId, contactInfo, method)` → creates invite doc

**1d. Screens** — `lib/features/tontine/screens/`

Build these screens. **Mobile-first design.** Use existing app patterns (Google Fonts, theme colors, responsive layouts).

1. **`tontine_home_screen.dart`** — Entry point. Shows list of user's circles as cards. Empty state with "Create a Circle" button. Each card shows: name, amount, days to next due, status pill (Forming/Active/Your Turn).

2. **`circle_dashboard_screen.dart`** — Main view for one circle. Header with circle name, "Month X of Y", countdown, pot amount, this month's recipient. Payment status board as a grid of member tiles (2 columns on mobile). Each tile shows: avatar, name, payout position, status color (green=confirmed, yellow=submitted, red=unpaid). Tapping a tile shows payment detail. Bottom action: "Submit My Payment" or "Review Submissions" for head.

3. **`submit_payment_screen.dart`** — Amount input with live validation against expected. Receipt upload (camera default on mobile, gallery as secondary). Payment date picker (defaults to today). Submit button disabled until receipt attached. On success, updates Firestore and shows confirmation.

4. **`review_submissions_screen.dart`** — For tontine head only. Progress bar. List of member submissions with receipt thumbnails, amount match indicator, confirm/reject buttons. Reject requires reason text.

5. **`create_circle_screen.dart`** — Multi-step form. Step 1: name, amount, member count, start date. Step 2: grace period, missed payment action, payment instructions text. Step 3: invite by phone or email (input + add as chips). Step 4: set payout order (draggable list). Step 5: review summary + create. Use `Stepper` widget or a custom step indicator.

6. **`join_circle_screen.dart`** — Shown when accepting an invite. Circle preview (name, head, amount, member count). For existing users: auto-join. For new users: signup flow (Phase 2).

**1e. Navigation Integration**

This is critical. Follow the existing patterns exactly:

- **Web dashboard:** Add tontine screen at index 28 in `_buildScreenForIndex()` in `dashboard.dart`. Increment `_screenCount` to 29. Add a "Circles" sidebar item in `sidebar_config.dart` for admin, teacher, and parent roles.

- **Mobile dashboard:** Add a "Circles" tab to the bottom navigation in `mobile_dashboard_screen.dart` for roles that have circle access. Follow the existing pattern of how tabs are built per role.

- **Parent dashboard:** Add a "Circles" entry in `parent_dashboard_layout.dart` if the parent has circle membership.

- **Role routing:** In `role_based_dashboard.dart`, the `member` role (Phase 2) should route to a tontine-only shell. For now, existing roles just get a new sidebar/tab entry.

**1f. Cloud Functions** — `functions/handlers/circles.js`

Create and export from `functions/index.js`. Follow the existing pattern (see `handlers/notifications.js` or `handlers/shifts.js`).

- `onCircleActivated` — Firestore trigger on `circles/{id}` when status changes to "active". Creates first cycle doc, notifies all members.
- `onContributionSubmitted` — Firestore trigger on `circle_contributions/{id}` when status changes to "submitted". Notifies head and all members.
- `onContributionConfirmed` — Trigger. Checks if all confirmed for current cycle. If yes, notifies head.
- `onPayoutMarkedSent` — Trigger on `circle_cycles/{id}` status → "completed". Updates recipient, advances cycle, creates next cycle doc, notifies everyone. If final cycle, marks circle completed.
- `sendCircleInvite` — Callable. For Phase 1, just creates the invite doc in Firestore. SMS/email sending is Phase 2 (for now, invites work in-app only).

**1g. Firestore Security Rules**

Add to `firestore.rules`:
- `circles`: read if authenticated and user is a member (query circle_members) or admin. Write if admin (for teacher/parent circles) or any authenticated user (for open circles, creator only).
- `circle_members`: read if you're a member of that circle or admin. Write restricted to circle head or admin.
- `circle_cycles`: read if member of circle. Write only via Cloud Functions (admin SDK).
- `circle_contributions`: read if member of circle. Write your own contribution only. Confirm/reject only if you're the head.
- `circle_invites`: read if you created the invite, are the invitee, or are admin. Write if creating for your own circle.

Key privacy rule: **Tontine queries must never join with the `users` collection.** All display data (name, photo) is stored directly on `circle_members`. This prevents heads from accessing internal Alluwal data.

---

### Phase 2: Member Role + External Invites (Build After Phase 1 Works)

**2a. New `member` Role**

Add `"member"` as a recognized user_type. A member:
- Joined Alluwal solely for a tontine circle
- Sees ONLY the tontine screens after login
- Has no access to shifts, chat, forms, classes, or any education features

In `role_based_dashboard.dart`, add a case for `'member'` that returns a tontine-only shell (just `TontineHomeScreen` with a simple app bar, no sidebar/bottom nav beyond circles).

In `UserRoleService.getAvailableRoles()`, `member` is treated like any other role — no special admin/teacher switching logic.

**2b. Phone Authentication**

Add Firebase phone auth (OTP via SMS) for new member signups:
- Enable Phone provider in Firebase Console (must be done manually, not in code)
- Create `lib/features/tontine/screens/phone_signup_screen.dart` — phone input → OTP verification → name entry → creates `member` account
- Only used for new members invited by phone. Does NOT change existing login flows.

**2c. Invite Flow for New Users**

When a tontine head invites by phone or email:
1. Cloud Function `sendCircleInvite` checks if contact exists in `users` collection
2. If exists: sets `existingUserId` on invite doc, sends in-app notification to that user
3. If not exists: for Phase 2, creates a pending invite. SMS/email sending requires Twilio or similar — configure separately.
4. When new user signs up via the invite flow, auto-join the circle.

**2d. Deep Linking (Phase 2 stretch)**

Format: `https://yourdomain.app/join?code=XXXXXXXX`
- This requires Firebase Dynamic Links or a custom solution
- If app installed: open directly to join screen with code pre-filled
- If not installed: redirect to store
- This is a nice-to-have for Phase 2 — in-app invite codes work fine for launch

---

### Phase 3: Admin Panel + Teacher/Parent Circles

**3a. Admin Tontine Management Screen** — `lib/features/tontine/screens/admin_circles_screen.dart`

Three tabs: Open / Teacher / Parent circles. Each shows a list with filters (status, date). Tap any circle for read-only ledger view.

**3b. Create Teacher Circle Flow**

Admin selects teachers from platform teacher list. System shows each teacher's average monthly earnings (query from existing `teaching_shifts` or payment data). Contribution must be ≤ 20% of average earnings — warn if exceeded. On create, send in-app invitations to teachers.

**3c. Teacher Circle Contribution Flow**

When admin processes monthly payouts (existing manual flow), show a deduction banner for circle teachers: "Circle deduction: $X. Send $Y instead of $Z." After sending adjusted payout, admin taps "Record Contribution" → logs in Firestore, notifies teacher.

**3d. Parent Circle Flow**

Admin creates, selects parents from existing parent list. Contributions work exactly like Open Circles (manual payment + receipt upload).

**3e. Monthly Payout Overlay**

Integrate with existing payment screens in `lib/features/parent/screens/` — when admin views a teacher's payout who is in a circle, show the deduction info.

---

### Phase 4: Trust Score + Polish

**4a. Trust Score**

Add to user document:
```
trustScore: {
  circlesCompleted: number,
  totalOnTimePayments: number,
  totalLatePayments: number,
  totalMissedPayments: number,
  lastUpdated: timestamp
}
```

Badges (displayed in circle member tiles only):
- No completed circles → "New Member"
- 1+ completed, < 2 late → "Trusted Member"  
- 2+ completed, 0 missed → "Community Pillar"

**4b. Notifications**

Use the existing `NotificationService` pattern. Key events:
- Circle activated → all members
- 3 days before due date → pending members
- Payment submitted → head + all members
- Payment confirmed/rejected → that member
- All paid → head ("Mark payout as sent")
- Payout sent → recipient + all members

Cloud Functions handle sending via FCM. Follow `functions/handlers/notifications.js` pattern.

---

## THINGS NOT TO BUILD

- No Stripe/automated payments — all payments are manual with receipt proof
- No bank/mobile money linking
- No public circle discovery/search
- No AI suggestions
- No interest or penalty fees
- No web-optimized tontine UI (mobile-first, web just needs to work)
- No email sending infrastructure in Phase 1 (use in-app invites)
- No SMS infrastructure in Phase 1 (requires Twilio setup separately)

---

## EDGE CASE: EXISTING USER INVITED TO OPEN CIRCLE

When a tontine head invites a phone/email that belongs to an existing teacher/parent/admin:
1. System detects the match silently at invite time (sets `existingUserId` on invite doc)
2. Existing user gets an in-app notification
3. They accept → added to circle with their existing account
4. Their role does NOT change — they just gain circle access
5. Tontine head sees them as a circle member only — no role/class/earnings info exposed
6. A "Circles" entry appears in their existing sidebar

---

## PRIVACY — ENFORCE AT EVERY LAYER

1. **Firestore rules** prevent `member` users from reading any collection except circles-related ones and their own user doc
2. **Circle member tiles** display data from `circle_members` collection, never from `users` collection
3. **Tontine head** of an Open Circle has zero access to internal Alluwal data
4. **Teacher/Parent Circles** are invisible to non-admin, non-member users
5. **`existingUserId`** on invites is readable only by admin and the circle creator

---

## FILE STRUCTURE SUMMARY

```
lib/features/tontine/
  models/
    circle.dart
    circle_member.dart
    circle_cycle.dart
    circle_contribution.dart
    circle_invite.dart
  services/
    tontine_service.dart
  screens/
    tontine_home_screen.dart
    circle_dashboard_screen.dart
    submit_payment_screen.dart
    review_submissions_screen.dart
    create_circle_screen.dart
    join_circle_screen.dart
    admin_circles_screen.dart        (Phase 3)
    phone_signup_screen.dart          (Phase 2)
  widgets/
    circle_card.dart
    member_tile.dart
    payment_status_board.dart
    cycle_countdown.dart
    trust_badge.dart

functions/handlers/circles.js
```

---

## HOW TO VERIFY YOUR WORK

After each phase:
1. Run `flutter analyze` — zero errors
2. Run the app on mobile (Android or iOS) — tontine screens load, navigation works
3. Create a circle, add members, submit a payment, confirm it, mark payout — full flow works
4. Check that NO existing feature is broken — dashboard, shifts, chat, forms all still work
5. Check that `_screenCount` in dashboard.dart matches the actual number of screens
6. Check that sidebar_config.dart entries have correct `screenIndex` values

---

## IMPORTANT NOTES FOR THE AI

- **Don't over-engineer.** Build the simplest working version first. You can refactor later.
- **Reuse existing patterns.** Look at how `ShiftService`, `PaymentService`, `ChatService` are structured. Look at how screens are built in `features/parent/screens/`. Copy those patterns.
- **Receipt upload:** Look at how profile picture upload works in `lib/features/profile/` for image upload patterns. Use Firebase Storage with path `circle_receipts/{circleId}/{contributionId}.jpg`.
- **Don't touch auth for Phase 1.** Phone auth and deep linking are Phase 2. For Phase 1, invites work in-app only — the head creates the circle, adds members who are already on the platform by searching existing users.
- **Mobile-first** means: design for phone screen first, use bottom sheets instead of dialogs where possible, large touch targets, camera as default for receipt upload.
- **When in doubt, skip it.** If something seems too complex for the phase you're on, leave a `// TODO: Phase X` comment and move on. A working Phase 1 is worth more than a half-finished Phase 3.
- **Translations:** Add all strings to ARB files. Don't hardcode any user-facing text. Use the existing pattern in `app_en.arb`.
