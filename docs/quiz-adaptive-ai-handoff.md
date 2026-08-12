# Quiz: Adaptive Difficulty + AI Question Generation — Test Handoff

Built and deployed 2026-07-14 from branch `feature/teacher-final-cutover`
(working tree remains uncommitted).

## What was implemented

### 1. Expanded question bank (static assets)

- `assets/quizzes/*.json` — 9 categories, 350 questions total, each tagged
  `difficulty: easy|medium|hard`:
  - Expanded (were ~10 each): `five_pillars` (42), `prophets`, `quran_basics`,
    `daily_duas`, `islamic_history`, `arabic_basics` (40 each).
  - New: `seerah`, `sahaba`, `islamic_manners` (36 each).
- New categories registered in
  `lib/features/quiz/models/quiz_category.dart` (`defaultCategories`).
- `pubspec.yaml` already globs `assets/quizzes/`, so no pubspec change.
- Original question ids and correct-answer positions were preserved; new ids
  continue each file's prefix numbering (`fp_013`…, `sr_001`…). Six repeated
  concepts in the bundled bank were rewritten as distinct questions during the
  2026-07-14 quality pass. Answer positions were shuffled to avoid
  correct-answer position bias.

### 2. Adaptive quiz engine (Flutter)

- **`lib/features/quiz/services/quiz_adaptive_session.dart`** — pure logic,
  no Firebase:
  - Session serves up to 10 questions (`sessionLength`), fewer if the pool is
    smaller.
  - Starts at the student's stored tier; 2 consecutive correct → tier up,
    2 consecutive wrong → tier down (never past easy/hard bounds). A wrong
    answer resets the correct streak and vice versa.
  - Prefers questions the student has never seen; searches nearest tiers
    (easier first) when the current tier runs out; recycles seen questions
    only when everything unseen is exhausted. Never repeats within a session.
- **`lib/features/quiz/services/quiz_progress_service.dart`** — persistence:
  - Firestore doc `quiz_progress/{uid}` shape:
    `{categories: {<categoryId>: {seen_ids: [...], skill_level: 'easy|medium|hard', updated_at}}}`.
  - When a student has seen the entire pool for a category, `seen_ids` resets
    to just the current session's questions (rotation restarts).
  - All reads/writes are best-effort: signed-out or offline students play
    normally without persistence.
- **`lib/features/quiz/services/quiz_service.dart`**:
  - `startSession(categoryId)` → loads bundled JSON, merges admin-approved AI
    questions from Firestore (`quiz_questions` where `category==X` and
    `status=='approved'`, deduped by id, best-effort), loads progress, returns
    a `QuizAdaptiveSession`.
  - `completeSession(categoryId, session)` → persists seen ids + ending tier.
  - Old `getQuestionsForCategory` kept for compatibility.
- **`lib/features/quiz/screens/quiz_play_screen.dart`** — pulls questions one
  at a time from the session, records correctness after each answer,
  fire-and-forgets `completeSession` when showing results. Header/progress bar
  use the session's `totalQuestions`.

### 3. AI generation pipeline (Cloud Functions, DEPLOYED)

- **`functions/handlers/quiz_generation.js`**, exported from `functions/index.js`:
  - `generateQuizQuestionsWeekly` — onSchedule `0 3 * * MON` America/New_York.
  - `generateQuizQuestionsNow` — onCall, admin-only (checks `users/{uid}`
    role/user_type/is_admin like other handlers), 300s timeout.
  - Both use secret `GEMINI_API_KEY` (set in prod, version 1).
  - Model fallback list, tried in order:
    `gemini-3.5-flash` → `gemini-flash-latest` → `gemini-3.1-flash-lite`.
    (Reason: `gemini-2.5-flash` is retired/404 for new keys; `gemini-2.0-flash`
    has free-tier quota 0; the newest models occasionally 503 under load.)
  - Per category per run: skips if ≥30 pending already; sends the complete
    bundled category bank plus up to the remaining 120 prior AI question texts
    (all statuses incl. rejected, so rejects aren't regenerated) to the model
    for dedupe; requests 10 questions as a JSON array; validates each (4
    unique non-empty options, int correctAnswer 0–3, known difficulty,
    question 10–300 chars, non-empty explanation); normalizes text
    (case/punctuation-insensitive) and drops exact and high-overlap
    rephrases before saving survivors to `quiz_questions` with
    `{status:'pending', source:'ai', model, created_at, id:<docId>}`.
  - Prompt constraints: kid-appropriate (ages 6–14), mainstream non-sectarian
    basics, no rulings/fatwas, well-established facts only, difficulty mix,
    varied correct-answer positions.
- **Firestore rules (DEPLOYED)**:
  - `quiz_questions`: read for signed-in users only when
    `resource.data.status == 'approved'` (admins read all); create/update/
    delete admin-only. Client queries must include
    `where('status','==','approved')` or they'll be denied.
  - `quiz_progress/{userId}`: read/write only when `request.auth.uid == userId`.

### 4. Admin review UI (Flutter)

- **`lib/features/quiz/screens/admin_quiz_review_screen.dart`** — streams
  pending questions (sorted client-side by `created_at` desc — deliberately no
  `orderBy` to avoid needing a composite index). Shows category/difficulty
  chips, options with the correct one highlighted, explanation. Approve /
  Reject update `status`, `reviewed_at`, `reviewed_by`. A "Generate questions"
  button calls `generateQuizQuestionsNow` (us-central1) with a spinner.
- Wiring: `dashboard.dart` case **35** (`_screenCount` is now 37 because the
  student Quiz screen uses case 36), sidebar item
  `quiz_review` in the admin **Communication** section
  (`sidebar_config.dart`), label localized via `sidebar_localization.dart`.
- All user-facing strings localized: keys `sidebarQuizReview`, `quizReview*`
  added to `app_en.arb`, `app_fr.arb`, `app_ar.arb`; `flutter gen-l10n` run.

## Deployment state

| Piece | State |
| --- | --- |
| GEMINI_API_KEY secret | set (v1) in alluwal-academy |
| generateQuizQuestionsWeekly / Now | live, us-central1, Node 20 gen2 |
| Firestore rules | released (verified diff vs prior deployed ruleset was quiz-only) |
| Flutter app (bank, engine, review UI) | released to Hostinger web build v179 |
| Content review of assets/quizzes/ by a human | NOT done |

## 2026-07-14 extension: monthly Bayannah competition + notifications

Tracked in GitHub issue `#36`. This extension is implemented in the working
tree and deployed to production.

### Competition rules

- Calendar month is calculated by the server in `America/New_York`; a new
  ledger opens automatically when the month key changes (`YYYY-MM`). Students
  can play throughout the month.
- Only authenticated users whose canonical `users/{uid}.user_type` is
  `student` can record competition answers. Admins can view and finalize.
- A question counts only once per student per month. Replaying the same
  question cannot increase totals. Each counted answer has its own immutable
  ledger document under
  `quiz_competitions/{month}/students/{uid}/answers/{questionId}`.
- The server validates bundled questions against
  `functions/data/quiz_answer_key.json` and approved AI questions against
  `quiz_questions/{id}`. The client cannot claim arbitrary question ids or
  correctness. A Jest sync test compares all 350 deployed answer-key entries
  with the Flutter JSON assets so they cannot drift silently.
- Students compete in age ranges rather than one global leaderboard: Early
  Learners (under 8, with no minimum age), Juniors (8–11), Youth (12–17), and Adults (18+). A student
  without reliable age information is `unassigned`: answers are preserved but
  the student is not ranked until the division is resolved.
- On the first Quiz visit, an unassigned student is asked for birth month and
  year. The full birth date is not collected. The server derives age at the
  first day of each competition month, so birthdays never move a student
  mid-competition and future division changes happen automatically. Existing
  DOB/age/adult-account data is reused. Self-declaration is a transactional,
  one-time write; admin corrections require a reason and are audited.
- Minimum winner eligibility: **20 unique questions across 3 different active
  days with at least 50% accuracy**. A division needs at least **2 eligible
  students** to name a competitive winner; otherwise participation remains
  visible but no winner is recorded for that division.
- Ranking order within a division: most unique answered questions, most
  correct answers, then most active days. Exact score ties receive the same
  rank and become co-winners. Finish time and uid are never used to break a
  real tie. There is no speed bonus, which avoids penalizing younger readers,
  students using assistive technology, or slower connections.
- Normal finalization happens after month end. Admins may close early or
  correct an already-finalized result only with a written reason of at least
  10 characters. Every finalization/correction writes an audit revision under
  `finalization_history`; an override winner must meet the same eligibility
  minimum.

### Implementation

- `functions/handlers/quiz_competition.js` exports:
  `recordQuizCompetitionAnswer`, `getQuizCompetitionLeaderboard`,
  `finalizeQuizCompetition`, `setOwnQuizCompetitionAge`,
  `setQuizCompetitionDivision`, and `onQuizQuestionApproved`.
- `onQuizQuestionApproved` fires only when a question transitions into
  `approved`. It sends one English or French FCM notification for that newly
  available question to student-role accounts, honors
  `notificationPreferences.quizEnabled == false`, supports legacy/current
  token fields, deduplicates tokens, and chunks multicast sends at 500.
  Pending AI-generated questions do not notify students.
- Student UI: `QuizHomeScreen` shows the current month, rules, unique answers,
  active days, age range, rank, and finalized winner/co-winner/no-winner
  result. Unassigned students receive the first-visit birth month/year setup.
  `QuizPlayScreen` starts the server write as soon as an answer is selected and
  waits before advancing; a localized warning is shown if the competition
  write fails.
- Admin UI: Quiz Review links to `AdminQuizCompetitionScreen`, which supports
  month and age-range selection, full active-student participation visibility
  (`not started`, `needs encouragement` after 7 inactive days,
  `participating`, `qualified`), privacy-trimmed public leaderboard review,
  audited division assignment, per-division winner finalization, and reasoned
  corrections.
- New UI is localized in English, French, and Arabic ARB files; `flutter
  gen-l10n` was run. (Arabic remains disabled in `LanguageService`.)
- Firestore client writes to competition summaries, entries, answers, and
  finalization/age/division histories are denied. Students may read only their
  own raw entry; the privacy-trimmed leaderboard is returned by the callable.

### Planned media-question automation

This was designed but intentionally not implemented in this extension:

1. Admin selects one or more age ranges and uploads/selects an audio or video.
2. A backend job extracts or generates a transcript, then drafts questions
   grounded only in that transcript, with source timestamps.
3. Questions remain `pending`; an admin must review/edit/approve them. Approval
   continues to trigger the existing student notification flow.
4. The student player records resume-safe progress heartbeats. Questions
   unlock only after meaningful unique playback coverage (for example 80%),
   not merely after pressing Play. Seeking, refreshes, duplicate tabs, and high
   playback rates must not create fake completion.
5. Admin participation adds `media not started`, `media incomplete`, and
   `questions not attempted` filters, with rate-limited reminders through the
   existing notification/chat systems.

The remaining product decision is which media sources are allowed (Firebase
uploads, YouTube links/captions, or both) and the required completion
percentage. AI-generated questions must never auto-publish.

### Extension verification

- `functions/tests/quiz_competition.test.js`: expanded coverage for New York month
  boundaries, strict month keys, bundled validation, all-assets answer-key
  synchronization, age-range boundaries, month-locked birthdays, privacy-
  minimized birth month/year derivation, missing-age handling, assignment
  expiry, accuracy/participation thresholds, fair shared ranks, engagement
  status,
  privacy names, FCM opt-out/language/token dedupe/batching, a verified answer
  write, and replay idempotency.
- Quiz-scoped backend run: 30/30 passing across competition + generation.
- Full Functions run: 304 passed, 7 skipped across 26 passing suites and one
  skipped suite.
- Flutter quiz tests: 15/15 passing (13 adaptive + 2 competition parsing).
- Full Flutter run: 265 passed. After the browser-driven desktop
  navigation and category-count fixes, the affected dashboard + quiz tests
  were rerun: 24/24 passing.
- Quiz-scoped analyzer: no errors or warnings; 13 pre-existing deprecation
  infos for `withOpacity` in the two quiz screens.
- Architecture check passed, and the approved `./build_release.sh` produced a
  successful local web release with cache-busting version 177.
- Browser verification used the designated production student/admin accounts
  against the local release build. It covered student desktop navigation,
  monthly stats, answering and advancing, a 390x844 mobile layout, admin
  leaderboard review/finalization, and French navigation/competition UI. The
  test exposed and fixed missing desktop student Quiz navigation and a stale
  `6 categories / 100+` label; the final UI reports 9 categories / 350+.
- A second browser pass verified the required first-visit age-range dialog,
  missing-field validation, birth month/year selection, transition from
  `unassigned` to Youth, admin age-range switching, visibility for `not
  started`, `needs encouragement`, and `qualified` students, and the same
  admin participation flow in French.
- Production release completed on 2026-07-14:
  - Targeted `alluwal-academy` Functions deploy: the two generation Functions
    were updated and the six competition Functions (answer recording,
    leaderboard, finalization, student age declaration, admin assignment, and
    approved-question notification) were created in `us-central1`.
  - `firestore.rules` compiled and released.
  - `./scripts/deploy_hostinger_web.sh` completed Hostinger web build v178,
    backed up the previous `public_html`, uploaded the release, and verified
    the public cache-busting references. Direct public fetches confirmed
    `index.html`, `manifest.json`, `flutter_bootstrap.js`, and `main.dart.js`
    all reference v178.
  - Read-only live browser smoke tests used the designated student and admin
    identities. The student saw the birth-month/year age-division prompt and
    safely deferred it; the competition page showed the monthly rules and
    unassigned state. The admin opened Quiz Review → Bayannah Competition and
    verified all five range choices, including Early Learners (under age 8),
    then switched to Youth. No age, answer, question, winner, reminder, or
    notification was written during the smoke test; both accounts were signed
    out afterward.

Human content review of the bundled quiz bank remains recommended. Media-based
questions remain a planned design, not a released feature.

## 2026-07-14 generation and full-lifecycle QA

- Corrected six duplicate concepts found in the bundled question bank and
  generated `functions/data/quiz_question_texts.json` from the 350 Flutter
  questions. A Jest sync test prevents that deployed generator catalog from
  drifting from the student app assets.
- Production generation was exercised through the authenticated admin callable
  after the catalog and close-rephrase guard were deployed. Gemini generated
  86 drafts across all nine categories (8–10 each), with no function errors.
  All drafts are `pending`, so no student can see them until an administrator
  reviews and approves them.
- Post-generation QA validated every new draft against all 350 bundled
  questions, 90 prior AI drafts, and the new batch: valid metadata/structure,
  four distinct options, valid answer index, explanation, supported category
  and difficulty, balanced per-category difficulty mix, and zero exact or
  high-overlap rephrase matches.
- A disposable `alluwal-dev` browser/API lifecycle test created two QA student
  accounts and then removed their Auth records, profiles, competition ledger,
  answer documents, audit history, and local fixture file. It verified:
  first-visit birth month/year declaration; the real student answer callable;
  answer feedback and advancing to the next question; 20 unique answers over
  three recorded active days; the 50% accuracy and two-student eligibility
  minimum; authenticated admin early finalization with its required reason;
  audit creation; and correct prize selection for the higher-scoring student.
- Hostinger web build v179 was deployed using the approved script. Public
  cache-busting references and all nine live quiz JSON assets were fetched and
  validated: 350 questions, unique ids/questions, four distinct options, and
  valid answer indexes.

## Existing automated tests (all passing at handoff)

- `test/features/quiz/quiz_adaptive_session_test.dart` — 13 tests (tier
  escalation/de-escalation, streak reset, bounds, no-repeat, seen-avoidance,
  recycling, adjacent-tier borrowing, session cap, tiny pools).
- `functions/tests/quiz_generation.test.js` — 21 tests (validation matrix,
  Gemini response parsing incl. markdown-fenced JSON, dedupe/normalization,
  prompt contents, category coverage).
- Full suites green: `flutter test` (259) and `cd functions && npm test` (272).

## 2026-07-14 compact category layout

- Replaced the desktop-only two-column quiz category grid with a responsive,
  compact grid. Category tiles now have a maximum width of 164px and a fixed
  128px height, so wider screens add columns rather than stretching two cards
  across the page.
- The tile icon, spacing, typography, button, corner radius, and shadow were
  reduced proportionally. Mobile retains a readable multi-column layout.
- `test/features/quiz/quiz_home_layout_test.dart` protects the responsive tile
  dimensions, and a browser run verified the signed-in student category page.
- Deployed to Hostinger with `./scripts/deploy_hostinger_web.sh` as web build
  v180. The public site now references the v180 bootstrap, manifest, and main
  Dart bundle cache-busting URLs.

## 2026-07-14 competition fairness, review workflow, and counting window

- Competition eligibility now requires a student to attempt every required
  quiz category, in addition to the existing unique-question, active-day, and
  accuracy requirements. The server persists the attempted categories with
  each counted answer, so the client cannot claim coverage it has not earned.
- Students receive only their immediately adjacent eligible leaderboard peers
  (one above and one below), within their own age division. Administrators
  retain the broader competition view.
- Administrators can set the first and last New York calendar days whose
  answers count for a competition month. The callable validates the window,
  records window-history audit data, and the answer-recording callable refuses
  to award competition points outside it. The student page displays that
  window clearly.
- The student competition panel now shows lifetime wins and expandable,
  category-by-category guidance based on each student's counted answers and
  accuracy, including a clear starting point for untouched categories.
- Quiz review is now server-authoritative. An administrator selects the
  teacher reviewers; those teachers can review the pending queue, and every
  decision stores the reviewer id, name, role, timestamp, and immutable review
  history. Client Firestore writes to quiz questions are blocked.
- New pending questions notify selected teacher reviewers in batches, rather
  than as individual alerts. Approved questions are likewise held for an
  administrator-triggered or hourly batch student notification, never sent
  instantly on approval.
- Production release: targeted `alluwal-academy` Functions deploy completed
  for the competition window and review/batch callables; Firestore rules were
  deployed; `./scripts/deploy_hostinger_web.sh` released web build v182.
  Public cache-busting URLs were fetched and confirmed at v182.
- Read-only production browser checks verified the administrator review and
  competition controls and the student competition view: the July 1–31
  counting window, lifetime wins, category-coverage requirement, and category
  guidance all rendered correctly. Test accounts were signed out afterward;
  no production answer, decision, notification, or competition setting was
  changed during browser QA.

## 2026-07-14 reviewer permissions and rejection reasons

- Generation is restricted twice: the production callable accepts only an
  administrator, and the web interface shows the generation, reviewer
  management, student-batch, and competition controls only to an
  administrator. Teacher reviewers can approve or reject only.
- Every rejected question now requires a non-empty reason (maximum 500
  characters). The callable validates and stores it on both the question and
  its immutable review-history record, with the reviewer identity and role.
- An unselected teacher is told clearly that an administrator must add them as
  a quiz reviewer; they cannot see any administrative generation controls.
- Targeted Jest review tests, quiz Flutter tests, analyzer, and architecture
  check passed. Production `reviewQuizQuestion` was updated and Hostinger web
  build v183 was released. Browser QA verified the unselected teacher view,
  the admin-only controls, the rejection-reason dialog, and the mandatory
  reason validation without changing any production questions or settings.

## Suggested verification for a testing agent

1. **Static content**: validate every `assets/quizzes/*.json` — unique ids,
   `correctAnswer` in range, 4 options, difficulty values, `category` field
   matches filename, counts match the table above. Check correct-answer
   position distribution isn't skewed.
2. **Engine edge cases** not covered by tests: pool with a single question;
   all questions seen AND sessionLength > pool; stored `skill_level` garbage.
3. **Firestore rules** (emulator or prod with a test student account):
   student cannot read pending/rejected `quiz_questions`; student cannot query
   without the approved filter; student cannot write another uid's
   `quiz_progress`; non-admin cannot update question status.
4. **Callable auth**: `generateQuizQuestionsNow` rejects unauthenticated and
   non-admin callers; admin call creates pending docs (uses real Gemini free
   tier — one call generates ≤90 questions, that's fine but don't loop it).
5. **End-to-end in app** (needs `flutter run` or web build): play a quiz as a
   student — verify difficulty climbs after 2 correct, "Question N of 10"
   is stable, replays don't repeat questions, `quiz_progress/{uid}` doc
   updates after finishing; as admin, open Quiz Review, generate, approve one,
   then confirm it can appear in a student session for that category.
6. **Known trade-offs (not bugs)**: quiz feature UI strings other than the new
   review screen are pre-existing hardcoded English; `completeSession` is
   fire-and-forget (a killed app can lose one session's progress); pending
   count in the header comes from the same stream (fine); AI questions are
   English-only for now.
