# How We Work on Alluvial Academy

**Read this first.** This is the friendly, example-heavy guide to how work
gets done on this project. If you're joining the team (human or working
with an AI assistant), start here. The formal specs are in
`CONTRIBUTING.md` and `AGENTS.md` — this doc walks you through the *why*
and the *what-it-looks-like-in-practice*.

---

## 1. What changed, in one paragraph

We used to push code directly to `main`. That caused constant merge
conflicts, features breaking other features, and no safety net. So we
made three changes:

1. **The repo is now public** (on GitHub Free, which is why branch
   protection works).
2. **`main` is locked.** You can't push to it directly anymore — every
   change goes through a **Pull Request (PR)**.
3. **GitHub Actions runs automated checks** on every PR. If a check
   fails, you can't merge until it's green.

Net effect: the robot catches broken code before it reaches `main`, and
two developers can work in parallel without stepping on each other.

---

## 2. Your first 5 minutes on the project

One-time setup on your machine:

```bash
# 1. Clone the repo
git clone https://github.com/hahimniane/alluvial_academy.git
cd alluvial_academy

# 2. Install the GitHub CLI (needed for PRs)
brew install gh          # macOS
# or: https://cli.github.com/ for other platforms
gh auth login            # follow the prompts

# 3. Install project dependencies
flutter pub get
cd functions && npm ci && cd ..
```

Open `AGENTS.md` and read it once. It contains the rules every person
(and every AI assistant) must follow — where code goes, what not to do,
how commits should look. The same rules are enforced by CI, so ignoring
them means your PR can't merge.

---

## 3. The core loop — the flow of every single change

Memorize this rhythm. Every feature, every bug fix, every typo fix
follows it:

```
Pull main → branch off → code → commit → push → open PR → CI runs →
review → merge → delete branch → pull main → start next thing.
```

### Commands for each step

```bash
# Step 1 — Get the latest main
git checkout main
git pull origin main

# Step 2 — Create a short-lived branch
git checkout -b feature/short-descriptive-name

# Step 3 — Do your work. Commit as you go.
# (edit files in your editor, then:)
git add <the-files-you-changed>
git commit -m "Add X to Y"

# Step 4 — Push your branch to GitHub
git push -u origin feature/short-descriptive-name

# Step 5 — Open a Pull Request against main
gh pr create

# Step 6 — Wait for CI to pass, then get a review

# Step 7 — Once approved and green, merge
gh pr merge --squash --delete-branch

# Step 8 — Back to main for your next task
git checkout main
git pull origin main
```

That's the whole loop. **You will do it many times a day.** Make it a
habit.

---

## 4. Why `main` is locked (and what happens if you try to push to it)

If you run:

```bash
git checkout main
# ...edit some files...
git push origin main
```

GitHub will reject it with an error like:

```
remote: error: GH006: Protected branch update failed for refs/heads/main.
remote: error: At least 1 approving review is required.
```

This is working as intended. The fix is to use a branch and a PR —
**not** to try harder.

**Why we did this:** before branch protection, one person's half-finished
work in `main` would break the other person's local build. Or someone's
AI agent would rewrite a file and push straight to production, and
nobody would know until users complained. Protected `main` makes this
impossible. The cost is one extra step (opening a PR). The benefit is
sanity.

---

## 5. Branch naming — keep it simple

Pick a prefix based on what you're doing:

| Prefix        | For                                          | Example                          |
| ------------- | -------------------------------------------- | -------------------------------- |
| `feature/*`   | New feature or enhancement                   | `feature/shift-notes-field`      |
| `fix/*`       | Regular bug fix                              | `fix/timesheet-timezone`         |
| `hotfix/*`    | Urgent production bug                        | `hotfix/login-redirect-loop`     |
| `chore/*`     | Tooling / deps / refactor (no user change)   | `chore/bump-firebase-sdk`        |
| `docs/*`      | Documentation only                           | `docs/contributing-guide`        |

**Keep branch names:**
- lowercase, dash-separated
- short — readable at a glance
- one purpose per branch — don't combine a bug fix with a feature

**Keep branches short-lived.** Merge within 2–3 days. Long-lived branches
are the #1 cause of ugly merge conflicts.

---

## 6. What CI checks, and what it means when it's red

Every PR runs **three automated checks**:

| Check                           | What it does                                             |
| ------------------------------- | -------------------------------------------------------- |
| **Architecture check (AGENTS.md)** | Fails if you put files in the wrong directories       |
| **Flutter (analyze / test / build web)** | Runs `flutter analyze`, `flutter test`, `flutter build web` |
| **Firebase Functions (lint / test)** | Runs `npm test` in `functions/`                      |

All three must be green before you can merge.

### Before you push, run the same checks locally

It's faster to catch a failure on your laptop than to wait for CI:

```bash
# Flutter side
dart format .
flutter analyze
flutter test

# Functions side
cd functions
npm test
cd ..
```

### What to do when CI fails

1. **Read the log.** Click the red ❌ on the PR page → click "Details".
   The actual error is usually in the last 30 lines.
2. **Fix the cause, not the symptom.** Don't disable a test to make it
   pass. Don't delete an analyzer rule. Fix the code.
3. **Push again.** CI re-runs automatically on every push to your branch.

---

## 7. Real example: adding a new feature

You want to add a "notes" field to each teaching shift.

```bash
# Start clean
git checkout main
git pull origin main

# Branch
git checkout -b feature/shift-notes-field

# Make the changes. For a Flutter feature in the shift area, code lives in:
#   lib/features/shift_management/
# So you'd edit:
#   - models/teaching_shift.dart (add a `notes` field)
#   - widgets/shift_details_dialog.dart (show/edit the field)
#   - services/shift_service.dart (persist it)

# Test locally
flutter analyze
flutter test

# Commit — one focused commit or a few small ones, either is fine
git add lib/features/shift_management/
git commit -m "feat(shifts): add notes field to teaching shifts"

# Push and open a PR
git push -u origin feature/shift-notes-field
gh pr create
```

When you run `gh pr create` it opens your editor with a **PR template**
pre-filled. Fill it out honestly:
- *Summary*: what and why
- *Test plan*: how you verified it works (list the steps)
- *Screenshots*: required for any UI change

Then wait for CI to turn green, ping a reviewer, and once approved, merge:

```bash
gh pr merge --squash --delete-branch
```

---

## 8. Real example: fixing a bug

A user reports that the timesheet review page is showing times in UTC
instead of the user's local timezone.

```bash
git checkout main
git pull origin main
git checkout -b fix/timesheet-review-timezone

# The bug lives in:
#   lib/features/time_clock/view_models/timesheet_review_view_model.dart
# Edit the file. Add a test in:
#   test/features/time_clock/...
# to prove the fix works and to prevent regression.

flutter test
git add lib/features/time_clock/ test/features/time_clock/
git commit -m "fix(timesheet): respect user timezone on review screen"
git push -u origin fix/timesheet-review-timezone
gh pr create
```

**Key habit:** for bug fixes, always add a test that would have caught
the bug. Otherwise the bug can come back.

---

## 9. Real example: hotfix to production

Something is broken in production and needs to ship in 15 minutes.

```bash
git checkout main
git pull origin main
git checkout -b hotfix/login-redirect-loop

# Fix the issue, minimum change needed
# ...
git add <fixed-file>
git commit -m "hotfix(auth): stop infinite redirect after login"
git push -u origin hotfix/login-redirect-loop
gh pr create --title "hotfix(auth): stop infinite redirect after login"
```

Same CI checks still apply. Same review still required. **No bypassing
branch protection, even for hotfixes.** If your team has more than one
dev, that second person reviewing is exactly what catches "oh wait this
hotfix will break X".

---

## 10. Real example: two developers working at the same time

**Situation:** You want to change the parent dashboard. Aliou wants to
fix a Firebase Functions bug.

### Before starting

Both of you announce it. A short Slack message, or a GitHub issue, or
just a quick "hey" on the team chat:

> You: "Starting parent dashboard redesign — touching
> `lib/features/parent/`."
>
> Aliou: "Starting invoice webhook fix — touching
> `functions/handlers/invoice.js`."

Different areas → no conflict risk. Go ahead in parallel.

### If you find out your PRs overlap

Whoever merges first, the other person does:

```bash
git checkout fix/your-branch
git fetch origin
git rebase origin/main    # or: git merge origin/main
# resolve any conflicts in your editor
flutter test              # make sure you didn't break anything
git push --force-with-lease
```

`--force-with-lease` is the safe version of `--force`. It only force-pushes
if nobody else pushed to your branch in the meantime.

---

## 11. Real example: working with an AI coding assistant

Pretty much everyone on this team uses one (Claude Code, Cursor,
Copilot, whatever). To make sure they all produce compliant output:

### When you start a session

Tell your AI to read `AGENTS.md` first. Good prompts:

> "Read AGENTS.md in this repo before doing anything. That file
> contains the rules you have to follow."

Most modern agents will auto-load this file anyway (it's symlinked into
`CLAUDE.md`, `.cursorrules`, `.windsurfrules`, `.github/copilot-instructions.md`,
and `CONVENTIONS.md` so every tool finds it).

### When your AI proposes something weird

- Proposes a new file in `lib/` root? **Reject.** Rules say only
  `main.dart` goes there.
- Proposes a file in `lib/admin/` or `lib/widgets/`? **Reject.** Those
  directories are forbidden. Feature code goes in `lib/features/<feature>/`.
- Proposes 30-file PRs? **Reject.** Split into multiple PRs. One PR = one
  concern.
- Proposes changing state management from Provider to something else?
  **Reject.** It's a hard rule in AGENTS.md.

The **Architecture check** CI job catches most of these automatically,
but stopping bad proposals before they turn into code saves everyone
time.

### Trust but verify

AI agents hallucinate file paths, function names, and "helpful"
refactors. Before accepting its output:
- `grep` for the names it used — do they exist?
- Run `flutter analyze` — does the code actually compile?
- Run the tests — does it actually work?

---

## 12. When CI fails: the three most common causes

### Cause A — The Architecture check failed

**Example error:**
```
❌ lib/payment_service.dart — new .dart files must live under
   lib/features/<feature>/ or lib/core/, not lib/ root
```

**Fix:** move the file to the correct location:
```bash
git mv lib/payment_service.dart lib/features/parent/services/payment_service.dart
# update imports in anything referencing it
flutter analyze
git commit -am "fix: move payment_service into parent feature folder"
git push
```

### Cause B — `flutter test` failed

Click into the CI log. Jump to the `Run unit / widget tests` step. The
failure looks like:

```
00:04 +12 -1: test/features/time_clock/clock_in_workflow_test.dart
      ✗ clock-in respects timezone
      Expected: 'America/New_York'
        Actual: 'UTC'
```

**Fix:** either your new code broke an existing test (= fix the code) or
your test is wrong (= fix the test). Re-run locally with:

```bash
flutter test test/features/time_clock/clock_in_workflow_test.dart
```

### Cause C — `npm test` failed in Functions

Open the `Run tests` step of the Functions job. Same idea — a Jest test
failed. Reproduce locally:

```bash
cd functions
npm test -- tests/the_failing_file.test.js
```

Fix, commit, push. CI re-runs automatically.

---

## 13. Where stuff lives — a map

```
alluvial_academy/
├── AGENTS.md                ← rules for humans & AI agents (READ THIS)
├── CLAUDE.md                → symlink to AGENTS.md
├── .cursorrules             → symlink to AGENTS.md
├── .windsurfrules           → symlink to AGENTS.md
├── CONVENTIONS.md           → symlink to AGENTS.md
├── CONTRIBUTING.md          ← formal workflow spec
├── README.md                ← project overview
│
├── .github/
│   ├── CODEOWNERS                 ← who must review which paths
│   ├── copilot-instructions.md    → symlink to AGENTS.md
│   ├── pull_request_template.md   ← fills your PR description
│   └── workflows/
│       └── ci.yml                 ← the CI pipeline
│
├── docs/
│   ├── HOW_WE_WORK.md       ← this file
│   ├── ci-setup.md          ← branch-protection setup steps
│   └── tech-debt.md         ← known issues CI does NOT block on
│
├── lib/                     ← Flutter source
│   ├── main.dart
│   ├── core/                ← shared across 3+ features
│   ├── features/            ← feature-first architecture
│   │   ├── audit/
│   │   ├── auth/
│   │   ├── shift_management/
│   │   └── …
│   └── l10n/                ← translation ARB files
│
├── functions/               ← Firebase Cloud Functions
│   ├── index.js             ← exports only
│   ├── handlers/            ← production handlers
│   ├── services/
│   ├── dev-scripts/         ← one-off scripts
│   └── tests/               ← Jest tests
│
├── test/                    ← Flutter tests
└── scripts/
    └── ci/
        └── check_architecture.sh  ← the rules the Architecture check enforces
```

---

## 14. What NOT to do anymore (and why)

| Don't do this                                | Why                                              |
| -------------------------------------------- | ------------------------------------------------ |
| `git push origin main`                       | Blocked by branch protection. Use a PR.          |
| `git push --force` to `main`                 | Blocked. Would erase history.                    |
| Merge your own PR without a review           | Blocked — at least one other person must approve.|
| Skip CI failures with `--no-verify`          | Bypasses local hooks, CI still fails.            |
| Put a new file in `lib/` root                | Architecture check rejects the PR.               |
| Put feature code in `lib/core/`              | Against the rules — `core/` is for shared-by-3+. |
| Create `lib/admin/` or `lib/screens/` files  | Forbidden dirs.                                  |
| Commit `.env`, API keys, service account JSON | GitGuardian flags it. Rotate if leaked.         |
| Push a 30-file, 5-concern PR                 | Reviewers will reject. Split it up.              |
| Let a branch live for 2+ weeks               | Guaranteed merge conflicts. Keep PRs small.      |

---

## 15. Cheat sheet

Print this, pin it somewhere.

```bash
# Start a new piece of work
git checkout main && git pull origin main
git checkout -b <type>/<short-name>

# Normal commit loop
git add <files>
git commit -m "imperative message"

# Check your own work before pushing
dart format . && flutter analyze && flutter test
cd functions && npm test && cd ..

# Push + open PR
git push -u origin HEAD
gh pr create

# Status of your open PRs
gh pr list --author "@me"
gh pr checks <pr-number>

# After approval + green CI
gh pr merge --squash --delete-branch

# Back to main for next task
git checkout main && git pull origin main
```

---

## 16. When in doubt

- **AGENTS.md** — the rules. Binding on every human and every AI agent.
- **CONTRIBUTING.md** — the formal workflow spec.
- **docs/ci-setup.md** — branch protection and CI setup details.
- **docs/tech-debt.md** — what CI does *not* enforce (pre-existing debt).
- **CODEOWNERS** — who gets pinged on PRs touching which paths.
- **A team member** — when the docs don't answer the question, ask. And
  then update this doc so the next person doesn't have to ask.


