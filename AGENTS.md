# AGENTS.md — Canonical Rules for AI Coding Agents

> **This is the single source of truth for every AI agent working on this repo.**
> Claude Code, Cursor, Copilot, Windsurf, Aider, or any future tool — they all
> read this file (via symlinks or their tool-specific config pointer). Humans
> read it too. **Do not duplicate rules into tool-specific files.**

If you are an AI agent: **read this entire file before generating code.**
If you are a human contributor: read `CONTRIBUTING.md` first, then this file.

---

## 0. Why this file exists

Multiple developers on this project use AI coding assistants. They use
**different** assistants (Claude Code, Cursor, etc.), and even the same
developer may switch between tools for different tasks. Without a shared
source of truth, each agent applies its own conventions and the codebase
drifts into inconsistency.

This file fixes that. Every rule here is binding on every agent and every
human. CI enforces the subset that can be enforced mechanically
(`scripts/ci/check_architecture.sh`).

---

## 1. Project at a glance

- **Stack:** Flutter (web + Android + iOS) + Firebase (Auth, Firestore,
  Functions, Hosting).
- **Backend:** Node.js 20 Cloud Functions in `functions/`, Jest for tests.
- **State management:** Provider (`ChangeNotifier`). **Do not introduce** Riverpod, Bloc, GetX, or any other state library.
- **Localization:** ARB files in `lib/l10n/`. **All user-facing strings must
  go through `AppLocalizations`.**
- **Firebase projects:** `alluwal-academy` (prod), `alluwal-dev` (dev).

---

## 2. Architecture rules (ENFORCED)

### Directory structure for Flutter code

```
lib/
  core/           # Shared across 3+ features ONLY
  features/       # Each feature is self-contained
    <feature>/
      screens/
      widgets/
      services/
      models/
      config/
  l10n/           # ARB translation files
  main.dart       # Entry point
```

### What goes in `lib/core/`

Only code used by **3 or more features**. Specifically:
- `core/services/` — auth, connectivity, theme, language, timezone,
  notifications, user_role, settings, version, prayer_time, islamic_calendar,
  chat (~16 services max).
- `core/models/` — `user.dart`, `employee_model.dart`.
- `core/utils/` — generic utilities (platform detection, timezone conversion).
- `core/widgets/` — generic UI (responsive builder, role switcher).
- `core/theme/` — app theme.
- `core/constants/` — app constants, build info.
- `core/enums/` — shared enums.

**If a service, model, or widget is used by 1–2 features, it belongs in
that feature's folder, not in `core/`.**

### Hard bans (CI will fail the PR)

1. ❌ **Never** create new files directly in `lib/` root. Only `main.dart`
   and auto-generated `firebase_options*.dart` are allowed there.
2. ❌ **Never** add new files under `lib/admin/`, `lib/widgets/`,
   `lib/utility_functions/`. (A legacy `lib/screens/` exists — do not add to it.)
3. ❌ **Never** create new `.js` files in `functions/` root. Production
   handlers go in `functions/handlers/`. One-off scripts go in
   `functions/dev-scripts/`. Tests go in `functions/tests/`.
4. ❌ **Never** add feature-specific code to `core/`.
5. ❌ **Never** import from another feature's internal files
   (`lib/features/A/` must not import from `lib/features/B/`). If two
   features need the same code, move it to `core/`.

### Feature directory reference

| Feature folder | What it covers |
|---|---|
| `audit/` | Teacher audits, admin audit review, coach evaluations |
| `auth/` | Login, password reset, authentication |
| `chat/` | In-app messaging, voice messages |
| `dashboard/` | Main dashboard, sidebar, role-based routing |
| `enrollment_management/` | Student/teacher enrollment, applications |
| `forms/` | Form builder, submission, templates, drafts, responses |
| `livekit/` | Video calls, LiveKit rooms, guest join, recordings playback |
| `notifications/` | Push notifications, preferences |
| `onboarding/` | New user onboarding flow |
| `parent/` | Parent dashboard, invoicing, payments, student progress |
| `profile/` | User profile, profile pictures |
| `quran/` | Quran studies, recitation |
| `quiz/` | Quizzes, assessments |
| `recordings/` | Class recordings list, playback |
| `settings/` | System settings, debug tools, prayer times |
| `shift_management/` | Shift CRUD, scheduling, calendar, recurrence, wages |
| `student/` | Student-specific views |
| `surah_podcast/` | Surah podcast player, episodes |
| `tasks/` | Task management, assignments |
| `teacher_applications/` | Teacher application review |
| `time_clock/` | Clock in/out, timesheets, timesheet review |
| `tutor/` | AI tutor interface |
| `user_management/` | Admin user list, edit user, role management |
| `website/` | Public landing pages, program pages, team page, job board |
| `website_management/` | CMS, content management |

### Firebase Functions layout

```
functions/
  index.js          # Exports only, no logic
  handlers/         # Production Cloud Function handlers
  services/         # Shared business logic
  utils/            # Shared utilities
  dev-scripts/      # Test, debug, fix, migration scripts
  tests/            # Jest test files
```

---

## 3. Code rules

- **No new dependencies without a stated reason.** If you add a Flutter
  package or npm dependency, the PR description must explain why the
  existing stack can't do it.
- **No secrets in source.** `.env`, API keys, service-account JSON, and
  Firebase config with secrets never get committed. GitGuardian scans
  every PR — if a secret leaks, rotate it immediately and tell the repo
  owner so history can be rewritten.
- **Default to no comments.** Only comment *why* something non-obvious was
  done. Don't explain what the code does — names already do that.
- **Use `AppLocalizations`** for every user-facing string. Hardcoded
  English is a bug.
- **Match existing style.** Don't reformat files you didn't meaningfully
  change. Don't rename things just because you'd pick a different name.

---

## 4. Workflow rules (how PRs happen)

Short version — see `CONTRIBUTING.md` for the full spec.

- **Branch from `main`**, prefix with `feature/`, `fix/`, `hotfix/`,
  `chore/`, or `docs/`.
- **Short-lived.** Merge within 2–3 days.
- **Open a PR, fill the template, wait for CI to be green, get one review,
  squash-merge.**
- **Never push directly to `main`.** Branch protection will reject it.

---

## 4.5 Build & deployment commands (project-specific)

### Web build → Hostinger

- **Never** run `flutter build web --release` on its own. Always bump the
  cache-busting version first:
  ```bash
  ./increment_version.sh && flutter build web --release
  ```
  The script updates `?v=X` query strings in `web/index.html` for
  `flutter_bootstrap.js` and `manifest.json`. Without it, users won't see
  new deploys until they hard-refresh.

- Deployment workflow to Hostinger:
  1. `./increment_version.sh && flutter build web --release`
  2. Upload `build/web/` contents to Hostinger
  3. Ensure `web/.htaccess` is uploaded to the Hostinger root for proper
     cache headers

### Localization regeneration

- After editing any `lib/l10n/app_*.arb` file, run:
  ```bash
  flutter gen-l10n
  ```
  This regenerates `lib/l10n/app_localizations.dart`. Skipping it means new
  keys won't resolve and the app may fail to build.
- `main.dart` is already wired with `AppLocalizations.delegate` and
  `LanguageService.supportedLocales` (en, fr, ar).

### Firebase Functions deploy

- Dev: `cd functions && npm run deploy:dev` (project `alluwal-dev`)
- Prod: `cd functions && npm run deploy:prod` (project `alluwal-academy`)
- Never run `firebase deploy` without specifying `--project`. Prod and dev
  use the same function names — the wrong flag ships dev code to prod.

---

## 5. Testing expectations

- **Flutter:** if you change behavior, add or update a test in `test/`.
  `flutter test` must pass locally before you push.
- **Functions:** Jest tests live in `functions/tests/`. Run
  `cd functions && npm test` before you push.
- **CI blocks merge on test failures.** Do not disable tests to get a
  PR through — fix the test or fix the code.

---

## 6. Multi-agent coordination protocol

Because more than one person (and more than one AI) works in this repo:

1. **Declare before you start.** For non-trivial work (anything that will
   take more than ~1 hour or touches shared code), open a GitHub issue
   describing what you're about to change *before* you open the PR. If
   someone is already working on adjacent code, coordinate first.
2. **Small PRs.** One PR = one concern. If your agent proposes a PR that
   touches 30 files across 5 unrelated features, reject that plan and
   split it up.
3. **Respect `CODEOWNERS`.** Paths listed there need owner approval. Don't
   bypass.
4. **Read context before acting.** Any agent should:
   - Read this file.
   - Read `CLAUDE.md` (same content, different entry point).
   - Read `CONTRIBUTING.md` for workflow.
   - Skim `docs/` for architecture decisions before proposing new ones.
5. **Don't invent. Check.** Before recommending a file path, function, or
   flag, verify it exists in the current tree. Agent memory gets stale.

---

## 7. When a rule is wrong

If you (human or agent) have a good reason to break a rule, **update this
file in the same PR** with the change and justification. Rules that exist
only in individual agents' heads are not rules. Rules live here.

---

## 8. Don't do this list (from past incidents)

- Don't bundle architecture changes with feature work. Separate PRs.
- Don't regenerate ARB files casually — review the diff.
- Don't refactor files you're only passing through. Stay on-task.
- Don't add "future-proof" abstractions for needs that don't exist yet.
- Don't use `git push --force` to `main` (impossible once branch
  protection is on, but also: don't).
- Don't skip hooks with `--no-verify` or `--no-gpg-sign` unless explicitly
  told to.

---

## 9. Where to look for more context

- `CONTRIBUTING.md` — workflow, branching, commit style.
- `CLAUDE.md` — symlinked to this file; Claude Code entry point.
- `.cursorrules` — symlinked to this file; Cursor entry point.
- `.github/copilot-instructions.md` — symlinked to this file; Copilot.
- `.windsurfrules` — symlinked to this file; Windsurf.
- `CONVENTIONS.md` — symlinked to this file; Aider.
- `docs/ci-setup.md` — CI and branch-protection setup.
- `docs/tech-debt.md` — known pre-existing issues; what CI does *not* enforce.
