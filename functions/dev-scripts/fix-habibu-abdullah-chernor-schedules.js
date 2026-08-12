#!/usr/bin/env node
/**
 * One-off schedule cleanup (prod alluwal-academy):
 * 1) Habibu Barry + Abdoullahi Diallo:
 *    Mon-Wed 1-2pm NY, Thu-Sat 11am-12pm NY. Delete other future slots; regenerate.
 * 2) Abdullah Baldee + Housainatou Mariam(a): confirm Mon/Tue only (no-op if already).
 * 3) Chernor Ahmadu Jalloh + Hady Barry: deactivate templates + delete all future shifts.
 *
 * Usage:
 *   node functions/dev-scripts/fix-habibu-abdullah-chernor-schedules.js           # dry-run
 *   node functions/dev-scripts/fix-habibu-abdullah-chernor-schedules.js --apply
 */
const admin = require('firebase-admin');
const {DateTime} = require('luxon');
const path = require('path');

const APPLY = process.argv.includes('--apply');
const TZ = 'America/New_York';

const HABIBU_TEACHER_ID = 'kjVbNRUjJoZRw3NTd3jIbREdYUu2';
const ABDOULLAHI_STUDENT_ID = '5HclexSt1POc766djXNNueGXrn92';
const HABIBU_TEMPLATE_ID = 'jg3QLS5emiscH42vFSul';

const ABDULLAH_TEACHER_ID = 'XBm5dxyerccp49BgBLw8pW02T8R2';
const HOUSAIN_STUDENT_IDS = [
  'i7smK0e7YRQvCtgzBAdQMJfA7LF2',
  'XdcKbJjT8rdhOvQ2Wxh3LDWTGQO2',
];

const CHERNOR_TEACHER_ID = 'oJlr3K34sYNDHSMMU9zGc1UfCZ33';
const HADY_STUDENT_IDS = [
  'Rli19WMtFsTU16v86dmNJhQopUj1',
  'iPmhG07i8hcQFopzoSSRURHiIlj1',
];

try {
  admin.app();
} catch (_) {
  try {
    const serviceAccount = require(path.join(__dirname, '../../serviceAccountKey.json'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: 'alluwal-academy',
    });
  } catch (_) {
    admin.initializeApp({projectId: 'alluwal-academy'});
  }
}

const db = admin.firestore();
const {
  _generateShiftsForTemplate,
} = require('../handlers/shift_templates');

function localParts(ts) {
  const d = ts.toDate();
  const local = DateTime.fromJSDate(d, {zone: 'utc'}).setZone(TZ);
  return {
    weekday: local.weekday, // 1=Mon .. 7=Sun
    hour: local.hour,
    minute: local.minute,
    label: local.toFormat('ccc yyyy-MM-dd h:mm a'),
    dateKey: local.toFormat('yyyy-MM-dd'),
  };
}

function isDesiredHabibuSlot(parts) {
  // Mon-Wed 13:00
  if ([1, 2, 3].includes(parts.weekday) && parts.hour === 13 && parts.minute === 0) {
    return true;
  }
  // Thu-Sat 11:00
  if ([4, 5, 6].includes(parts.weekday) && parts.hour === 11 && parts.minute === 0) {
    return true;
  }
  return false;
}

async function deleteInChunks(refs) {
  let deleted = 0;
  for (let i = 0; i < refs.length; i += 400) {
    const chunk = refs.slice(i, i + 400);
    const batch = db.batch();
    for (const ref of chunk) batch.delete(ref);
    if (APPLY) await batch.commit();
    deleted += chunk.length;
  }
  return deleted;
}

async function fixHabibu() {
  console.log('\n=== Habibu Barry + Abdoullahi Diallo ===');
  const templateRef = db.collection('shift_templates').doc(HABIBU_TEMPLATE_ID);
  const templateSnap = await templateRef.get();
  if (!templateSnap.exists) {
    throw new Error(`Habibu template ${HABIBU_TEMPLATE_ID} not found`);
  }
  const template = templateSnap.data();
  const weekdayTimeSlots = [
    {weekday: 1, start_hour: 13, start_minute: 0, end_hour: 14, end_minute: 0},
    {weekday: 2, start_hour: 13, start_minute: 0, end_hour: 14, end_minute: 0},
    {weekday: 3, start_hour: 13, start_minute: 0, end_hour: 14, end_minute: 0},
    {weekday: 4, start_hour: 11, start_minute: 0, end_hour: 12, end_minute: 0},
    {weekday: 5, start_hour: 11, start_minute: 0, end_hour: 12, end_minute: 0},
    {weekday: 6, start_hour: 11, start_minute: 0, end_hour: 12, end_minute: 0},
  ];

  const nextRecurrence = {
    ...(template.enhanced_recurrence || {}),
    type: 'weekly',
    selectedWeekdays: [1, 2, 3, 4, 5, 6],
    useDifferentTimesPerDay: true,
    weekdayTimeSlots,
  };

  console.log('Template update:', {
    selectedWeekdays: nextRecurrence.selectedWeekdays,
    weekdayTimeSlots,
  });

  if (APPLY) {
    await templateRef.set(
      {
        start_time: '13:00',
        end_time: '14:00',
        duration_minutes: 60,
        admin_timezone: TZ,
        enhanced_recurrence: nextRecurrence,
        last_modified: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }

  const now = admin.firestore.Timestamp.now();
  const snap = await db
    .collection('teaching_shifts')
    .where('teacher_id', '==', HABIBU_TEACHER_ID)
    .where('shift_start', '>=', now)
    .get();

  const keep = [];
  const remove = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    const sids = data.student_ids || [];
    if (!sids.includes(ABDOULLAHI_STUDENT_ID)) continue;
    const parts = localParts(data.shift_start);
    const row = {id: doc.id, label: parts.label, ref: doc.ref, status: data.status};
    if (isDesiredHabibuSlot(parts)) keep.push(row);
    else remove.push(row);
  }

  console.log(`Keep ${keep.length}:`, keep.map((r) => r.label).slice(0, 12));
  console.log(`Delete ${remove.length}:`, remove.map((r) => r.label).slice(0, 20));

  const deleted = await deleteInChunks(remove.map((r) => r.ref));
  console.log(`${APPLY ? 'Deleted' : 'Would delete'} ${deleted} incorrect Habibu shifts`);

  if (APPLY) {
    const refreshed = (await templateRef.get()).data();
    const result = await _generateShiftsForTemplate({
      templateId: HABIBU_TEMPLATE_ID,
      template: refreshed,
    });
    console.log('Regenerated from template:', result);
  } else {
    console.log('Would regenerate missing Habibu slots from updated template');
  }
}

async function checkAbdullah() {
  console.log('\n=== Abdullah Baldee + Housainatou Mariam(a) ===');
  const now = admin.firestore.Timestamp.now();
  const snap = await db
    .collection('teaching_shifts')
    .where('teacher_id', '==', ABDULLAH_TEACHER_ID)
    .where('shift_start', '>=', now)
    .get();

  const byWeekday = {};
  const extras = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    const sids = data.student_ids || [];
    if (!HOUSAIN_STUDENT_IDS.some((id) => sids.includes(id))) continue;
    const parts = localParts(data.shift_start);
    byWeekday[parts.weekday] = (byWeekday[parts.weekday] || 0) + 1;
    if (![1, 2].includes(parts.weekday)) {
      extras.push({id: doc.id, label: parts.label, ref: doc.ref});
    }
  }

  console.log('Future weekday counts (1=Mon..7=Sun):', byWeekday);
  if (extras.length === 0) {
    console.log('Already Mon/Tue only — nothing to delete.');
  } else {
    console.log(`Found ${extras.length} non Mon/Tue shifts to delete`);
    await deleteInChunks(extras.map((r) => r.ref));
  }
}

async function wipeChernorHady() {
  console.log('\n=== Chernor Ahmadu Jalloh + Hady Barry (delete all) ===');
  const templatesSnap = await db
    .collection('shift_templates')
    .where('teacher_id', '==', CHERNOR_TEACHER_ID)
    .get();

  const hadyTemplates = [];
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const sids = data.student_ids || [];
    const names = data.student_names || [];
    if (
      HADY_STUDENT_IDS.some((id) => sids.includes(id)) ||
      names.some((n) => /hady\s+barry/i.test(String(n || '')))
    ) {
      hadyTemplates.push({id: doc.id, ref: doc.ref, is_active: data.is_active, students: names});
    }
  }
  console.log(
    `Hady templates to deactivate (${hadyTemplates.length}):`,
    hadyTemplates.map((t) => `${t.id} active=${t.is_active}`),
  );

  if (APPLY) {
    for (const t of hadyTemplates) {
      await t.ref.set(
        {
          is_active: false,
          deactivated_at: admin.firestore.FieldValue.serverTimestamp(),
          deactivated_reason: 'admin_schedule_cleanup_chernor_hady',
          last_modified: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }
  }

  const now = admin.firestore.Timestamp.now();
  const snap = await db
    .collection('teaching_shifts')
    .where('teacher_id', '==', CHERNOR_TEACHER_ID)
    .where('shift_start', '>=', now)
    .get();

  const toDelete = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    const sids = data.student_ids || [];
    const names = data.student_names || [];
    if (
      HADY_STUDENT_IDS.some((id) => sids.includes(id)) ||
      names.some((n) => /hady\s+barry/i.test(String(n || '')))
    ) {
      toDelete.push({
        id: doc.id,
        label: localParts(data.shift_start).label,
        ref: doc.ref,
      });
    }
  }
  console.log(
    `Future Hady shifts to delete (${toDelete.length}):`,
    toDelete.map((r) => r.label),
  );
  const deleted = await deleteInChunks(toDelete.map((r) => r.ref));
  console.log(`${APPLY ? 'Deleted' : 'Would delete'} ${deleted} Chernor+Hady shifts`);
}

async function main() {
  console.log(APPLY ? 'APPLY MODE — writing to Firestore' : 'DRY RUN — no writes');
  await fixHabibu();
  await checkAbdullah();
  await wipeChernorHady();
  console.log('\nDone.');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
