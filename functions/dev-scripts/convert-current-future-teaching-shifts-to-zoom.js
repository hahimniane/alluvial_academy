/**
 * Convert current/future teaching shifts and active teaching templates to Zoom.
 *
 * Run from functions/:
 *   node dev-scripts/convert-current-future-teaching-shifts-to-zoom.js
 *   node dev-scripts/convert-current-future-teaching-shifts-to-zoom.js --apply
 */

const admin = require('firebase-admin');

const PROJECT_ID = process.env.FIREBASE_PROJECT || 'alluwal-academy';
const APPLY = process.argv.includes('--apply') || process.env.DRY_RUN === 'false';
const BATCH_LIMIT = 400;
const SAFE_HUB_MAX_MINUTES = 28 * 60;

admin.initializeApp({ projectId: PROJECT_ID });

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const toDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  const parsed = new Date(value);
  return Number.isFinite(parsed.getTime()) ? parsed : null;
};

const isTeaching = (data) => (
  String(data.category || data.shift_category || 'teaching')
    .trim()
    .toLowerCase() === 'teaching'
);

const durationMinutes = (start, end) => {
  if (!start || !end) return null;
  return Math.max(0, Math.round((end.getTime() - start.getTime()) / 60000));
};

const routingUpdateForShift = (data) => {
  const start = toDate(data.shift_start || data.shiftStart);
  const end = toDate(data.shift_end || data.shiftEnd);
  const minutes = durationMinutes(start, end);
  const base = {
    video_provider: 'zoom',
    zoom_routing_updated_at: FieldValue.serverTimestamp(),
    updated_at: FieldValue.serverTimestamp(),
    last_modified: FieldValue.serverTimestamp(),
  };

  if (minutes != null && minutes > SAFE_HUB_MAX_MINUTES) {
    return {
      ...base,
      zoomRoutingMode: 'single',
      zoom_routing_mode: 'single',
      zoom_disable_hub_routing: true,
      zoomDisableHubRouting: true,
      zoom_hub_fallback_reason: 'hub_window_exceeds_zoom_lifetime',
    };
  }

  return {
    ...base,
    zoomRoutingMode: 'hub',
    zoom_routing_mode: 'hub',
    zoom_disable_hub_routing: FieldValue.delete(),
    zoomDisableHubRouting: FieldValue.delete(),
    zoom_hub_fallback_reason: FieldValue.delete(),
  };
};

const commitBatchIfNeeded = async ({ batch, count, force = false }) => {
  if (!APPLY || count === 0 || (!force && count < BATCH_LIMIT)) {
    return { batch, count };
  }
  await batch.commit();
  return { batch: db.batch(), count: 0 };
};

async function convertShifts() {
  const now = admin.firestore.Timestamp.fromDate(new Date());
  const snapshot = await db.collection('teaching_shifts')
    .where('shift_end', '>=', now)
    .get();

  let batch = db.batch();
  let count = 0;
  const stats = {
    scanned: snapshot.size,
    teaching: 0,
    hub: 0,
    singleOverlong: 0,
    alreadyZoomHub: 0,
  };

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    if (!isTeaching(data)) continue;
    stats.teaching += 1;

    const update = routingUpdateForShift(data);
    if (update.zoom_routing_mode === 'single') {
      stats.singleOverlong += 1;
    } else {
      stats.hub += 1;
      if (
        String(data.video_provider || data.videoProvider || '').toLowerCase() === 'zoom' &&
        String(data.zoom_routing_mode || data.zoomRoutingMode || '').toLowerCase() === 'hub' &&
        data.zoom_disable_hub_routing !== true &&
        data.zoomDisableHubRouting !== true
      ) {
        stats.alreadyZoomHub += 1;
      }
    }

    if (APPLY) {
      batch.set(doc.ref, update, { merge: true });
      count += 1;
      const reset = await commitBatchIfNeeded({ batch, count });
      batch = reset.batch;
      count = reset.count;
    }
  }

  await commitBatchIfNeeded({ batch, count, force: true });
  return stats;
}

async function convertTemplates() {
  const snapshot = await db.collection('shift_templates').get();
  let batch = db.batch();
  let count = 0;
  const stats = {
    scanned: snapshot.size,
    teachingActive: 0,
    updated: 0,
  };

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    if (data.is_active === false) continue;
    if (!isTeaching(data)) continue;
    stats.teachingActive += 1;
    stats.updated += 1;

    if (APPLY) {
      batch.set(doc.ref, {
        video_provider: 'zoom',
        updated_at: FieldValue.serverTimestamp(),
        last_modified: FieldValue.serverTimestamp(),
      }, { merge: true });
      count += 1;
      const reset = await commitBatchIfNeeded({ batch, count });
      batch = reset.batch;
      count = reset.count;
    }
  }

  await commitBatchIfNeeded({ batch, count, force: true });
  return stats;
}

async function main() {
  console.log(`[convert-current-future-teaching-shifts-to-zoom] project=${PROJECT_ID} mode=${APPLY ? 'apply' : 'dry-run'}`);
  const shiftStats = await convertShifts();
  const templateStats = await convertTemplates();
  console.log(JSON.stringify({ shiftStats, templateStats }, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
