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
