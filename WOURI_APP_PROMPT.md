# Build "Wouri" — A Standalone Tontine (Rotating Savings Circle) App

You are building a complete standalone mobile app called **Wouri** using React Native (Expo) with its own Firebase backend. Wouri is a tontine app — a rotating savings circle where a group of people each contribute a fixed amount every cycle, and each cycle the full pot goes to one member in a fixed order until everyone has received once.

**This app is standalone** — it has its own Firebase project, its own auth, its own Firestore. However, it connects to an external platform called "Alluvial Academy" via a REST API to pull teacher and parent data for admin-created circles. Build the entire app end-to-end. Do not ask any questions. Make all reasonable design decisions yourself.

---

## Tech Stack

- **Frontend:** React Native with Expo (managed workflow), TypeScript throughout
- **Navigation:** React Navigation (bottom tabs + stack navigators)
- **State Management:** Zustand
- **Backend:** Firebase (Authentication email/password, Firestore, Cloud Functions v2 Node.js/TypeScript, Cloud Messaging, Firebase Storage)
- **Image Picking:** expo-image-picker (for receipt photos)
- **Date Formatting:** date-fns
- **Styling:** NativeWind (TailwindCSS for React Native)
- **Localization:** i18next with react-i18next (English, French, Arabic — RTL support for Arabic)
- **Phone Input:** react-native-phone-number-input (for phone-based invites with country code picker)

---

## Core Concepts

A **circle** is a savings group. Members each contribute a fixed amount every cycle (weekly/biweekly/monthly/quarterly). Each cycle, the entire pooled amount (the "pot") goes to one member based on a pre-set payout order. This rotates until every member has received the pot exactly once.

**Key terminology in the data model:**
- **Circle** = the savings group. Firestore collection is `circles`.
- **Tontine Head** = the creator/manager of the circle (`is_tontine_head: true` on their member doc)
- **Cycle** = one collection+payout period. Cycle N means the member at payout position N receives the pot.
- **Contribution** = a single member's payment for a specific cycle
- **Payout** = when the collected pot is sent to the designated recipient

**Three circle types:**
1. **Open (`type: "open"`)** — Any Wouri user creates a circle. They become the tontine head. They invite members by email or phone. Payments are manual (members upload receipt photos, head confirms/rejects).
2. **Teacher (`type: "teacher"`)** — Created by a Wouri admin. Members are teachers fetched from the Alluvial Academy API. Can use "manual selection" (admin picks specific teachers) or "open enrollment" (teachers who meet eligibility rules can self-join). Contributions tracked as "payroll deduction" (admin deducts from teacher payouts externally).
3. **Parent (`type: "parent"`)** — Created by a Wouri admin. Members are parents fetched from the Alluvial Academy API. Manual selection only. Receipt-based payments like open circles.

---

## Alluvial Academy Integration API

Wouri does NOT have direct access to Alluvial Academy's database. Instead, you must build a simple REST API (as Firebase Cloud Functions HTTP endpoints in Wouri's own backend) that proxies requests to Alluvial Academy. For now, build the Wouri side of the integration assuming the following API contract exists. Create placeholder/mock implementations that return realistic data so the app is functional, with clear TODO comments marking where real API calls will go.

### API Endpoints to Build (on Wouri's Cloud Functions)

**`GET /api/alluvial/teachers`**
Returns a list of active teachers from Alluvial Academy.
```json
{
  "teachers": [
    {
      "alluvial_user_id": "abc123",
      "display_name": "Fatou Diallo",
      "email": "fatou@example.com",
      "phone_number": "+12125551234",
      "photo_url": "https://...",
      "hourly_rate": 25.0,
      "employment_start_date": "2024-06-15T00:00:00Z",
      "is_active": true
    }
  ]
}
```

**`GET /api/alluvial/teachers/:userId/shifts?days=30`**
Returns shift count and total hours for a teacher in the last N days (for eligibility checking).
```json
{
  "shift_count": 12,
  "total_hours": 18.5
}
```

**`GET /api/alluvial/parents`**
Returns a list of active parents from Alluvial Academy.
```json
{
  "parents": [
    {
      "alluvial_user_id": "def456",
      "display_name": "Amadou Ba",
      "email": "amadou@example.com",
      "phone_number": "+221771234567",
      "photo_url": null,
      "is_active": true
    }
  ]
}
```

**`GET /api/alluvial/teachers/:userId/eligibility`**
Returns pre-computed eligibility data for a teacher.
```json
{
  "hourly_rate": 25.0,
  "estimated_monthly_income": 1000.0,
  "employment_start_date": "2024-06-15T00:00:00Z",
  "months_employed": 22,
  "shifts_last_30_days": 12
}
```

When the Alluvial Academy team is ready, they will expose matching endpoints on their side. For now, use mock data with 10-15 realistic teacher records and 5-10 parent records. Include a mix of names from West African cultures (Wolof, Mandinka, Fula, Diola names) and some generic names.

### How Integration Works in the App

- When an admin creates a teacher or parent circle, the "Select Members" panel fetches from these API endpoints instead of querying Wouri's own `users` collection.
- Selected teachers/parents are stored as `circle_members` in Wouri's Firestore with their `alluvial_user_id` in an extra field. They do NOT need Wouri accounts to be members — the admin manages their contributions on their behalf.
- For "open enrollment" teacher circles, the eligibility service calls the eligibility endpoint to check each teacher's income, tenure, and shift activity.
- Push notifications for teacher/parent circles go only to the admin (tontine head), since teachers/parents may not have the Wouri app installed.

---

## Firestore Data Model

All top-level collections (NOT subcollections):

### Collection: `users`
```
users/{userId}
  uid: string
  display_name: string
  first_name: string
  last_name: string
  email: string
  phone_number: string
  profile_picture_url: string | null
  user_type: "user" | "admin" (default "user")
  date_added: Timestamp
  is_active: boolean
  fcm_token: string | null
  fcm_tokens: [{ token: string, platform: string, updated_at: Timestamp }]
```

### Collection: `circles`
```
circles/{circleId}
  title: string
  type: "open" | "teacher" | "parent"
  status: "forming" | "active" | "completed" | "cancelled"
  contribution_amount: number
  currency: string ("USD", "XOF", "EUR", "GBP", "CAD")
  frequency: "weekly" | "biweekly" | "monthly" | "quarterly"
  total_members: number
  current_cycle_index: number (0-based)
  created_by: string (userId)
  created_at: Timestamp (use FieldValue.serverTimestamp())
  start_date: Timestamp
  rules: {
    grace_period_days: number,
    missed_payment_action: "move_to_back" | "suspend"
  }
  payment_instructions: string
  enrollment_mode: "manual" | "open" (only meaningful for teacher circles)
  max_members: number | null (only for open enrollment)
  eligibility_rules: {
    income_multiplier: number,
    min_tenure_months: number,
    min_shifts_last_30_days: number
  } | null
```

### Collection: `circle_members`
```
circle_members/{memberId}
  circle_id: string
  user_id: string (Wouri userId for open circles, OR alluvial_user_id for teacher/parent circles)
  display_name: string
  photo_url: string | null
  contact_info: string (email or phone)
  is_tontine_head: boolean
  payout_position: number (1-indexed)
  status: "invited" | "active" | "suspended" | "completed" | "removed"
  joined_at: Timestamp | null
  total_contributed: number (running total, updated by Cloud Function)
  total_received: number (running total, updated by Cloud Function)
  has_received_payout: boolean
  alluvial_user_id: string | null (set for teacher/parent members pulled from Alluvial API)
```

### Collection: `circle_cycles`
```
circle_cycles/{cycleId}
  circle_id: string
  cycle_number: number (1-indexed)
  due_date: Timestamp
  payout_recipient_user_id: string
  payout_amount: number
  status: "pending" | "in_progress" | "completed"
  total_expected: number
  total_collected: number
  payout_sent_at: Timestamp | null
```

### Collection: `circle_contributions`
```
circle_contributions/{contributionId}
  circle_id: string
  cycle_id: string
  user_id: string
  display_name: string
  expected_amount: number
  submitted_amount: number | null
  amount_is_correct: boolean | null
  status: "pending" | "submitted" | "confirmed" | "rejected" | "missed"
  payment_method: "manual" | "payroll_deduction"
  receipt_image_url: string | null
  submitted_at: Timestamp | null
  payment_date: Timestamp | null
  confirmed_at: Timestamp | null
  confirmed_by: string | null
  rejection_reason: string | null
```

### Collection: `circle_invites`
```
circle_invites/{inviteId}
  circle_id: string
  circle_name: string
  invite_method: "email" | "phone"
  contact_info: string
  created_by: string (userId)
  created_at: Timestamp
  status: "pending" | "accepted" | "expired"
  existing_user_id: string | null
  accepted_by: string | null
  accepted_at: Timestamp | null
```

---

## Screens & Features — Build ALL of These

### 1. Auth Screens

**Welcome Screen:**
- App name "Wouri" in large bold text with a subtle wave/water motif (Wouri is a river in Cameroon)
- Tagline: "Save Together, Grow Together"
- Two buttons: "Sign Up" and "Log In"
- Language selector at the top (EN / FR / AR)

**Sign Up Screen:**
- Fields: First Name, Last Name, Email, Phone Number (with country code picker), Password
- On submit: create Firebase Auth user, then create Firestore `users` doc
- Navigate to Profile Setup

**Login Screen:**
- Email + Password
- "Forgot Password" link → Firebase Auth password reset email
- Navigate to Home on success

**Profile Setup (shown after first login if profile_picture_url is null):**
- Profile picture upload (camera or gallery → Firebase Storage at `profile_pictures/{userId}`)
- Phone number field (pre-filled if provided during signup)
- "Complete Setup" button

### 2. Home Screen (Main Tab — "My Circles")

**Top: Gradient banner** (teal `#0F766E` to green `#10B981`, top-left to bottom-right):
- Title: "Savings" (localized)
- Subtitle explaining what a tontine is
- Info icon (ⓘ) that shows a tooltip/bottom sheet with description on tap
- "Create Circle" button: white background, teal text, icon `add_circle_outline`

**Admin Quick Actions** (only if user's `user_type == "admin"`):
- White card with "Admin Actions" header and admin shield icon
- Two buttons side by side: "Teacher Circle" and "Parent Circle" — each navigates to Create Admin Circle screen with the respective type
- "View All" link in the header navigates to Admin Circles Management screen

**Pending Invites Banner** (only if user has pending invites — amber/yellow container):
- Header: "X Pending Invites" with envelope icon
- Lists up to 3 invites showing circle name and contact info
- Each has a "Review" button → navigates to Join Circle screen

**Available Circles Section** (only for users who are teachers — shown if open enrollment circles exist):
- Header: "Available Circles" with explore icon
- Lists open enrollment teacher circles in "forming" status
- Each card shows:
  - Circle title
  - Eligibility badge: "Eligible" (green) or "Not Eligible" (red) — determined by calling the Alluvial eligibility API
  - Monthly contribution amount
  - Open spots count (max_members - total_members) or "Unlimited"
  - Eligibility rule chips (income requirement, tenure requirement, shift requirement)
  - If not eligible: list of specific failure reasons in red
  - "Join Circle" button (disabled if not eligible or full)

**My Circles** — split into two sections:
- **"Circles I Created"** — where `created_by == currentUser.uid` (green border accent)
- **"Circles I Joined"** — where user is a member but not creator

Each circle renders a **CircleCard**:
- Circle title (bold, 18px)
- "Created by you" badge if creator (green shield icon + text)
- Status badge pill: Forming=amber `#F59E0B`, Active=green `#10B981`, Completed=blue `#2563EB`, Cancelled=red `#EF4444`
- Two info blocks side by side:
  - "Monthly Contribution": formatted currency amount
  - "Pot Amount": contribution × total_members
- Bottom row:
  - "Month X of Y" (current cycle of total) or "No active cycle"
  - Countdown chip: "Due in X days" (blue), "Due today" (green), "Overdue by Xd" (red), or "No deadline" (gray)
- Tap → Circle Dashboard screen

**Empty state** (no circles):
- Large circle container (84x84) with green bg and groups icon
- "No Circles Yet" title
- "Create your first savings circle or join one" subtitle
- "Create Circle" CTA button

### 3. Create Circle Flow (Open Circles — Regular Users)

Single scrollable screen with 4 sections, each with a step number header:

**Step 1 — Basics** (icon: sparkle, color: teal):
- Circle Name: text input with `group_work` icon, placeholder "e.g. Family Savings"
- Row: Contribution Amount (with $ prefix) + Member Count (side by side)
- Start Date: tappable row showing formatted date, with "Edit" chip that opens date picker (default: 30 days from now)
- Frequency: choice chips with icons — Weekly, Biweekly, Monthly (default), Quarterly
- Each field has an info (ⓘ) icon that opens a bottom sheet modal with explanation text

**Step 2 — Rules** (icon: shield, color: amber):
- Grace Period Days: number input with timer icon
- Missed Payment Action: dropdown — "Move to back of line" or "Suspend member"
- Payment Instructions: multiline text input, placeholder "e.g. Send via Zelle to ..."
- Each with info icon + bottom sheet

**Step 3 — Invite Members** (icon: people, color: blue):
- Blue info banner: "Search for existing Wouri users by email or phone. Non-users will receive an invitation."
- Invite method toggle: choice chips for "Email" or "Phone"
- Search input + "Add" button:
  - If email method: text input with `@` icon
  - If phone method: phone input with country code picker
  - On add: searches Wouri's `users` collection for matching email or phone
  - If found: shows user's name and adds them with their userId
  - If not found: adds them by contact info only (they'll get an invite email/SMS)
  - Duplicate detection by userId or contactInfo
- Participant count badge: "X of Y members added" — amber if incomplete, green when exact match
- List of added participants: each shows avatar (initials in gradient square), name, contact info, and red X remove button
- Creator is auto-added at position 1 and cannot be removed

**Step 4 — Payout Order** (icon: swap_vert, color: purple):
- Only shown when all members have been added (participant count == target)
- If not all added: amber warning box "Add all members before setting the payout order"
- When ready: drag-and-drop reorderable list
  - Each item: position number in gradient circle (green for creator, blue for others), name, contact info, drag handle
  - Creator's row has green background tint
  - Hint text: "Drag to reorder. Position 1 receives the pot first."

**Bottom bar:** Sticky "Create Circle" button (teal, with rocket icon). Shows spinner when creating.

**On submit:**
1. Validate: name required, amount > 0, member count >= 2, grace period >= 0, payment instructions required, participant count matches target
2. Create `circles` doc with `status: "forming"`, `type: "open"`
3. Create `circle_members` for each participant (creator = `status: "active"`, others = `status: "invited"`)
4. Create `circle_invites` for non-creator participants (triggers Cloud Function for email/SMS/push)
5. Navigate to Circle Dashboard

### 4. Create Admin Circle Screen (Admin Only — Teacher/Parent Circles)

Two-panel layout (side by side on tablet/desktop, tabs on phone):

**Left Panel — Circle Details form:**
- For teacher circles only: Enrollment Mode toggle with two tappable options:
  - "Manual Selection" (person_search icon): "Hand-pick teachers for this circle"
  - "Open Enrollment" (public icon): "Set rules and let eligible teachers join"
  - Selected option has teal border, teal tint bg, radio button filled
- Circle Name, Contribution Amount (USD), Start Date picker, Frequency dropdown
- Rules: Grace Period, Missed Payment Action, Payment Instructions

**Right Panel — depends on enrollment mode:**

*Manual Selection mode:*
- Header: "Select [Teachers/Parents]" with count badge "X Selected"
- Search bar: "Search by name or email..."
- Scrollable list fetched from Alluvial API (`GET /api/alluvial/teachers` or `/parents`)
- Each row: checkbox + avatar (photo or initials) + full name + email
- Selected rows have teal tint background
- Checkbox: teal filled with white checkmark when selected, gray border when not

*Open Enrollment mode (teacher circles only):*
- Header: "Eligibility Rules"
- Each rule field has icon, label, expandable hint text (ⓘ toggle):
  - Income Multiplier (monetization icon): "e.g. 1.6 means teacher's estimated monthly income must be >= 1.6x the contribution amount"
  - Minimum Tenure (calendar icon): dropdown — No minimum, 1 month, 3 months, 6 months, 12 months
  - Minimum Shifts in Last 30 Days (school icon): number input
  - Maximum Members (group icon): number input, "0 = Unlimited"

**Bottom bar:** "Create [Teacher/Parent] Circle" button.

**On submit (manual mode):**
1. Creates `circles` doc with `type: "teacher"` or `"parent"`, `status: "active"` (skips forming since admin selects members directly)
2. Creates `circle_members` for each selected teacher/parent with `status: "active"`, `alluvial_user_id` set
3. `onCircleActivated` Cloud Function fires, creating the first cycle + contribution docs

**On submit (open enrollment):**
1. Creates `circles` doc with `status: "forming"`, `enrollment_mode: "open"`, eligibility_rules set, `total_members: 0`
2. `onOpenCircleCreated` Cloud Function fires, evaluates teachers via API, sends notifications to eligible ones

### 5. Admin Circles Management Screen
- AppBar: "Admin Circle Management" with add button (popup menu: Teacher Circle / Parent Circle)
- Streams ALL circles from Firestore ordered by `created_at` descending
- Each row: Card with title (bold), subtitle "Type: [type] | Status: [status]", chevron right
- Tap → Circle Dashboard

### 6. Circle Dashboard Screen

The main detail view for a circle. Uses real-time listeners (Firestore snapshots) for circle, members, current cycle, and contributions.

**Computed values:**
- Is current user the tontine head?
- Current cycle's recipient member
- Confirmed count, submitted count of contributions
- Progress: confirmed / active_members
- Total pot: contribution_amount × total_members
- Can activate: is head AND circle is forming AND all members are active
- Completed payout count: members where has_received_payout == true

**Responsive:** Different layouts for mobile (< 1100px) and desktop (>= 1100px).

**Mobile Layout (scrollable ListView):**

1. **Circle Info Header** — dark card (`#0F172A` background, 24px border radius):
   - Circle title (white, 24px, w800)
   - Status badge + frequency badge (pills)
   - Row: Contribution amount + Pot amount (large white text)
   - Tontine head name with crown icon
   - Start date
   - If circle is forming and user is head: member progress (e.g., "3 of 5 members joined")

2. **Action Buttons:**
   - If head: "Review Submissions" button (primary, filled) — navigates to Review Submissions screen
   - If member: "Submit Payment" button — navigates to Submit Payment screen. Disabled with "Payment Confirmed" label if contribution already confirmed.
   - If forming + head + all members joined: "Activate Circle" button (green)
   - Activate calls `TontineService.activateCircle()` which sets status to "active" (triggers Cloud Function)

3. **Cycle Progress Card** (only when active cycle exists):
   - "Cycle X of Y" header with cycle status badge
   - Circular progress indicator: confirmed / total active members
   - Recipient: name with crown icon, "receives the pot this cycle"
   - Due date with countdown chip
   - Stats row: confirmed count, submitted count

4. **Payment Status Board** — grid of member tiles (2 columns mobile, 3+ desktop):
   Each **MemberTile** shows:
   - Top row: Avatar (photo or initials in circle, blue bg) + status badge pill
     - Status colors: Pending=red `#DC2626`, Submitted=amber `#F59E0B`, Confirmed=green `#10B981`, Rejected=red `#EF4444`, Invited=gray `#94A3B8`
   - Member name (truncated, 1 line)
   - Chips row: Position badge "#N" (gray pill) + "Current Recipient" badge (blue pill) if applicable
   - Amount: submitted amount in bold if paid, or expected amount in light gray if pending
   - Label: "Submitted" or "Expected"
   - Recipient tiles: blue border + light blue bg

5. **Member Management** (head only, forming status):
   - List of members with invite status
   - "Resend Invite" button for invited (pending) members — calls `resendCircleInvite` Cloud Function

6. **Edit button** in AppBar (head only) → Edit Circle screen

**Desktop Layout (two columns):**
- Left (60%): Circle info header, cycle progress, action buttons
- Right (40%): Payment status board with 3-column grid and larger tiles

### 7. Submit Payment Screen

For members to submit their contribution for the current cycle.

- **Summary Card** (dark `#0F172A` bg): circle title, expected amount formatted, due date
- **Payment Details Section** (white card):
  - Amount input (pre-filled with expected amount)
  - Helper text below: "Amount matches expected" or "Amount does not match expected"
  - Payment date: tappable row with date picker (default today, can pick up to 7 days in future, 365 days in past)
- **Receipt Section** (white card):
  - "Use Camera" filled button + "Choose from Gallery" outlined button
  - Shows selected file name OR existing receipt image preview if resubmitting a rejected contribution
  - "Receipt required" warning in red if none selected
- **Submit Button** (full width, disabled if no receipt or while submitting)

**On submit:**
1. Upload receipt to Firebase Storage at `circle_receipts/{circleId}/{cycleId}/{userId}/{filename}`
2. Create or update (merge) `circle_contributions` doc: status = "submitted", submitted_at = serverTimestamp
3. If resubmitting rejected contribution: reuse the same doc, overwrite status/amount/receipt
4. Show success snackbar, navigate back

### 8. Review Submissions Screen (Tontine Head Only)

- **Progress Card**: linear progress bar (green) showing confirmed/total, text "X of Y confirmed"
- **Member Submission Cards** (one per active member):
  - Avatar + name + status badge with color
  - Info rows: Expected Amount, Submitted Amount
  - If rejected: shows rejection reason
  - Receipt image preview (tappable for full screen)
  - Two buttons at bottom: "Reject" (outlined) + "Confirm" (filled)
    - Confirm: updates contribution status to "confirmed", Cloud Function increments member's `total_contributed`
    - Reject: opens dialog with text field for reason, updates status to "rejected" with reason
    - Both disabled when contribution is not in "submitted" status
- **"Mark Payout Sent" button** (bottom, full width): only enabled when ALL active members confirmed AND cycle not yet completed
  - On tap: marks cycle as "completed" → triggers `onCycleCompleted` Cloud Function which:
    - Updates recipient's `total_received` and `has_received_payout`
    - If more cycles remain: creates next cycle + contributions, notifies everyone
    - If all cycles done: marks circle as "completed"

### 9. Join Circle Screen (Accepting an Invite)

- **Gradient banner** (teal to green): circle title + "You've been invited to join this savings circle"
- **Info rows** (white cards, label on left, value on right):
  - Contribution Amount (formatted currency)
  - Frequency (Weekly/Biweekly/Monthly/Quarterly — localized)
  - Member Count
  - Circle Head (display name)
  - Start Date
- **"Join Circle" button** (full width)

**On join (transaction):**
1. Update invite: status → "accepted", accepted_by, accepted_at
2. Update member: status → "active", joined_at, display_name + photo from current user profile
3. Navigate to Circle Dashboard
4. Cloud Function `onMemberJoined` fires: notifies head, auto-activates if all members joined

### 10. Edit Circle Screen (Head Only)

Form with:
- Circle Name (text input)
- Contribution Amount (number input)
- Frequency (dropdown: weekly, biweekly, monthly, quarterly)
- Start Date (date picker)
- Grace Period Days (number input)
- Missed Payment Action (dropdown: Move to back / Suspend)
- Payment Instructions (multiline text)
- Save button in AppBar

On save: updates the `circles` doc. Shows success snackbar, pops back.

### 11. Notifications Screen (Tab)

- Lists all push notification history for the user
- Each notification: icon based on type, title, body, relative timestamp
- Tap navigates to relevant circle dashboard if applicable
- Mark as read on tap

### 12. Profile Screen (Tab)

- Profile picture (tappable to change)
- Display name, email, phone
- "Edit Profile" option
- "Sign Out" button
- App version at bottom

---

## Cloud Functions (Firebase Functions v2, TypeScript)

### Firestore Triggers:

**`onCircleActivated`** — trigger: `circles/{circleId}` update
When status changes TO "active":
1. Get all circle members ordered by payout_position
2. Get active members only
3. Determine recipient: member at payout_position = (current_cycle_index + 1)
4. Calculate due_date: start_date + (cycle_index months)
5. Create `circle_cycles` doc with status "in_progress"
6. Create `circle_contributions` doc for each active member (status "pending", payment_method "manual")
7. Send push notification to all members: "[title] is now active. [recipient] receives the first payout."

**`onContributionStatusChanged`** — trigger: `circle_contributions/{id}` update
When status changes:
1. Recalculate `total_collected` on the cycle doc (sum of all confirmed submitted_amounts)
2. If changed to "confirmed": increment member's `total_contributed` by submitted_amount
3. If changed to "submitted": notify head + all members "[name] submitted a payment"
4. If changed to "confirmed" AND all active members now confirmed: notify head "All contributions confirmed. You can mark the payout as sent."

**`onCycleCompleted`** — trigger: `circle_cycles/{id}` update
When status changes TO "completed":
1. Update recipient's `total_received` (increment by payout_amount) and `has_received_payout: true`
2. Calculate next_cycle_index = current_cycle_index + 1
3. If next_cycle_index >= total_members:
   - Mark circle status as "completed"
   - Mark all members status as "completed"
   - Notify everyone: "[title] has completed all payout cycles"
4. Otherwise:
   - Increment circle's current_cycle_index
   - Create next cycle + contributions (same logic as onCircleActivated)
   - Notify everyone: "[next_recipient] is the next payout recipient"

**`onMemberJoined`** — trigger: `circle_members/{id}` update
When status changes from "invited" to "active":
1. Notify tontine head: "[name] joined your savings circle"
2. Check if ALL members are now active AND circle is "forming" → auto-activate: set circle status to "active"

**`onInviteCreated`** — trigger: `circle_invites/{id}` create
1. If invite_method == "email": send invite email (use a simple email service — SendGrid, Mailgun, or just log for now with TODO)
2. If invite_method == "phone" and no existing_user_id: send SMS (Twilio placeholder with TODO)
3. If existing_user_id is set: send push notification via FCM

**`onOpenCircleCreated`** — trigger: `circles/{id}` create
When enrollment_mode == "open" and type == "teacher":
1. Call Alluvial API to get all teachers
2. For each teacher, call eligibility endpoint and check against circle's eligibility_rules
3. Send push notifications to eligible teachers (or log for now since they may not have Wouri installed — TODO)

**`onOpenCircleMemberAdded`** — trigger: `circle_members/{id}` create
When a new member joins an open enrollment circle:
1. If circle is "forming" and total_members reached max_members: auto-activate

### Callable Function:

**`resendCircleInvite`** — callable (authenticated)
1. Verify caller is the tontine head of the circle
2. Re-send the invite via the original method (email, SMS, and/or push)
3. Return `{ success: true, emailSent, smsSent, pushSent }`

### HTTP Endpoints (for Alluvial API proxy):

**`GET /api/alluvial/teachers`** — returns mock teacher data (see API section above)
**`GET /api/alluvial/teachers/:userId/shifts`** — returns mock shift data
**`GET /api/alluvial/teachers/:userId/eligibility`** — returns mock eligibility data
**`GET /api/alluvial/parents`** — returns mock parent data

Mark all with `// TODO: Replace with real Alluvial Academy API calls` comments.

---

## Push Notifications

Use Firebase Cloud Messaging. On app launch, request permission and save FCM token to user doc (both `fcm_token` field and append to `fcm_tokens` array with platform info).

**Notification types and when sent:**
- `circle_activated` — when circle status changes to active
- `circle_contribution_submitted` — when any member submits a payment
- `circle_cycle_ready_for_payout` — when all contributions confirmed (to head only)
- `circle_next_cycle_started` — when a new cycle begins
- `circle_member_joined` — when an invited member accepts (to head only)
- `circle_completed` — when all cycles are done
- `open_circle_available` — when new open enrollment circle created (to eligible teachers)
- `circle_invite` — when user is invited to a circle
- `circle_invite_reminder` — when invite is resent

Each notification carries `data` with `type`, `circleId`, and optionally `cycleId` or `inviteId` for navigation.

---

## UI Design System

**Color palette:**
| Token | Hex | Usage |
|---|---|---|
| primary | `#0F766E` | Buttons, headers, accents, tontine head badges |
| primary-light | `#CCFBF1` | Light teal backgrounds |
| success | `#10B981` | Active status, confirmed, eligible |
| warning | `#F59E0B` | Forming status, submitted, pending invites |
| info | `#2563EB` | Completed status, recipient highlight, cycle info |
| danger | `#EF4444` | Cancelled, rejected, missed, overdue |
| danger-dark | `#DC2626` | Pending contribution (unpaid) |
| text-primary | `#0F172A` | Primary text, dark card backgrounds |
| text-secondary | `#475569` | Labels, section headers |
| text-tertiary | `#64748B` | Helper text, secondary info |
| text-muted | `#94A3B8` | Placeholder text, disabled states |
| border | `#E2E8F0` | Card borders, dividers |
| bg-screen | `#F8FAFC` | Screen backgrounds |
| bg-card | `#FFFFFF` | Card backgrounds |

**Design patterns:**
- Cards: white bg, `borderRadius: 24`, shadow `rgba(15,23,42,0.07)` blur 20 offset-y 12
- Status badge pills: `borderRadius: 999`, 12% opacity background of status color, w800 font
- Gradient headers: `LinearGradient` from `#0F766E` to `#10B981`
- Section step headers: icon in colored rounded square (12% opacity) + title + step counter chip
- Info icons: small (18px) ⓘ in teal circle, open bottom sheet on tap
- Bottom sheets: white container with drag handle bar at top, rounded top corners
- Font weights: titles=w800, labels=w700, body=w600, helper=w600
- Buttons: filled teal bg, white text, borderRadius 14-16, padding 14-16
- Empty states: 84x84 circle with icon, title, subtitle, CTA
- Grids: 2 columns phone, 3+ tablet
- Form inputs: filled bg `#F8FAFC`, no visible border, teal focus border, 12px border radius
- Avatar initials: first letter of first name + first letter of last name, uppercase, bold, in colored circle

**Currency formatting:**
- USD: `$X,XXX` (dollar sign, comma separator)
- Other: `CURRENCY X,XXX` (e.g., `XOF 50,000`)
- Show decimals only if fractional part exists

---

## Navigation Structure

**Bottom Tab Bar (4 tabs):**
1. **Home** (house icon) — Tontine Home screen
2. **My Circles** (groups icon) — same as Home but focused on circle list (can combine with Home if preferred)
3. **Notifications** (bell icon with unread badge) — Notification list
4. **Profile** (person icon) — Profile screen

**Stack screens (pushed from any tab):**
- Circle Dashboard
- Create Circle
- Create Admin Circle
- Admin Circles Management
- Join Circle
- Submit Payment
- Review Submissions
- Edit Circle

---

## File Structure

```
src/
  app/
    App.tsx                     # Entry point, providers, navigation setup
    navigation.tsx              # Tab + stack navigator config
  components/
    CircleCard.tsx
    MemberTile.tsx
    CycleCountdown.tsx
    PaymentStatusBoard.tsx
    StatusBadge.tsx
    InfoBottomSheet.tsx
    GradientHeader.tsx
    EmptyState.tsx
  features/
    auth/
      screens/
        WelcomeScreen.tsx
        LoginScreen.tsx
        SignUpScreen.tsx
        ProfileSetupScreen.tsx
      services/
        authService.ts
    tontine/
      screens/
        TontineHomeScreen.tsx
        CreateCircleScreen.tsx
        CreateAdminCircleScreen.tsx
        AdminCirclesScreen.tsx
        CircleDashboardScreen.tsx
        SubmitPaymentScreen.tsx
        ReviewSubmissionsScreen.tsx
        JoinCircleScreen.tsx
        EditCircleScreen.tsx
      services/
        tontineService.ts       # All Firestore CRUD for circles
        eligibilityService.ts   # Calls Alluvial API for eligibility
        receiptUploadService.ts # Firebase Storage upload
        alluvialApiService.ts   # HTTP client for Alluvial API endpoints
      models/
        types.ts                # All TypeScript interfaces matching Firestore schema
      config/
        tontineUi.ts            # Color functions, status labels, currency formatting
    notifications/
      screens/
        NotificationsScreen.tsx
      services/
        notificationService.ts  # FCM setup, token management
    profile/
      screens/
        ProfileScreen.tsx
  hooks/
    useAuth.ts
    useCircle.ts
    useCircleMembers.ts
    useCurrentCycle.ts
    useContributions.ts
    usePendingInvites.ts
  stores/
    authStore.ts
  i18n/
    en.json
    fr.json
    ar.json
    index.ts
  utils/
    currency.ts
    initials.ts
    dates.ts
  theme/
    colors.ts
    spacing.ts

functions/
  src/
    index.ts                    # Exports all functions
    handlers/
      circles.ts                # All Firestore triggers
      alluvialProxy.ts          # HTTP endpoints for Alluvial API
    services/
      notifications.ts          # FCM helper
      mockAlluvialData.ts       # Mock teacher/parent data
    utils/
      helpers.ts
```

---

## Important Implementation Notes

1. **All Firestore field names use snake_case** (e.g., `circle_id`, `payout_position`, `created_at`). When parsing, also accept camelCase variants as fallbacks for robustness.

2. **Timestamps:** Always use `serverTimestamp()` for `created_at`, `joined_at`, `submitted_at`, `confirmed_at`. Use `Timestamp.fromDate()` for user-selected dates like `start_date`, `payment_date`, `due_date`.

3. **Batch writes:** Use Firestore batch writes when creating a circle (circle doc + member docs + invite docs in one batch). Use transactions for invite acceptance (prevent double-accept race condition).

4. **Real-time listeners:** Circle Dashboard must use Firestore `onSnapshot` listeners (not one-time reads) for circle, members, current cycle, and contributions — so the UI updates live when other members submit payments.

5. **Receipt upload:** Use expo-image-picker to get the image, then upload to Firebase Storage. Support both camera and gallery. For web compatibility, handle the platform difference.

6. **Eligibility service:** For open enrollment circles, call the Alluvial API endpoints. Compute: `estimated_monthly_income = hourly_rate * avg_weekly_hours * 4`. Check income >= contribution * income_multiplier, tenure >= min_tenure_months, shifts >= min_shifts_last_30_days. Return pass/fail for each rule with human-readable failure messages.

7. **Cycle creation logic:** When creating a cycle, the recipient is the active member whose `payout_position == cycle_index + 1`. Due date is `start_date + cycle_index months`. Payout amount is `contribution_amount * number_of_active_members`.

8. **Auto-activation:** Circles auto-activate when the last invited member joins (Cloud Function detects all members active → sets status to "active"). For open enrollment, auto-activates when total_members reaches max_members.

9. **Admin vs regular users:** Check `user_type` field on the user doc. Only admins see the admin quick actions and can create teacher/parent circles. Regular users can only create open circles.

10. **Teacher/parent members don't need Wouri accounts.** They are managed by the admin. Their `user_id` field stores the `alluvial_user_id`. The admin submits contributions and reviews them on their behalf for payroll deduction circles.

---

## Build Order

1. Expo project setup + Firebase config + NativeWind
2. Auth screens (Welcome, Login, SignUp, Profile Setup)
3. Zustand auth store + Firebase Auth integration
4. TypeScript interfaces for all Firestore models
5. i18n setup with EN/FR/AR translations
6. TontineService (all Firestore CRUD)
7. Tontine Home screen with circle list + CircleCard component
8. Create Circle flow (4-step form)
9. Circle Dashboard screen with all nested listeners
10. Submit Payment screen with receipt upload
11. Review Submissions screen with confirm/reject
12. Join Circle screen with invite acceptance
13. Edit Circle screen
14. Cloud Functions — all Firestore triggers
15. Cloud Functions — Alluvial API proxy with mock data
16. Create Admin Circle screen + Admin Circles Management
17. Eligibility service + Available Circles section
18. Push notification setup (FCM token, notification handlers)
19. Notifications screen
20. Profile screen

**Build everything. Do not stop until the app is complete and functional. Every screen, every Cloud Function, every service.**
