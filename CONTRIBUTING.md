# Contributing to Alluvial Academy

This guide is how we work together without stepping on each other's toes.
Read it once before your first PR. If anything is unclear, open an issue.

---

## 1. Branching strategy — **GitHub Flow**

We use a simple trunk-based model. There is **one long-lived branch: `main`**.
Everything else is a short-lived branch that gets merged and deleted.

### The only branch that matters: `main`

- `main` is **always deployable**. If it's green on CI, it can ship to production.
- You **never commit directly to `main`**. Branch protection enforces this.
- Every change lands through a Pull Request.

### Short-lived working branches

Branch off `main`, do your work, open a PR, merge, delete the branch.

| Prefix        | Use for                                      | Example                          |
| ------------- | -------------------------------------------- | -------------------------------- |
| `feature/*`   | New feature or enhancement                   | `feature/shift-notes-field`      |
| `fix/*`       | Bug fix that isn't urgent                    | `fix/timesheet-timezone`         |
| `hotfix/*`    | Urgent production bug — fast-track to `main` | `hotfix/login-redirect-loop`     |
| `chore/*`     | Tooling, deps, refactors, no behavior change | `chore/bump-firebase-sdk`        |
| `docs/*`      | Documentation only                           | `docs/contributing-guide`        |

**Naming rules:**
- lowercase, dash-separated (`feature/shift-notes`, not `Feature/ShiftNotes`)
- short and descriptive — a reader should get the gist from the name
- no ticket numbers required, but fine to add: `feature/AA-42-shift-notes`

### Rules for branches

1. **Short-lived.** Merge within **2–3 days**. Long-lived branches are the #1
   cause of painful merge conflicts. If work is bigger, break it into multiple
   PRs (a feature flag or a scaffolded-but-unused module both work).
2. **One purpose per branch.** If you're fixing a bug AND adding a feature,
   that's two branches and two PRs.
3. **Rebase (or merge) `main` into your branch daily** while it's open, so
   conflicts surface early and stay small.
4. **Delete after merge.** GitHub offers a button — use it.

---

## 2. The PR workflow

```
main ──●──────●──────●───────●──────
        \      \     /       /
         \    feature/x ────●
          \                /
           fix/y ─────────●
```

1. **Pull latest `main`**
   ```bash
   git checkout main
   git pull origin main
   ```
2. **Branch off `main`**
   ```bash
   git checkout -b feature/your-thing
   ```
3. **Commit as you work.** Small, focused commits. Commit messages in
   imperative mood:
   - ✅ `Add notes field to TeachingShift model`
   - ❌ `added stuff`
4. **Push and open a PR** against `main`.
5. **Fill out the PR template** — especially the test plan. Screenshots for
   any UI change.
6. **CI must be green.** If a check fails, fix it — don't merge around it.
7. **Get a review.** At least one approval required before merging.
8. **Use "Squash and merge"** to keep `main` history clean (one commit per PR).
9. **Delete the branch** after merge.

### Keeping your branch up to date

While your PR is open, `main` may move. Keep up daily:

```bash
git checkout feature/your-thing
git fetch origin
git rebase origin/main        # preferred — clean linear history
# or if you prefer:
git merge origin/main          # fine, just messier history
```

If there are conflicts, resolve them locally, run `flutter analyze` and
`flutter test`, then push. If you rebased, you'll need `git push --force-with-lease`
(never `--force`).

---

## 3. Commit message style

Short, imperative, 50–72 chars for the subject line. Optional body for the "why".

```
Add notes field to TeachingShift model

Teachers asked for a free-form note field on individual shifts so they
can record context for later review. Persisted on the teaching_shifts
Firestore doc under `notes`. UI follows up in a separate PR.
```

Prefixes are optional but welcome: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`.

---

## 4. What CI checks

Every PR runs `.github/workflows/ci.yml`. It must pass before merge.

**Flutter job:**
- `dart format --set-exit-if-changed` — code must be formatted
- `flutter analyze` — no analyzer warnings
- `flutter test` — all unit/widget tests pass
- `flutter build web --release` — web build compiles

**Functions job:**
- `npm ci` — install
- `npm run lint` (if configured)
- `npm test` — all Jest tests pass

### Run these locally before pushing

```bash
# Flutter
dart format .
flutter analyze
flutter test

# Functions (if you touched functions/)
cd functions
npm test
```

If local passes and CI fails, read the CI logs — don't retry blindly.

---

## 5. Architecture rules (enforced)

These are duplicated from `CLAUDE.md` — read that file for the full version.

- Flutter code goes in `lib/features/<feature>/` (feature-first).
- `lib/core/` is only for code used by 3+ features.
- **Never** create new files in `lib/` root (except `main.dart`).
- Firebase functions handlers go in `functions/handlers/`. One-off scripts
  go in `functions/dev-scripts/`, never in `functions/` root.
- All user-facing strings go through `AppLocalizations` (ARB files in
  `lib/l10n/`).

If a PR violates these, a reviewer will ask you to restructure before merge.

---

## 6. Secrets, config, and things that must NEVER be committed

- `.env`, `.env.*`, `functions/.env` — Firebase, Stripe, Twilio, etc.
- Service-account JSON files
- `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
  should be committed only if the repo policy allows — ask before adding.
- API keys of any kind in source code

If you accidentally commit a secret: **do not just delete it in a new commit.**
The secret is still in git history. Rotate the secret immediately, then
tell the repo owner so history can be rewritten.

---

## 7. Review expectations

As a reviewer:
- Read the PR description first. If the test plan is empty, ask for it.
- Pull the branch and run it locally for any non-trivial UI change.
- Block on correctness. Suggest (not block) on style.
- Approve only when you'd be comfortable shipping it.

As an author:
- Respond to every comment. "Done" or "Won't fix because X" — not silence.
- Don't force-push after a review has started unless you use
  `--force-with-lease` and tell the reviewer. Prefer pushing new commits.

---

## 8. When things go wrong

- **Merge conflicts:** rebase `main` in, resolve, re-run tests, push.
- **CI is flaky:** if a test fails once and passes on re-run, open an issue to
  make it deterministic. Don't just keep hitting "re-run jobs".
- **Production broke:** branch `hotfix/<thing>` off `main`, fix it, PR,
  squash-merge, deploy. File a follow-up to add a test that catches it.

---

Questions? Open an issue or ask in the team chat.
