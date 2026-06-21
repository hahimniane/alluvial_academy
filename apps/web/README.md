# Alluwal Web Migration

This is the web-native migration app for the public Alluwal site and, over time, the authenticated dashboard.

## Stack

- Next.js static export
- TypeScript
- Tailwind CSS
- Firebase JS SDK
- Playwright

These dependencies are intentionally separate from the Flutter app so mobile remains Flutter while the web surface can be migrated route by route.

## Commands

```bash
cd apps/web
npm install
npm run dev
npm run typecheck
npm run build
npm run test:e2e
```

The app defaults to the same `alluwal-dev` Firebase web config used by Flutter dev builds. Use `.env.local` only when overriding the project, such as a production Hostinger build.

## Hostinger package

```bash
cd apps/web
npm run build
npm run package:hostinger
npm run serve:hostinger -- -l 3040
```

`package:hostinger` creates repo-level `build/hostinger-web`. If repo-level `build/web` exists, it is copied into `build/hostinger-web/app` as the temporary Flutter dashboard bridge.

For release bridge packaging, build Flutter with the repo-approved command first:

```bash
./increment_version.sh && flutter build web --release --pwa-strategy=none
```

For dev browser QA against `alluwal-dev`, keep the required cache-busting/build flags and add the Firebase environment define:

```bash
./increment_version.sh && flutter build web --release --pwa-strategy=none --dart-define=FIREBASE_ENV=dev
```

## Browser tests

Default Playwright tests avoid real Firebase writes and login secrets. Enable deeper checks with:

```bash
ALLUWAL_RUN_WRITE_E2E=1 npm run test:e2e
ALLUWAL_E2E_EMAIL=... ALLUWAL_E2E_PASSWORD=... npm run test:e2e
```
