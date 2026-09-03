#!/usr/bin/env node
/**
 * Migrate enrollment documents onto the new scheduling vocabulary.
 *
 *   node scripts/migrate_enrollment_schema.mjs            # dry run, changes nothing
 *   node scripts/migrate_enrollment_schema.mjs --apply    # write
 *
 * Three value changes, from the design handoff §1.3 and §1.4:
 *
 *   program.classType                'Group' -> 'With Other Students'
 *                                    'Both'  -> 'One-on-One'
 *   preferences.timeOfDayPreference  'Flexible' -> removed
 *
 * `'Both'` is the one with no specified successor. It meant "either suits us",
 * which maps to no single new value, so it takes the narrower reading. Those
 * rows are listed individually in the output — read them before applying.
 *
 * **History is not rewritten.** `metadata.lastBroadcastSnapshot`,
 * `metadata.adminScheduleEdits` and `metadata.pricingSnapshot` record what was
 * true at the time; migrating them would forge the record of what a family
 * actually asked for. They keep their old values and the readers normalise.
 */

import admin from 'firebase-admin';

const APPLY = process.argv.includes('--apply');
const PROJECT = process.env.GOOGLE_CLOUD_PROJECT || 'alluwal-academy';

admin.initializeApp({
  credential: process.env.FIREBASE_SERVICE_ACCOUNT
    ? admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT))
    : admin.credential.applicationDefault(),
  projectId: PROJECT,
});
const db = admin.firestore();

const CLASS_TYPE_MAP = {
  Group: 'With Other Students',
  Both: 'One-on-One',
};

const str = (v) => (typeof v === 'string' ? v.trim() : '');

const main = async () => {
  const snap = await db.collection('enrollments').get();
  console.log(`project ${PROJECT} · ${snap.size} enrollment documents`);
  console.log(APPLY ? 'MODE: APPLY — writing changes\n' : 'MODE: DRY RUN — nothing will be written\n');

  const planned = [];
  const both = [];

  for (const doc of snap.docs) {
    const d = doc.data();
    const changes = {};
    const notes = [];

    const classType = str(d.program?.classType);
    if (CLASS_TYPE_MAP[classType]) {
      changes['program.classType'] = CLASS_TYPE_MAP[classType];
      notes.push(`classType ${classType} -> ${CLASS_TYPE_MAP[classType]}`);
      if (classType === 'Both') {
        both.push({
          id: doc.id,
          student: str(d.student?.name ?? d.studentName) || 'Student',
          subject: str(d.subject ?? d.programTitle),
          days: (d.preferences?.days || []).join(', '),
          block: str(d.preferences?.timeOfDayPreference),
          notes: str(d.preferences?.schedulingNotes),
        });
      }
    }

    if (str(d.preferences?.timeOfDayPreference) === 'Flexible') {
      changes['preferences.timeOfDayPreference'] = admin.firestore.FieldValue.delete();
      notes.push('timeOfDayPreference Flexible -> removed');
    }

    if (Object.keys(changes).length > 0) {
      planned.push({ ref: doc.ref, id: doc.id, changes, notes });
    }
  }

  console.log(`documents to change: ${planned.length}`);
  const tally = {};
  for (const p of planned) for (const n of p.notes) tally[n] = (tally[n] || 0) + 1;
  for (const [note, count] of Object.entries(tally).sort((a, b) => b[1] - a[1])) {
    console.log(`   ${String(count).padStart(4)}  ${note}`);
  }

  if (both.length) {
    console.log(`\nThe ${both.length} 'Both' rows — the handoff does not say what these become.`);
    console.log("Defaulting to 'One-on-One'. Read these before applying:\n");
    for (const b of both) {
      console.log(`  ${b.id}  ${b.student} — ${b.subject}`);
      console.log(`     days: ${b.days || '(none)'} · block: ${b.block || '(none)'}`);
      if (b.notes) console.log(`     family note: "${b.notes.replace(/\s+/g, ' ').slice(0, 120)}"`);
    }
  }

  if (!APPLY) {
    console.log('\nDry run complete. Re-run with --apply to write.');
    return;
  }
  if (planned.length === 0) {
    console.log('\nNothing to do.');
    return;
  }

  let written = 0;
  for (let i = 0; i < planned.length; i += 400) {
    const batch = db.batch();
    for (const p of planned.slice(i, i + 400)) {
      batch.update(p.ref, {
        ...p.changes,
        // Leave a trail, in the style of metadata.actionHistory.
        'metadata.schemaMigration': {
          at: admin.firestore.FieldValue.serverTimestamp(),
          version: 'scheduling-vocabulary-v2',
          applied: p.notes,
        },
      });
      written += 1;
    }
    await batch.commit();
  }
  console.log(`\nWrote ${written} document(s).`);
};

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('migration failed:', err);
    process.exit(1);
  });
