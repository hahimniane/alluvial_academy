# Dev Firebase project setup (rules/indexes + functions only)

This repo is configured for two Firebase projects:
- **prod**: `alluwal-academy`
- **dev**: `alluwal-dev`

Safety: `.firebaserc` sets the **default** Firebase project to `alluwal-dev` so an accidental `firebase deploy` won’t touch prod.

The goal is to deploy **only**:
- Firestore rules (`firestore.rules`)
- Firestore indexes (`firestore.indexes.json`)
- Cloud Functions (`functions/`)

No Hosting or Storage files are copied/deployed as part of this flow.

## 1) Deploy backend to dev

From repo root:

```bash
./scripts/deploy_dev_backend.sh
```

Notes:
- Firestore rules/indexes deploy on the free Spark plan.
- **Cloud Functions require the Blaze plan** on the dev project (Firebase will block enabling `cloudbuild.googleapis.com` on Spark).

This runs (in two stages):

```bash
firebase deploy --project dev --only firestore:rules,firestore:indexes
firebase deploy --project dev --only functions
```

## 2) LiveKit secrets (dev)

Some LiveKit callable functions declare secrets:
- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`

Firebase Secrets use Google Secret Manager, which also requires the **Blaze plan** on the dev project.

If you want LiveKit to work in **dev**, set real values in the dev project:

```bash
printf '%s' "$LIVEKIT_URL" | firebase functions:secrets:set LIVEKIT_URL --project alluwal-dev --data-file -
printf '%s' "$LIVEKIT_API_KEY" | firebase functions:secrets:set LIVEKIT_API_KEY --project alluwal-dev --data-file -
printf '%s' "$LIVEKIT_API_SECRET" | firebase functions:secrets:set LIVEKIT_API_SECRET --project alluwal-dev --data-file -
```

Then redeploy functions:

```bash
cd functions
npm run deploy:dev
```

If you don’t have LiveKit credentials yet but still want Functions deployed, you can set placeholders (LiveKit features will return “not configured”):

```bash
printf ' ' | firebase functions:secrets:set LIVEKIT_URL --project alluwal-dev --data-file -
printf ' ' | firebase functions:secrets:set LIVEKIT_API_KEY --project alluwal-dev --data-file -
printf ' ' | firebase functions:secrets:set LIVEKIT_API_SECRET --project alluwal-dev --data-file -
```

If you see a warning/error about an Artifact Registry cleanup policy, run:

```bash
firebase functions:artifacts:setpolicy --project alluwal-dev --force
```

## 3) Create fresh dev admin accounts

Because this is a separate Firebase project, you can create fresh accounts without affecting prod.

1. In Firebase Console → **Authentication** (dev project):
   - Enable **Email/Password**
   - Add a user (your admin email)
2. In Firebase Console → **Firestore Database** (dev project):
   - Create a document in `users/{uid}` (use the Auth user’s UID as the document ID)
   - Minimum recommended fields:
     - `user_type`: `admin` (or `super_admin`)
     - `is_active`: `true`
     - `e-mail`: your email in lowercase
     - `first_name`, `last_name`: optional but helpful

That’s enough for the app + callable functions to recognize you as an admin in dev.

## 4) Use dev in debug, prod in release

This repo contains:
- Prod config: `lib/firebase_options.dart`
- Dev config: `lib/firebase_options_dev.dart`

Default behavior (see `lib/main.dart`):
- Debug/profile: **dev**
- Release builds (including `flutter build web --release`): **prod**

In debug/profile builds, the app shows a small **DEV/PROD** banner in the top-left so you can confirm which Firebase project is being used.

Optional override (any build mode):

```bash
# Force prod (useful for debugging prod without rebuilding)
flutter run -d chrome --dart-define=FIREBASE_ENV=prod

# Force dev
flutter run -d chrome --dart-define=FIREBASE_ENV=dev
```

## 5) Seed a few dev users (optional)

If you want a quick starting point without copying prod data, you can create a couple of accounts in the dev project by calling the deployed function.

1. Copy the example file and edit emails/passwords:

```bash
cp scripts/dev_seed_users.example.json scripts/dev_seed_users.json
```

2. Run the seeder:

```bash
node scripts/seed_dev_users.js scripts/dev_seed_users.json
```

Notes:
- This creates **new** Firebase Auth users + Firestore `users/{uid}` docs in **dev**.
- It does not touch Storage or any prod data.
