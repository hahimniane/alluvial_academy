# Teacher console parity rule

The teacher console is moving from the Flutter web app (`/app/`) to the Next.js
app (`/teacher/`), the same way students moved to `/student/` in August 2026.

**The rule: a teacher signing in on the web must not be able to tell which app
they are using.** Same screens, same data, same actions, same words, same
outcomes. Anything less is not a migration, it is a downgrade — and unlike a
cosmetic regression, a missing teacher action costs someone a class or a
payment.

## The gate: no screen ships until it passes all seven

A ported screen is done when, checked against the Flutter screen it replaces:

1. **Entry point.** Same sidebar section, label, icon and order. The URL is
   reachable directly and survives a refresh.
2. **Data.** Same Firestore collections, filters, ordering and limits; same
   callables with the same arguments. Where a period of classes is involved it
   reads live **and** archived shifts (see the money rule below).
3. **Actions.** Every button, menu item, dialog and swipe action in Flutter
   exists here and performs the same write, with the same confirmation and the
   same validation. No action is silently dropped as "rare".
4. **States.** Loading, empty, error and permission-denied all render, and say
   what the Flutter screen says.
5. **Rules.** Role gating matches: a teacher sees exactly what a teacher saw,
   no more. Admin-only affordances stay out.
6. **Words.** Labels and messages match the Flutter copy, and French is
   translated. Copy never describes build state or past behaviour.
7. **Proof.** Exercised against production with a real teacher account, both
   read and write, before it counts as done.

## Cutover

- The redirect flipping teachers from Flutter to Next.js is the **last** change,
  not the first. Until every screen passes, `/teacher/*` keeps forwarding to
  `/app/`.
- Flip behind the same mechanism students use: the role switch in
  `lib/features/dashboard/screens/role_based_dashboard.dart`, web only. The
  native store app stays on Flutter.
- The Flutter teacher screens stay in the tree after the flip. They are still
  the phone app.

## Constraints that bind every screen here

- **Auth persistence**: `apps/web/src/lib/firebase.ts` pins
  `browserLocalPersistence`. Never call `getAuth()` first, or Flutter is signed
  out. Any page embedded in Flutter also needs the COEP header.
- **Money**: hours, pay, invoices and attendance read live **and** archived
  shifts through the shared readers. Guard tests enforce it.
- **Web and phone parity**: a customer-facing change does not ship web-only.
  The Flutter phone app keeps its own teacher screens; if behaviour changes,
  both change.

## Progress

Tracked in `docs/teacher-web-parity-status.md`, one row per screen with its
verdict against the seven checks. A screen may only be marked done when its
row says so.
