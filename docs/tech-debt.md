# Tech Debt Backlog

Captured at the moment CI was introduced. This is the stuff CI is *not*
enforcing today so the project can ship, but should be burned down over time.

---

## 1. Analyzer warnings: ~2014 pre-existing issues

`flutter analyze` currently reports ~2014 issues. **Zero are errors.** They are
a mix of `warning` and `info` severities covering:

- Unused imports, unused fields, unused local variables
- Dead code
- Unnecessary casts
- `print()` calls in scripts (pre-existing, in `scripts/`)
- Dangling library doc comments

### Why it's not blocking CI today

Turning on `--fatal-warnings` would block every PR until all 2014 are fixed.
That's weeks of cleanup before a single new feature could ship.

### The plan to close this out

**Ratchet strategy:** new code must not add warnings. Existing warnings get
cleaned up in small, opportunistic PRs (labeled `chore: lint cleanup`).
When the count hits zero, flip the CI step:

```diff
- run: flutter analyze --no-fatal-warnings --no-fatal-infos
+ run: flutter analyze
```

A reviewer catching new warnings in a PR should ask for them to be fixed
before merge — the CI warnings report makes them visible in the Actions logs.

---

## 2. Formatting (`dart format`) is non-blocking

Many files in the tree are not formatted. CI runs the format check but the
step is `continue-on-error: true` so it won't block merges.

### The plan

Run once across the whole tree, commit the result to `main` in one focused PR:

```bash
git checkout -b chore/format-entire-tree main
dart format .
git add -A
git commit -m "chore: apply dart format to entire tree"
git push -u origin chore/format-entire-tree
# open PR
```

After that PR merges, flip the CI step to hard-block:

```diff
- continue-on-error: true
- run: dart format --output=none --set-exit-if-changed .
+ run: dart format --output=none --set-exit-if-changed .
```

---

## 3. Broken Jest suite: `functions/tests/shift_lifecycle_reschedule.test.js`

Currently fails with `TypeError: onDocumentWritten is not a function`.
Looks like a mock setup issue, not a product bug — but it blocks the
`Firebase Functions` CI job from going green.

### Options

- **Fix the test mock** (preferred — 15–30 min of work).
- **Quarantine with `describe.skip`** and a FIXME comment linking an issue.
- **Delete** if the functionality it covers no longer exists.

**Until this is resolved, CI will be red on every PR.** Do this before turning
on branch protection rules (see `docs/ci-setup.md`).

---

## 4. Stale git branches

The remote has backup/integrate/local-merge branches from previous work
(some dated Dec 2025). They're noise in the branch picker and IDE. See
`docs/ci-setup.md` §4 for the cleanup commands.

---

## 5. Uncommitted working-tree changes (at time of CI setup)

At the time CI was scaffolded, `git status` showed ~30 modified files in `lib/`
and `functions/`. Those aren't part of the CI setup — they're an unrelated
in-progress change. Commit them or stash them before opening the CI-setup PR
to keep the diff reviewable.
