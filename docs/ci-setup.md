# CI/CD & Branch Protection — One-Time Setup

This is the checklist to run **once** after merging the CI scaffolding PR.
It locks `main` so nobody (including you) can push broken code into it.

> ⚠ These steps change shared repo state. Do them yourself — Claude will not
> run them for you.

> ⚠ **Before enabling branch protection**, resolve the broken Jest suite
> listed in `docs/tech-debt.md` §3. Otherwise CI will be red on every PR
> and nothing will be mergeable.

---

## 1. Install & auth the GitHub CLI (once)

```bash
# macOS
brew install gh
gh auth login     # choose GitHub.com → HTTPS → browser
```

Verify:

```bash
gh repo view hahimniane/alluvial_academy
```

---

## 2. Enable branch protection on `main`

Paste this whole block into your shell. It sets every rule in one call.

```bash
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  /repos/hahimniane/alluvial_academy/branches/main/protection \
  -f "required_status_checks[strict]=true" \
  -f "required_status_checks[contexts][]=Architecture check (AGENTS.md)" \
  -f "required_status_checks[contexts][]=Flutter (analyze / test / build web)" \
  -f "required_status_checks[contexts][]=Firebase Functions (lint / test)" \
  -f "enforce_admins=false" \
  -f "required_pull_request_reviews[required_approving_review_count]=1" \
  -f "required_pull_request_reviews[dismiss_stale_reviews]=true" \
  -f "required_pull_request_reviews[require_code_owner_reviews]=true" \
  -f "required_pull_request_reviews[require_last_push_approval]=false" \
  -f "restrictions=" \
  -F "required_linear_history=true" \
  -F "allow_force_pushes=false" \
  -F "allow_deletions=false" \
  -F "required_conversation_resolution=true" \
  -F "block_creations=false" \
  -F "lock_branch=false"
```

What each rule does, in English:

| Rule                                 | Effect                                                     |
| ------------------------------------ | ---------------------------------------------------------- |
| `required_status_checks`             | CI jobs must be green before merge is allowed.             |
| `strict: true`                       | Branch must be **up to date** with `main` before merging.  |
| `required_approving_review_count: 1` | At least one approving review required.                    |
| `dismiss_stale_reviews: true`        | Pushing new commits invalidates old approvals.             |
| `require_code_owner_reviews: true`   | CODEOWNERS must approve changes to their paths.            |
| `required_linear_history: true`      | Squash or rebase only — no merge commits on `main`.        |
| `allow_force_pushes: false`          | Nobody can rewrite `main` history.                         |
| `allow_deletions: false`             | `main` can't be deleted.                                   |
| `required_conversation_resolution`   | All PR review comments must be resolved before merge.      |

---

## 3. Repo-level settings (one-time, via GitHub UI)

Go to **Settings → General → Pull Requests** and set:

- ✅ **Allow squash merging** (default commit message: "Pull request title and description")
- ❌ **Allow merge commits** — disable
- ❌ **Allow rebase merging** — optional, off by default is fine
- ✅ **Always suggest updating pull request branches**
- ✅ **Automatically delete head branches** ← this is important, keeps the branch list clean

Go to **Settings → Actions → General** and set:

- **Workflow permissions:** Read repository contents and packages permissions
- **Allow GitHub Actions to create and approve pull requests:** ❌ off

---

## 4. Clean up stale branches

You currently have ~10 branches in `origin`. Most look like old integration work.
After reading each to confirm, delete the merged/obsolete ones:

```bash
# List remote branches and their last commit author/date
git fetch --prune
git for-each-ref --sort=-committerdate refs/remotes/origin \
  --format='%(committerdate:short) %(authorname) %(refname:short)'

# When you're sure a branch is dead:
git push origin --delete <branch-name>
```

Likely candidates from your repo (verify before deleting):

- `backup/integrate-before-feature`
- `backup/local-merge-connectteam-full`
- `backup/main-before-force-6104e78-20251226-143233`
- `local-merge/connectteam-full`
- `integrate/connectteam-shift-tasks-redesign` (if already merged)

---

## 5. Secrets that CI might need later

CI currently doesn't need any secrets — it just runs tests and builds.
When you add Firebase Hosting preview deploys or App Distribution, add:

- `FIREBASE_SERVICE_ACCOUNT_ALLUWAL_ACADEMY` — JSON key for prod project
- `FIREBASE_SERVICE_ACCOUNT_ALLUWAL_DEV` — JSON key for dev project

Add them under **Settings → Secrets and variables → Actions → New repository secret**.

---

## 6. Verify it works

1. Create a test branch:
   ```bash
   git checkout -b chore/test-ci main
   git commit --allow-empty -m "chore: verify CI pipeline"
   git push -u origin chore/test-ci
   ```
2. Open a PR against `main`.
3. You should see:
   - Both CI checks running (Flutter + Functions)
   - The PR template pre-filled
   - A "Review required" banner (CODEOWNERS)
   - A "Required: status checks" banner
   - No "Merge" button until CI is green AND you approve

If all of that shows up — you're done. Close the test PR and delete the branch.

---

## 7. What to add next (Phase 2+)

- **Firebase Hosting preview channels per PR** — every PR gets a live URL.
  See: https://github.com/FirebaseExtended/action-hosting-deploy
- **Auto-deploy to prod on merge to `main`** — only after you trust CI.
- **Dependabot** for dependency updates — `.github/dependabot.yml`.
- **Codecov or similar** to track test-coverage trends over time.
