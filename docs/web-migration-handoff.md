# Web Migration Handoff

Last updated: 2026-06-21

## Stop Point

Paused at the start of the About page parity pass.

Do not keep polishing the already accepted screens. The next visible gap is
`/about/`.

## Branch

Checkpoint branch:

```bash
feature/web-next-migration-checkpoint
```

This branch contains the Next.js migration checkpoint and does not intentionally
include unrelated Flutter/mobile dirty files from the local workspace.

## Implemented In This Checkpoint

- Created `apps/web` with Next.js static export, TypeScript, Tailwind CSS,
  Firebase JS SDK, and Playwright.
- Added Hostinger packaging that places the Next.js site at the static root and
  the Flutter bridge under `/app`.
- Ported the public web routes:
  `/`, `/about/`, `/team/`, `/programs/`, `/contact/`,
  `/teacher-application/`, `/leadership-application/`, `/login/`, `/enroll/`.
- Added Firebase models/helpers for the public CMS bundle and fallback data.
- Added Firebase Auth login/logout/reset and `/app` bridge entry.
- Added public form submission flows for contact, teacher application,
  leadership application, and enrollment.
- Added a Firestore rule allowing anonymous create for
  `leadership_applications`.
- Fixed contact form browser writes by using the Firestore REST create endpoint
  for `contact_messages`.
- Added/expanded Playwright coverage for route smoke checks, forms, auth bridge,
  mobile navigation, and Team directory interactions.

## Parity Status

Parity acceptable:

- Enrollment/student application flow:
  role, student details, program, schedule, review/contact, success.
- Home page.
- Programs page.
- Contact page.
- Team page, including category filters and profile sheet.

Started but not patched:

- About page. The current Next version still has a dark hero and extra sections.
  The running Flutter baseline shows a simpler page:
  centered `About Alluwal Education Hub` heading, mission/vision cards,
  `Learn More About Us` button, blue CTA band with Quran image, simple copyright
  footer.

Not started after this pause:

- Teacher application visual parity pass.
- Leadership application visual parity pass.
- Login/auth bridge parity pass.
- Dashboard/CMS module migration.

## Verification Already Run

From `apps/web`:

```bash
npm run typecheck
NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build
PLAYWRIGHT_BASE_URL=http://127.0.0.1:3021 npm run test:e2e
ALLUWAL_RUN_WRITE_E2E=1 PLAYWRIGHT_BASE_URL=http://127.0.0.1:3021 npx playwright test tests/forms.spec.ts --project=chromium --grep "contact form writes"
npm run package:hostinger
```

Most recent full suite result:

```text
48 passed, 36 skipped
```

Package sanity checks already passed:

```bash
find build/hostinger-web/app \( -name 'flutter_service_worker.js' -o -name '_next*' -o -name '.DS_Store' \) -print
du -sh build/hostinger-web build/hostinger-web/app apps/web/out apps/web/out/_next
git diff --check
```

Expected package size at the checkpoint:

```text
133M build/hostinger-web
111M build/hostinger-web/app
 22M apps/web/out
5.8M apps/web/out/_next
```

## How To Continue

1. Install/build the web app if needed:

   ```bash
   cd apps/web
   npm install
   NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build
   ```

2. Serve the Next static export:

   ```bash
   cd apps/web/out
   python3 -m http.server 3021 --bind 127.0.0.1
   ```

3. Serve or rebuild the Flutter web baseline:

   ```bash
   cd build/web
   python3 -m http.server 3032 --bind 127.0.0.1
   ```

   If `build/web` is stale or missing, use the repo-approved Flutter web build:

   ```bash
   ./increment_version.sh && flutter build web --release --pwa-strategy=none
   ```

4. Continue with About parity:

   - Capture Flutter desktop/mobile screenshots from `http://127.0.0.1:3032/`.
   - Capture Next desktop/mobile screenshots from `http://127.0.0.1:3021/about/`.
   - Patch `apps/web/src/components/AboutContent.tsx`.
   - Match the currently running Flutter baseline, not old assumptions.

5. After the About patch:

   ```bash
   cd apps/web
   npm run typecheck
   NEXT_PUBLIC_USE_CMS_FALLBACK=1 npm run build
   PLAYWRIGHT_BASE_URL=http://127.0.0.1:3021 npm run test:e2e
   npm run package:hostinger
   git diff --check
   ```

## Parity Rule

For each screen, use at most two focused visual polish passes. Fix
user-noticeable gaps: missing content, wrong layout structure, wrong copy,
broken mobile behavior, broken forms, console errors. Do not loop on tiny font
rendering, pixel spacing, or differences a normal user would not notice.
